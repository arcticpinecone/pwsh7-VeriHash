function Invoke-VeriHashHotPath {
    <#
    .SYNOPSIS
        Single-file hot-path orchestrator: PE-detect, parallel hash+sig via ThreadJob, stream output, return result.
    .DESCRIPTION
        Runs Get-VeriHashResult and Get-VeriHashSignature in two parallel ThreadJobs (D-A3-1).
        Hash ThreadJob imports VeriHash.Core via -InitializationScript; Sig ThreadJob imports
        VeriHash.HotPath via -InitializationScript (D-A3-2). Polls jobs with Wait-Job -Any
        (D-A3-3) and renders the hash stanza via Format-VeriHashReport once the hash job
        completes, then renders the signature stanza via Write-Host once the sig job
        completes. Wraps the entire orchestration in a Stopwatch for WallClockMs (PERF-05).
        Returns VeriHash.HotPathResult.
    .PARAMETER Path
        File to hash + verify. Resolved with Resolve-Path -LiteralPath.
    .PARAMETER Algorithm
        MD5 | SHA256 (default) | SHA512.
    .PARAMETER Log
        When set (or $env:VERIHASH_LOG=1), writes one plain-text line per file.
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

        [switch]$Log
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
    try { $sidecar = Test-VeriHashSidecar -Path $resolved -ErrorAction SilentlyContinue } catch { $sidecar = $null }

    $reportSplat = @{ Result = $hashResult }
    if ($null -ne $clip)    { $reportSplat['CompareTo']   = $clip }
    if ($null -ne $sidecar) { $reportSplat['SidecarInfo'] = $sidecar }
    Format-VeriHashReport @reportSplat

    # Now wait for the sig job to complete (Wait-Job -Any again so the orchestrator
    # never blocks on sig if the hash job overshoots due to disk pressure).
    do {
        $null = Wait-Job -Job @($sigJob) -Any -Timeout 1
    } until ($sigJob.State -in 'Completed', 'Failed', 'Stopped')

    $sigResult = Receive-Job -Job $sigJob -Wait -AutoRemoveJob
    $sigDoneMs = [int]$sigSw.ElapsedMilliseconds
    if ($null -eq $sigResult) {
        $sigResult = [pscustomobject]@{ Status = 'error'; Reason = 'sig job returned no payload' }
    }

    $sigLine = "Signature: $($sigResult.Status)" + $(if ($sigResult.Reason) { " ($($sigResult.Reason))" } else { '' })
    $sigColor = switch ($sigResult.Status) {
        'valid'    { 'Green' }
        'invalid'  { 'Red' }
        'unsigned' { 'Yellow' }
        'skipped'  { 'DarkGray' }
        default    { 'Magenta' }
    }
    Write-Host $sigLine -ForegroundColor $sigColor

    $sw.Stop()
    $wallMs = [int]$sw.ElapsedMilliseconds

    $matchResult = 'matched'
    $hasComparator = $false
    if ($null -ne $clip -and $clip.Hash) {
        $hasComparator = $true
        if ($hashResult.Hash -ne $clip.Hash) { $matchResult = 'mismatch' }
    }
    if ($null -ne $sidecar -and $sidecar.Hash) {
        $hasComparator = $true
        if ($hashResult.Hash -ne $sidecar.Hash) { $matchResult = 'mismatch' }
    }

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
