BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force
    $script:PEFixture = Join-Path $PSScriptRoot 'Fixtures/tiny-pe.bin'
    $env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')
    # Detect platform once so -Skip expressions are cheap and consistent.
    $script:OnWindows = ($IsWindows)
}
AfterAll {
    Remove-Module VeriHash.HotPath -ErrorAction SilentlyContinue
    Remove-Item Env:VERIHASH_LOG_PATH -ErrorAction SilentlyContinue
}

Describe 'Get-VeriHashSignature platform gate (D-A1-1)' {
    It 'On non-Windows returns Status=skipped, Reason=not supported on this platform; never P/Invokes' -Skip:($IsWindows) {
        $p = $script:PEFixture
        InModuleScope VeriHash.HotPath -Parameters @{ p = $p } {
            param($p)
            Mock Invoke-WinVerifyTrust { return 0 }
            $r = Get-VeriHashSignature -Path $p -IsPE
            $r.Status | Should -Be 'skipped'
            $r.Reason | Should -Be 'not supported on this platform'
            Should -Invoke Invoke-WinVerifyTrust -Times 0
        }
    }
}

Describe 'Get-VeriHashSignature non-PE handling (PERF-01)' {
    It 'Returns Status=skipped, Reason="not a PE file" when -IsPE is $false' -Skip:(-not $IsWindows) {
        $p = $script:PEFixture
        InModuleScope VeriHash.HotPath -Parameters @{ p = $p } {
            param($p)
            Mock Invoke-WinVerifyTrust { return 0 }
            $r = Get-VeriHashSignature -Path $p   # no -IsPE
            $r.Status | Should -Be 'skipped'
            $r.Reason | Should -Be 'not a PE file'
            Should -Invoke Invoke-WinVerifyTrust -Times 0
        }
    }
}

Describe 'Get-VeriHashSignature HRESULT to Status (PERF-02)' -Skip:(-not $IsWindows) {
    It 'S_OK (0) -> valid' {
        $p = $script:PEFixture
        InModuleScope VeriHash.HotPath -Parameters @{ p = $p } {
            param($p)
            Mock Invoke-WinVerifyTrust { return 0 }
            (Get-VeriHashSignature -Path $p -IsPE).Status | Should -Be 'valid'
        }
    }

    It 'TRUST_E_NOSIGNATURE (0x800B0100) -> unsigned' {
        $p = $script:PEFixture
        InModuleScope VeriHash.HotPath -Parameters @{ p = $p } {
            param($p)
            Mock Invoke-WinVerifyTrust { return -2146762496 }
            (Get-VeriHashSignature -Path $p -IsPE).Status | Should -Be 'unsigned'
        }
    }

    It 'TRUST_E_BAD_DIGEST (0x80096010) -> invalid' {
        $p = $script:PEFixture
        InModuleScope VeriHash.HotPath -Parameters @{ p = $p } {
            param($p)
            Mock Invoke-WinVerifyTrust { return -2146869232 }
            (Get-VeriHashSignature -Path $p -IsPE).Status | Should -Be 'invalid'
        }
    }

    It 'TRUST_E_EXPLICIT_DISTRUST (0x800B0111) -> invalid' {
        $p = $script:PEFixture
        InModuleScope VeriHash.HotPath -Parameters @{ p = $p } {
            param($p)
            Mock Invoke-WinVerifyTrust { return -2146762479 }
            (Get-VeriHashSignature -Path $p -IsPE).Status | Should -Be 'invalid'
        }
    }

    It 'CERT_E_EXPIRED (0x800B0101) -> invalid' {
        $p = $script:PEFixture
        InModuleScope VeriHash.HotPath -Parameters @{ p = $p } {
            param($p)
            Mock Invoke-WinVerifyTrust { return -2146762495 }
            (Get-VeriHashSignature -Path $p -IsPE).Status | Should -Be 'invalid'
        }
    }

    It 'CERT_E_REVOKED (0x80092010) -> invalid' {
        $p = $script:PEFixture
        InModuleScope VeriHash.HotPath -Parameters @{ p = $p } {
            param($p)
            Mock Invoke-WinVerifyTrust { return -2146885616 }
            (Get-VeriHashSignature -Path $p -IsPE).Status | Should -Be 'invalid'
        }
    }

    It 'CERT_E_UNTRUSTEDROOT (0x800B0109) -> invalid' {
        $p = $script:PEFixture
        InModuleScope VeriHash.HotPath -Parameters @{ p = $p } {
            param($p)
            Mock Invoke-WinVerifyTrust { return -2146762487 }
            (Get-VeriHashSignature -Path $p -IsPE).Status | Should -Be 'invalid'
        }
    }

    It 'CERT_E_CHAINING (0x800B010A) -> invalid' {
        $p = $script:PEFixture
        InModuleScope VeriHash.HotPath -Parameters @{ p = $p } {
            param($p)
            Mock Invoke-WinVerifyTrust { return -2146762486 }
            (Get-VeriHashSignature -Path $p -IsPE).Status | Should -Be 'invalid'
        }
    }

    It 'Unknown HRESULT (0xDEADBEEF) -> error with hex Reason' {
        $p = $script:PEFixture
        InModuleScope VeriHash.HotPath -Parameters @{ p = $p } {
            param($p)
            Mock Invoke-WinVerifyTrust { return -559038737 }   # 0xDEADBEEF as int32
            $r = Get-VeriHashSignature -Path $p -IsPE
            $r.Status | Should -Be 'error'
            $r.Reason | Should -Match '0xDEADBEEF'
        }
    }
}
