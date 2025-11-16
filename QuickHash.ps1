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
            $fileContent = Get-Content -Path $InputValue -Encoding Byte -ReadCount 0
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
