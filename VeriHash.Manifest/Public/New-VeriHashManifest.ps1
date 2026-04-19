function New-VeriHashManifest {
    <#
    .SYNOPSIS
        Creates a GNU sha256sum-compatible manifest for the specified files.
    .DESCRIPTION
        Hashes each input file sequentially using Get-VeriHashResult (D-09),
        writes the manifest atomically via temp-file-then-rename (D-10),
        and returns a VeriHash.ManifestCreateResult object.
        SHA256-only for MVP (D-07). Structured output only (D-17).
    .PARAMETER Path
        One or more file paths to include in the manifest. All files must
        share a single parent directory (MANIFEST-02). Files with hash
        extensions are silently filtered (MANIFEST-03, D-18).
    .OUTPUTS
        VeriHash.ManifestCreateResult
    .EXAMPLE
        New-VeriHashManifest -Path file1.txt, file2.txt
    #>
    [CmdletBinding()]
    [OutputType('VeriHash.ManifestCreateResult')]
    param(
        [Parameter(Mandatory)]
        [string[]]$Path
    )
    throw 'Not implemented — Plan 03-02 will implement this function.'
}
