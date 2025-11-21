<#
.SYNOPSIS
    Performance profiler for VeriHash operations
.DESCRIPTION
    Measures the time spent in various operations to understand overhead breakdown
#>

param(
    [Parameter(Mandatory)]
    [string]$FilePath,

    [ValidateSet('SHA256', 'MD5', 'SHA512')]
    [string]$Algorithm = 'SHA256'
)

Write-Host "`n=== VeriHash Performance Profiler ===" -ForegroundColor Cyan
Write-Host "File: $FilePath" -ForegroundColor Cyan
Write-Host "Algorithm: $Algorithm`n" -ForegroundColor Cyan

$measurements = @{}

# 1. Get-Item operation
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$fileItem = Get-Item -LiteralPath $FilePath -ErrorAction Stop
$sw.Stop()
$measurements['Get-Item'] = $sw.Elapsed.TotalMilliseconds

# 2. File size formatting
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$sizeBytes = $fileItem.Length
if ($sizeBytes -ge 1GB) {
    $sizeFormatted = "{0:N2} GB" -f ($sizeBytes / 1GB)
} elseif ($sizeBytes -ge 1MB) {
    $sizeFormatted = "{0:N2} MB" -f ($sizeBytes / 1MB)
} elseif ($sizeBytes -ge 1KB) {
    $sizeFormatted = "{0:N2} KB" -f ($sizeBytes / 1KB)
} else {
    $sizeFormatted = "$sizeBytes bytes"
}
$sw.Stop()
$measurements['Size Formatting'] = $sw.Elapsed.TotalMilliseconds

# 3. Date/Time operations
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$currentUTC = (Get-Date).ToUniversalTime()
$utcString = $currentUTC.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
$sw.Stop()
$measurements['DateTime Operations'] = $sw.Elapsed.TotalMilliseconds

# 4. Digital signature check
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$signature = Get-AuthenticodeSignature -LiteralPath $FilePath -ErrorAction SilentlyContinue
$isSigned = $signature -and $signature.Status -eq 'Valid'
$sw.Stop()
$measurements['Digital Signature Check'] = $sw.Elapsed.TotalMilliseconds

# 5. Hash computation
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$hashObj = Get-FileHash -LiteralPath $FilePath -Algorithm $Algorithm -ErrorAction Stop
$hashValue = $hashObj.Hash
$sw.Stop()
$measurements['Hash Computation'] = $sw.Elapsed.TotalMilliseconds

# 6. Sidecar file write (simulated - write to temp)
$tempSidecar = [System.IO.Path]::GetTempFileName()
$sidecarContent = "$hashValue *$($fileItem.Name)"
$sw = [System.Diagnostics.Stopwatch]::StartNew()
Set-Content -Path $tempSidecar -Value $sidecarContent -Encoding UTF8 -Force
$sw.Stop()
$measurements['Sidecar File Write'] = $sw.Elapsed.TotalMilliseconds
Remove-Item -Path $tempSidecar -Force -ErrorAction SilentlyContinue

# 7. Console output overhead (10 Write-Host calls)
$sw = [System.Diagnostics.Stopwatch]::StartNew()
for ($i = 1; $i -le 10; $i++) {
    Write-Host "Test output line $i" -ForegroundColor Gray | Out-Null
}
$sw.Stop()
$measurements['Console Output (10 lines)'] = $sw.Elapsed.TotalMilliseconds

# Clear the test output
try {
    Clear-Host
} catch {
    # Clear-Host fails in non-interactive contexts (like Pester tests), silently ignore
}

# Calculate totals and percentages
$total = ($measurements.Values | Measure-Object -Sum).Sum
$sortedMeasurements = $measurements.GetEnumerator() | Sort-Object -Property Value -Descending

# Build result object for programmatic access (Pester tests)
$resultObject = [PSCustomObject]@{
    FilePath = $FilePath
    Algorithm = $Algorithm
    Measurements = $measurements
    Total = $total
    SortedMeasurements = $sortedMeasurements
}

# Display results for human consumption
Write-Host "`n=== VeriHash Performance Profiler ===" -ForegroundColor Cyan
Write-Host "File: $FilePath" -ForegroundColor Cyan
Write-Host "Algorithm: $Algorithm`n" -ForegroundColor Cyan

Write-Host "Performance Breakdown:" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

foreach ($entry in $sortedMeasurements) {
    $name = $entry.Key
    $ms = $entry.Value

    # Color code by time
    $color = if ($ms -gt 10) { 'Red' } elseif ($ms -gt 5) { 'Yellow' } elseif ($ms -gt 1) { 'Cyan' } else { 'Gray' }

    Write-Host ("{0,-30} : {1,7:N2} ms" -f $name, $ms) -ForegroundColor $color
}

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ("{0,-30} : {1,7:N2} ms" -f "TOTAL", $total) -ForegroundColor Green

# Calculate percentages
Write-Host "`nPercentage Breakdown:" -ForegroundColor Yellow
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

foreach ($entry in $sortedMeasurements) {
    $name = $entry.Key
    $ms = $entry.Value
    $percentage = ($ms / $total) * 100

    $color = if ($percentage -gt 25) { 'Red' } elseif ($percentage -gt 10) { 'Yellow' } else { 'Gray' }

    Write-Host ("{0,-30} : {1,6:N2}%" -f $name, $percentage) -ForegroundColor $color
}

Write-Host ""

# Return the result object for programmatic access (Pester tests can use this!)
return $resultObject
