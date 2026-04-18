function ConvertTo-VeriHashAlgorithm {
    <#
    .SYNOPSIS
        Maps a hash hex string (or '<algo>:<hex>' prefixed form) to its algorithm.
    .DESCRIPTION
        Private helper. Accepts either bare hex (length -> MD5/SHA256/SHA512)
        or a prefixed form 'md5:...'|'sha256:...'|'sha512:...'. Returns
        $null when the input cannot be confidently mapped (including the
        prefix-overrides-length rejection: 'md5:' + 64 hex must reject).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$InputHash
    )
    $null = $PSBoundParameters
    throw 'NotImplemented: ConvertTo-VeriHashAlgorithm -- implemented in plan 01-02'
}
