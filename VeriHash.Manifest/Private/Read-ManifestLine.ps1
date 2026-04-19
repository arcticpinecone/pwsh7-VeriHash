function Read-ManifestLine {
    <#
    .SYNOPSIS
        Parses a single manifest line with strict regex.
    .DESCRIPTION
        Handles blank lines and # comments (D-04), then applies strict
        SHA256 regex (MANIFEST-04). Returns $null for skip, a hashtable
        for valid lines, or a hashtable with Malformed=$true for parse errors.
    .PARAMETER Line
        Raw manifest line (may include trailing CR from CRLF files).
    .OUTPUTS
        System.Collections.Hashtable or $null.
        $null = skip (blank/comment).
        @{ Hash; Mode; Filename } = valid parsed line.
        @{ Malformed = $true; RawLine = ... } = parse error.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Line
    )
    $trimmed = $Line.TrimEnd("`r")
    if ([string]::IsNullOrWhiteSpace($trimmed)) { return $null }
    if ($trimmed.StartsWith('#')) { return $null }
    $m = [regex]::Match($trimmed, '^([0-9a-fA-F]{64})[ ](\*| )(.+)$')
    if ($m.Success) {
        return @{
            Hash     = $m.Groups[1].Value.ToLowerInvariant()
            Mode     = $m.Groups[2].Value
            Filename = $m.Groups[3].Value
        }
    }
    return @{ Malformed = $true; RawLine = $trimmed }
}
