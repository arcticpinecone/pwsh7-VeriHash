function Invoke-VeriHashSidecarDetect {
    <#
    .SYNOPSIS
        Auto-detects sidecar vs manifest intent for a hash-extension file.
    .DESCRIPTION
        Reads a .sha256/.sha512/.md5 file and routes by line count:
        - 0 non-blank lines: error (SIDE-05)
        - 1 non-blank line:  sidecar verify — hash companion, compare (SIDE-01/02/03/04)
        - N non-blank lines: delegate to Test-VeriHashManifest (SIDE-01)
        Companion resolution: GNU format → filename from line; bare hash →
        strip hash extension from sidecar filename (SIDE-02).
        Focused verify only — no Authenticode, no clipboard, no hot-path (D-01, D-03).
    .PARAMETER Path
        Path to the hash-extension sidecar/manifest file.
    .OUTPUTS
        VeriHash.SidecarVerifyResult (1-line) or VeriHash.ManifestVerifyResult (N-line)
    .EXAMPLE
        Invoke-VeriHashSidecarDetect -Path 'download.iso.sha256'
    #>
    [CmdletBinding()]
    [OutputType('VeriHash.SidecarVerifyResult', 'VeriHash.ManifestVerifyResult')]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    # Step 1 — Resolve sidecar path and determine algorithm (D-02)
    $resolvedSidecar = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    $sidecarDir = Split-Path -Parent $resolvedSidecar
    $sidecarLeaf = Split-Path -Leaf $resolvedSidecar

    $algoMap = [ordered]@{
        '.sha512' = 'SHA512'
        '.sha256' = 'SHA256'
        '.md5'    = 'MD5'
    }
    $ext = [System.IO.Path]::GetExtension($resolvedSidecar).ToLowerInvariant()
    $algorithm = $algoMap[$ext]
    if (-not $algorithm) {
        Write-Error "Unsupported sidecar extension: $ext"
        return
    }

    # Step 2 — Read and filter blank lines
    $rawLines = [System.IO.File]::ReadAllLines($resolvedSidecar)
    $lines = @($rawLines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

    # Step 3 — Dispatch on line count
    if ($lines.Count -eq 0) {
        Write-Error "Sidecar file is empty: $resolvedSidecar"
        return
    }

    if ($lines.Count -gt 1) {
        return Test-VeriHashManifest -Path $resolvedSidecar
    }

    # Step 4 — Single-line sidecar verify (SIDE-01/02)
    $line = $lines[0]
    $parsed = Read-SidecarLine -Line $line
    if ($null -ne $parsed -and $parsed.Filename) {
        $companionName = $parsed.Filename
        $expectedHash = $parsed.Hash
    } else {
        $trimmedLine = $line.Trim()
        if ($trimmedLine -match '^[A-Fa-f0-9]+$') {
            $companionName = [System.IO.Path]::GetFileNameWithoutExtension($sidecarLeaf)
            $expectedHash = $trimmedLine.ToLowerInvariant()
        } else {
            Write-Error "Cannot parse sidecar line: $trimmedLine"
            return
        }
    }

    # Step 5 — Path traversal guard (T-6-01)
    if ([System.IO.Path]::IsPathRooted($companionName)) {
        Write-Error "Companion filename contains absolute path: $companionName"
        return
    }
    if ($companionName -match '^[A-Za-z]:') {
        Write-Error "Companion filename contains absolute path: $companionName"
        return
    }
    $resolvedCompanion = [System.IO.Path]::GetFullPath(
        [System.IO.Path]::Combine($sidecarDir, $companionName)
    )
    $baseDirWithSep = $sidecarDir.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    ) + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolvedCompanion.StartsWith($baseDirWithSep, [System.StringComparison]::OrdinalIgnoreCase)) {
        Write-Error "Companion filename escapes sidecar directory: $companionName"
        return
    }

    # Step 6 — Companion existence check (SIDE-04)
    $companionPath = $resolvedCompanion
    if (-not (Test-Path -LiteralPath $companionPath)) {
        Write-Error "Companion file not found: $companionName"
        return
    }

    # Step 7 — Hash length warning (D-04)
    $expectedLengths = @{ 'MD5' = 32; 'SHA256' = 64; 'SHA512' = 128 }
    $expectedLen = $expectedLengths[$algorithm]
    $warning = $null
    if ($expectedHash.Length -ne $expectedLen) {
        $warning = "Unexpected hash length: expected $expectedLen chars for $algorithm, got $($expectedHash.Length)"
        Write-Warning $warning
    }

    # Step 8 — Hash companion and compare (D-01: focused, D-03: no clipboard)
    $actual = Get-VeriHashResult -Path $companionPath -Algorithm $algorithm
    $status = if ($actual.Hash -eq $expectedHash) { 'pass' } else { 'mismatch' }

    return [pscustomobject]@{
        PSTypeName    = 'VeriHash.SidecarVerifyResult'
        SidecarPath   = $resolvedSidecar
        CompanionPath = $actual.FilePath
        Algorithm     = $algorithm
        ExpectedHash  = $expectedHash
        ActualHash    = $actual.Hash
        Status        = $status
        ElapsedMs     = $actual.ElapsedMs
        Warning       = $warning
    }
}
