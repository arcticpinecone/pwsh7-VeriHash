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
    # SHA1 is here because vendors still publish it, not because VeriHash
    # endorses it. It is answerable as a question; it is never written as a
    # durable record -- see the sidecar rule in Invoke-VeriHashHotPath.
    $map = @{ MD5 = 32; SHA1 = 40; SHA256 = 64; SHA512 = 128 }
    $len = $map[$Algorithm.ToUpperInvariant()]
    if ($null -eq $len) { return 0 }
    return [int]$len
}
