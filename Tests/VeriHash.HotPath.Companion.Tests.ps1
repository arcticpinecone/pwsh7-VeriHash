BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force
    . "$PSScriptRoot/TestHelpers.ps1"

    # An oracle independent of the system under test cannot agree with it by
    # sharing a bug.
    function script:TrueHash {
        param([string]$Path, [string]$Algorithm = 'SHA256')
        return (Get-FileHash -LiteralPath $Path -Algorithm $Algorithm).Hash.ToLowerInvariant()
    }
}
AfterAll {
    Remove-Module VeriHash.HotPath -ErrorAction SilentlyContinue
}

Describe 'Weak primary gets a SHA256 companion (CMP-15, CMP-16)' {
    BeforeEach {
        Mock -ModuleName VeriHash.Core Get-VeriHashPlatform { 'Windows' }
        $script:WorkDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $script:WorkDir
        $script:Target = Join-Path $script:WorkDir 'companion-target.bin'
        [System.IO.File]::WriteAllBytes($script:Target, [byte[]](1..64))
    }

    Context 'A vendor MD5 on the clipboard' {
        It 'Answers the MD5 question with a green MATCH' {
            $md5 = TrueHash $script:Target 'MD5'
            Mock -ModuleName VeriHash.Core Get-Clipboard { $md5 }

            $out = (Invoke-VeriHashHotPath -Path $script:Target 6>&1 | Out-String | Remove-Ansi)

            $out | Should -Match 'MATCH'
            $out | Should -Not -Match 'UNVERIFIED'
            $out | Should -Not -Match 'MISMATCH'
        }

        It 'Computes SHA256 alongside it and reports both' {
            $md5 = TrueHash $script:Target 'MD5'
            Mock -ModuleName VeriHash.Core Get-Clipboard { $md5 }

            $r = Invoke-VeriHashHotPath -Path $script:Target 6>$null

            $r.HashAlgorithm      | Should -Be 'MD5'
            $r.Hash               | Should -BeExactly $md5
            $r.CompanionAlgorithm | Should -Be 'SHA256'
            $r.CompanionHash      | Should -BeExactly (TrueHash $script:Target 'SHA256')
        }

        It 'Writes a .sha256 sidecar and never a .md5' {
            $md5 = TrueHash $script:Target 'MD5'
            Mock -ModuleName VeriHash.Core Get-Clipboard { $md5 }

            $null = Invoke-VeriHashHotPath -Path $script:Target 6>$null

            Test-Path -LiteralPath "$($script:Target).sha256" | Should -BeTrue
            Test-Path -LiteralPath "$($script:Target).md5"    | Should -BeFalse
            # The sidecar must record the SHA256 digest, not the MD5 one.
            (Get-Content -LiteralPath "$($script:Target).sha256" -TotalCount 1) |
                Should -Match ([regex]::Escape((TrueHash $script:Target 'SHA256')))
        }

        It 'Puts the companion SHA256 digest on screen' {
            $md5 = TrueHash $script:Target 'MD5'
            Mock -ModuleName VeriHash.Core Get-Clipboard { $md5 }
            $sha = TrueHash $script:Target 'SHA256'
            $firstGroup = $sha.Substring(0, 8)

            $out = (Invoke-VeriHashHotPath -Path $script:Target 6>&1 | Out-String | Remove-Ansi)

            $out | Should -Match 'sha256'
            $out | Should -Match ([regex]::Escape($firstGroup))
        }

        It 'Names both algorithms in the header and attributes the primary (CMP-18)' {
            $md5 = TrueHash $script:Target 'MD5'
            Mock -ModuleName VeriHash.Core Get-Clipboard { $md5 }

            $out = (Invoke-VeriHashHotPath -Path $script:Target 6>&1 | Out-String | Remove-Ansi)

            $out | Should -Match ([regex]::Escape('MD5 (clipboard) + SHA256'))
        }

        It 'Labels the comparison weak on the clipboard row (CMP-07)' {
            $md5 = TrueHash $script:Target 'MD5'
            Mock -ModuleName VeriHash.Core Get-Clipboard { $md5 }

            $out = (Invoke-VeriHashHotPath -Path $script:Target 6>&1 | Out-String | Remove-Ansi)

            $out | Should -Match 'weak'
        }
    }

    Context 'A vendor SHA1 on the clipboard (CMP-17)' {
        It 'Answers the SHA1 question and still writes .sha256' {
            $sha1 = TrueHash $script:Target 'SHA1'
            Mock -ModuleName VeriHash.Core Get-Clipboard { $sha1 }

            $r = Invoke-VeriHashHotPath -Path $script:Target 6>$null

            $r.HashAlgorithm      | Should -Be 'SHA1'
            $r.MatchResult        | Should -Be 'matched'
            $r.CompanionAlgorithm | Should -Be 'SHA256'
            Test-Path -LiteralPath "$($script:Target).sha256" | Should -BeTrue
            Test-Path -LiteralPath "$($script:Target).sha1"   | Should -BeFalse
        }
    }

    Context 'A weak hash that does NOT match' {
        It 'Reports MISMATCH and writes no sidecar at all' {
            Mock -ModuleName VeriHash.Core Get-Clipboard { 'c' * 32 }

            $r = Invoke-VeriHashHotPath -Path $script:Target 6>$null

            $r.MatchResult | Should -Be 'mismatch'
            Test-Path -LiteralPath "$($script:Target).sha256" | Should -BeFalse
            Test-Path -LiteralPath "$($script:Target).md5"    | Should -BeFalse
        }
    }

    Context 'Strong primaries pay for no second pass' {
        It 'Runs no companion for a default SHA256 run' {
            Mock -ModuleName VeriHash.Core Get-Clipboard { $null }

            $r = Invoke-VeriHashHotPath -Path $script:Target 6>$null

            $r.HashAlgorithm      | Should -Be 'SHA256'
            $r.CompanionAlgorithm | Should -BeNullOrEmpty
        }

        It 'Runs no companion for an explicit SHA512 run and writes .sha512' {
            Mock -ModuleName VeriHash.Core Get-Clipboard { $null }

            $r = Invoke-VeriHashHotPath -Path $script:Target -Algorithm SHA512 6>$null

            $r.CompanionAlgorithm | Should -BeNullOrEmpty
            Test-Path -LiteralPath "$($script:Target).sha512" | Should -BeTrue
            Test-Path -LiteralPath "$($script:Target).sha256" | Should -BeFalse
        }
    }

    Context 'Algorithm precedence' {
        It 'Lets an explicit flag outrank the clipboard' {
            Mock -ModuleName VeriHash.Core Get-Clipboard { TrueHash $script:Target 'MD5' }

            $r = Invoke-VeriHashHotPath -Path $script:Target -Algorithm SHA512 6>$null

            $r.HashAlgorithm | Should -Be 'SHA512'
        }

        It 'Companions an explicit weak flag too' {
            # The user asked for MD5, not for the absence of SHA256.
            Mock -ModuleName VeriHash.Core Get-Clipboard { $null }

            $r = Invoke-VeriHashHotPath -Path $script:Target -Algorithm MD5 6>$null

            $r.HashAlgorithm      | Should -Be 'MD5'
            $r.CompanionAlgorithm | Should -Be 'SHA256'
            Test-Path -LiteralPath "$($script:Target).sha256" | Should -BeTrue
            Test-Path -LiteralPath "$($script:Target).md5"    | Should -BeFalse
        }

        It 'Ignores an unsupported clipboard paste and stays on SHA256' {
            Mock -ModuleName VeriHash.Core Get-Clipboard { 'not a hash at all' }

            $r = Invoke-VeriHashHotPath -Path $script:Target 6>$null

            $r.HashAlgorithm      | Should -Be 'SHA256'
            $r.CompanionAlgorithm | Should -BeNullOrEmpty
        }
    }

    Context 'Batch mode is never redirected by the clipboard' {
        It 'Hashes every file with the batch algorithm despite an MD5 paste' {
            Mock -ModuleName VeriHash.Core Get-Clipboard { 'c' * 32 }
            $second = Join-Path $script:WorkDir 'companion-second.bin'
            [System.IO.File]::WriteAllBytes($second, [byte[]](9..40))

            $b = Invoke-VeriHashBatch -FilePath @($script:Target, $second) 6>$null

            foreach ($r in $b.Results) { $r.HashAlgorithm | Should -Be 'SHA256' }
        }
    }
}
