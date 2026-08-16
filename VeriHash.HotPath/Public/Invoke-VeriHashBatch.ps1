function Invoke-VeriHashBatch {
    <#
    .SYNOPSIS
        Multi-file hot-path loop: per-file Invoke-VeriHashHotPath, accumulate tally, emit byte-locked tally line.
    .DESCRIPTION
        Sequential foreach over $FilePath (D-A4-1: no per-file parallelism -- preserves output ordering).
        Per-file failure (file not found, hash error, etc.) is caught and bucketed as 'missing'
        (D-A4-3 continue-and-tally -- never fail-fast in batch mode). Tally has exactly 3 buckets:
        matched, mismatch, missing (D-A4-2). TallyLine string format is byte-locked
        (CONTEXT.md <specifics>): '<m>/<N> matched, <x> mismatch, <z> missing'.
    .PARAMETER FilePath
        One or more file paths to process.
    .PARAMETER Algorithm
        MD5 | SHA256 (default) | SHA512. Applied to all files.
    .PARAMETER Log
        Pass through to Invoke-VeriHashHotPath (one log line per file).
    .OUTPUTS
        VeriHash.BatchResult
    #>
    [CmdletBinding()]
    [OutputType('VeriHash.BatchResult')]
    param(
        [Parameter(Mandatory)]
        [string[]]$FilePath,

        [ValidateSet('MD5', 'SHA256', 'SHA512')]
        [string]$Algorithm = 'SHA256',

        [switch]$Log
    )

    $results  = New-Object 'System.Collections.Generic.List[object]'
    $matched  = 0
    $mismatch = 0
    $missing  = 0

    foreach ($p in $FilePath) {
        try {
            $r = Invoke-VeriHashHotPath -Path $p -Algorithm $Algorithm -Log:$Log
            $results.Add($r)
            switch ($r.MatchResult) {
                'matched'  { $matched++ }
                'mismatch' { $mismatch++ }
                default    { $missing++ }
            }
        } catch {
            $missing++
            $results.Add([pscustomobject]@{
                PSTypeName       = 'VeriHash.HotPathResult'
                FilePath         = $p
                Hash             = $null
                HashAlgorithm    = $Algorithm
                HashElapsedMs    = 0
                Signature        = 'error'
                SignatureReason  = "$($_.Exception.Message)"
                SigElapsedMs     = 0
                WallClockMs      = 0
                IsPE             = $false
                MatchResult      = 'missing'
            })
        }
    }

    # Byte-locked tally line -- DO NOT REFORMAT (CONTEXT.md <specifics>; MULTI-02 success-criterion test pins this string).
    $tallyLine = '{0}/{1} matched, {2} mismatch, {3} missing' -f $matched, $FilePath.Count, $mismatch, $missing
    Write-Host $tallyLine -ForegroundColor Yellow

    return [pscustomobject]@{
        PSTypeName = 'VeriHash.BatchResult'
        Results    = $results.ToArray()
        Tally      = @{ Total = $FilePath.Count; Matched = $matched; Mismatch = $mismatch; Missing = $missing }
        TallyLine  = $tallyLine
    }
}
