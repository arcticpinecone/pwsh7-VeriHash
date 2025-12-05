<#
    VeriHash.ps1 - A cross-platform PowerShell tool for computing and verifying file hashes

    Copyright (C) 2024-2025 arcticpinecone <arcticpinecone@arcticpinecone.eu>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program. If not, see <https://www.gnu.org/licenses/>.

    ============================================================================

    Author: arcticpinecone | arcticpinecone@arcticpinecone.eu
    Updated: December 6, 2025
    Version: 1.3.0

    Description:
    VeriHash is a PowerShell tool for computing and verifying SHA256 file hashes.
    It requires PowerShell 7 or later, which is a modern, cross-platform edition
    of PowerShell different from the older Windows PowerShell that comes built-in
    with Windows 10/11. If you have never used PowerShell 7 before, rest assured
    it's easy to install and safe to run _alongside_ your existing system.

    Basic Usage
    1. Run without parameters to select a file interactively.
        - e.g., double click VeriHash.ps1 in Windows Explorer to simply launch it
            Then select a file to hash, or, a sidecar file like '.sha2' or '.md5' file to verify a hash.)

    2. Run in terminal easily. Provide a file path to compute its hash and create a sidecar file:
       .\VeriHash.ps1 "C:\path\to\file.exe"

    3. Provide a sidecar file to verify the referenced file's hash:
       .\VeriHash.ps1 "C:\path\to\file.exe.sha2_256"

    4. Provide a file and an input hash to compare:
       .\VeriHash.ps1 "C:\path\to\file.exe" -hash "ABC123..."

        See README for more information.
        [[# Adding VeriHash to Your PowerShell Profile]]

        For an easy way to just use it from anywhere like:
        ```powershell
        verihash filename.ext
        ```

#>
# Requires PowerShell 7+
param (
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$FilePath,

    [Alias("InputHash")]
    [Parameter(Mandatory = $false)]
    [string]$Hash,  # We'll validate ourselves across multiple patterns

    [Parameter(Mandatory = $false)]
    [ValidateSet('MD5', 'SHA256', 'SHA512', 'All')]
    [string[]]$Algorithm,

    [Parameter(Mandatory = $false)]
    [switch]$OnlyVerify,

    [Parameter(Mandatory = $false)]
    [switch]$SendTo,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$SkipSignatureCheck,

    [Parameter(Mandatory = $false)]
    [switch]$NoPause,

    [Parameter(Mandatory = $false)]
    [switch]$SystemWide,

    [Alias("h", "?")]
    [Parameter(Mandatory = $false)]
    [switch]$Help
)

# Initialize variables early
$RunningOnWindows = $PSVersionTable.Platform -eq 'Win32NT'
$RunningOnLinux = $PSVersionTable.Platform -eq 'Unix' -and $PSVersionTable.OS -match 'Linux'

# File extensions that support Authenticode signatures
$script:SignableExtensions = @(
    # Windows PE executables and libraries
    '.exe', '.dll', '.sys', '.ocx', '.cpl', '.scr',

    # Windows installers and packages
    '.msi', '.msix', '.appx', '.cab',

    # Scripts that support Authenticode
    '.ps1', '.psm1', '.psd1', '.ps1xml',
    '.vbs', '.vbe', '.js', '.jse', '.wsf'
)

# File extensions that CAN be signed, but NOT with Authenticode
$script:NonAuthenticodeSignableExtensions = @(
    '.jar',          # Java signing (jarsigner)
    '.apk', '.aab',  # Android signing
    '.app', '.ipa',  # Apple signing
    '.pkg', '.dmg',  # macOS signing
    '.pdf'           # PDF digital signatures
)

# Desktop environment configuration for Linux context menu integration
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

## Context Menu Integration Functions (defined early so they're available for -SendTo handler)

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
    $scriptFullPath = $PSCommandPath
    $scriptDir     = Split-Path $scriptFullPath -Parent

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

    $scriptFullPath = $PSCommandPath
    $scriptDir = Split-Path $scriptFullPath -Parent

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
    } else {
        $execComputeHash = "$pwshPath -NoProfile -ExecutionPolicy Bypass -File `"$scriptFullPath`" `"%f`""
        $execVerifyHash = "$pwshPath -NoProfile -ExecutionPolicy Bypass -File `"$scriptFullPath`" `"%f`" -OnlyVerify"
    }

    $desktopContent = @"
[Desktop Entry]
Type=Service
X-KDE-ServiceTypes=KonqPopupMenu/Plugin
MimeType=application/octet-stream;
Actions=ComputeHash;VerifyHash;

[Desktop Action ComputeHash]
Name=Compute Hash (VeriHash)
Icon=$iconPath
Exec=$execComputeHash

[Desktop Action VerifyHash]
Name=Verify Hash (VeriHash)
Icon=$iconPath
Exec=$execVerifyHash
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
    Write-Host "  3. Choose 'Compute Hash (VeriHash)' or 'Verify Hash (VeriHash)'"
    Write-Host ""

    if ($SystemWide) {
        Write-Host "Installed system-wide for all users." -ForegroundColor Magenta
    }
    else {
        Write-Host "Installed for current user only." -ForegroundColor Magenta
        Write-Host "Run with -SystemWide flag for system-wide installation." -ForegroundColor DarkGray
    }
}

# Handle common help flags (--help, -h, /?, etc.) that might have been passed as FilePath
$helpFlags = @('--help', '--Help', '-h', '-H', '/?', '/h', '/H', 'help', 'HELP')
if ($FilePath -in $helpFlags) {
    $Help = $true
    $FilePath = $null  # Clear it so it doesn't cause errors later
}

# Handle Help parameter
if ($Help) {
    Write-Host "VeriHash.ps1 - A tool to compute and verify file hashes (MD5, SHA256, SHA512)." -ForegroundColor Green
    Write-Host "Usage: .\VeriHash.ps1 [FilePath] [-Hash <Hash>] [-Algorithm <Alg>] [-OnlyVerify] [-Force] [-SkipSignatureCheck] [-NoPause] [-SendTo] [-Help]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor White
    Write-Host "  FilePath             : Path to the file to hash or verify." -ForegroundColor Yellow
    Write-Host "  -Hash, -InputHash    : Provide a MD5, SHA256, or SHA512 hash for verification." -ForegroundColor Yellow
    Write-Host "  -Algorithm           : Specify which hash(es) to compute: MD5, SHA256, SHA512, or All." -ForegroundColor Yellow
    Write-Host "                         Can specify multiple (e.g., -Algorithm MD5,SHA512)." -ForegroundColor Yellow
    Write-Host "                         Default: SHA256 (if no -Hash provided)" -ForegroundColor Yellow
    Write-Host "  -OnlyVerify          : Only verify the provided hash, don't compute additional hashes." -ForegroundColor Yellow
    Write-Host "  -Force               : Auto-update sidecars without prompting when hash mismatches detected." -ForegroundColor Yellow
    Write-Host "  -SkipSignatureCheck  : Skip digital signature verification (faster for small files)." -ForegroundColor Yellow
    Write-Host "  -NoPause             : Skip the 'Press Enter to continue...' prompt at the end." -ForegroundColor Yellow
    Write-Host "  -SendTo              : Creates context menu integration (Windows: SendTo, Linux: desktop-specific)." -ForegroundColor Yellow
    Write-Host "  -SystemWide          : System-wide installation (Linux only, requires sudo). Default: user-level." -ForegroundColor Yellow
    Write-Host "  -Help                : Displays this help message." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor White
    Write-Host "  .\VeriHash.ps1 'C:\file.txt'                              # Compute SHA256" -ForegroundColor Cyan
    Write-Host "  .\VeriHash.ps1 'C:\file.txt' -Hash 'ABC123...'            # Verify hash + compute SHA256" -ForegroundColor Cyan
    Write-Host "  .\VeriHash.ps1 'C:\file.txt' -Hash 'ABC...' -OnlyVerify  # Only verify, no extra hashing" -ForegroundColor Cyan
    Write-Host "  .\VeriHash.ps1 'C:\file.txt' -Algorithm MD5,SHA512       # Compute MD5 and SHA512" -ForegroundColor Cyan
    Write-Host "  .\VeriHash.ps1 'C:\file.txt' -Algorithm All              # Compute all hash types" -ForegroundColor Cyan
    Write-Host "  .\VeriHash.ps1 'C:\file.txt' -Force                      # Auto-update sidecar if mismatch" -ForegroundColor Cyan
    Write-Host "  .\VeriHash.ps1 'C:\file.txt' -SkipSignatureCheck         # Skip signature check (faster)" -ForegroundColor Cyan
    Write-Host "  .\VeriHash.ps1 -SendTo                                   # Install context menu (user-level)" -ForegroundColor Cyan
    Write-Host "  sudo pwsh -File VeriHash.ps1 -SendTo -SystemWide         # System-wide install (Linux)" -ForegroundColor Cyan
    return
}

## Handle context menu integration installation
if ($SendTo) {
    try {
        if ($RunningOnWindows) {
            Install-WindowsSendTo
        }
        elseif ($RunningOnLinux) {
            Install-LinuxContextMenu -SystemWide:$SystemWide
        }
        else {
            Write-Warning "Context menu integration is only supported on Windows and Linux."
            Write-Host "Current Platform: $($PSVersionTable.Platform)"
        }
        return
    }
    catch {
        Write-Error "Error installing context menu integration: $_"
        return
    }
}

function Select-File {
    if ($RunningOnWindows) {
        try {
            Add-Type -AssemblyName System.Windows.Forms
            $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $openFileDialog.Filter = "All Files (*.*)|*.*"
            $openFileDialog.Multiselect = $false
            $dialogResult = $openFileDialog.ShowDialog()
            if ($dialogResult -eq 'OK') {
                return $openFileDialog.FileName
            } elseif ($dialogResult -eq 'Cancel') {
                # User explicitly cancelled - return null to exit
                return $null
            }
        } catch {
            Write-Host "Unable to display file dialog. Please enter the file path manually." -ForegroundColor Yellow
        }
        # Fallback to manual entry if dialog failed or wasn't shown
        Write-Host "Please enter the full path to the file (or press Enter to cancel):" -ForegroundColor Cyan
        $inputPath = Read-Host
        if ([string]::IsNullOrWhiteSpace($inputPath)) {
            return $null
        }
        return $inputPath
    } else {
        Write-Host "Please enter the full path to the file:" -ForegroundColor Cyan
        $inputPath = Read-Host
        return $inputPath
    }
}

function Test-InputHash {
    param (
        [string]$ComputedHash,
        [string]$InputHash
    )
    if ($ComputedHash.ToUpper() -eq $InputHash.ToUpper()) {
        Write-Host "Hash matches! ✅" -ForegroundColor Green
    } else {
        Write-Host "Hash does not match! 🚫" -ForegroundColor Red
    }
}

###############################################################################
# NEW: This function now detects MD5, SHA256, or SHA512 by length and pattern.
###############################################################################
function Get-ClipboardHash {
    $clipboard = $null

    # Try different methods to get clipboard based on platform
    if ($RunningOnWindows) {
        # Windows: Use built-in Get-Clipboard
        try {
            $clipboard = Get-Clipboard -ErrorAction Stop
        }
        catch {
            Write-Host "Failed to retrieve clipboard contents. Ensure the clipboard contains text." -ForegroundColor Yellow
            return $null
        }
    }
    elseif ($RunningOnLinux) {
        # Linux: Try multiple clipboard tools
        $clipboardTools = @(
            @{ Name = 'wl-paste'; Args = @() },                    # Wayland
            @{ Name = 'xclip'; Args = @('-selection', 'clipboard', '-o') },  # X11
            @{ Name = 'xsel'; Args = @('--clipboard', '--output') }           # X11 alternative
        )

        foreach ($tool in $clipboardTools) {
            if (Get-Command $tool.Name -ErrorAction SilentlyContinue) {
                try {
                    if ($tool.Args.Count -gt 0) {
                        $clipboardRaw = & $tool.Name $tool.Args 2>$null
                    } else {
                        $clipboardRaw = & $tool.Name 2>$null
                    }
                    # PowerShell may return array if output has newlines, join into string
                    if ($clipboardRaw) {
                        if ($clipboardRaw -is [array]) {
                            $clipboard = ($clipboardRaw -join "`n")
                        } else {
                            $clipboard = $clipboardRaw
                        }
                        break
                    }
                }
                catch {
                    continue
                }
            }
        }

        if (-not $clipboard) {
            Write-Host "Failed to retrieve clipboard contents." -ForegroundColor Yellow
            Write-Host "Install clipboard tool: sudo pacman -S wl-clipboard  (Wayland)" -ForegroundColor Yellow
            Write-Host "                     or: sudo pacman -S xclip         (X11)" -ForegroundColor Yellow
            return $null
        }
    }
    else {
        # macOS or other Unix
        try {
            $clipboard = Get-Clipboard -ErrorAction Stop
        }
        catch {
            Write-Host "Clipboard access not supported on this platform." -ForegroundColor Yellow
            return $null
        }
    }

    # Trim whitespace just to be safe
    $clipboard = $clipboard.Trim()

    # Patterns for each recognized hash type
    $md5Pattern    = '^[A-Fa-f0-9]{32}$'
    $sha256Pattern = '^[A-Fa-f0-9]{64}$'
    $sha512Pattern = '^[A-Fa-f0-9]{128}$'

    if ($clipboard -match $md5Pattern) {
        return [pscustomobject]@{
            Algorithm = 'MD5'
            Hash      = $clipboard.ToUpper()
        }
    } elseif ($clipboard -match $sha256Pattern) {
        return [pscustomobject]@{
            Algorithm = 'SHA256'
            Hash      = $clipboard.ToUpper()
        }
    } elseif ($clipboard -match $sha512Pattern) {
        return [pscustomobject]@{
            Algorithm = 'SHA512'
            Hash      = $clipboard.ToUpper()
        }
    } else {
        return $null
    }
}

###############################################################################
# Helper to compute a file hash with a given algorithm
# and (optionally) save to a sidecar file with a typical extension.
###############################################################################
function Get-And-SaveHash {
    param (
        [string]$PathToFile,
        [string]$Algorithm,  # MD5 | SHA256 | SHA512
        [string]$InputHash,  # Optional clipboard/input hash for comparison
        [switch]$Force
    )

    # Start timing
    $hashStartTime = Get-Date

    # Use built-in Get-FileHash
    $fileHash = Get-FileHash -Path $PathToFile -Algorithm $Algorithm
    $hashValue = $fileHash.Hash.ToUpper()

    # End timing
    $hashEndTime = Get-Date
    $hashDuration = $hashEndTime - $hashStartTime

    # Decide extension
    switch ($Algorithm) {
        'MD5'    { $ext = '.md5'     }
        'SHA256' { $ext = '.sha256'  }
        'SHA512' { $ext = '.sha512'  }
        default  { $ext = '.unknown' }
    }

    # Construct the sidecar name
    $fileInfo = Get-Item $PathToFile
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileInfo.Name)
    $extension = [System.IO.Path]::GetExtension($fileInfo.Name)
    $hashFileName = "$baseName$extension$ext"
    $hashFilePath = Join-Path -Path $fileInfo.DirectoryName -ChildPath $hashFileName

    # Prepare the new content: "HASHVALUE  filename.ext" (standard Unix format)
    $hashContent = "$hashValue  $($fileInfo.Name)"

    # 1) If sidecar doesn't exist, just create it
    if (-not (Test-Path $hashFilePath)) {
        Set-Content -Path $hashFilePath -Value $hashContent -Force
        return [pscustomobject]@{
            Algorithm     = $Algorithm
            Hash          = $hashValue
            Sidecar       = $hashFilePath
            SidecarHash   = $null
            SidecarMatch  = $null
            Duration      = $hashDuration
            SidecarExists = $false
        }
    }

    # 2) If a sidecar *does* exist, let's see what's inside
    $oldContent = (Get-Content $hashFilePath -Raw).Trim()
    # Standard format is "HASHVALUE  filename.ext" (Unix style)
    # But support legacy format "filename.ext  HASHVALUE" for backward compatibility
    $oldParts = $oldContent -split '\s+'
    [string]$oldHash = $null

    # Try to find which part is the hash by checking if it's all hex
    foreach ($part in $oldParts) {
        if ($part -match '^[A-Fa-f0-9]{32,128}$') {
            $oldHash = $part.ToUpper()
            break
        }
    }

    $sidecarMatches = ($oldHash -eq $hashValue)

    if ($sidecarMatches) {
        # The existing sidecar already has the same hash - no update needed
        return [pscustomobject]@{
            Algorithm     = $Algorithm
            Hash          = $hashValue
            Sidecar       = $hashFilePath
            SidecarHash   = $oldHash
            SidecarMatch  = $true
            Duration      = $hashDuration
            SidecarExists = $true
        }
    }
    else {
        # There's a mismatch
        if ($Force) {
            # Auto-update without prompting
            Set-Content -Path $hashFilePath -Value $hashContent -Force
            return [pscustomobject]@{
                Algorithm     = $Algorithm
                Hash          = $hashValue
                Sidecar       = $hashFilePath
                SidecarHash   = $hashValue  # Now contains the updated hash
                SidecarMatch  = $true       # Now matches since we just updated it
                Duration      = $hashDuration
                SidecarExists = $true
                ForceUpdated  = $true
            }
        }
        else {
            # Prompt the user with enhanced options
            Write-Host ""
            Write-Warning "Sidecar hash differs from computed hash!"
            Write-Host ""
            Write-Host "This means either:" -ForegroundColor Yellow
            Write-Host "  • The file has changed since the sidecar was created" -ForegroundColor Yellow
            Write-Host "  • The sidecar file is incorrect or corrupted" -ForegroundColor Yellow
            Write-Host ""

            # Show the comparison matrix (file hash as source of truth)
            Write-Host "FILE HASH:      $hashValue  " -NoNewline -ForegroundColor Magenta
            Write-Host "← This is what the file is RIGHT NOW" -ForegroundColor DarkGray
            Write-Host ""
            Write-Host "COMPARISONS:" -ForegroundColor White

            # Show clipboard comparison if we have an input hash
            if ($InputHash) {
                Write-Host "  Clipboard:    $InputHash  " -NoNewline -ForegroundColor Yellow
                if ($hashValue -eq $InputHash) {
                    Write-Host "✅ Match" -ForegroundColor Green
                } else {
                    Write-Host "🚫 Does NOT match" -ForegroundColor Red
                }
            }

            # Show sidecar comparison
            Write-Host "  Sidecar:      $oldHash  " -NoNewline -ForegroundColor Cyan
            Write-Host "🚫 Does NOT match" -ForegroundColor Red
            Write-Host ""

            # Context-aware summary
            if ($InputHash -and ($hashValue -eq $InputHash)) {
                Write-Host "Since clipboard hash matches the file, the sidecar appears to be wrong." -ForegroundColor Yellow
            } elseif ($InputHash -and ($hashValue -ne $InputHash)) {
                Write-Host "Both clipboard and sidecar differ from the file. Investigation needed." -ForegroundColor Yellow
            }
            Write-Host ""

            # Prompt the user
            $userChoice = Read-Host "[U]pdate sidecar / [K]eep existing / [R]ename old & create new / [C]ancel (Use -Force to auto-update)"

            # Add visual separator after user choice
            Write-Host ""
            Write-Host "---" -ForegroundColor Cyan

            switch -Regex ($userChoice) {
                '^u' {
                    # Update/Overwrite
                    Set-Content -Path $hashFilePath -Value $hashContent -Force
                    Write-Host "✅ Updated sidecar file with new hash." -ForegroundColor Green
                    Write-Host "---" -ForegroundColor Cyan
                    Write-Host ""
                    return [pscustomobject]@{
                        Algorithm     = $Algorithm
                        Hash          = $hashValue
                        Sidecar       = $hashFilePath
                        SidecarHash   = $hashValue  # Now contains the updated hash
                        SidecarMatch  = $true       # Now matches since we just updated it
                        Duration      = $hashDuration
                        SidecarExists = $true
                        UserUpdated   = $true
                    }
                }
                '^r' {
                    # Rename old file so you don't lose it
                    $newName = $hashFileName + ".old"
                    Rename-Item -Path $hashFilePath -NewName $newName -ErrorAction SilentlyContinue
                    Write-Host "📝 Renamed existing sidecar to '$newName' and created new one." -ForegroundColor Yellow
                    Write-Host "---" -ForegroundColor Cyan
                    Write-Host ""
                    Set-Content -Path $hashFilePath -Value $hashContent -Force
                    return [pscustomobject]@{
                        Algorithm     = $Algorithm
                        Hash          = $hashValue
                        Sidecar       = $hashFilePath
                        SidecarHash   = $hashValue  # Now contains the new hash
                        SidecarMatch  = $true       # New sidecar matches the file hash
                        Duration      = $hashDuration
                        SidecarExists = $true
                        UserRenamed   = $true
                    }
                }
                '^k' {
                    # Keep existing
                    Write-Host "Kept existing sidecar. No changes made." -ForegroundColor Cyan
                    Write-Host "---" -ForegroundColor Cyan
                    Write-Host ""
                    return [pscustomobject]@{
                        Algorithm     = $Algorithm
                        Hash          = $hashValue
                        Sidecar       = $hashFilePath
                        SidecarHash   = $oldHash
                        SidecarMatch  = $false
                        Duration      = $hashDuration
                        SidecarExists = $true
                        UserKept      = $true
                    }
                }
                default {
                    # Cancel
                    Write-Host "Cancelled. Sidecar left as-is." -ForegroundColor Cyan
                    Write-Host "---" -ForegroundColor Cyan
                    Write-Host ""
                    return [pscustomobject]@{
                        Algorithm     = $Algorithm
                        Hash          = $hashValue
                        Sidecar       = $hashFilePath
                        SidecarHash   = $oldHash
                        SidecarMatch  = $false
                        Duration      = $hashDuration
                        SidecarExists = $true
                        UserCancelled = $true
                    }
                }
            }
        }
    }
}

###############################################################################
# Main function to either verify or compute one or two hashes
###############################################################################
function Invoke-HashFile {
    param (
        [string]$FilePath,
        [string]$InputHash,
        [string[]]$Algorithm,
        [switch]$OnlyVerify,
        [switch]$Force,
        [switch]$SkipSignatureCheck,
        [switch]$NoPause
    )

    # Only check clipboard if no InputHash was explicitly provided
    [pscustomobject]$clipboardHashInfo = $null

    if (-not $InputHash) {
        Write-Host "No -Hash parameter provided. Checking clipboard for MD5/SHA256/SHA512..." -ForegroundColor Cyan
        $clipboardHashInfo = Get-ClipboardHash
        if ($clipboardHashInfo) {
            $InputHash  = $clipboardHashInfo.Hash
            Write-Host "Detected $($clipboardHashInfo.Algorithm) hash in clipboard: $InputHash" -ForegroundColor Green
        } else {
            Write-Host "No valid hash found in clipboard. Proceeding with no verification." -ForegroundColor Yellow
        }
    }

    # Prompt for file if not provided or invalid
    if (-not $FilePath -or -not (Test-Path $FilePath)) {
        $FilePath = Select-File
        if (-not $FilePath) {
            Write-Host "Operation cancelled. No file was selected." -ForegroundColor Yellow
            return
        }
        if (-not (Test-Path $FilePath)) {
            Write-Error "The file path provided does not exist: $FilePath"
            return
        }
    }

    # Resolve full path
    $FilePath = (Resolve-Path -Path $FilePath).Path
    $fileInfo = Get-Item $FilePath

    # Check if the selected file is a checksum file (support both old and new extensions)
    $isVerificationFile = $fileInfo.Extension -in ('.sha256', '.sha512', '.md5', '.sha2_256', '.sha2')

    try {
        # Current times
        $currentUTC = Get-Date -AsUTC

        Write-Host "Start UTC:    $($currentUTC.ToString("yyyy-MM-ddTHH:mm:ss.fffZ"))" -ForegroundColor Cyan
        Write-Host "---" -ForegroundColor Cyan

        # Start timing immediately after displaying Start UTC
        # This ensures "Total time" matches the Start UTC → End UTC delta
        $startTime = Get-Date

        # If user gave us a sidecar file, verify it (regardless of -Hash parameter)
        if ($isVerificationFile) {
            # If they also provided -Hash, inform them we're ignoring it and doing the smart thing
            if ($InputHash) {
                Write-Host "📋 Detected sidecar file with -Hash parameter." -ForegroundColor Cyan
                Write-Host "   Ignoring provided hash and verifying the referenced file instead..." -ForegroundColor Yellow
                Write-Host "---" -ForegroundColor Cyan
            }
            # This is a recognized sidecar, so do a verification against the referenced file
            Test-HashSidecar $FilePath
        }
        else {
            # Normal file handling
            Write-Host ("File selected:    " + $fileInfo.Name) -ForegroundColor Green
            Write-Host "---" -ForegroundColor Cyan
            Write-Host "[Metadata]" -ForegroundColor White
            Write-Host ("File Path:    " + $fileInfo.FullName) -ForegroundColor Cyan

            $formattedBytes = $fileInfo.Length.ToString("N0").Replace(",", " ")
            Write-Host ("File Size:    " + "{0:N2}" -f ($fileInfo.Length / 1MB) + " MB  (" + "$formattedBytes bytes" + ")") -ForegroundColor Yellow

            $createdTime  = $fileInfo.CreationTimeUtc
            $modifiedTime = $fileInfo.LastWriteTimeUtc

            Write-Host "Created:      " -NoNewline -ForegroundColor Yellow
            Write-Host ($createdTime.ToLocalTime().ToString("MMMM dd, yyyy") + " | " + $createdTime.ToLocalTime().ToString("HH:mm:ss")) -ForegroundColor Cyan

            Write-Host "Modified:     " -NoNewline -ForegroundColor Yellow
            Write-Host ($modifiedTime.ToLocalTime().ToString("MMMM dd, yyyy") + " | " + $modifiedTime.ToLocalTime().ToString("HH:mm:ss")) -ForegroundColor Cyan

            Write-Host "---" -ForegroundColor Cyan

            # Check digital signature (unless -SkipSignatureCheck is specified)
            if (-not $SkipSignatureCheck) {
                if ($RunningOnWindows) {
                    $fileExtension = $fileInfo.Extension.ToLower()

                    if ($fileExtension -in $script:SignableExtensions) {
                        # File supports Authenticode - check it
                        try {
                            $signature = Get-AuthenticodeSignature -FilePath $FilePath
                            if ($signature.Status -eq 'Valid') {
                                Write-Host "Digitally Signed?:       True ✅" -ForegroundColor Green
                                Write-Host ("Signer:       " + $signature.SignerCertificate.Subject) -ForegroundColor Magenta
                            } else {
                                Write-Host "Digitally Signed?:       False 🚫" -ForegroundColor Red
                            }
                        }
                        catch {
                            Write-Host "Error retrieving signature: $_" -ForegroundColor Yellow
                        }
                    }
                    elseif ($fileExtension -in $script:NonAuthenticodeSignableExtensions) {
                        # File can be signed, but not with Authenticode
                        Write-Host "Digitally Signed?:       N/A (non-Authenticode signature format) ⚪" -ForegroundColor Gray
                    }
                    else {
                        # File cannot be signed at all
                        Write-Host "Digitally Signed?:       N/A (file type cannot be signed) ⚪" -ForegroundColor Gray
                    }
                }
                else {
                    Write-Host "Digitally Signed?:       Skipped (Authenticode signatures are not supported on this platform) 🚫" -ForegroundColor Yellow
                }
                Write-Host "---" -ForegroundColor Cyan
            }
            elseif ($SkipSignatureCheck) {
                Write-Host "Digitally Signed?:       Skipped (SkipSignatureCheck enabled) 🚫" -ForegroundColor Yellow
                Write-Host "---" -ForegroundColor Cyan
            }

            ###################################################################
            # Determine which algorithms to compute
            ###################################################################
            $algorithmsToCompute = @()

            # Step 1: If user provided -Hash, detect and verify it
            if ($InputHash) {
                $detectedAlgorithm = $null

                if ($clipboardHashInfo) {
                    # We detected from clipboard
                    $detectedAlgorithm = $clipboardHashInfo.Algorithm
                } else {
                    # Detect by length from command line -Hash parameter
                    switch ($InputHash.Length) {
                        32  { $detectedAlgorithm = 'MD5'    }
                        64  { $detectedAlgorithm = 'SHA256' }
                        128 { $detectedAlgorithm = 'SHA512' }
                        default {
                            Write-Host "Hash length doesn't match MD5/SHA256/SHA512. Assuming SHA256 by default..." -ForegroundColor Yellow
                            $detectedAlgorithm = 'SHA256'
                        }
                    }
                }

                # Compute and verify the detected algorithm
                Write-Host "`n[Hash Verification - $detectedAlgorithm]" -ForegroundColor White
                Write-Host "Computing $detectedAlgorithm hash..." -ForegroundColor Cyan
                $resVerify = Get-And-SaveHash -PathToFile $FilePath -Algorithm $detectedAlgorithm -InputHash $InputHash -Force:$Force

                # Format hash time
                $minutes = [Math]::Floor($resVerify.Duration.TotalMinutes)
                $seconds = $resVerify.Duration.Seconds
                $ms = $resVerify.Duration.Milliseconds
                $hashTimeStr = "{0:N3} second(s)  ({1:00} minutes, {2:00} seconds, {3:000} ms)" -f $resVerify.Duration.TotalSeconds, $minutes, $seconds, $ms
                Write-Host "Hash time:      $hashTimeStr" -ForegroundColor Cyan

                # Calculate and display hash speed (only if duration is meaningful)
                if ($resVerify.Duration.TotalSeconds -ge 0.001) {
                    $speedMBps = $fileInfo.Length / $resVerify.Duration.TotalSeconds / 1MB
                    if ($speedMBps -ge 1000) {
                        $speedStr = "{0:N2} GB/s" -f ($speedMBps / 1024)
                    } else {
                        $speedStr = "{0:N2} MB/s" -f $speedMBps
                    }
                    Write-Host "Hash speed:     $speedStr" -ForegroundColor Cyan
                }
                Write-Host ""

                # Display file hash as source of truth
                Write-Host "FILE HASH:      $($resVerify.Hash)  " -NoNewline -ForegroundColor Magenta
                Write-Host "← This is what the file is RIGHT NOW" -ForegroundColor DarkGray
                Write-Host ""

                # Display comparisons
                Write-Host "COMPARISONS:" -ForegroundColor White

                # Clipboard comparison
                Write-Host "  Clipboard:    $InputHash  " -NoNewline -ForegroundColor Yellow
                if ($resVerify.Hash -eq $InputHash) {
                    Write-Host "✅ Match" -ForegroundColor Green
                } else {
                    Write-Host "🚫 Does NOT match" -ForegroundColor Red
                }

                # Sidecar comparison (if exists)
                if ($resVerify.SidecarExists) {
                    Write-Host "  Sidecar:      $($resVerify.SidecarHash)  " -NoNewline -ForegroundColor Cyan
                    if ($resVerify.SidecarMatch) {
                        Write-Host "✅ Match" -ForegroundColor Green
                    } else {
                        Write-Host "🚫 Does NOT match" -ForegroundColor Red
                    }
                }

                Write-Host ""

                # Summary statement
                $clipboardMatch = ($resVerify.Hash -eq $InputHash)
                if ($resVerify.SidecarExists) {
                    if ($clipboardMatch -and $resVerify.SidecarMatch) {
                        Write-Host "✅ All verifications passed!" -ForegroundColor Green
                    } elseif (-not $clipboardMatch -and -not $resVerify.SidecarMatch) {
                        Write-Host "⚠️  WARNING: File hash differs from BOTH clipboard and sidecar!" -ForegroundColor Red
                        Write-Host "   The file appears to have changed." -ForegroundColor Yellow
                        if ($resVerify.ForceUpdated) {
                            Write-Host "   ⚡ Force mode: Automatically updated sidecar with new hash." -ForegroundColor Yellow
                        }
                    } elseif ($clipboardMatch -and -not $resVerify.SidecarMatch) {
                        Write-Host "⚠️  Clipboard hash matches, but sidecar does not." -ForegroundColor Yellow
                        if ($resVerify.ForceUpdated) {
                            Write-Host "   ⚡ Force mode: Automatically updated sidecar with new hash." -ForegroundColor Yellow
                        }
                    } else {
                        Write-Host "⚠️  Sidecar matches, but clipboard hash does not!" -ForegroundColor Yellow
                    }
                } else {
                    if ($clipboardMatch) {
                        Write-Host "✅ Clipboard hash matches!" -ForegroundColor Green
                    } else {
                        Write-Host "⚠️  Clipboard hash does NOT match the file!" -ForegroundColor Red
                    }
                }

                Write-Host ""
                # Show appropriate label based on whether sidecar was updated
                if ($resVerify.SidecarMatch) {
                    Write-Host "Sidecar path:   $($resVerify.Sidecar)" -ForegroundColor Green
                } else {
                    Write-Host "Saved to:       $($resVerify.Sidecar)" -ForegroundColor Green
                }

                # If -OnlyVerify is set, we're done - don't compute additional hashes
                if ($OnlyVerify) {
                    Write-Host "`n-OnlyVerify specified. Skipping additional hash computations." -ForegroundColor Cyan
                    # Skip Step 2
                } else {
                    # Add other algorithms if user specified -Algorithm
                    if ($Algorithm) {
                        foreach ($alg in $Algorithm) {
                            if ($alg -eq 'All') {
                                $algorithmsToCompute = @('MD5', 'SHA256', 'SHA512')
                                break
                            }
                            if ($alg -ne $detectedAlgorithm -and $alg -notin $algorithmsToCompute) {
                                $algorithmsToCompute += $alg
                            }
                        }
                    } else {
                        # Default: add SHA256 if we didn't already verify it
                        if ($detectedAlgorithm -ne 'SHA256') {
                            $algorithmsToCompute += 'SHA256'
                        }
                    }
                }
            }
            else {
                # No hash to verify - just compute hash(es)
                if ($Algorithm) {
                    # User specified which algorithm(s) to compute
                    foreach ($alg in $Algorithm) {
                        if ($alg -eq 'All') {
                            $algorithmsToCompute = @('MD5', 'SHA256', 'SHA512')
                            break
                        }
                        if ($alg -notin $algorithmsToCompute) {
                            $algorithmsToCompute += $alg
                        }
                    }
                } else {
                    # Default: SHA256 only
                    $algorithmsToCompute = @('SHA256')
                }
            }

            ###################################################################
            # Step 2: Compute additional algorithms (if any)
            ###################################################################
            foreach ($alg in $algorithmsToCompute) {
                Write-Host "`n[Hash - $alg]" -ForegroundColor White
                Write-Host "Computing $alg hash..." -ForegroundColor Cyan
                # Note: We don't pass InputHash here because it's for a different algorithm
                $res = Get-And-SaveHash -PathToFile $FilePath -Algorithm $alg -Force:$Force

                # Format hash time
                $minutes = [Math]::Floor($res.Duration.TotalMinutes)
                $seconds = $res.Duration.Seconds
                $ms = $res.Duration.Milliseconds
                $hashTimeStr = "{0:N3} second(s)  ({1:00} minutes, {2:00} seconds, {3:000} ms)" -f $res.Duration.TotalSeconds, $minutes, $seconds, $ms
                Write-Host "Hash time:      $hashTimeStr" -ForegroundColor Cyan

                # Calculate and display hash speed (only if duration is meaningful)
                if ($res.Duration.TotalSeconds -ge 0.001) {
                    $speedMBps = $fileInfo.Length / $res.Duration.TotalSeconds / 1MB
                    if ($speedMBps -ge 1000) {
                        $speedStr = "{0:N2} GB/s" -f ($speedMBps / 1024)
                    } else {
                        $speedStr = "{0:N2} MB/s" -f $speedMBps
                    }
                    Write-Host "Hash speed:     $speedStr" -ForegroundColor Cyan
                }
                Write-Host ""

                Write-Host "Computed hash:  $($res.Hash)" -ForegroundColor Magenta

                # Show sidecar status
                if ($res.SidecarExists) {
                    Write-Host "Sidecar hash:   $($res.SidecarHash)" -ForegroundColor Cyan
                    if ($res.SidecarMatch) {
                        Write-Host "✅ Sidecar matches! No update needed." -ForegroundColor Green
                        Write-Host "Sidecar path:   $($res.Sidecar)" -ForegroundColor Green
                    } else {
                        if ($res.ForceUpdated) {
                            Write-Host "⚡ Force mode: Automatically updated sidecar with new hash." -ForegroundColor Yellow
                        }
                        Write-Host "Saved to:       $($res.Sidecar)" -ForegroundColor Green
                    }
                } else {
                    Write-Host "Saved to:       $($res.Sidecar)" -ForegroundColor Green
                }
            }

            ###################################################################
            # Done computing
            ###################################################################
            $endTime  = Get-Date
            $endUTC   = Get-Date -AsUTC
            $duration = $endTime - $startTime

            Write-Host "`n---" -ForegroundColor Cyan
            Write-Host "Completed:      $($endTime.ToString("MMMM dd, yyyy | HH:mm:ss"))" -ForegroundColor Cyan
            Write-Host "End UTC:        $($endUTC.ToString("yyyy-MM-ddTHH:mm:ss.fffZ"))" -ForegroundColor Cyan

            # Format total hash time with milliseconds
            $minutes = [Math]::Floor($duration.TotalMinutes)
            $seconds = $duration.Seconds
            $ms = $duration.Milliseconds
            Write-Host ("Total time:     {0:N3} second(s)  ({1:00} minutes, {2:00} seconds, {3:000} ms)" -f $duration.TotalSeconds, $minutes, $seconds, $ms) -ForegroundColor Cyan
        }
    }
    catch {
        Write-Error "An error occurred: $_"
    }

    if (-not $NoPause -and $Host.Name -eq 'ConsoleHost') {
        Read-Host -Prompt "Press Enter to continue..."
    }
}

function Test-HashSidecar {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$SidecarPath
    )

    process {
        if (-not (Test-Path -Path $SidecarPath)) {
            Write-Error "Sidecar file '$SidecarPath' does not exist."
            return
        }

        # Read all lines from the sidecar file
        $lines = Get-Content -Path $SidecarPath | Where-Object { $_.Trim() -ne '' }

        if ($lines.Count -eq 0) {
            Write-Error "Sidecar '$SidecarPath' is empty."
            return
        }

        $sidecarDir = Split-Path -Path $SidecarPath -Parent
        $totalFiles = $lines.Count
        $passedFiles = 0
        $failedFiles = 0
        $missingFiles = 0

        Write-Host "Checksum file:      $SidecarPath" -ForegroundColor Cyan
        Write-Host "Total entries:      $totalFiles" -ForegroundColor Cyan
        Write-Host "---" -ForegroundColor Cyan

        foreach ($line in $lines) {
            # Parse each line: "hash  filename" or "hash *filename"
            # Support both two-space and space-asterisk formats
            if ($line -match '^([A-Fa-f0-9]+)\s+\*?(.+)$') {
                $inputHash = $matches[1].ToUpper()
                $referencedFilename = $matches[2].Trim()

                # Figure out which hash algorithm by length
                switch ($inputHash.Length) {
                    32  { $algorithm = 'MD5'    }
                    64  { $algorithm = 'SHA256' }
                    128 { $algorithm = 'SHA512' }
                    default {
                        Write-Warning "Unrecognized hash length '$($inputHash.Length)' for '$referencedFilename'. Skipping."
                        continue
                    }
                }

                # The original file should be next to the sidecar
                $fileToCheck = Join-Path -Path $sidecarDir -ChildPath $referencedFilename

                if (-not (Test-Path $fileToCheck)) {
                    Write-Host "$referencedFilename" -NoNewline -ForegroundColor Yellow
                    Write-Host " - MISSING ⚠️" -ForegroundColor Red
                    $missingFiles++
                    continue
                }

                # Compute the actual hash
                $computedHash = (Get-FileHash -Algorithm $algorithm -Path $fileToCheck).Hash.ToUpper()

                if ($computedHash -eq $inputHash) {
                    Write-Host "$referencedFilename" -NoNewline -ForegroundColor Cyan
                    Write-Host " - OK ✅" -ForegroundColor Green
                    $passedFiles++
                }
                else {
                    Write-Host "$referencedFilename" -NoNewline -ForegroundColor Yellow
                    Write-Host " - FAILED 🚫" -ForegroundColor Red
                    Write-Host "  Expected: $inputHash" -ForegroundColor DarkGray
                    Write-Host "  Got:      $computedHash" -ForegroundColor DarkGray
                    $failedFiles++
                }
            }
            else {
                Write-Warning "Invalid format in line: $line"
            }
        }

        # Summary
        Write-Host "---" -ForegroundColor Cyan
        Write-Host "Summary:" -ForegroundColor White
        Write-Host "  Passed:  $passedFiles" -ForegroundColor Green
        if ($failedFiles -gt 0) {
            Write-Host "  Failed:  $failedFiles" -ForegroundColor Red
        }
        if ($missingFiles -gt 0) {
            Write-Host "  Missing: $missingFiles" -ForegroundColor Yellow
        }
    }
}

# If FilePath was provided, verify that it exists before we do anything
if ($FilePath) {
    if (-not (Test-Path $FilePath)) {
        Write-Error "Invalid -FilePath parameter: The file path provided does not exist. Ensure the path is correct."
        return
    }
}

# Finally, run the main function
Invoke-HashFile -FilePath $FilePath -InputHash $Hash -Algorithm $Algorithm -OnlyVerify:$OnlyVerify -Force:$Force -SkipSignatureCheck:$SkipSignatureCheck -NoPause:$NoPause
