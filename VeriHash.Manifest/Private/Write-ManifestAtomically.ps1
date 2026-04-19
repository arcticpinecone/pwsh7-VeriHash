function Write-ManifestAtomically {
    <#
    .SYNOPSIS
        Writes manifest content to a file using atomic temp-then-rename.
    .DESCRIPTION
        Creates a temp file in the same directory, writes UTF-8 NoBOM content
        with LF line endings, then renames to the target path. Uses finally
        block for cleanup to handle PipelineStoppedException (Ctrl+C).
    .PARAMETER Lines
        Array of manifest content lines (without line terminators).
    .PARAMETER TargetPath
        Final destination path for the manifest file.
    .OUTPUTS
        None — writes file or throws.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Lines,

        [Parameter(Mandatory)]
        [string]$TargetPath
    )
    $targetDir = Split-Path -Parent $TargetPath
    $tempFile = Join-Path $targetDir "~verihash-$([guid]::NewGuid().ToString('N').Substring(0, 8)).tmp"
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    $content = ($Lines -join "`n") + "`n"
    try {
        [System.IO.File]::WriteAllText($tempFile, $content, $utf8NoBom)
        Move-Item -LiteralPath $tempFile -Destination $TargetPath -ErrorAction Stop
    }
    finally {
        if (Test-Path -LiteralPath $tempFile) {
            Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
        }
    }
}
