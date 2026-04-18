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

    It 'Exports Invoke-VeriHashHotPath after Plan 02 manifest update' {
        (Get-Command -Module VeriHash.HotPath).Name | Should -Contain 'Invoke-VeriHashHotPath'
    }

    It 'Exports exactly the locked Plan 02 public surface' {
        $expected = @('Get-VeriHashSignature', 'Invoke-VeriHashHotPath') | Sort-Object
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

Describe 'Invoke-VeriHashHotPath: result-object shape (D-A5-1)' {
    BeforeAll {
        $script:PEFixture    = Join-Path $PSScriptRoot 'Fixtures/tiny-pe.bin'
        $script:NotPEFixture = Join-Path $PSScriptRoot 'Fixtures/tiny-not-pe.bin'
    }

    It 'PE input: returns VeriHash.HotPathResult with all D-A5-1 fields' {
        $r = Invoke-VeriHashHotPath -Path $script:PEFixture -Algorithm SHA256
        $r.PSTypeNames | Should -Contain 'VeriHash.HotPathResult'
        $r.IsPE | Should -BeTrue
        $r.HashAlgorithm | Should -Be 'SHA256'
        $r.Hash | Should -Match '^[0-9a-f]{64}$'
        $r.HashElapsedMs | Should -BeGreaterOrEqual 0
        $r.SigElapsedMs  | Should -BeGreaterOrEqual 0
        $r.WallClockMs   | Should -BeGreaterOrEqual 0
        $r.Signature     | Should -BeIn @('valid', 'invalid', 'unsigned', 'skipped', 'error')
    }

    It 'Non-PE input: IsPE=$false; Signature=skipped; Reason="not a PE file"; SigElapsedMs=0' {
        $r = Invoke-VeriHashHotPath -Path $script:NotPEFixture -Algorithm SHA256
        $r.IsPE | Should -BeFalse
        $r.Signature | Should -Be 'skipped'
        $r.SignatureReason | Should -Be 'not a PE file'
        $r.SigElapsedMs | Should -Be 0
    }

    It 'Non-PE input: host output contains literal "Signature: skipped (not a PE file)"' {
        $captured = Invoke-VeriHashHotPath -Path $script:NotPEFixture -Algorithm SHA256 6>&1 | Out-String
        $captured | Should -Match 'Signature:\s*skipped\s*\(not a PE file\)'
    }
}

Describe 'Invoke-VeriHashHotPath: PERF-05 wall-clock honesty' {
    It 'Returned WallClockMs within 50ms of Measure-Command' {
        $fixture = Join-Path $PSScriptRoot 'Fixtures/tiny-pe.bin'
        $script:result = $null
        $measured = Measure-Command { $script:result = Invoke-VeriHashHotPath -Path $fixture -Algorithm SHA256 6>$null }
        [math]::Abs($script:result.WallClockMs - [int]$measured.TotalMilliseconds) | Should -BeLessOrEqual 50
    }
}

Describe 'Invoke-VeriHashHotPath: cross-platform' -Skip:($IsWindows) {
    It 'On non-Windows returns Signature=skipped, Reason=not supported on this platform' {
        $fixture = Join-Path $PSScriptRoot 'Fixtures/tiny-pe.bin'
        $r = Invoke-VeriHashHotPath -Path $fixture -Algorithm SHA256
        $r.Signature | Should -Be 'skipped'
        $r.SignatureReason | Should -Be 'not supported on this platform'
    }
}
