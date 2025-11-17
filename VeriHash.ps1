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
    Updated: November 17, 2025
    Version: 1.2.3

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

    [Alias("h", "?")]
    [Parameter(Mandatory = $false)]
    [switch]$Help
)

# Initialize variables early
$RunningOnWindows = $PSVersionTable.Platform -eq 'Win32NT'

# Handle common help flags (--help, -h, /?, etc.) that might have been passed as FilePath
$helpFlags = @('--help', '--Help', '-h', '-H', '/?', '/h', '/H', 'help', 'HELP')
if ($FilePath -in $helpFlags) {
    $Help = $true
    $FilePath = $null  # Clear it so it doesn't cause errors later
}

# Handle Help parameter
if ($Help) {
    Write-Host "VeriHash.ps1 - A tool to compute and verify file hashes (MD5, SHA256, SHA512)." -ForegroundColor Green
    Write-Host "Usage: .\VeriHash.ps1 [FilePath] [-Hash <Hash>] [-Algorithm <Alg>] [-OnlyVerify] [-SendTo] [-Help]" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Parameters:" -ForegroundColor White
    Write-Host "  FilePath          : Path to the file to hash or verify." -ForegroundColor Yellow
    Write-Host "  -Hash, -InputHash : Provide a MD5, SHA256, or SHA512 hash for verification." -ForegroundColor Yellow
    Write-Host "  -Algorithm        : Specify which hash(es) to compute: MD5, SHA256, SHA512, or All." -ForegroundColor Yellow
    Write-Host "                      Can specify multiple (e.g., -Algorithm MD5,SHA512)." -ForegroundColor Yellow
    Write-Host "                      Default: SHA256 (if no -Hash provided)" -ForegroundColor Yellow
    Write-Host "  -OnlyVerify       : Only verify the provided hash, don't compute additional hashes." -ForegroundColor Yellow
    Write-Host "  -SendTo           : Creates a SendTo shortcut for easy access (Windows only)." -ForegroundColor Yellow
    Write-Host "  -Help             : Displays this help message." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor White
    Write-Host "  .\VeriHash.ps1 'C:\file.txt'                              # Compute SHA256" -ForegroundColor Cyan
    Write-Host "  .\VeriHash.ps1 'C:\file.txt' -Hash 'ABC123...'            # Verify hash + compute SHA256" -ForegroundColor Cyan
    Write-Host "  .\VeriHash.ps1 'C:\file.txt' -Hash 'ABC...' -OnlyVerify  # Only verify, no extra hashing" -ForegroundColor Cyan
    Write-Host "  .\VeriHash.ps1 'C:\file.txt' -Algorithm MD5,SHA512       # Compute MD5 and SHA512" -ForegroundColor Cyan
    Write-Host "  .\VeriHash.ps1 'C:\file.txt' -Algorithm All              # Compute all hash types" -ForegroundColor Cyan
    Write-Host "  .\VeriHash.ps1 -SendTo                                   # Install SendTo shortcut" -ForegroundColor Cyan
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
function Get-And-SaveHash {
    param (
        [string]$PathToFile,
        [string]$Algorithm  # MD5 | SHA256 | SHA512
    )

    # Use built-in Get-FileHash
    $fileHash = Get-FileHash -Path $PathToFile -Algorithm $Algorithm
    $hashValue = $fileHash.Hash.ToUpper()

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
                # Rename old file so you don't lose it
                $newName = $hashFileName + ".old"
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
function Invoke-HashFile {
    param (
        [string]$FilePath,
        [string]$InputHash,
        [string[]]$Algorithm,
        [switch]$OnlyVerify
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
        $currentUTC   = Get-Date -AsUTC
        $currentLocal = Get-Date

        Write-Host "Universal:    $($currentUTC.ToString("yyyy-MM-ddTHH:mm:ss.fffZ"))" -ForegroundColor Cyan
        Write-Host "Local Sys:    $($currentLocal.ToString("MMMM dd, yyyy")) | $($currentLocal.ToString("HH:mm:ss"))" -ForegroundColor Cyan
        Write-Host "---" -ForegroundColor Cyan

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
                    Write-Host "Digitally Signed?:       Skipped (Authenticode signatures are not supported on this platform) 🚫" -ForegroundColor Yellow
                }
                Write-Host "---" -ForegroundColor Cyan
            }

            # Start computing
            $startTime = Get-Date

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
                Write-Host "Input Hash:     $InputHash" -ForegroundColor Yellow
                $resVerify = Get-And-SaveHash -PathToFile $FilePath -Algorithm $detectedAlgorithm
                Write-Host "Computed Hash:  $($resVerify.Hash)" -ForegroundColor Magenta
                Test-InputHash -ComputedHash $resVerify.Hash -InputHash $InputHash
                Write-Host "Saved to:       $($resVerify.Sidecar)" -ForegroundColor Green

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
                $res = Get-And-SaveHash -PathToFile $FilePath -Algorithm $alg
                Write-Host "$alg Hash:  $($res.Hash)" -ForegroundColor Magenta
                Write-Host "Saved to:   $($res.Sidecar)" -ForegroundColor Green
            }

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
Invoke-HashFile -FilePath $FilePath -InputHash $Hash -Algorithm $Algorithm -OnlyVerify:$OnlyVerify
