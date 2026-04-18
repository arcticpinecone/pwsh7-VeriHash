function Read-ClipboardHash {
    <#
    .SYNOPSIS
        Reads a hash from the clipboard, inferring algorithm by length or prefix.
    .DESCRIPTION
        Supports two forms:
          1. Bare hex (length-inferred): 32 -> MD5, 64 -> SHA256, 128 -> SHA512.
          2. Prefixed: '<algo>:<hex>' where <algo> in md5|sha256|sha512.
        Returns $null on non-Windows platforms (cross-platform clipboard is
        deferred to the v2.x backlog) or when no usable hash is present.
    .OUTPUTS
        [pscustomobject]@{ Algorithm; Hash } -- Hash is lowercase hex.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()
    $null = $PSBoundParameters
    throw 'NotImplemented: Read-ClipboardHash -- implemented in plan 01-02'
}
