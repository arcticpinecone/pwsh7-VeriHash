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

        Sidecar writes are suppressed whenever ANY check proved the file bad -- the
        comparator's verdict or the sidecar's own -- because a file that failed
        verification must never have its hash recorded as if it were authoritative.
        The algorithm is chosen before any hashing starts, by precedence:

            explicit -Algorithm  >  supported clipboard hash  >  SHA256

        An explicit flag is a choice; the clipboard is a question; a choice
        outranks a question. A WEAK primary (MD5, SHA1) additionally earns a
        SHA256 companion computed in its own ThreadJob, so a vendor who
        published only an MD5 still gets their question answered while the user
        still receives the digest worth keeping.
    .PARAMETER Path
        File to hash + verify. Resolved with Resolve-Path -LiteralPath.
    .PARAMETER Algorithm
        MD5 | SHA1 | SHA256 (default) | SHA512.

        Bound explicitly, it outranks the clipboard. Left unbound, a recognised
        clipboard hash selects it -- which is why the code tests
        $PSBoundParameters rather than comparing against 'SHA256': a
        default-valued parameter is otherwise indistinguishable from one the
        caller set to the same value on purpose.
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

        [ValidateSet('MD5', 'SHA1', 'SHA256', 'SHA512')]
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

    # --- algorithm selection, BEFORE any hashing ----------------------------
    # The clipboard is read here rather than after the hash job because it can
    # decide what the hash job computes. One Get-Clipboard is not measurable
    # against a file read.
    $clip = $null
    try { $clip = Read-ClipboardHash -ErrorAction SilentlyContinue } catch { $clip = $null }

    $explicitAlgorithm = $PSBoundParameters.ContainsKey('Algorithm')
    $clipboardChose    = (-not $explicitAlgorithm) -and $clip -and $clip.Algorithm
    $primary           = if ($explicitAlgorithm)     { $Algorithm }
                         elseif ($clipboardChose)    { [string]$clip.Algorithm }
                         else                        { 'SHA256' }

    # A weak primary answers the user's question but is not worth keeping. The
    # companion is what gets recorded; see the sidecar section below.
    $companionAlgorithm = if ($primary -in @('MD5', 'SHA1')) { 'SHA256' } else { $null }

    $hashJob = Start-ThreadJob -Name 'hash' -InitializationScript $hashInit -ScriptBlock {
        param($p, $algo)
        Get-VeriHashResult -Path $p -Algorithm $algo
    } -ArgumentList $resolved, $primary

    $companionJob = if ($companionAlgorithm) {
        Start-ThreadJob -Name 'companion' -InitializationScript $hashInit -ScriptBlock {
            param($p, $algo)
            Get-VeriHashResult -Path $p -Algorithm $algo
        } -ArgumentList $resolved, $companionAlgorithm
    } else { $null }

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

    $companionResult = $null
    if ($companionJob) {
        do {
            $null = Wait-Job -Job @($companionJob) -Any -Timeout 1
        } until ($companionJob.State -in 'Completed', 'Failed', 'Stopped')
        $companionResult = Receive-Job -Job $companionJob -Wait -AutoRemoveJob
    }

    # The SHA256 digest for this run, whichever job produced it. This is what
    # gets recorded on disk and what answers a .sha256 sidecar for free.
    $sha256Result = if ($primary -eq 'SHA256')     { $hashResult }
                    elseif ($null -ne $companionResult) { $companionResult }
                    else                           { $null }

    $sidecar = $null
    # -ComputedResult hands the sidecar check the digest we are already holding.
    # Without it, Test-VeriHashSidecar makes a SECOND full pass over the file to
    # recompute a hash we have -- on a 600 MB installer that doubled the wall
    # clock.
    #
    # -Algorithm pins the search on weak-primary runs. Unpinned,
    # Get-PreferredSidecar would happily pick the .sha512 or .md5 sitting next
    # to the file and force that second pass anyway, precisely on the primary
    # workflow (paste a hash, Send To) and precisely on files verified before,
    # which is when a sidecar exists at all. Pinned to SHA256, the companion
    # digest answers it for nothing. Strong-primary runs stay unpinned, because
    # a .sha512 that proves a file corrupt is worth re-hashing for (CMP-11).
    $sidecarSplat = @{ Path = $resolved; ErrorAction = 'SilentlyContinue' }
    if ($null -ne $sha256Result) { $sidecarSplat['ComputedResult'] = $sha256Result }
    else                         { $sidecarSplat['ComputedResult'] = $hashResult }
    if ($companionAlgorithm)     { $sidecarSplat['Algorithm']      = $companionAlgorithm }
    try { $sidecar = Test-VeriHashSidecar @sidecarSplat } catch { $sidecar = $null }

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
    # Same function the renderer calls. The banner and the sidecar-write
    # decision MUST agree -- a checklist that says 'created' under a MISMATCH
    # banner would be reporting a write that never should have happened -- and
    # the only way to guarantee agreement is to ask once, not to restate the
    # rule here and hope the two copies stay in step. They did not.
    $comparator   = Resolve-VeriHashComparator -CompareTo $clip -SidecarInfo $sidecar -ComputedAlgorithm $primary
    $expectedHash = $comparator.ExpectedHash
    $isMismatch   = ($null -ne $expectedHash) -and ($hashResult.Hash -ne $expectedHash)

    # --- sidecar creation/update ---------------------------------------------
    # Never write over a sidecar for a file that failed verification.
    #
    # Suppression is keyed off ALL available negative evidence, not off the
    # comparator's verdict alone. Test-VeriHashSidecar independently compares
    # the file against its sidecar using THAT sidecar's algorithm, re-hashing
    # when it has to, and a 'mismatch' from it is a real fact about the file.
    # When the comparator abstains -- an unusable clipboard, or a .sha512
    # sidecar under a SHA256 run -- $isMismatch is false, and keying only off
    # it would overwrite a good vendor hash with a corrupt file's digest and
    # report the write as a green checklist row. The algorithm guard exists to
    # stop VeriHash COMPARING across algorithms; it must not stop VeriHash
    # BELIEVING a comparison something else already made correctly.
    $sidecarProvenBad = ($null -ne $sidecar) -and ($sidecar.SidecarStatus -eq 'mismatch')
    $suppressWrite    = $isMismatch -or $sidecarProvenBad

    # The sidecar records the digest worth KEEPING, which is never the weak one.
    # A vendor's choice of MD5 is a fact about their release page, not a reason
    # to leave a weak permanent record beside the user's file -- and
    # Get-PreferredSidecar ranks .sha512 > .sha256 > .md5, so a .md5 written
    # once would be a weak file that a LATER run could promote to the trusted
    # comparator. Never writing it closes that path entirely.
    $sidecarAlgorithm = if ($companionAlgorithm) { $companionAlgorithm } else { $primary }
    $sidecarResult    = if ($companionAlgorithm) { $sha256Result }       else { $hashResult }

    $algoExtMap = @{ 'SHA256' = '.sha256'; 'SHA512' = '.sha512' }
    $algoExt    = $algoExtMap[$sidecarAlgorithm]
    if (-not $algoExt -or -not $sidecarResult) {
        # A hashtable miss returns $null, not an error, which would make
        # $sidecarPath equal $resolved -- and the write below would replace the
        # file being verified with a 100-byte text file, reporting '+ updated'.
        # MD5 and SHA1 are deliberately absent from the map: reaching here with
        # one means the companion rule above failed to run, and a loud stop is
        # the only acceptable outcome.
        throw "unmapped algorithm '$sidecarAlgorithm' -- refusing to derive a sidecar path"
    }
    $sidecarPath     = "$resolved$algoExt"
    $sidecarLeaf     = [System.IO.Path]::GetFileName($sidecarPath)
    $sidecarLeafName = Split-Path -Leaf $resolved
    $sidecarRecord   = $sidecar

    if ($suppressWrite) {
        # An existing sidecar record already describes itself accurately
        # (matched / mismatch / error); only synthesize when there is nothing.
        if ($null -eq $sidecarRecord) {
            $sidecarRecord = [pscustomobject]@{
                SidecarStatus = 'none'
                SidecarName   = $sidecarLeaf
                Algorithm     = $sidecarAlgorithm
                ExpectedHash  = $null
            }
        }
    } else {
        $sidecarVerb = 'created'
        $shouldWrite = $true
        if (Test-Path -LiteralPath $sidecarPath) {
            $existingLine = (Get-Content -LiteralPath $sidecarPath -TotalCount 1)
            if ($existingLine -match '^([A-Fa-f0-9]+)\s' -and $matches[1].ToLowerInvariant() -eq $sidecarResult.Hash) {
                $shouldWrite = $false
            } else {
                $sidecarVerb = 'updated'
            }
        }
        if ($shouldWrite) {
            $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
            [System.IO.File]::WriteAllText($sidecarPath, "$($sidecarResult.Hash) *$sidecarLeafName`n", $utf8NoBom)
            # ExpectedHash stays $null on purpose: a sidecar VeriHash just wrote
            # from this very hash is not evidence of anything, and handing it to
            # the renderer as a comparator would claim a match against ourselves.
            $sidecarRecord = [pscustomobject]@{
                SidecarStatus = $sidecarVerb
                SidecarName   = $sidecarLeaf
                Algorithm     = $sidecarAlgorithm
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
    if ($null -ne $clip)            { $reportSplat['CompareTo']   = $clip }
    if ($null -ne $sidecarRecord)   { $reportSplat['SidecarInfo'] = $sidecarRecord }
    if ($null -ne $companionResult) { $reportSplat['Companion']   = $companionResult }
    if ($clipboardChose)            { $reportSplat['ClipboardChoseAlgorithm'] = $true }
    if ($Compact)                   { $reportSplat['Compact']     = $true }
    Format-VeriHashReport @reportSplat

    # Reuses the verdict computed above rather than re-deriving it. The previous
    # rule compared against $sidecar.Hash, which Test-VeriHashSidecar sets to the
    # COMPUTED digest of this same file -- a value compared against itself. It
    # could never report a same-algorithm mismatch (a corrupted file tallied
    # green), and it always reported one when the sidecar's algorithm differed
    # from this run (a false alarm on a good file). The expected value lives in
    # $sidecar.ExpectedHash, which $expectedHash already reads with the
    # algorithm guard the banner uses.
    # An unusable comparator must not report 'matched'. The user asked a
    # question and got no answer; labelling that with the word for a successful
    # verification is survivable in the single-file view (the yellow banner is
    # right there) but not in batch, where the banners scroll away and the
    # tally is all that remains.
    #
    # Source 'none' still reports 'matched' -- a plain hash-only run, where the
    # user never asked anything, has reported that since v2.0 and nobody is
    # misled by it.
    $hasComparator = ($null -ne $expectedHash)
    $matchResult   = if ($isMismatch) { 'mismatch' }
                     elseif ($comparator.Source -eq 'unusable') { 'unverified' }
                     else { 'matched' }

    $sigSkippedNonPE = (-not $isPE) -and ($sigResult.Status -eq 'skipped')
    $effectiveSigMs = if ($sigSkippedNonPE) { 0 } else { $sigDoneMs }

    if ($Log -or $env:VERIHASH_LOG -eq '1') {
        $size = if ($null -ne $hashResult.Size) { [int64]$hashResult.Size } else { 0 }
        $logOp     = if ($hasComparator) { 'verify' } else { 'hash' }
        $logResult = if ($hasComparator) { if ($matchResult -eq 'matched') { 'ok' } else { 'mismatch' } } else { 'n/a' }
        Write-VeriHashLog -Op $logOp -Algorithm $primary -Hash $hashResult.Hash `
            -Bytes $size -ElapsedMs $wallMs -Result $logResult -Path $resolved -Log:$Log
    }

    return [pscustomobject]@{
        PSTypeName       = 'VeriHash.HotPathResult'
        FilePath         = $resolved
        Hash             = $hashResult.Hash
        HashAlgorithm    = $primary
        HashElapsedMs    = [int]($hashResult.ElapsedMs)
        Signature        = $sigResult.Status
        SignatureReason  = [string]$sigResult.Reason
        SigElapsedMs     = $effectiveSigMs
        WallClockMs      = $wallMs
        IsPE             = [bool]$isPE
        MatchResult      = $matchResult
        # $null on the common strong-algorithm run. Present only when a weak
        # primary earned a companion, so a caller can tell 'no companion ran'
        # from 'the companion is the same as the primary'.
        CompanionAlgorithm = $companionAlgorithm
        CompanionHash      = if ($null -ne $companionResult) { $companionResult.Hash } else { $null }
    }
}
