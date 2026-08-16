function Resolve-ManifestTargetPath {
    <#
    .SYNOPSIS
        Generates the manifest file path with timestamp naming and collision handling.
    .DESCRIPTION
        Builds filename per D-01: YYYY-MM-DDTHHMMSSZ_manifest.<algorithm>.
        If that file exists, appends -1, -2, etc. per D-02.
    .PARAMETER Directory
        Target directory for the manifest file.
    .PARAMETER Algorithm
        Hash algorithm name for the extension. Default 'sha256'.
    .OUTPUTS
        System.String — absolute path to the manifest file (guaranteed not to exist yet).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Directory,

        [string]$Algorithm = 'sha256'
    )
    $timestamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHHmmss') + 'Z'
    $baseName = "${timestamp}_manifest.${Algorithm}"
    $candidate = Join-Path $Directory $baseName
    if (-not (Test-Path -LiteralPath $candidate)) {
        return $candidate
    }
    $counter = 1
    do {
        $candidate = Join-Path $Directory "${timestamp}_manifest-${counter}.${Algorithm}"
        $counter++
    } while (Test-Path -LiteralPath $candidate)
    return $candidate
}
