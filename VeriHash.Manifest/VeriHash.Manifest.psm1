$ErrorActionPreference = 'Stop'

# Manifest module depends on Get-VeriHashResult from VeriHash.Core for all hashing (D-09).
# Import Core eagerly so callers don't have to.
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
