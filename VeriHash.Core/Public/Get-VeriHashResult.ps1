function Get-VeriHashResult {
    <#
    .SYNOPSIS
        Computes a single file hash and returns a VeriHash.Result object.
    .DESCRIPTION
        Pure hash compute. Returns a [pscustomobject] with PSTypeName
        'VeriHash.Result' carrying FilePath, Size, Algorithm, Hash (lowercase
        hex), and ElapsedMs.
    .PARAMETER Path
        Filesystem path to the file to hash. Resolved with -LiteralPath.
    .PARAMETER Algorithm
        One of 'MD5', 'SHA256', 'SHA512'. Default 'SHA256'.
    .OUTPUTS
        VeriHash.Result
    #>
    [CmdletBinding()]
    [OutputType('VeriHash.Result')]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [ValidateSet('MD5', 'SHA256', 'SHA512')]
        [string]$Algorithm = 'SHA256'
    )
    $null = $PSBoundParameters
    throw 'NotImplemented: Get-VeriHashResult -- implemented in plan 01-02'
}
