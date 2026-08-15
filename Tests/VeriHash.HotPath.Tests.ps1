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
        $expected = @('Get-VeriHashSignature', 'Invoke-VeriHashHotPath', 'Invoke-VeriHashBatch') | Sort-Object
        $actual   = (Get-Command -Module VeriHash.HotPath).Name | Sort-Object
        Compare-Object $actual $expected | Should -BeNullOrEmpty
    }

    It 'Manifest pins PowerShellVersion 7.0 and CompatiblePSEditions Core' {
        $m = Test-ModuleManifest "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1"
        $m.PowerShellVersion | Should -Be ([version]'7.0')
        $m.CompatiblePSEditions | Should -Contain 'Core'
    }

    It 'No forbidden WTD_DISABLE_MD2_MD4 flag in VeriHash.HotPath/'{
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

    # The standalone 'Signature: ...' line is gone as of the unified render --
    # the signature verdict now reaches the user through the checklist grid.
    # Covered by 'Carries the real signature verdict into the checklist row'.
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

Describe 'Invoke-VeriHashHotPath unified render (FMT-09)' {
    BeforeAll {
        . "$PSScriptRoot/TestHelpers.ps1"
        $script:SavedColorEnv = Save-VeriHashColorEnv
        Set-VeriHashColorEnv -Mode Truecolor
        $script:PrevEncoding = [Console]::OutputEncoding
        try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch { }

        # Captures the host stream WITHOUT the returned object: the assignment
        # inside the scriptblock swallows the success stream, so Out-String sees
        # only the rendered report. The result is parked for shape assertions.
        function script:RenderHotPath {
            param([string]$Path)
            $out = & { $script:LastResult = Invoke-VeriHashHotPath -Path $Path } 6>&1 | Out-String
            return (($out -replace "`r`n", "`n") | Remove-Ansi)
        }
    }
    AfterAll {
        try { [Console]::OutputEncoding = $script:PrevEncoding } catch { }
        Restore-VeriHashColorEnv -Saved $script:SavedColorEnv
    }
    BeforeEach {
        # A fresh directory per test: the sidecar written by one test must not
        # turn the next test's 'created' into 'matched'.
        $script:WorkDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $script:WorkDir
        $script:Target  = Join-Path $script:WorkDir 'render-target.bin'
        [System.IO.File]::WriteAllBytes($script:Target, [byte[]](1..64))
    }

    It 'Renders one checklist and no second signature or sidecar line' {
        $out = script:RenderHotPath -Path $script:Target
        ([regex]::Matches($out, '(?m)^signature\s')).Count | Should -Be 1
        $out | Should -Not -Match 'Signature:'
        $out | Should -Not -Match 'Sidecar:'
    }

    It 'Carries the real signature verdict into the checklist row' {
        $out = script:RenderHotPath -Path $script:Target
        $out | Should -Match ([regex]::Escape('skipped (not a PE file)'))
        $out | Should -Not -Match 'not checked'
    }

    It 'Writes a sidecar and reports it as created in the checklist' {
        $out = script:RenderHotPath -Path $script:Target
        Test-Path -LiteralPath "$($script:Target).sha256" | Should -BeTrue
        $out | Should -Match ([regex]::Escape('created — render-target.bin.sha256'))
    }

    It 'Suppresses the sidecar write when the clipboard verdict is MISMATCH' {
        Mock -ModuleName VeriHash.Core Get-Clipboard { '0' * 64 }
        Mock -ModuleName VeriHash.Core Get-VeriHashPlatform { 'Windows' }
        $null = script:RenderHotPath -Path $script:Target
        Test-Path -LiteralPath "$($script:Target).sha256" | Should -BeFalse
    }

    It 'Explains the suppressed sidecar in the checklist row' {
        Mock -ModuleName VeriHash.Core Get-Clipboard { '0' * 64 }
        Mock -ModuleName VeriHash.Core Get-VeriHashPlatform { 'Windows' }
        $out = script:RenderHotPath -Path $script:Target
        $out | Should -Match ([regex]::Escape('none found · not written on mismatch'))
    }

    It 'Leaves the HotPathResult shape unchanged' {
        $null = script:RenderHotPath -Path $script:Target
        foreach ($prop in @('FilePath', 'Hash', 'HashAlgorithm', 'HashElapsedMs', 'Signature',
                            'SignatureReason', 'SigElapsedMs', 'WallClockMs', 'IsPE', 'MatchResult')) {
            $script:LastResult.PSObject.Properties.Name | Should -Contain $prop
        }
    }
}
