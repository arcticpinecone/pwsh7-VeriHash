function Read-SidecarLine {
    <#
    .SYNOPSIS
        Parses a single sidecar line into @{ Hash; Filename } or $null.
    .DESCRIPTION
        Private helper. Recognizes both v1 sidecar shapes:
            HASH  filename     (two-space, GNU coreutils text mode)
            HASH *filename     (one-space + asterisk, GNU coreutils binary mode)
        Hash is returned lowercase. Returns $null on no match.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Line
    )
    $null = $PSBoundParameters
    throw 'NotImplemented: Read-SidecarLine -- implemented in plan 01-02'
}
