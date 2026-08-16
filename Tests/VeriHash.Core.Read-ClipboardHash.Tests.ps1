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

        It 'Detects 40-hex as SHA1 (CMP-17)' {
            $hex = 'da39a3ee5e6b4b0d3255bfef95601890afd80709'
            Mock -ModuleName VeriHash.Core Get-Clipboard { $hex }
            Mock -ModuleName VeriHash.Core Get-VeriHashPlatform { 'Windows' }
            $r = Read-ClipboardHash
            $r.Algorithm | Should -Be 'SHA1'
            $r.Hash | Should -BeExactly $hex
        }

        It 'Detects a grouped SHA1 (CMP-17 + CMP-19)' {
            Mock -ModuleName VeriHash.Core Get-Clipboard { 'da39a3ee 5e6b4b0d 3255bfef 95601890 afd80709' }
            Mock -ModuleName VeriHash.Core Get-VeriHashPlatform { 'Windows' }
            (Read-ClipboardHash).Algorithm | Should -Be 'SHA1'
        }

        It 'Detects sha1: prefix (CMP-17)' {
            $hex = 'b' * 40
            Mock -ModuleName VeriHash.Core Get-Clipboard { "sha1:$hex" }
            Mock -ModuleName VeriHash.Core Get-VeriHashPlatform { 'Windows' }
            (Read-ClipboardHash).Algorithm | Should -Be 'SHA1'
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

    Context 'Whitespace and vendor formatting (CORE-05)' {
        BeforeEach {
            Mock -ModuleName VeriHash.Core Get-VeriHashPlatform { 'Windows' }
        }

        It 'Reads back its own 8-character display groups' {
            # The exact clipboard from the field report: VeriHash's own report
            # output, copied and pasted back in. Phase 7 taught VeriHash to
            # PRINT grouped hex without teaching it to READ grouped hex.
            $grouped = '5417cedc 1aeb16b4 88b80840 25246b64 a5e9da4d 71388f32 4b107140 dfe00699'
            Mock -ModuleName VeriHash.Core Get-Clipboard { $grouped }
            $r = Read-ClipboardHash
            $r.Algorithm | Should -Be 'SHA256'
            $r.Hash | Should -BeExactly '5417cedc1aeb16b488b8084025246b64a5e9da4d71388f324b107140dfe00699'
        }

        It 'Joins display groups that wrapped across lines (SHA512)' {
            # Format-VeriHashHexGroup wraps at 8 groups, so a SHA512 always
            # copies out as two lines.
            $line1 = '00112233 44556677 8899aabb ccddeeff 00112233 44556677 8899aabb ccddeeff'
            $line2 = 'ffeeddcc bbaa9988 77665544 33221100 ffeeddcc bbaa9988 77665544 33221100'
            Mock -ModuleName VeriHash.Core Get-Clipboard { @($line1, $line2) }
            $r = Read-ClipboardHash
            $r.Algorithm | Should -Be 'SHA512'
            $r.Hash.Length | Should -Be 128
        }

        It 'Reads certutil-style 2-character groups' {
            $hex = '5417cedc1aeb16b488b8084025246b64a5e9da4d71388f324b107140dfe00699'
            $pairs = (0..31 | ForEach-Object { $hex.Substring($_ * 2, 2) }) -join ' '
            Mock -ModuleName VeriHash.Core Get-Clipboard { $pairs }
            $r = Read-ClipboardHash
            $r.Algorithm | Should -Be 'SHA256'
            $r.Hash | Should -BeExactly $hex
        }

        It 'Reads a vendor label with a space after the colon' {
            $hex = 'a' * 64
            Mock -ModuleName VeriHash.Core Get-Clipboard { "SHA-256: $hex" }
            $r = Read-ClipboardHash
            $r.Algorithm | Should -Be 'SHA256'
            $r.Hash | Should -BeExactly $hex
        }

        It 'Reads a sha256sum line, ignoring the filename' {
            $hex = 'b' * 64
            Mock -ModuleName VeriHash.Core Get-Clipboard { "$hex *Docker Desktop Installer.exe" }
            $r = Read-ClipboardHash
            $r.Algorithm | Should -Be 'SHA256'
            $r.Hash | Should -BeExactly $hex
        }

        It 'Refuses to concatenate two separate SHA256 hashes into a SHA512' {
            # 64 + 64 = 128. Joining whitespace blindly would mint a comparator
            # out of two unrelated digests and compare a file against it.
            Mock -ModuleName VeriHash.Core Get-Clipboard { @(('a' * 64), ('b' * 64)) }
            Read-ClipboardHash | Should -BeNullOrEmpty
        }

        It 'Refuses to concatenate two separate MD5 hashes into a SHA256' {
            Mock -ModuleName VeriHash.Core Get-Clipboard { ('c' * 32) + ' ' + ('d' * 32) }
            Read-ClipboardHash | Should -BeNullOrEmpty
        }

        It 'Refuses ragged groups that are not a uniform split of one digest' {
            Mock -ModuleName VeriHash.Core Get-Clipboard { 'deadbeef cafe0 12345678 9abcdef0' }
            Read-ClipboardHash | Should -BeNullOrEmpty
        }

        It 'Still rejects prose that happens to contain no hex' {
            Mock -ModuleName VeriHash.Core Get-Clipboard { 'copy the vendor hash and re-run' }
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

        It 'Distinguishes grouped hex from plain hex on the checklist row' {
            $grouped = '5417cedc 1aeb16b4 88b80840 25246b64 a5e9da4d 71388f32 4b107140 dfe00699'
            Mock -ModuleName VeriHash.Core Get-Clipboard { $grouped }
            Mock -ModuleName VeriHash.Core Get-VeriHashPlatform { 'Windows' }
            (Read-ClipboardHash).Format | Should -BeExactly 'grouped hex, SHA256'
        }

        It 'Normalises an uppercase prefix to lowercase for display' {
            $hex = 'a' * 128
            Mock -ModuleName VeriHash.Core Get-Clipboard { "SHA512:$hex" }
            Mock -ModuleName VeriHash.Core Get-VeriHashPlatform { 'Windows' }
            (Read-ClipboardHash).Format | Should -BeExactly 'prefixed, sha512:'
        }
    }
}
