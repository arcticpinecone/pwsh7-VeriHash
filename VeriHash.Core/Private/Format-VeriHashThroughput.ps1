function Format-VeriHashThroughput {
    <#
    .SYNOPSIS
        Renders hash throughput as '~<n> MB/s' or '~<n> GB/s'.
    .DESCRIPTION
        Spec rule: one decimal below 10 MB/s, integer otherwise, GB/s at or
        above 1000 MB/s. ElapsedMs is clamped to a 1 ms floor so sub-millisecond
        hashes of tiny files cannot divide by zero.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [long]$Bytes,

        [Parameter(Mandatory)]
        [int]$ElapsedMs
    )
    $inv  = [cultureinfo]::InvariantCulture
    $ms   = if ($ElapsedMs -lt 1) { 1 } else { $ElapsedMs }
    $mbps = ([double]$Bytes / 1MB) / ($ms / 1000.0)

    if ($mbps -ge 1000) { return '~' + ($mbps / 1024).ToString('0.0', $inv) + ' GB/s' }
    if ($mbps -lt 10)   { return '~' + $mbps.ToString('0.0', $inv) + ' MB/s' }
    return '~' + ([Math]::Round($mbps)).ToString($inv) + ' MB/s'
}
