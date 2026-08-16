function Get-VeriHashHexLength {
    <#
    .SYNOPSIS
        Hex-character length of a digest for a given algorithm.
    .DESCRIPTION
        One map, so algorithm-to-length never disagrees with itself across
        call sites. ConvertTo-VeriHashAlgorithm validates prefixed pastes with
        it; Resolve-VeriHashComparator asserts on it.
    .OUTPUTS
        System.Int32 -- 0 for an unknown algorithm.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [string]$Algorithm
    )
    $map = @{ MD5 = 32; SHA256 = 64; SHA512 = 128 }
    $len = $map[$Algorithm.ToUpperInvariant()]
    if ($null -eq $len) { return 0 }
    return [int]$len
}
