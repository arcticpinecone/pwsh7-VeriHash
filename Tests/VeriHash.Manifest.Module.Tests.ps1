BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    Import-Module "$PSScriptRoot/../VeriHash.Manifest/VeriHash.Manifest.psd1" -Force
    $env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')
    # Add repo root to PSModulePath so Test-ModuleManifest can resolve VeriHash.Core by name (999.3)
    $script:origPSModulePath = $env:PSModulePath
    $repoRoot = (Resolve-Path "$PSScriptRoot/..").Path
    if ($env:PSModulePath -notlike "*$repoRoot*") {
        $env:PSModulePath = "$repoRoot$([IO.Path]::PathSeparator)$env:PSModulePath"
    }
}
AfterAll {
    Remove-Module VeriHash.Manifest -ErrorAction SilentlyContinue
    Remove-Item Env:VERIHASH_LOG_PATH -ErrorAction SilentlyContinue
    $env:PSModulePath = $script:origPSModulePath
}

Describe 'VeriHash.Manifest module manifest + exports' {
    It 'Imports cleanly' {
        { Import-Module "$PSScriptRoot/../VeriHash.Manifest/VeriHash.Manifest.psd1" -Force } | Should -Not -Throw
    }

    It 'Re-imports with -Force without errors' {
        { 1..2 | ForEach-Object { Import-Module "$PSScriptRoot/../VeriHash.Manifest/VeriHash.Manifest.psd1" -Force } } | Should -Not -Throw
    }

    It 'Exports exactly the locked public surface: New-VeriHashManifest, Test-VeriHashManifest' {
        $expected = @('New-VeriHashManifest', 'Test-VeriHashManifest') | Sort-Object
        $actual   = (Get-Command -Module VeriHash.Manifest).Name | Sort-Object
        Compare-Object $actual $expected | Should -BeNullOrEmpty
    }

    It 'Manifest pins PowerShellVersion 7.0 and CompatiblePSEditions Core' {
        $m = Test-ModuleManifest "$PSScriptRoot/../VeriHash.Manifest/VeriHash.Manifest.psd1"
        $m.PowerShellVersion | Should -Be ([version]'7.0')
        $m.CompatiblePSEditions | Should -Contain 'Core'
    }

    It 'Declares RequiredModules including VeriHash.Core (D-16)' {
        $m = Test-ModuleManifest "$PSScriptRoot/../VeriHash.Manifest/VeriHash.Manifest.psd1"
        $m.RequiredModules.Name | Should -Contain 'VeriHash.Core'
    }

    It 'No Write-Host calls in VeriHash.Manifest/ (D-17)'{
        $hits = Get-ChildItem "$PSScriptRoot/../VeriHash.Manifest" -Recurse -File |
            Select-String -Pattern 'Write-Host' -ErrorAction SilentlyContinue
        $hits | Should -BeNullOrEmpty
    }
}
