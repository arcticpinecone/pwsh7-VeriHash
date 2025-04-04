<#   
    VeriHash.ps1
    Author: arcticpinecone | arcticpinecone@arcticpinecone.eu
    Date:   April 04, 2024
    Version: 1.1.1

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
    [switch]$SendTo,
    
    [Parameter(Mandatory = $false)]
    [switch]$Help
)

# Initialize variables early
$RunningOnWindows = $PSVersionTable.Platform -eq 'Win32NT'
$IsInteractive    = $Host.UI.SupportsVirtualTerminal

if ($SendTo) {
    # Perform SendTo shortcut creation
    if ($RunningOnWindows) {
        try {
            $sendToPath    = Join-Path $env:AppData "Microsoft\Windows\SendTo"
            $shortcutPath  = Join-Path $sendToPath "VeriHash.lnk"
            $pwshCommand   = "pwsh"
            $scriptFullPath = $PSCommandPath
            $arguments      = "-NoProfile -File `"$scriptFullPath`""
            $iconPath       = Join-Path (Split-Path $scriptFullPath -Parent) "Icons\VeriHash_256.ico"

            $shell         = New-Object -ComObject WScript.Shell
            $shortcut      = $shell.CreateShortcut($shortcutPath)
            $shortcut.TargetPath      = $pwshCommand
            $shortcut.Arguments       = $arguments
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
    Write-Host "VeriHash.ps1 - A tool to compute and verify file hashes (MD5, SHA256, SHA512)." -ForegroundColor Green
    Write-Host "Usage: .\VeriHash.ps1 [FilePath] [-Hash <Hash>] [-SendTo] [-Help]" -ForegroundColor Cyan
    Write-Host "Parameters:" -ForegroundColor White
    Write-Host "  FilePath         : Path to the file to hash or verify." -ForegroundColor Yellow
    Write-Host "  -Hash, -InputHash: Provide a MD5, SHA256, or SHA512 hash for verification." -ForegroundColor Yellow
    Write-Host "  -SendTo          : Creates a SendTo shortcut for easy access." -ForegroundColor Yellow
    Write-Host "  -Help            : Displays this help message." -ForegroundColor Yellow
    Write-Host "Examples:" -ForegroundColor White
    Write-Host "  .\VeriHash.ps1 -FilePath 'C:\Example\file.txt'" -ForegroundColor Cyan
    Write-Host "  .\VeriHash.ps1 -FilePath 'C:\Example\file.txt' -Hash 'YOUR_HASH_HERE'" -ForegroundColor Cyan
    Write-Host "  .\VeriHash.ps1 -SendTo" -ForegroundColor Cyan
    return
}

## Double-check if user specified -SendTo in combination with other things:
if ($SendTo -and $RunningOnWindows) {
    try {
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

###############################################################################
# NEW: This function now detects MD5, SHA256, or SHA512 by length and pattern.
###############################################################################
function Get-ClipboardHash {
    try {
        # Retrieve the clipboard contents as text
        $clipboard = Get-Clipboard -ErrorAction Stop
    }
    catch {
        Write-Host "Failed to retrieve clipboard contents. Ensure the clipboard contains text." -ForegroundColor Yellow
        return $null
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
function Compute-And-SaveHash {
    param (
        [string]$PathToFile,
        [string]$Algorithm  # MD5 | SHA256 | SHA512
    )

    # Use built-in Get-FileHash
    $fileHash = Get-FileHash -Path $PathToFile -Algorithm $Algorithm
    $hashValue = $fileHash.Hash.ToUpper()

    # Decide extension
    switch ($Algorithm) {
        'MD5'    { $ext = '.md5'       }
        'SHA256' { $ext = '.sha2_256'  }
        'SHA512' { $ext = '.sha2'      }
        default  { $ext = '.unknown'   }
    }

    # Construct the sidecar name
    $fileInfo = Get-Item $PathToFile
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileInfo.Name)
    $extension = [System.IO.Path]::GetExtension($fileInfo.Name)
    $hashFileName = "$baseName$extension$ext"
    $hashFilePath = Join-Path -Path $fileInfo.DirectoryName -ChildPath $hashFileName

    # Prepare the new content: "filename.ext  HASHVALUE"
    $hashContent = "$($fileInfo.Name)  $hashValue"

    # 1) If sidecar doesn't exist, just create it
    if (-not (Test-Path $hashFilePath)) {
        Set-Content -Path $hashFilePath -Value $hashContent -Force
        return [pscustomobject]@{
            Algorithm = $Algorithm
            Hash      = $hashValue
            Sidecar   = $hashFilePath
        }
    }

    # 2) If a sidecar *does* exist, let's see what's inside
    $oldContent = (Get-Content $hashFilePath -Raw).Trim()
    # Typically sidecar is "filename.ext  ABC123..."
    $oldParts = $oldContent -split '\s+(?=[A-Fa-f0-9]+$)'
    # We'll assume the second part is the old hash
    [string]$oldHash = $null
    if ($oldParts.Count -eq 2) {
        $oldHash = $oldParts[1].ToUpper()
    }

    if ($oldHash -eq $hashValue) {
        # The existing sidecar already has the same hash
        Write-Host "Sidecar file '$hashFileName' already matches the computed hash. No update needed." -ForegroundColor Cyan
    }
    else {
        # There's a mismatch
        Write-Warning "Sidecar file '$hashFileName' already exists but has a different hash!"
        Write-Host "Existing hash: $oldHash"
        Write-Host "New hash:      $hashValue"
        Write-Host ""

        # Prompt the user
        $userChoice = Read-Host "Overwrite existing sidecar? [Y]es/[N]o/[R]ename"
        switch -Regex ($userChoice) {
            '^y' {
                # Overwrite
                Set-Content -Path $hashFilePath -Value $hashContent -Force
                Write-Host "Updated sidecar file with new hash." -ForegroundColor Green
            }
            '^r' {
                # Rename old file so you don’t lose it
                $newName = $hashFileName + ".old"
                $backupPath = Join-Path $fileInfo.DirectoryName $newName
                Rename-Item -Path $hashFilePath -NewName $newName -ErrorAction SilentlyContinue
                Write-Host "Renamed existing sidecar to '$newName' and writing a new one..." -ForegroundColor Yellow
                Set-Content -Path $hashFilePath -Value $hashContent -Force
            }
            default {
                Write-Host "Skipping overwrite. Sidecar left as-is." -ForegroundColor Cyan
            }
        }
    }

    return [pscustomobject]@{
        Algorithm = $Algorithm
        Hash      = $hashValue
        Sidecar   = $hashFilePath
    }
}

###############################################################################
# Main function to either verify or compute one or two hashes
###############################################################################
function Run-HashFile {
    param (
        [string]$FilePath,
        [string]$InputHash
    )

    # Attempt to detect from the clipboard if no InputHash provided
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
    $isVerificationFile = $fileInfo.Extension -in ('.sha2_256', '.sha2', '.md5')

    try {
        # Current times
        $currentUTC   = Get-Date -AsUTC
        $currentLocal = Get-Date

        Write-Host "Universal:    $($currentUTC.ToString("yyyy-MM-ddTHH:mm:ss.fffZ"))" -ForegroundColor Cyan
        Write-Host "Local Sys:    $($currentLocal.ToString("MMMM dd, yyyy")) | $($currentLocal.ToString("HH:mm:ss"))" -ForegroundColor Cyan
        Write-Host "---" -ForegroundColor Cyan

        # If user gave us a sidecar file to directly verify, do that
        if ($isVerificationFile -and -not $InputHash) {
            # This is a recognized sidecar, so do a verification against the referenced file
            Verify-HashSidecar $FilePath
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

            # Check digital signature if file < 1GB and running on Windows
            if ($fileInfo.Length -lt 1GB) {
                if ($RunningOnWindows) {
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
                else {
                    Write-Host "Signed:       Skipped (Authenticode signatures are not supported on this platform) 🚫" -ForegroundColor Yellow
                }
                Write-Host "---" -ForegroundColor Cyan
            }

            # Start computing
            $startTime = Get-Date

            ###################################################################
            # Step 1: If we recognized a hash from either the command line
            #         or the clipboard, attempt to figure out which algorithm
            #         it is (MD5, SHA256, or SHA512) and compare.
            ###################################################################
            $mainAlgorithm = $null
            if ($InputHash -and (-not $clipboardHashInfo)) {
                # If user explicitly gave -Hash on command line, we attempt to detect by length
                switch ($InputHash.Length) {
                    32 { $mainAlgorithm = 'MD5'   }
                    64 { $mainAlgorithm = 'SHA256'}
                    128{ $mainAlgorithm = 'SHA512'}
                    default { 
                        Write-Host "Hash length doesn't match MD5/SHA256/SHA512. Assuming SHA256 by default..." -ForegroundColor Yellow
                        $mainAlgorithm = 'SHA256'
                    }
                }
            } elseif ($clipboardHashInfo) {
                # We got an explicit detection from the clipboard
                $mainAlgorithm = $clipboardHashInfo.Algorithm
            }

            $hashResults   = @()
            $computedMatch = $false

            if ($mainAlgorithm) {
                # 1a) Compute the "main" algorithm
                Write-Host "`n[Hash - Detected from input/clipboard]" -ForegroundColor White
                Write-Host "Algorithm:  $mainAlgorithm" -ForegroundColor Green
                Write-Host "Input Hash: $InputHash" -ForegroundColor Yellow
                $resMain = Compute-And-SaveHash -PathToFile $FilePath -Algorithm $mainAlgorithm

                Write-Host "Computed Hash:  $($resMain.Hash)" -ForegroundColor Magenta
                Verify-InputHash -ComputedHash $resMain.Hash -InputHash $InputHash
                Write-Host "Saved to:       $($resMain.Sidecar)" -ForegroundColor Green
                $hashResults += $resMain
            }

            ###################################################################
            # Step 2: Always do a SHA256, it’s best as minimum standard.
            ###################################################################
            Write-Host "`n[Hash - Standard SHA256]" -ForegroundColor White
            $res256 = Compute-And-SaveHash -PathToFile $FilePath -Algorithm 'SHA256'
            Write-Host "SHA256 Hash:  $($res256.Hash)" -ForegroundColor Magenta
            Write-Host "Saved to:     $($res256.Sidecar)" -ForegroundColor Green

            # If the user’s input hash was also SHA256, we can do the check again:
            if ($mainAlgorithm -eq 'SHA256') {
                Write-Host "Verifying again with the same input SHA256..." -ForegroundColor Cyan
                Verify-InputHash -ComputedHash $res256.Hash -InputHash $InputHash
            }

            $hashResults += $res256

            ###################################################################
            # Done computing
            ###################################################################
            $endTime  = Get-Date
            $duration = $endTime - $startTime
            Write-Host "`nCompleted:    $($endTime.ToString("MMMM dd, yyyy | HH:mm:ss"))" -ForegroundColor Cyan
            Write-Host ("Hash time:    {0:N0} second(s)  ({1})" -f $duration.TotalSeconds, $duration.ToString("mm' minutes, 'ss' seconds'")) -ForegroundColor Cyan
        }
    }
    catch {
        Write-Error "An error occurred: $_"
    }

    if ($Host.Name -eq 'ConsoleHost') {
        Read-Host -Prompt "Press Enter to continue..."
    }
}

function Verify-HashSidecar {
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

        # Slurp the entire sidecar contents
        $content   = (Get-Content -Path $SidecarPath -Raw).Trim()

        # Typically sidecar is "filename.ext  ABC123..." with whitespace in between
        $parts = $content -split '\s+(?=[A-Fa-f0-9]+$)'
        if ($parts.Count -lt 2) {
            Write-Error "Sidecar '$SidecarPath' does not have the expected 'filename hash' format."
            return
        }

        $referencedFilename = $parts[0]
        $inputHash          = $parts[1].ToUpper()

        # Figure out which hash algorithm by length
        switch ($inputHash.Length) {
            32  { $algorithm = 'MD5'    }
            64  { $algorithm = 'SHA256' }
            128 { $algorithm = 'SHA512' }
            default {
                Write-Error "Unrecognized hash length '$($inputHash.Length)' in sidecar. Only MD5, SHA256, or SHA512 supported."
                return
            }
        }

        # The original file should be next to the sidecar
        $sidecarDir = Split-Path -Path $SidecarPath -Parent
        $fileToCheck = Join-Path -Path $sidecarDir -ChildPath $referencedFilename
        if (-not (Test-Path $fileToCheck)) {
            Write-Error "The file '$fileToCheck' (referenced by '$SidecarPath') does not exist."
            return
        }

        Write-Host "Sidecar file:       $SidecarPath" -ForegroundColor Cyan
        Write-Host "Hashing file:       $fileToCheck" -ForegroundColor Cyan
        Write-Host "Algorithm:          $algorithm"   -ForegroundColor Yellow
        Write-Host "Expected Hash:      $inputHash"   -ForegroundColor Yellow

        # Compute the actual hash
        $computedHash = (Get-FileHash -Algorithm $algorithm -Path $fileToCheck).Hash.ToUpper()
        Write-Host "Computed Hash:      $computedHash" -ForegroundColor Yellow

        if ($computedHash -eq $inputHash) {
            Write-Host "`nHash matches! ✅" -ForegroundColor Green
        }
        else {
            Write-Host "`nHash does not match! 🚫" -ForegroundColor Red
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
Run-HashFile -FilePath $FilePath -InputHash $Hash
