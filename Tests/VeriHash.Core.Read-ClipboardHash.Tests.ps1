BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
}
AfterAll {
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
}

Describe 'Read-ClipboardHash (CORE-03 + CORE-04)' {
    Context 'Length inference' {
        It 'Detects 32-hex as MD5' {
            Mock -ModuleName VeriHash.Core Get-Clipboard { '5d41402abc4b2a76b9719d911017c592' }
            Mock -ModuleName VeriHash.Core Get-VeriHashPlatform { 'Windows' }
            $r = Read-ClipboardHash
            $r.Algorithm | Should -Be 'MD5'
            $r.Hash | Should -Be '5d41402abc4b2a76b9719d911017c592'
        }

        It 'Detects 64-hex as SHA256' {
            $hex = 'a' * 64
            Mock -ModuleName VeriHash.Core Get-Clipboard { $hex }
            Mock -ModuleName VeriHash.Core Get-VeriHashPlatform { 'Windows' }
            $r = Read-ClipboardHash
            $r.Algorithm | Should -Be 'SHA256'
        }

        It 'Detects 128-hex as SHA512' {
            $hex = 'b' * 128
            Mock -ModuleName VeriHash.Core Get-Clipboard { $hex }
            Mock -ModuleName VeriHash.Core Get-VeriHashPlatform { 'Windows' }
            $r = Read-ClipboardHash
            $r.Algorithm | Should -Be 'SHA512'
        }

        It 'Returns $null for garbage input' {
            Mock -ModuleName VeriHash.Core Get-Clipboard { 'not a hash' }
            Mock -ModuleName VeriHash.Core Get-VeriHashPlatform { 'Windows' }
            Read-ClipboardHash | Should -BeNullOrEmpty
        }
    }

    Context 'Prefix form (CORE-04)' {
        It 'Detects sha256: prefix' {
            $hex = 'c' * 64
            Mock -ModuleName VeriHash.Core Get-Clipboard { "sha256:$hex" }
            Mock -ModuleName VeriHash.Core Get-VeriHashPlatform { 'Windows' }
            $r = Read-ClipboardHash
            $r.Algorithm | Should -Be 'SHA256'
        }

        It 'Detects md5: prefix' {
            $hex = 'd' * 32
            Mock -ModuleName VeriHash.Core Get-Clipboard { "md5:$hex" }
            Mock -ModuleName VeriHash.Core Get-VeriHashPlatform { 'Windows' }
            $r = Read-ClipboardHash
            $r.Algorithm | Should -Be 'MD5'
        }

        It 'Detects sha512: prefix' {
            $hex = 'e' * 128
            Mock -ModuleName VeriHash.Core Get-Clipboard { "sha512:$hex" }
            Mock -ModuleName VeriHash.Core Get-VeriHashPlatform { 'Windows' }
            $r = Read-ClipboardHash
            $r.Algorithm | Should -Be 'SHA512'
        }

        It 'Rejects when prefix conflicts with length (md5: + 64 hex)' {
            $hex = 'f' * 64
            Mock -ModuleName VeriHash.Core Get-Clipboard { "md5:$hex" }
            Mock -ModuleName VeriHash.Core Get-VeriHashPlatform { 'Windows' }
            Read-ClipboardHash | Should -BeNullOrEmpty
        }
    }

    Context 'Non-Windows behavior' {
        It 'Returns $null on Linux' {
            Mock -ModuleName VeriHash.Core Get-VeriHashPlatform { 'Linux' }
            Read-ClipboardHash | Should -BeNullOrEmpty
        }
    }

    Context 'Detected format (FMT)' {
        It 'Reports bare hex as plain hex with the inferred algorithm' {
            $hex = '3eb53e022fc03d61dffe2aff3244103daef28166b9c538cabbf04462fa59c775'
            Mock -ModuleName VeriHash.Core Get-Clipboard { $hex }
            Mock -ModuleName VeriHash.Core Get-VeriHashPlatform { 'Windows' }
            (Read-ClipboardHash).Format | Should -BeExactly 'plain hex, SHA256'
        }

        It 'Reports an algo-prefixed hash as prefixed with the literal prefix' {
            $hex = '3eb53e022fc03d61dffe2aff3244103daef28166b9c538cabbf04462fa59c775'
            Mock -ModuleName VeriHash.Core Get-Clipboard { "sha256:$hex" }
            Mock -ModuleName VeriHash.Core Get-VeriHashPlatform { 'Windows' }
            (Read-ClipboardHash).Format | Should -BeExactly 'prefixed, sha256:'
        }

        It 'Reports MD5 by length' {
            Mock -ModuleName VeriHash.Core Get-Clipboard { '441b45a2052b1f74aa946ba587a8f4f7' }
            Mock -ModuleName VeriHash.Core Get-VeriHashPlatform { 'Windows' }
            (Read-ClipboardHash).Format | Should -BeExactly 'plain hex, MD5'
        }

        It 'Normalises an uppercase prefix to lowercase for display' {
            $hex = 'a' * 128
            Mock -ModuleName VeriHash.Core Get-Clipboard { "SHA512:$hex" }
            Mock -ModuleName VeriHash.Core Get-VeriHashPlatform { 'Windows' }
            (Read-ClipboardHash).Format | Should -BeExactly 'prefixed, sha512:'
        }
    }
}
