<#   
    VeriHash.ps1
    Author: arcticpinecone | arcticpinecone@arcticpinecone.eu
    Date:   December 09, 2024
    Version: 1.0.7

    Description:
    VeriHash is a PowerShell tool for computing and verifying SHA256 file hashes.
    It requires PowerShell 7 or later, which is a modern, cross-platform edition
    of PowerShell different from the older Windows PowerShell that comes built-in
    with Windows 10/11. If you have never used PowerShell 7 before, rest assured
    it's easy to install and safe to run _alongside_ your existing system.

    Getting PowerShell 7
    > https://aka.ms/powershell (Redirect via Microsoft)
    On Windows, you can install PowerShell 7 from the [Microsoft Store](https://aka.ms/PSWindows) 
        or download the installer from the [official GitHub releases page](https://github.com/PowerShell/PowerShell/releases). 
    - On macOS or Linux, you can follow the straightforward instructions provided in the [PowerShell Documentation](https://docs.microsoft.com/powershell/).
    
    Basic Usage
    1. Run without parameters to select a file interactively. 
        - e.g., double click VeriHash.ps1 in Windows Explorer to simply launch it
            Then select a file to hash, or, a '.sha2_256' file to verify a hash.)

    2. Run in terminal easily. Provide a file path to compute its SHA256 hash and create a .sha2_256 file:
       .\VeriHash.ps1 "C:\path\to\file.exe"

    3. Provide a .sha2_256 file to verify the referenced file's hash:
       .\VeriHash.ps1 "C:\path\to\file.exe.sha2_256"

    4. Provide a file and an input hash to compare:
       .\VeriHash.ps1 "C:\path\to\file.exe" -hash "ABC123..."
    
        See README for more information.
        [[# Adding VeriHash to Your PowerShell Profile]] 
        
        For an easy way to just use it from anywhere like:
        ```powershell
        verihash filename.ext
        ```

    # Example output for a known compare
    ---
    Universal:    2024-12-06T23:24:16.476Z
    Local Sys:    December 07, 2024 | 01:24:16
    ---
    File selected:    PowerShell-7.4.6-win-x64.msi
    ---
    [Metadata]
    File Path:    C:\Users\username\Downloads\PowerShell-7.4.6-win-x64.msi
    File Size:    104.14 MB  (109 203 456 bytes)
    Created:      December 06, 2024 | 20:18:09
    Modified:     December 06, 2024 | 20:18:22
    ---
    Signed:       True ✅
    Signer:       CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US
    ---
    [Hash]
    Algorithm:       SHA256
    Hashing file:     PowerShell-7.4.6-win-x64.msi
    Input Hash:       ED331A04679B83D4C013705282D1F3F8D8300485EB04C081F36E11EAF1148BD0
    Computed Hash:    ED331A04679B83D4C013705282D1F3F8D8300485EB04C081F36E11EAF1148BD0
    Hash matches! ✅
    Completed:    December 07, 2024 | 01:24:18
    Hash time:    1 second(s)    (00 minutes, 00 seconds)
    ---

#>
# Requires PowerShell 7+
param (
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$FilePath,
    
    [Alias("InputHash")]
    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[A-Fa-f0-9]{64}$')]
    [string]$Hash,
    
    [Parameter(Mandatory = $false)]
    [switch]$SendTo,
    
    [Parameter(Mandatory = $false)]
    [switch]$Help
)

# Initialize variables early
$RunningOnWindows = $PSVersionTable.Platform -eq 'Win32NT'
$IsInteractive = $Host.UI.SupportsVirtualTerminal

if ($SendTo) {
    # Perform SendTo shortcut creation
    if ($RunningOnWindows) {
        try {
            $sendToPath = Join-Path $env:AppData "Microsoft\Windows\SendTo"
            $shortcutPath = Join-Path $sendToPath "VeriHash.lnk"
            $pwshCommand = "pwsh"
            $scriptFullPath = $PSCommandPath
            $arguments = "-NoProfile -File `"$scriptFullPath`""
            $iconPath = Join-Path (Split-Path $scriptFullPath -Parent) "Icons\VeriHash_256.ico"

            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut($shortcutPath)
            $shortcut.TargetPath = $pwshCommand
            $shortcut.Arguments = $arguments
            $shortcut.WorkingDirectory = (Split-Path $scriptFullPath -Parent)
            if (Test-Path $iconPath) {
                $shortcut.IconLocation = $iconPath
            }
            $shortcut.Save()
            Write-Host "Shortcut created at: $shortcutPath" -ForegroundColor Green
        }
        catch {
            Write-Error "Error creating SendTo shortcut: $_"
        }
    } else {
        Write-Error "SendTo is supported only on Windows systems."
    }
    # Exit script after processing SendTo
    return
}

# Handle Help parameter
if ($Help) {
    Write-Host "VeriHash.ps1 - A tool to compute and verify SHA256 hashes." -ForegroundColor Green
    Write-Host "Usage: .\VeriHash.ps1 [FilePath] [-Hash <Hash>] [-SendTo] [-Help]" -ForegroundColor Cyan
    Write-Host "Parameters:" -ForegroundColor White
    Write-Host "  FilePath         : Path to the file to hash or verify." -ForegroundColor Yellow
    Write-Host "  -Hash, -InputHash: Provide a SHA256 hash for verification." -ForegroundColor Yellow
    Write-Host "  -SendTo          : Creates a SendTo shortcut for easy access." -ForegroundColor Yellow
    Write-Host "  -Help            : Displays this help message." -ForegroundColor Yellow
    Write-Host "Examples:" -ForegroundColor White
    Write-Host "  .\VeriHash.ps1 -FilePath 'C:\Example\file.txt'" -ForegroundColor Cyan
    Write-Host "  .\VeriHash.ps1 -FilePath 'C:\Example\file.txt' -Hash 'YOUR_SHA256_HASH_HERE'" -ForegroundColor Cyan
    Write-Host "  .\VeriHash.ps1 -SendTo" -ForegroundColor Cyan
    return
}

## Check for -SendTo flag early
if ($SendTo -and $RunningOnWindows) {
    try {
        # Determine the user's SendTo folder
        $sendToPath = Join-Path $env:AppData "Microsoft\Windows\SendTo"
        $shortcutPath = Join-Path $sendToPath "VeriHash.lnk"

        # Use pwsh.exe (PowerShell Core). Modify if you use Windows PowerShell.
        $pwshCommand = "pwsh"

        # Get the full path of the current script
        $scriptFullPath = $PSCommandPath
        $scriptDir = Split-Path $scriptFullPath -Parent

        # Arguments for the shortcut
        $currentExecutionPolicy = Get-ExecutionPolicy
        if ($currentExecutionPolicy -ne 'Unrestricted' -and $currentExecutionPolicy -ne 'Bypass') {
            $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptFullPath`""
        } else {
            $arguments = "-NoProfile -File `"$scriptFullPath`""
        }

        # Resolve the icon path relative to the script directory
        $iconPath = Join-Path $scriptDir "Icons\VeriHash_256.ico"

        # Create the shortcut
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $pwshCommand
        $shortcut.Arguments = $arguments
        $shortcut.WorkingDirectory = $scriptDir

        # Check if the icon exists and set it
        if (Test-Path $iconPath) {
            $shortcut.IconLocation = $iconPath
        } else {
            Write-Warning "Icon file not found: $iconPath. Shortcut will use default icon."
        }

        # Save the shortcut
        $shortcut.Save()

        Write-Host "Shortcut created at: $shortcutPath" -ForegroundColor Green
        return
    }
    catch {
        Write-Error "Error creating SendTo shortcut: $_"
        return
        }
}

function Select-File {
    if ($RunningOnWindows) {
        Add-Type -AssemblyName System.Windows.Forms
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Filter = "All Files (*.*)|*.*"
        $openFileDialog.Multiselect = $false
        $dialogResult = $openFileDialog.ShowDialog()
        if ($dialogResult -eq 'OK') {
            return $openFileDialog.FileName
        }
    } else {
        Write-Host "Please enter the full path to the file:" -ForegroundColor Cyan
        $inputPath = Read-Host
        return $inputPath
    }
    return $null
}

function Verify-InputHash {
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

function Get-ClipboardSha256 {
    try {
        # Retrieve the clipboard contents as text
        $clipboard = Get-Clipboard -ErrorAction Stop
    }
    catch {
        Write-Host "Failed to retrieve clipboard contents. Ensure the clipboard contains text." -ForegroundColor Yellow
        return $null
    }

    # Define a regex pattern for a 64-char hex string (SHA256)
    $sha256Pattern = '^[A-Fa-f0-9]{64}$'

    # Check if clipboard matches the SHA256 pattern
    if ($clipboard -match $sha256Pattern) {
        # Return the hash in uppercase (optional)
        return $clipboard.ToUpper()
    } else {
        # Return $null without writing additional messages here
        return $null
    }
}


function Run-HashFile {
    param (
        [string]$FilePath,
        [string]$Algorithm = "SHA256",
        [string]$InputHash
    )

    # If InputHash is not provided, attempt to get it from clipboard
    if (-not $InputHash) {
        Write-Host "No InputHash provided. Checking clipboard for a valid SHA256 hash..." -ForegroundColor Cyan
        $InputHash = Get-ClipboardSha256
        if ($InputHash) {
            Write-Host "Using SHA256 hash from clipboard: $InputHash" -ForegroundColor Green
        } else {
            Write-Host "No valid SHA256 hash found in clipboard. Proceeding without verification." -ForegroundColor Yellow
        }
    }

    # Prompt for file if not provided or invalid
    if (-not $FilePath -or -not (Test-Path $FilePath)) {
        $FilePath = Select-File
    }

    if (-not $FilePath -or -not (Test-Path $FilePath)) {
        Write-Error "Invalid -FilePath parameter: The file path provided is either missing or does not exist. Ensure the path is correct and the file exists."
        if ($Host.Name -eq 'ConsoleHost') {
            Read-Host -Prompt "Press Enter to exit..."
        }
        return
    }

    # Resolve full path
    $FilePath = (Resolve-Path -Path $FilePath).Path
    $fileInfo = Get-Item $FilePath

    # Check if the selected file is a .sha2_256 file
    $isVerificationFile = $fileInfo.Extension -eq ".sha2_256"

    try {
        # Current times
        $currentUTC = Get-Date -AsUTC
        $currentLocal = Get-Date

        Write-Host "Universal:    $($currentUTC.ToString("yyyy-MM-ddTHH:mm:ss.fffZ"))" -ForegroundColor Cyan
        Write-Host "Local Sys:    $($currentLocal.ToString("MMMM dd, yyyy")) | $($currentLocal.ToString("HH:mm:ss"))" -ForegroundColor Cyan
        Write-Host "---" -ForegroundColor Cyan

        if ($isVerificationFile -and -not $InputHash) {
            # If this is a .sha2_256 file and no InputHash was given, run the verification function
            Verify-SHA256 $FilePath
        } else {
            # Normal file handling
            Write-Host ("File selected:    " + $fileInfo.Name) -ForegroundColor Green
            Write-Host "---" -ForegroundColor Cyan
            Write-Host "[Metadata]" -ForegroundColor White
            Write-Host ("File Path:    " + $fileInfo.FullName) -ForegroundColor Cyan

            $formattedBytes = $fileInfo.Length.ToString("N0").Replace(",", " ")
            Write-Host ("File Size:    " + "{0:N2}" -f ($fileInfo.Length / 1MB) + " MB  (" + "$formattedBytes bytes" + ")") -ForegroundColor Yellow

            $createdTime = $fileInfo.CreationTimeUtc
            $modifiedTime = $fileInfo.LastWriteTimeUtc

            Write-Host "Created:      " -NoNewline -ForegroundColor Yellow
            Write-Host ($createdTime.ToLocalTime().ToString("MMMM dd, yyyy") + " | " + $createdTime.ToLocalTime().ToString("HH:mm:ss")) -ForegroundColor Cyan

            Write-Host "Modified:     " -NoNewline -ForegroundColor Yellow
            Write-Host ($modifiedTime.ToLocalTime().ToString("MMMM dd, yyyy") + " | " + $modifiedTime.ToLocalTime().ToString("HH:mm:ss")) -ForegroundColor Cyan

            Write-Host "---" -ForegroundColor Cyan

            # Check digital signature if file < 1GB and running on Windows
            if ($fileInfo.Length -lt 1GB) {
                if ($RunningOnWindows) {
                    try {
                        $signature = Get-AuthenticodeSignature -FilePath $FilePath
                        if ($signature.Status -eq 'Valid') {
                            Write-Host "Signed:       True ✅" -ForegroundColor Green
                            Write-Host ("Signer:       " + $signature.SignerCertificate.Subject) -ForegroundColor Magenta
                        } else {
                            Write-Host "Signed:       False 🚫" -ForegroundColor Red
                        }
                    }
                    catch {
                        Write-Host "Error retrieving signature: $_" -ForegroundColor Yellow
                    }
                }
                else {
                    Write-Host "Signed:       Skipped (Authenticode signatures are not supported on this platform) 🚫" -ForegroundColor Yellow
                }
                Write-Host "---" -ForegroundColor Cyan
            }

            if ($InputHash -and $isVerificationFile) {
                Write-Host "⛔ WARNING: You are attempting to verify against a .sha2_256 file by hashing it directly." -ForegroundColor Red
                Write-Host "Instead, you should run this tool on the original file or just the .sha2_256 file without -Hash." -ForegroundColor White
                Write-Host "This .sha2_256 file is a verification file, not the file it references. 🤦" -ForegroundColor Blue
                Write-Host "---" -ForegroundColor Cyan
            }

            # Compute the hash
            $startTime = Get-Date
            $fileHash = Get-FileHash -Path $FilePath -Algorithm $Algorithm
            $endTime = Get-Date
            $duration = $endTime - $startTime

            Write-Host "[Hash]" -ForegroundColor White
            Write-Host "Algorithm:       " -NoNewline -ForegroundColor White
            Write-Host ($fileHash.Algorithm) -ForegroundColor Green

            if ($InputHash) {
                Write-Host "Hashing file:     " -NoNewline -ForegroundColor White
                Write-Host ($fileInfo.Name) -ForegroundColor Cyan

                Write-Host "Input Hash:       " -NoNewline -ForegroundColor White
                Write-Host ($InputHash.ToUpper()) -ForegroundColor Yellow

                Write-Host "Computed Hash:    " -NoNewline -ForegroundColor White
                Write-Host ($fileHash.Hash.ToUpper()) -ForegroundColor Magenta

                # Compare input vs computed
                Verify-InputHash -ComputedHash $fileHash.Hash -InputHash $InputHash
            } else {
                # Just show computed hash normally
                Write-Host "Hash data:       " -NoNewline -ForegroundColor White
                Write-Host ($fileHash.Hash) -ForegroundColor Magenta

                # If SHA256, also save hash to a .sha2_256 file
                if ($fileHash.Algorithm -eq "SHA256") {
                    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileInfo.Name)
                    $extension = [System.IO.Path]::GetExtension($fileInfo.Name)
                    $hashFileName = "$baseName$extension.sha2_256"
                    $hashFilePath = Join-Path -Path $fileInfo.DirectoryName -ChildPath $hashFileName
                    $hashContent = "$($fileInfo.Name)  $($fileHash.Hash)"
                    Set-Content -Path $hashFilePath -Value $hashContent -Force
                    Write-Host "Hash saved to: $hashFilePath" -ForegroundColor Green
                }
            }

            # Print completion and timing
            Write-Host ("Completed:    " + $endTime.ToString("MMMM dd, yyyy | HH:mm:ss")) -ForegroundColor Cyan
            Write-Host ("Hash time:    " + "{0:N0} second(s)" -f $duration.TotalSeconds + "    (" + $duration.ToString("mm' minutes, 'ss' seconds'") + ")") -ForegroundColor Cyan
        }

    }
    catch {
        Write-Error "An error occurred: $_"
    }

    if ($Host.Name -eq 'ConsoleHost') {
        Read-Host -Prompt "Press Enter to continue..."
    }
}

function Verify-SHA256 {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Sha256FilePath
    )

    process {
        try {
            if (-not (Test-Path -Path $Sha256FilePath)) {
                Write-Error "The file '$Sha256FilePath' does not exist."
                return
            }

            $sha256Dir = Split-Path -Path $Sha256FilePath -Parent
            $content = (Get-Content -Path $Sha256FilePath -Raw).Trim()
            $parts = $content -split '\s+(?=[A-Fa-f0-9]{64}$)'

            if ($parts.Count -ne 2) {
                Write-Error "The file '$Sha256FilePath' does not have the expected 'filename hash' format."
                return
            }

            $filename = $parts[0]
            $inputHash = $parts[1].ToUpper()
            $fileToHashPath = Join-Path -Path $sha256Dir -ChildPath $filename

            if (-not (Test-Path -Path $fileToHashPath)) {
                Write-Error "The file to verify '$fileToHashPath' does not exist."
                return
            }

            $computedHash = (Get-FileHash -Path $fileToHashPath -Algorithm SHA256).Hash.ToUpper()

            $inputFile = (Resolve-Path -Path $Sha256FilePath).Path

            Write-Host "Input file:       $inputFile" -ForegroundColor Cyan
            Write-Host "Hashing file:     $filename" -ForegroundColor Cyan
            Write-Host "Input Hash:       $inputHash" -ForegroundColor Yellow
            Write-Host "Computed Hash:    $computedHash" -ForegroundColor Yellow
            if ($computedHash -eq $inputHash) {
                Write-Host "`nHash matches! ✅" -ForegroundColor Green
            } else {
                Write-Host "`nHash does not match! 🚫" -ForegroundColor Red
            }
        }
        catch {
            Write-Error "An error occurred: $_"
        }
    }
}

# Adjusted FilePath validation
# Only validate if FilePath is provided
if ($FilePath) {
    if (-not (Test-Path $FilePath)) {
        Write-Error "Invalid -FilePath parameter: The file path provided does not exist. Ensure the path is correct."
        return
    }
}

# Call Run-HashFile only with valid inputs
Run-HashFile -FilePath $FilePath -InputHash $Hash
