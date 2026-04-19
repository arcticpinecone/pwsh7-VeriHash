function Test-PathTraversal {
    <#
    .SYNOPSIS
        Returns $true if a manifest entry path is safely within the base directory.
    .DESCRIPTION
        Resolves the entry path relative to the base directory using
        [IO.Path]::GetFullPath (works with non-existent paths). Ensures the
        resolved path starts with the base directory + separator to prevent
        sibling-directory prefix collisions (Pitfall 3).
    .PARAMETER EntryPath
        Relative path from the manifest entry.
    .PARAMETER BaseDirectory
        Absolute path to the manifest file's parent directory.
    .OUTPUTS
        System.Boolean — $true if safe, $false if path escapes.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$EntryPath,

        [Parameter(Mandatory)]
        [string]$BaseDirectory
    )
    $resolved = [System.IO.Path]::GetFullPath(
        [System.IO.Path]::Combine($BaseDirectory, $EntryPath)
    )
    $baseDirWithSep = $BaseDirectory.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    ) + [System.IO.Path]::DirectorySeparatorChar
    return $resolved.StartsWith($baseDirWithSep, [System.StringComparison]::OrdinalIgnoreCase)
}
