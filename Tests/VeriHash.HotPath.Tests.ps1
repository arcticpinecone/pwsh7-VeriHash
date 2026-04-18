BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force
    $env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')
}
AfterAll {
    Remove-Module VeriHash.HotPath -ErrorAction SilentlyContinue
    Remove-Item Env:VERIHASH_LOG_PATH -ErrorAction SilentlyContinue
}

Describe 'VeriHash.HotPath module manifest + exports (Plan 01 surface)' {
    It 'Imports cleanly' {
        { Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force } | Should -Not -Throw
    }

    It 'Re-imports with -Force without "type already defined"' {
        { 1..2 | ForEach-Object { Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force } } | Should -Not -Throw
    }

    It 'Exports Get-VeriHashSignature' {
        (Get-Command -Module VeriHash.HotPath).Name | Should -Contain 'Get-VeriHashSignature'
    }

    It 'Exports exactly the locked Plan 01 public surface' {
        $expected = @('Get-VeriHashSignature') | Sort-Object
        $actual   = (Get-Command -Module VeriHash.HotPath).Name | Sort-Object
        Compare-Object $actual $expected | Should -BeNullOrEmpty
    }

    It 'Manifest pins PowerShellVersion 7.0 and CompatiblePSEditions Core' {
        $m = Test-ModuleManifest "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1"
        $m.PowerShellVersion | Should -Be ([version]'7.0')
        $m.CompatiblePSEditions | Should -Contain 'Core'
    }

    It 'No PSFramework references in VeriHash.HotPath/' {
        $hits = Get-ChildItem "$PSScriptRoot/../VeriHash.HotPath" -Recurse -File |
            Select-String -Pattern 'PSFramework|Write-PSFMessage' -ErrorAction SilentlyContinue
        $hits | Should -BeNullOrEmpty
    }

    It 'No forbidden WTD_DISABLE_MD2_MD4 flag in VeriHash.HotPath/' {
        $hits = Get-ChildItem "$PSScriptRoot/../VeriHash.HotPath" -Recurse -File |
            Select-String -Pattern 'WTD_DISABLE_MD2_MD4' -ErrorAction SilentlyContinue
        $hits | Should -BeNullOrEmpty
    }

    It 'No redundant $IsWindows / $RunningOnWindows redefinitions in VeriHash.HotPath/' {
        # Carried-forward from Phase 1 D-A2: only Get-VeriHashPlatform may decide platform.
        # We allow read-only references? Plan acceptance criteria say zero matches at all.
        $hits = Get-ChildItem "$PSScriptRoot/../VeriHash.HotPath" -Recurse -File |
            Select-String -Pattern '\$IsWindows|\$RunningOnWindows' -ErrorAction SilentlyContinue
        $hits | Should -BeNullOrEmpty
    }
}
