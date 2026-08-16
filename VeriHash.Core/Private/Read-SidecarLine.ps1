function Read-SidecarLine {
    <#
    .SYNOPSIS
        Parses a v1 sidecar line into hash + filename.
    .DESCRIPTION
        Accepts both v1 sidecar formats:
          'HASH  filename'  (two-space, GNU coreutils text mode)
          'HASH *filename'  (one-space + asterisk, GNU coreutils binary mode)
    .OUTPUTS
        System.Collections.Hashtable -- @{ Hash; Filename } or $null.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Line
    )
    if ($Line -match '^([A-Fa-f0-9]+)\s+\*?(.+)$') {
        return @{ Hash = $matches[1].ToLowerInvariant(); Filename = $matches[2].Trim() }
    }
    return $null
}
