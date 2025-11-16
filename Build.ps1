#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build script for VeriHash

.DESCRIPTION
    This script will handle build/release tasks for VeriHash.
    Currently a placeholder for future expansion.

    Potential future features:
    - Update version numbers in script files
    - Generate release notes from CHANGELOG.md
    - Package for distribution
    - Create signed releases
    - Update documentation

.PARAMETER Version
    Version number to build (e.g., "1.2.2")

.PARAMETER UpdateVersion
    Update version numbers in VeriHash.ps1

.EXAMPLE
    .\Build.ps1
    Runs basic build checks

.EXAMPLE
    .\Build.ps1 -Version "1.3.0" -UpdateVersion
    Updates version to 1.3.0
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$Version,

    [switch]$UpdateVersion
)

$ErrorActionPreference = 'Stop'
$scriptRoot = $PSScriptRoot

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  VeriHash - Build Script" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# First, run all tests
Write-Host "Running tests before build..." -ForegroundColor Yellow
& "$scriptRoot\Test-All.ps1" -CI

if ($LASTEXITCODE -ne 0) {
    Write-Error "Tests failed. Build aborted."
    exit 1
}

# Update version if requested
if ($UpdateVersion -and $Version) {
    Write-Host "`nUpdating version to $Version..." -ForegroundColor Yellow

    $veriHashPath = Join-Path $scriptRoot "VeriHash.ps1"
    $content = Get-Content $veriHashPath -Raw

    # Update version in comment header
    $content = $content -replace '(Version:\s+)[\d\.]+', "`${1}$Version"

    Set-Content -Path $veriHashPath -Value $content -NoNewline

    Write-Host "✅ Version updated in VeriHash.ps1" -ForegroundColor Green
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  ✅ Build completed successfully!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Review changes: git status" -ForegroundColor White
Write-Host "  2. Update CHANGELOG.md with changes" -ForegroundColor White
Write-Host "  3. Commit changes: git add . && git commit" -ForegroundColor White
Write-Host "  4. Tag release: git tag -a v$Version -m 'Release v$Version'" -ForegroundColor White
Write-Host "  5. Push: git push && git push --tags`n" -ForegroundColor White
