BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    $script:Fixture = Join-Path $PSScriptRoot 'Fixtures/VeriHash_1024.ico'
}
AfterAll {
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
}

Describe 'Get-VeriHashResult (CORE-02)' {
    It 'Returns VeriHash.Result for MD5 with lowercase 32-hex hash' {
        $r = Get-VeriHashResult -Path $script:Fixture -Algorithm MD5
        $r.PSTypeNames | Should -Contain 'VeriHash.Result'
        $r.FilePath | Should -Not -BeNullOrEmpty
        $r.Algorithm | Should -Be 'MD5'
        $r.Hash | Should -Match '^[a-f0-9]{32}$'
        $r.Size | Should -BeOfType [long]
        $r.ElapsedMs | Should -BeGreaterOrEqual 0
    }

    It 'Returns VeriHash.Result for SHA256 with lowercase 64-hex hash' {
        $r = Get-VeriHashResult -Path $script:Fixture -Algorithm SHA256
        $r.PSTypeNames | Should -Contain 'VeriHash.Result'
        $r.Algorithm | Should -Be 'SHA256'
        $r.Hash | Should -Match '^[a-f0-9]{64}$'
        $r.Size | Should -BeOfType [long]
        $r.ElapsedMs | Should -BeGreaterOrEqual 0
    }

    It 'Returns VeriHash.Result for SHA512 with lowercase 128-hex hash' {
        $r = Get-VeriHashResult -Path $script:Fixture -Algorithm SHA512
        $r.PSTypeNames | Should -Contain 'VeriHash.Result'
        $r.Algorithm | Should -Be 'SHA512'
        $r.Hash | Should -Match '^[a-f0-9]{128}$'
        $r.Size | Should -BeOfType [long]
        $r.ElapsedMs | Should -BeGreaterOrEqual 0
    }

    It 'Rejects nonexistent paths' {
        { Get-VeriHashResult -Path '/no/such/file.bin' -Algorithm SHA256 } | Should -Throw
    }
}
