function Invoke-VeriHashHotPath {
    <#
    .SYNOPSIS
        Single-file hot-path orchestrator: PE-detect, parallel hash+sig via ThreadJob, stream output, return result.
    .DESCRIPTION
        Runs Get-VeriHashResult and Get-VeriHashSignature in two parallel ThreadJobs (D-A3-1).
        Hash ThreadJob imports VeriHash.Core via -InitializationScript; Sig ThreadJob imports
        VeriHash.HotPath via -InitializationScript (D-A3-2). Polls jobs with Wait-Job -Any
        (D-A3-3), then hands every collected fact -- hash, clipboard, sidecar, signature --
        to a SINGLE Format-VeriHashReport call. The signature is a checklist row, not a
        trailing line, so nothing is rendered until both jobs are in. Wraps the entire
        orchestration in a Stopwatch for WallClockMs (PERF-05), stopping it just before
        the render so the reported total and WallClockMs are one number.

        The file is hashed exactly ONCE: the hash job's digest is handed to the sidecar
        check via -ComputedResult rather than recomputed there.
        Returns VeriHash.HotPathResult.

        Sidecar writes are suppressed when the verdict is MISMATCH: a file that failed
        verification must never have its hash recorded as if it were authoritative.
    .PARAMETER Path
        File to hash + verify. Resolved with Resolve-Path -LiteralPath.
    .PARAMETER Algorithm
        MD5 | SHA256 (default) | SHA512.
    .PARAMETER Log
        When set (or $env:VERIHASH_LOG=1), writes one plain-text line per file.
    .PARAMETER Compact
        Render the condensed per-file report used by batch mode: header, banner,
        and checklist only. The hash comparison block survives a MISMATCH, because
        a file that failed is exactly the one whose divergence the user must see.
    .OUTPUTS
        VeriHash.HotPathResult
    #>
    [CmdletBinding()]
    [OutputType('VeriHash.HotPathResult')]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [ValidateSet('MD5', 'SHA256', 'SHA512')]
        [string]$Algorithm = 'SHA256',

        [switch]$Log,

        # Batch mode: render the condensed per-file view (header, banner, checklist).
        [switch]$Compact
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    $isPE     = Test-IsPEFile -Path $resolved

    $coreModule    = Get-Module VeriHash.Core
    $hotPathModule = Get-Module VeriHash.HotPath
    $corePsd1 = if ($coreModule) {
        $coreModule.Path
    } else {
        Join-Path $PSScriptRoot '..\..\VeriHash.Core\VeriHash.Core.psd1'
    }
    $hotPathPsd1 = if ($hotPathModule) {
        $hotPathModule.Path
    } else {
        Join-Path $PSScriptRoot '..\..\VeriHash.HotPath\VeriHash.HotPath.psd1'
    }

    $hashInit = [scriptblock]::Create("Import-Module '$corePsd1' -Force")
    $sigInit  = [scriptblock]::Create("Import-Module '$hotPathPsd1' -Force")

    $hashJob = Start-ThreadJob -Name 'hash' -InitializationScript $hashInit -ScriptBlock {
        param($p, $algo)
        Get-VeriHashResult -Path $p -Algorithm $algo
    } -ArgumentList $resolved, $Algorithm

    $sigSw  = [System.Diagnostics.Stopwatch]::StartNew()
    $sigJob = Start-ThreadJob -Name 'sig' -InitializationScript $sigInit -ScriptBlock {
        param($p, $isPE)
        Get-VeriHashSignature -Path $p -IsPE:$isPE
    } -ArgumentList $resolved, $isPE

    $bothJobs = @($hashJob, $sigJob)

    # Poll with Wait-Job -Any (D-A3-3), but proceed past the hash stanza only after
    # the hash job specifically completes. This preserves the streaming contract
    # (PERF-04: hash line printed before signature line in the common case).
    do {
        $null = Wait-Job -Job $bothJobs -Any -Timeout 1
    } until ($hashJob.State -in 'Completed', 'Failed', 'Stopped')

    $hashResult = Receive-Job -Job $hashJob -Wait -AutoRemoveJob

    $clip    = $null
    $sidecar = $null
    try { $clip    = Read-ClipboardHash -ErrorAction SilentlyContinue }    catch { $clip = $null }
    # -ComputedResult hands the sidecar check the digest the hash job just produced.
    # Without it, Test-VeriHashSidecar makes a SECOND full pass over the file to
    # recompute a hash we are already holding -- on a 600 MB installer that doubled
    # the wall clock. It still re-hashes on its own when the strongest sidecar uses
    # a different algorithm, which is the only case where our digest cannot answer.
    try { $sidecar = Test-VeriHashSidecar -Path $resolved -ComputedResult $hashResult -ErrorAction SilentlyContinue } catch { $sidecar = $null }

    # Now wait for the sig job to complete (Wait-Job -Any again so the orchestrator
    # never blocks on sig if the hash job overshoots due to disk pressure). The
    # report is a single block covering hash AND signature, so it cannot be
    # rendered until both facts are in hand.
    do {
        $null = Wait-Job -Job @($sigJob) -Any -Timeout 1
    } until ($sigJob.State -in 'Completed', 'Failed', 'Stopped')

    $sigResult = Receive-Job -Job $sigJob -Wait -AutoRemoveJob
    $sigDoneMs = [int]$sigSw.ElapsedMilliseconds
    if ($null -eq $sigResult) {
        $sigResult = [pscustomobject]@{ Status = 'error'; Reason = 'sig job returned no payload'; Signer = $null }
    }

    # --- verdict -------------------------------------------------------------
    # Mirrors Format-VeriHashReport's comparator rule exactly (clipboard wins;
    # sidecar is a same-algorithm fallback). The banner and the sidecar-write
    # decision MUST agree -- a checklist that says 'created' under a MISMATCH
    # banner would be reporting a write that never should have happened.
    $expectedHash = $null
    if ($clip -and $clip.Hash) {
        $expectedHash = ([string]$clip.Hash).ToLowerInvariant()
    } elseif ($sidecar -and $sidecar.ExpectedHash -and $sidecar.Algorithm -eq $Algorithm) {
        $expectedHash = ([string]$sidecar.ExpectedHash).ToLowerInvariant()
    }
    $isMismatch = ($null -ne $expectedHash) -and ($hashResult.Hash -ne $expectedHash)

    # --- sidecar creation/update ---------------------------------------------
    # Never write over a sidecar for a file that failed verification (spec:
    # 'do NOT write/update a sidecar when the clipboard verdict is MISMATCH').
    $algoExtMap      = @{ 'SHA256' = '.sha256'; 'SHA512' = '.sha512'; 'MD5' = '.md5' }
    $sidecarPath     = "$resolved$($algoExtMap[$Algorithm])"
    $sidecarLeaf     = [System.IO.Path]::GetFileName($sidecarPath)
    $sidecarLeafName = Split-Path -Leaf $resolved
    $sidecarRecord   = $sidecar

    if ($isMismatch) {
        # An existing sidecar record already describes itself accurately
        # (matched / mismatch / error); only synthesize when there is nothing.
        if ($null -eq $sidecarRecord) {
            $sidecarRecord = [pscustomobject]@{
                SidecarStatus = 'none'
                SidecarName   = $sidecarLeaf
                Algorithm     = $Algorithm
                ExpectedHash  = $null
            }
        }
    } else {
        $sidecarVerb = 'created'
        $shouldWrite = $true
        if (Test-Path -LiteralPath $sidecarPath) {
            $existingLine = (Get-Content -LiteralPath $sidecarPath -TotalCount 1)
            if ($existingLine -match '^([A-Fa-f0-9]+)\s' -and $matches[1].ToLowerInvariant() -eq $hashResult.Hash) {
                $shouldWrite = $false
            } else {
                $sidecarVerb = 'updated'
            }
        }
        if ($shouldWrite) {
            $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
            [System.IO.File]::WriteAllText($sidecarPath, "$($hashResult.Hash) *$sidecarLeafName`n", $utf8NoBom)
            # ExpectedHash stays $null on purpose: a sidecar VeriHash just wrote
            # from this very hash is not evidence of anything, and handing it to
            # the renderer as a comparator would claim a match against ourselves.
            $sidecarRecord = [pscustomobject]@{
                SidecarStatus = $sidecarVerb
                SidecarName   = $sidecarLeaf
                Algorithm     = $Algorithm
                ExpectedHash  = $null
            }
        }
    }

    # --- single unified render ------------------------------------------------
    # Stop the clock BEFORE rendering so the total the report prints and the
    # WallClockMs the caller receives are the same number. Two timings that differ
    # by the cost of drawing the report is exactly the contradiction this block is
    # meant to resolve; rendering is output, not verification work.
    $sw.Stop()
    $wallMs = [int]$sw.ElapsedMilliseconds

    $reportSplat = @{ Result = $hashResult; Signature = $sigResult; TotalMs = $wallMs }
    if ($null -ne $clip)          { $reportSplat['CompareTo']   = $clip }
    if ($null -ne $sidecarRecord) { $reportSplat['SidecarInfo'] = $sidecarRecord }
    if ($Compact)                 { $reportSplat['Compact']     = $true }
    Format-VeriHashReport @reportSplat

    # Reuses the verdict computed above rather than re-deriving it. The previous
    # rule compared against $sidecar.Hash, which Test-VeriHashSidecar sets to the
    # COMPUTED digest of this same file -- a value compared against itself. It
    # could never report a same-algorithm mismatch (a corrupted file tallied
    # green), and it always reported one when the sidecar's algorithm differed
    # from this run (a false alarm on a good file). The expected value lives in
    # $sidecar.ExpectedHash, which $expectedHash already reads with the
    # algorithm guard the banner uses.
    $hasComparator = ($null -ne $expectedHash)
    $matchResult   = if ($isMismatch) { 'mismatch' } else { 'matched' }

    $sigSkippedNonPE = (-not $isPE) -and ($sigResult.Status -eq 'skipped')
    $effectiveSigMs = if ($sigSkippedNonPE) { 0 } else { $sigDoneMs }

    if ($Log -or $env:VERIHASH_LOG -eq '1') {
        $size = if ($null -ne $hashResult.Size) { [int64]$hashResult.Size } else { 0 }
        $logOp     = if ($hasComparator) { 'verify' } else { 'hash' }
        $logResult = if ($hasComparator) { if ($matchResult -eq 'matched') { 'ok' } else { 'mismatch' } } else { 'n/a' }
        Write-VeriHashLog -Op $logOp -Algorithm $Algorithm -Hash $hashResult.Hash `
            -Bytes $size -ElapsedMs $wallMs -Result $logResult -Path $resolved -Log:$Log
    }

    return [pscustomobject]@{
        PSTypeName       = 'VeriHash.HotPathResult'
        FilePath         = $resolved
        Hash             = $hashResult.Hash
        HashAlgorithm    = $Algorithm
        HashElapsedMs    = [int]($hashResult.ElapsedMs)
        Signature        = $sigResult.Status
        SignatureReason  = [string]$sigResult.Reason
        SigElapsedMs     = $effectiveSigMs
        WallClockMs      = $wallMs
        IsPE             = [bool]$isPE
        MatchResult      = $matchResult
    }
}
