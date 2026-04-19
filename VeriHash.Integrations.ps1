<#
    VeriHash.Integrations.ps1 - OS integration installers (SendTo, KDE context menu)

    Copyright (C) 2024-2025 arcticpinecone <arcticpinecone@arcticpinecone.eu>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Dot-sourced lazily by VeriHash.ps1 when -SendTo is invoked.
    Not loaded during normal hash/verify operations (INTEG-01).
#>

if (-not (Get-Module -Name 'VeriHash.Core')) {
    Import-Module "$PSScriptRoot/VeriHash.Core/VeriHash.Core.psd1"
}

$script:DesktopEnvironments = @{
    'KDE' = @{
        Name = 'KDE Plasma'
        FileType = '.desktop'
        UserPath = '~/.local/share/kio/servicemenus/'
        SystemPath = '/usr/share/kio/servicemenus/'
        DetectionVars = @('KDE_FULL_SESSION', 'KDE_SESSION_VERSION')
        DesktopValue = @('KDE', 'plasma')
        Handler = 'Install-KDEContextMenu'
    }
    # Future: GNOME, XFCE, etc. can be added here
}

function Get-DesktopEnvironment {
    <#
    .SYNOPSIS
        Detects the current Linux desktop environment.
    .DESCRIPTION
        Attempts to identify the desktop environment using XDG_CURRENT_DESKTOP,
        DESKTOP_SESSION, and desktop-specific environment variables.
    .OUTPUTS
        String - Desktop environment key (e.g., 'KDE', 'GNOME') or $null if not detected
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # Method 1: XDG_CURRENT_DESKTOP (most reliable, standardized)
    $xdgDesktop = $env:XDG_CURRENT_DESKTOP
    if ($xdgDesktop) {
        foreach ($de in $script:DesktopEnvironments.Keys) {
            $config = $script:DesktopEnvironments[$de]
            foreach ($value in $config.DesktopValue) {
                if ($xdgDesktop -match $value) {
                    return $de
                }
            }
        }
    }

    # Method 2: DESKTOP_SESSION (fallback)
    $desktopSession = $env:DESKTOP_SESSION
    if ($desktopSession) {
        foreach ($de in $script:DesktopEnvironments.Keys) {
            $config = $script:DesktopEnvironments[$de]
            foreach ($value in $config.DesktopValue) {
                if ($desktopSession -match $value) {
                    return $de
                }
            }
        }
    }

    # Method 3: Desktop-specific environment variables (last resort)
    foreach ($de in $script:DesktopEnvironments.Keys) {
        $config = $script:DesktopEnvironments[$de]
        if ($config.DetectionVars) {
            foreach ($varName in $config.DetectionVars) {
                if (Test-Path "env:$varName") {
                    return $de
                }
            }
        }
    }

    # Could not detect desktop environment
    return $null
}

function Install-WindowsSendTo {
    <#
    .SYNOPSIS
        Creates a Windows SendTo shortcut for VeriHash.
    .DESCRIPTION
        Installs a shortcut in the Windows SendTo folder, enabling right-click "Send To" functionality.
    #>
    [CmdletBinding()]
    param()

    $sendToPath    = Join-Path $env:AppData "Microsoft\Windows\SendTo"
    $shortcutPath  = Join-Path $sendToPath "VeriHash.lnk"
    $pwshCommand   = "pwsh"
    $scriptFullPath = Join-Path $PSScriptRoot "VeriHash.ps1"
    $scriptDir     = $PSScriptRoot

    # Check execution policy
    $currentExecutionPolicy = Get-ExecutionPolicy
    if ($currentExecutionPolicy -ne 'Unrestricted' -and $currentExecutionPolicy -ne 'Bypass') {
        $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptFullPath`""
    } else {
        $arguments = "-NoProfile -File `"$scriptFullPath`""
    }

    $iconPath = Join-Path $scriptDir "Icons\VeriHash_256.ico"
    $shell    = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath      = $pwshCommand
    $shortcut.Arguments       = $arguments
    $shortcut.WorkingDirectory = $scriptDir

    if (Test-Path $iconPath) {
        $shortcut.IconLocation = $iconPath
    } else {
        Write-Warning "Icon file not found: $iconPath. Shortcut will use default icon."
    }

    $shortcut.Save()

    Write-Host "Shortcut created at: $shortcutPath" -ForegroundColor Green

    # Manifest shortcut (INTEG-02, D-10)
    $manifestShortcutPath = Join-Path $sendToPath "VeriHash - Manifest.lnk"
    $manifestShortcut = $shell.CreateShortcut($manifestShortcutPath)
    $manifestShortcut.TargetPath = $pwshCommand
    $manifestShortcut.Arguments = "$arguments -Manifest"
    $manifestShortcut.WorkingDirectory = $scriptDir

    if (Test-Path $iconPath) {
        $manifestShortcut.IconLocation = $iconPath
    }

    $manifestShortcut.Save()
    Write-Host "Manifest shortcut created at: $manifestShortcutPath" -ForegroundColor Green
}

function Install-LinuxContextMenu {
    <#
    .SYNOPSIS
        Installs context menu integration for Linux desktop environments.
    .DESCRIPTION
        Detects the desktop environment and installs appropriate context menu entries.
    .PARAMETER SystemWide
        Install system-wide for all users (requires root privileges).
    #>
    [CmdletBinding()]
    param(
        [switch]$SystemWide
    )

    $desktop = Get-DesktopEnvironment

    if (-not $desktop) {
        Write-Warning "Could not detect desktop environment."
        Write-Host ""
        Write-Host "Detected environment variables:" -ForegroundColor Yellow
        Write-Host "  XDG_CURRENT_DESKTOP: $env:XDG_CURRENT_DESKTOP"
        Write-Host "  DESKTOP_SESSION: $env:DESKTOP_SESSION"
        Write-Host ""
        Write-Host "Currently supported:" -ForegroundColor Cyan
        Write-Host "  - KDE Plasma (Dolphin file manager)"
        Write-Host "  - GNOME (Nautilus) - Coming soon"
        return
    }

    $config = $script:DesktopEnvironments[$desktop]

    $handlerFunction = Get-Command $config.Handler -ErrorAction SilentlyContinue
    if (-not $handlerFunction) {
        Write-Warning "Desktop environment '$desktop' detected but not yet supported."
        Write-Host "Support for $($config.Name) is planned for a future release."
        return
    }

    & $config.Handler -SystemWide:$SystemWide
}

function Install-KDEContextMenu {
    <#
    .SYNOPSIS
        Installs KDE/Dolphin context menu integration for VeriHash.
    .DESCRIPTION
        Creates a .desktop service menu file for KDE Plasma's Dolphin file manager.
    .PARAMETER SystemWide
        Install system-wide for all users (requires root privileges).
    #>
    [CmdletBinding()]
    param(
        [switch]$SystemWide
    )

    $scriptFullPath = Join-Path $PSScriptRoot "VeriHash.ps1"
    $scriptDir = $PSScriptRoot

    # Determine installation path
    if ($SystemWide) {
        $installPath = '/usr/share/kio/servicemenus'
        $iconPath = '/usr/share/icons/hicolor/1024x1024/apps/verihash.png'

        # Check if running as root
        $isRoot = ($env:USER -eq 'root')
        if (-not $isRoot -and (Get-Command id -ErrorAction SilentlyContinue)) {
            $uid = & id -u
            $isRoot = ($uid -eq '0')
        }

        if (-not $isRoot) {
            Write-Error "System-wide installation requires root privileges."
            Write-Host ""
            Write-Host "Please run with sudo:" -ForegroundColor Yellow
            Write-Host "  sudo pwsh -File VeriHash.ps1 -SendTo -SystemWide"
            Write-Host ""
            Write-Host "For user-level installation (recommended):" -ForegroundColor Cyan
            Write-Host "  ./VeriHash.ps1 -SendTo"
            return
        }
    }
    else {
        $installPath = "$env:HOME/.local/share/kio/servicemenus"
        $iconPath = "$env:HOME/.local/share/icons/hicolor/1024x1024/apps/verihash.png"
    }

    $desktopFile = Join-Path $installPath 'verihash.desktop'

    # Create directory
    if (-not (Test-Path $installPath)) {
        New-Item -ItemType Directory -Path $installPath -Force | Out-Null
        Write-Host "Created directory: $installPath" -ForegroundColor Cyan
    }

    # Copy icon
    $sourceIcon = Join-Path $scriptDir 'Icons/VeriHash_1024.png'
    if (Test-Path $sourceIcon) {
        $iconDir = Split-Path $iconPath -Parent
        if (-not (Test-Path $iconDir)) {
            New-Item -ItemType Directory -Path $iconDir -Force | Out-Null
        }
        Copy-Item -Path $sourceIcon -Destination $iconPath -Force
        Write-Host "Copied icon to: $iconPath" -ForegroundColor Cyan
    }
    else {
        Write-Warning "Icon file not found: $sourceIcon"
        $iconPath = 'utilities-file-archiver'  # Fallback to system icon
    }

    # Find pwsh
    $pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
    if (-not $pwshPath) {
        Write-Error "PowerShell 7 (pwsh) not found in PATH."
        Write-Host ""
        Write-Host "Install PowerShell 7:" -ForegroundColor Yellow
        Write-Host "  Arch/Garuda: sudo pacman -S powershell"
        Write-Host "  Ubuntu/Debian: sudo apt install powershell"
        Write-Host "  Fedora: sudo dnf install powershell"
        Write-Host "  Or visit: https://github.com/PowerShell/PowerShell/releases"
        return
    }

    # Ensure VeriHash.ps1 has execute permissions (required by KDE)
    if (Get-Command chmod -ErrorAction SilentlyContinue) {
        & chmod +x "$scriptFullPath" 2>$null
        Write-Host "Set execute permissions on: $scriptFullPath" -ForegroundColor Cyan
    }

    # Find terminal emulator
    $terminalCmd = $null
    $terminals = @('konsole', 'xterm', 'gnome-terminal', 'xfce4-terminal', 'alacritty', 'kitty')
    foreach ($term in $terminals) {
        if (Get-Command $term -ErrorAction SilentlyContinue) {
            $terminalCmd = $term
            break
        }
    }

    if (-not $terminalCmd) {
        Write-Warning "No terminal emulator found. VeriHash will run without visual output."
        $terminalCmd = ""
    }

    # Create .desktop file
    # Note: We launch in a terminal so user can see the output
    if ($terminalCmd) {
        $execComputeHash = "$terminalCmd -e $pwshPath -NoProfile -ExecutionPolicy Bypass -File `"$scriptFullPath`" `"%f`""
        $execVerifyHash = "$terminalCmd -e $pwshPath -NoProfile -ExecutionPolicy Bypass -File `"$scriptFullPath`" `"%f`" -OnlyVerify"
        $execManifestHash = "$terminalCmd -e $pwshPath -NoProfile -ExecutionPolicy Bypass -File `"$scriptFullPath`" -Manifest `"%f`""
    } else {
        $execComputeHash = "$pwshPath -NoProfile -ExecutionPolicy Bypass -File `"$scriptFullPath`" `"%f`""
        $execVerifyHash = "$pwshPath -NoProfile -ExecutionPolicy Bypass -File `"$scriptFullPath`" `"%f`" -OnlyVerify"
        $execManifestHash = "$pwshPath -NoProfile -ExecutionPolicy Bypass -File `"$scriptFullPath`" -Manifest `"%f`""
    }

    $desktopContent = @"
[Desktop Entry]
Type=Service
X-KDE-ServiceTypes=KonqPopupMenu/Plugin
MimeType=application/octet-stream;
Actions=ComputeHash;VerifyHash;ManifestHash;

[Desktop Action ComputeHash]
Name=Compute Hash (VeriHash)
Icon=$iconPath
Exec=$execComputeHash

[Desktop Action VerifyHash]
Name=Verify Hash (VeriHash)
Icon=$iconPath
Exec=$execVerifyHash

[Desktop Action ManifestHash]
Name=Manifest (VeriHash)
Icon=$iconPath
Exec=$execManifestHash
"@

    Set-Content -Path $desktopFile -Value $desktopContent -Force -Encoding UTF8

    # Make .desktop file executable (required by KDE for security)
    if (Get-Command chmod -ErrorAction SilentlyContinue) {
        & chmod +x "$desktopFile" 2>$null
    }

    Write-Host ""
    Write-Host "KDE context menu integration installed successfully!" -ForegroundColor Green
    Write-Host "Location: $desktopFile" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "To use:" -ForegroundColor Yellow
    Write-Host "  1. Right-click any file in Dolphin"
    Write-Host "  2. Select 'Actions' submenu"
    Write-Host "  3. Choose 'Compute Hash', 'Verify Hash', or 'Manifest (VeriHash)'"
    Write-Host ""

    if ($SystemWide) {
        Write-Host "Installed system-wide for all users." -ForegroundColor Magenta
    }
    else {
        Write-Host "Installed for current user only." -ForegroundColor Magenta
        Write-Host "Run with -SystemWide flag for system-wide installation." -ForegroundColor DarkGray
    }
}
