<#
    QuickHash.ps1 - Lightweight interactive tool for quick hash calculations

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
#>

# Define the main function to calculate hash
function Get-Hash {
    param (
        [Parameter(Mandatory = $true)]
        [string]$InputValue,

        [Parameter(Mandatory = $true)]
        [ValidateSet("MD5", "SHA256")]
        [string]$Algorithm
    )

    try {
        Write-Host "Starting hash calculation for input: $InputValue using algorithm: $Algorithm" -ForegroundColor Cyan

        # Check if input is a file path or string
        if (Test-Path -Path $InputValue) {
            # It's a file path, compute hash of the file
            Write-Host "Input is a file. Computing hash of the file..." -ForegroundColor Green
            $fileContent = Get-Content -Path $InputValue -AsByteStream -Raw
            $hash = $null
            switch ($Algorithm) {
                "MD5" {
                    $hash = [System.Security.Cryptography.MD5]::Create()
                    break
                }
                "SHA256" {
                    $hash = [System.Security.Cryptography.SHA256]::Create()
                    break
                }
            }
            $computedHash = $hash.ComputeHash($fileContent)
            $hash.Dispose()
            $hashString = [BitConverter]::ToString($computedHash) -replace '-'
            Write-Host "Hash of the file ($InputValue): $hashString" -ForegroundColor Yellow
        }
        else {
            # It's a string, compute hash of the string
            Write-Host "Input is a string. Computing hash of the string..." -ForegroundColor Green
            $encodedInput = [System.Text.Encoding]::UTF8.GetBytes($InputValue)
            $hash = $null
            switch ($Algorithm) {
                "MD5" {
                    $hash = [System.Security.Cryptography.MD5]::Create()
                    break
                }
                "SHA256" {
                    $hash = [System.Security.Cryptography.SHA256]::Create()
                    break
                }
            }
            $computedHash = $hash.ComputeHash($encodedInput)
            $hash.Dispose()
            $hashString = [BitConverter]::ToString($computedHash) -replace '-'
            Write-Host "Hash of the string ('$InputValue'): $hashString" -ForegroundColor Yellow
        }

    }
    catch {
        Write-Host "An error occurred: $_" -ForegroundColor Red
    }
}

# Prompt user for input: String or file path
$userInput = Read-Host "Please enter a string or a file path"

# Request algorithm choice
$algorithmChoice = Read-Host "Please choose an algorithm (MD5 or SHA256)"

# Validate algorithm choice
if (-not ($algorithmChoice -in @("MD5", "SHA256"))) {
    Write-Host "Invalid algorithm choice. Please select either MD5 or SHA256." -ForegroundColor Red
    exit
}

# Call Get-Hash with the appropriate parameters
Get-Hash -InputValue $userInput -Algorithm $algorithmChoice

Write-Host "Process completed." -ForegroundColor Cyan
