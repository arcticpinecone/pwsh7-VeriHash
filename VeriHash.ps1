<#
    VeriHash.ps1 — Cross-platform file integrity verification (thin CLI dispatcher)
    Copyright (C) 2024-2026 arcticpinecone <arcticpinecone@arcticpinecone.eu>
    SPDX-License-Identifier: AGPL-3.0-or-later
    Version: 2.0.0 | Updated: April 19, 2026
    See LICENSE.md for full AGPL-3.0 terms.
#>
<#
.SYNOPSIS
    VeriHash v2.0 — Cross-platform file integrity verification.
.DESCRIPTION
    Thin CLI dispatcher that imports VeriHash.Core, VeriHash.HotPath, and
    VeriHash.Manifest modules, routes parameters to the correct entry function,
    renders output, and handles centralized pause-at-end.
.PARAMETER FilePath
    One or more file paths to hash or verify. Accepts pipeline and SendTo input.
.PARAMETER Manifest
    Switch to manifest mode. Extension auto-detect: .sha256/.sha512/.md5 files
    are verified; all other files are used to create a new manifest.
.PARAMETER InstallSendTo
    Install OS context-menu integration (Windows SendTo / Linux desktop menu).
.PARAMETER InstallKDE
    Install KDE Dolphin context menu specifically.
.PARAMETER NoPause
    Never pause at exit, even when launched from Explorer/SendTo.
.PARAMETER SystemWide
    System-wide integration install (Linux only, requires sudo).
.PARAMETER Log
    Write one log line per file to ~/.verihash/verihash.log.
.PARAMETER Help
    Show usage help and exit.
.EXAMPLE
    .\VeriHash.ps1 file.exe
.EXAMPLE
    .\VeriHash.ps1 file1.txt, file2.txt -Manifest
#>
param(
    [Parameter(Position = 0, ValueFromRemainingArguments)]
    [string[]]$FilePath,
    [switch]$Manifest,
    [switch]$InstallSendTo,
    [switch]$InstallKDE,
    [switch]$NoPause,
    [switch]$SystemWide,
    [switch]$Log,
    [Alias('h', '?')]
    [switch]$Help
)
$ErrorActionPreference = 'Stop'

# Conditional import: skip if already loaded (testability — tests pre-load with mocks)
foreach ($mod in @('VeriHash.Core', 'VeriHash.HotPath', 'VeriHash.Manifest')) {
    if (-not (Get-Module -Name $mod)) {
        Import-Module (Join-Path $PSScriptRoot "$mod\$mod.psd1") -Force -ErrorAction Stop
    }
}

function Test-VeriHashInteractive {
    <#
    .SYNOPSIS
        Determines whether VeriHash should pause at exit.
    .DESCRIPTION
        Returns $true if launched from a GUI shell (Explorer, Dolphin, etc.)
        so the output window does not vanish before the user reads it.
        Returns $false for terminal sessions and redirected input.
    .OUTPUTS
        System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Redirected stdin → scripted, never pause
    if ([Console]::IsInputRedirected) { return $false }

    try {
        $parent = (Get-Process -Id $PID).Parent
        if ($null -eq $parent) { return $true }
        $name = $parent.ProcessName.ToLowerInvariant()
        # GUI launchers where output window would vanish
        return $name -in @('explorer', 'sihost', 'dolphin', 'nautilus', 'thunar')
    } catch {
        return $false
    }
}

# Help flag detection in FilePath
$helpFlags = @('--help', '-h', '-H', '/?', '/h', '/H', 'help')
if ($FilePath.Count -eq 1 -and $FilePath[0] -in $helpFlags) {
    $Help = [switch]::Present
    $FilePath = $null
}

# Help banner display
if ($Help) {
    Write-Host 'VeriHash v2.0 — Modular file integrity verification' -ForegroundColor Green
    Write-Host ''
    Write-Host 'Usage:' -ForegroundColor White
    Write-Host '  .\VeriHash.ps1 <file>                  # SHA256 hash + sidecar + clipboard check' -ForegroundColor Cyan
    Write-Host '  .\VeriHash.ps1 <files...>               # Multi-file batch with tally' -ForegroundColor Cyan
    Write-Host '  .\VeriHash.ps1 <files...> -Manifest     # Create sha256sum manifest' -ForegroundColor Cyan
    Write-Host '  .\VeriHash.ps1 <file.sha256> -Manifest  # Verify sha256sum manifest' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Switches:' -ForegroundColor White
    Write-Host '  -Manifest       Create or verify a sha256sum-compatible manifest' -ForegroundColor Yellow
    Write-Host '  -InstallSendTo  Install Windows SendTo / Linux context menu shortcuts' -ForegroundColor Yellow
    Write-Host '  -InstallKDE     Install KDE Dolphin context menu entry' -ForegroundColor Yellow
    Write-Host '  -NoPause        Never pause at exit' -ForegroundColor Yellow
    Write-Host '  -SystemWide     System-wide install (Linux only, requires sudo)' -ForegroundColor Yellow
    Write-Host '  -Log            Log each file to ~/.verihash/verihash.log' -ForegroundColor Yellow
    Write-Host '  -Help, -h, -?   Show this help' -ForegroundColor Yellow
    return
}

# Integration dispatch (lazy dot-source)
if ($InstallSendTo -or $InstallKDE) {
    . "$PSScriptRoot\VeriHash.Integrations.ps1"
    try {
        $platform = Get-VeriHashPlatform
        if ($InstallSendTo) {
            if ($platform -eq 'Windows') {
                Install-WindowsSendTo
            } elseif ($platform -eq 'Linux') {
                Install-LinuxContextMenu -SystemWide:$SystemWide
            } else {
                Write-Warning "Context menu integration is only supported on Windows and Linux."
            }
        }
        if ($InstallKDE) {
            if ($platform -eq 'Linux') {
                Install-KDEContextMenu -SystemWide:$SystemWide
            } else {
                Write-Warning '-InstallKDE is only supported on Linux.'
            }
        }
    } catch {
        Write-Error "Integration install failed: $_"
    }
    return
}

# No-args interactive case
if (-not $FilePath -or $FilePath.Count -eq 0) {
    Write-Host 'VeriHash v2.0 — Modular file integrity verification' -ForegroundColor Green
    Write-Host 'Run with -Help for usage, or drag files onto VeriHash.' -ForegroundColor Cyan
    if (-not $NoPause -and (Test-VeriHashInteractive)) {
        Read-Host -Prompt 'Press Enter to continue...'
    }
    return
}

# Main dispatch
$exitCode = 0

try {
    if ($Manifest) {
        # Manifest mode: extension auto-detect
        $manifestExts = @('.sha256', '.sha512', '.md5')
        $isVerify = $FilePath.Count -eq 1 -and
            [System.IO.Path]::GetExtension($FilePath[0]).ToLowerInvariant() -in $manifestExts

        if ($isVerify) {
            $result = Test-VeriHashManifest -Path $FilePath[0]
            Write-Host "Manifest verify: $($result.ManifestPath)" -ForegroundColor Cyan
            foreach ($entry in $result.Entries) {
                $color = switch ($entry.Status) {
                    'pass'    { 'Green' }
                    'mismatch' { 'Red' }
                    'missing'  { 'Yellow' }
                    default    { 'Red' }
                }
                Write-Host "  $($entry.Path): $($entry.Status)" -ForegroundColor $color
            }
            $s = $result.Summary
            $tallyColor = if ($result.ExitCode -eq 0) { 'Green' } else { 'Red' }
            Write-Host "$($s.Passed)/$($s.Total) passed, $($s.Failed) mismatch, $($s.Missing) missing" -ForegroundColor $tallyColor
            $exitCode = $result.ExitCode
        } else {
            $result = New-VeriHashManifest -Path $FilePath
            Write-Host "Manifest created: $($result.ManifestPath)" -ForegroundColor Green
            Write-Host "$($result.FileCount) files, $($result.Algorithm), $($result.ElapsedMs) ms" -ForegroundColor Cyan
        }
    } else {
        # Hash mode
        if ($FilePath.Count -eq 1) {
            Invoke-VeriHashHotPath -Path $FilePath[0] -Log:$Log
        } else {
            Invoke-VeriHashBatch -FilePath $FilePath -Log:$Log
        }
    }
} catch {
    Write-Error "$_"
    $exitCode = 1
}
if (-not $NoPause -and (Test-VeriHashInteractive)) { Read-Host -Prompt 'Press Enter to continue...' }
if ($exitCode -ne 0) { exit $exitCode }