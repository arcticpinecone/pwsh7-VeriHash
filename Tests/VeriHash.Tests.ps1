BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    $script:TestIconFile  = Join-Path $PSScriptRoot 'Fixtures/VeriHash_1024.ico'
    $script:TestOutputDir = Join-Path $TestDrive 'VeriHashTests'
    New-Item -ItemType Directory -Path $script:TestOutputDir -Force | Out-Null
}
AfterAll {
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
}

# Phase 1 note:
#   The legacy Pester suite (Test-InputHash, Get-ClipboardHash, Get-And-SaveHash,
#   Test-HashSidecar, Sidecar Update / Force / Match, Clipboard+Sidecar Interaction,
#   Help System, SkipSignatureCheck, Smart Signature Detection, Logging)
#   exercised the v1 monolith VeriHash.ps1 via the dot-source-with-dummy-path hack.
#   All Phase-1-relevant behaviors are now covered by Tests/VeriHash.Core.*.Tests.ps1:
#     - Test-InputHash         -> Get-VeriHashResult.Tests.ps1
#     - Get-ClipboardHash      -> Read-ClipboardHash.Tests.ps1
#     - Test-HashSidecar       -> Test-VeriHashSidecar.Tests.ps1
#     - Get-And-SaveHash       -> deferred to Phase 2 (write-side Save-VeriHashSidecar)
#     - Help / Force / -SendTo -> deferred to Phase 6 (CLI rewrite around Core)
#     - Logging                -> Write-VeriHashLog (Core, Phase 1)
#   This file is retained as a thin smoke-test so Phase 5 has a clear migration target
#   when it deletes the v1 monolith VeriHash.ps1.

Describe 'VeriHash.Core smoke tests' {
    It 'Imports the module and exports the 6 public functions' {
        $expected = @(
            'Format-VeriHashReport'
            'Get-VeriHashPlatform'
            'Get-VeriHashResult'
            'Read-ClipboardHash'
            'Test-VeriHashSidecar'
            'Write-VeriHashLog'
        )
        $actual = (Get-Command -Module VeriHash.Core).Name | Sort-Object
        $actual | Should -Be $expected
    }

    It 'Computes the canonical SHA256 for the bundled icon fixture' {
        $r = Get-VeriHashResult -Path $script:TestIconFile -Algorithm SHA256
        $r.Hash | Should -Be '3eb53e022fc03d61dffe2aff3244103daef28166b9c538cabbf04462fa59c775'
    }

    It 'Legacy VeriHash.ps1 monolith still parses without syntax errors' {
        $tokens = $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            (Join-Path $PSScriptRoot '..' 'VeriHash.ps1'),
            [ref]$tokens,
            [ref]$errors
        ) | Out-Null
        $errors | Should -BeNullOrEmpty
    }
}
