$ErrorActionPreference = 'Stop'

# HotPath orchestrator depends on Get-VeriHashResult / Format-VeriHashReport / Read-ClipboardHash
# / Test-VeriHashSidecar / Write-VeriHashLog from VeriHash.Core, plus Get-VeriHashPlatform.
# Import Core eagerly so callers don't have to (Plan 02-02 follow-up to Open Question 4).
$coreManifest = Join-Path $PSScriptRoot '..\VeriHash.Core\VeriHash.Core.psd1'
if (Test-Path -LiteralPath $coreManifest) {
    Import-Module $coreManifest -Force -Global -ErrorAction Stop
}

# Dot-source Private helpers FIRST so Public functions can call them at runtime.
Get-ChildItem -Path "$PSScriptRoot/Private" -Filter '*.ps1' -ErrorAction SilentlyContinue |
    ForEach-Object { . $_.FullName }

# Then dot-source Public functions.
$publicFiles = @(Get-ChildItem -Path "$PSScriptRoot/Public" -Filter '*.ps1' -ErrorAction SilentlyContinue)
foreach ($f in $publicFiles) { . $f.FullName }

# Belt-and-suspenders alongside the manifest's FunctionsToExport.
Export-ModuleMember -Function $publicFiles.BaseName
