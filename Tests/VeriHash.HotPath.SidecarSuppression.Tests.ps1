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

Describe 'Sidecar-write suppression keys off ALL negative evidence (CMP-11)' {
    BeforeEach {
        Mock -ModuleName VeriHash.Core Get-VeriHashPlatform { 'Windows' }
        $script:WorkDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $script:WorkDir
        $script:Target = Join-Path $script:WorkDir 'suppress-target.bin'
        [System.IO.File]::WriteAllBytes($script:Target, [byte[]](1..64))
    }

    Context 'The comparator abstained but the sidecar knew (regression)' {
        It 'Does NOT overwrite a mismatching .sha256 when the clipboard holds an MD5' {
            # Before the comparator extraction, the false MISMATCH accidentally
            # suppressed this write. Removing the false MISMATCH without
            # replacing the suppression removes the accident and keeps nothing:
            # the vendor's good hash gets replaced by the corrupt file's digest
            # and the checklist reports it green.
            Mock -ModuleName VeriHash.Core Get-Clipboard { 'c' * 32 }
            $sidecarPath = "$($script:Target).sha256"
            $vendorLine  = ('0' * 64) + ' *suppress-target.bin'
            Set-Content -LiteralPath $sidecarPath -Value $vendorLine
            $before = [System.IO.File]::ReadAllBytes($sidecarPath)

            $null = Invoke-VeriHashHotPath -Path $script:Target -Algorithm SHA256 6>$null

            $after = [System.IO.File]::ReadAllBytes($sidecarPath)
            $after | Should -Be $before
        }

        It 'Does NOT create a .sha256 when a .sha512 sidecar proved the file bad' {
            # Live on main before this fix, with no clipboard involved at all.
            # The .sha512 outranks .sha256 in Get-PreferredSidecar, so
            # Test-VeriHashSidecar re-hashes with SHA512 and returns
            # SidecarStatus='mismatch' -- which nothing read.
            Mock -ModuleName VeriHash.Core Get-Clipboard { $null }
            Set-Content -LiteralPath "$($script:Target).sha512" -Value (('0' * 128) + ' *suppress-target.bin')

            $null = Invoke-VeriHashHotPath -Path $script:Target -Algorithm SHA256 6>$null

            Test-Path -LiteralPath "$($script:Target).sha256" | Should -BeFalse
        }

        It 'Renders the sidecar mismatch rather than a green write row' {
            Mock -ModuleName VeriHash.Core Get-Clipboard { $null }
            Set-Content -LiteralPath "$($script:Target).sha512" -Value (('0' * 128) + ' *suppress-target.bin')

            $out = (Invoke-VeriHashHotPath -Path $script:Target -Algorithm SHA256 6>&1 |
                Out-String | Remove-Ansi)

            $out | Should -Match 'sidecar mismatch'
            $out | Should -Not -Match 'created'
            $out | Should -Not -Match 'updated'
        }
    }

    Context 'Suppression does not fire on good files (regression for the original bug)' {
        It 'Writes the sidecar when the clipboard holds an MD5 and no sidecar exists' {
            # The reported field bug: an intact file had its sidecar write
            # suppressed because an unrelated MD5 was on the clipboard.
            Mock -ModuleName VeriHash.Core Get-Clipboard { 'c' * 32 }

            $null = Invoke-VeriHashHotPath -Path $script:Target -Algorithm SHA256 6>$null

            Test-Path -LiteralPath "$($script:Target).sha256" | Should -BeTrue
        }

        It 'Leaves a matching sidecar alone and reports it as matched' {
            Mock -ModuleName VeriHash.Core Get-Clipboard { 'c' * 32 }
            Set-Content -LiteralPath "$($script:Target).sha256" `
                        -Value ((script:TrueHash $script:Target) + ' *suppress-target.bin')

            $r = Invoke-VeriHashHotPath -Path $script:Target -Algorithm SHA256 6>$null

            $r.MatchResult | Should -Be 'unverified'
        }
    }

    Context 'VeriHash never writes to the path it was asked to verify (CMP-14)' {
        It 'Leaves the target byte-identical for every supported algorithm' -ForEach @(
            @{ Algo = 'MD5'; Ext = '.sha256' }
            @{ Algo = 'SHA1'; Ext = '.sha256' }
            @{ Algo = 'SHA256'; Ext = '.sha256' }
            @{ Algo = 'SHA512'; Ext = '.sha512' }
        ) {
            # The property that matters. A hashtable miss on the extension map
            # returns $null rather than throwing, which would make the sidecar
            # path equal the target and replace the file being verified with a
            # ~100-byte text file -- reported as a green '+ updated' row.
            #
            # The weak algorithms map to .sha256, not to .md5/.sha1 (CMP-16):
            # the sidecar records the digest worth keeping, and the companion
            # is what supplies it.
            Mock -ModuleName VeriHash.Core Get-Clipboard { $null }
            $before = [System.IO.File]::ReadAllBytes($script:Target)

            $null = Invoke-VeriHashHotPath -Path $script:Target -Algorithm $Algo 6>$null

            [System.IO.File]::ReadAllBytes($script:Target) | Should -Be $before
            (Get-ChildItem -LiteralPath $script:WorkDir -File).Name |
                Should -Contain "suppress-target.bin$Ext"
        }

        It 'Never writes a .md5 or .sha1 sidecar under any algorithm (CMP-16)' -ForEach @(
            @{ Algo = 'MD5' }, @{ Algo = 'SHA1' }, @{ Algo = 'SHA256' }, @{ Algo = 'SHA512' }
        ) {
            # Get-PreferredSidecar ranks .sha512 > .sha256 > .md5, so a .md5
            # written once becomes a weak file a LATER run could promote to the
            # trusted comparator. Never writing it closes that path.
            Mock -ModuleName VeriHash.Core Get-Clipboard { $null }

            $null = Invoke-VeriHashHotPath -Path $script:Target -Algorithm $Algo 6>$null

            $written = (Get-ChildItem -LiteralPath $script:WorkDir -File).Name
            $written | Should -Not -Contain 'suppress-target.bin.md5'
            $written | Should -Not -Contain 'suppress-target.bin.sha1'
        }

        It 'Guards the derivation site rather than relying on the ValidateSet alone' {
            # ValidateSet protects the parameter, not the logic that assumed
            # it. Step 2 makes $Algorithm come from clipboard-parsed text, and
            # this guard is what keeps the failure unreachable after that.
            $src = Get-Content "$PSScriptRoot/../VeriHash.HotPath/Public/Invoke-VeriHashHotPath.ps1" -Raw
            $src | Should -Match 'refusing to derive a sidecar path'
        }
    }
}

Describe 'MatchResult and the batch tally carry the unverified state (CMP-12)' {
    BeforeEach {
        Mock -ModuleName VeriHash.Core Get-VeriHashPlatform { 'Windows' }
        Mock -ModuleName VeriHash.Core Get-Clipboard { 'c' * 32 }
        $script:WorkDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $script:WorkDir
        $script:A = Join-Path $script:WorkDir 'a.bin'
        $script:B = Join-Path $script:WorkDir 'b.bin'
        [System.IO.File]::WriteAllBytes($script:A, [byte[]](1..64))
        [System.IO.File]::WriteAllBytes($script:B, [byte[]](65..128))
    }

    It 'Reports unverified, not matched, when the clipboard could not be used' {
        $r = Invoke-VeriHashHotPath -Path $script:A -Algorithm SHA256 6>$null
        $r.MatchResult | Should -Be 'unverified'
    }

    It 'Surfaces the count on Tally.Unverified' {
        $b = Invoke-VeriHashBatch -FilePath @($script:A, $script:B) -Algorithm SHA256 6>$null
        $b.Tally.Unverified | Should -Be 2
    }

    It 'Keeps TallyLine byte-identical to its Phase 7 format and numbers' {
        # The byte-lock protects the format string AND the arithmetic. Without
        # the explicit 'unverified' switch arm these files would fall to
        # default and tally as missing -- files that exist and hashed fine,
        # reported absent.
        $b = Invoke-VeriHashBatch -FilePath @($script:A, $script:B) -Algorithm SHA256 6>$null
        $b.TallyLine | Should -Be '2/2 matched, 0 mismatch, 0 missing'
    }

    It 'Renders unverified per-file lines, not missing' {
        $out = (Invoke-VeriHashBatch -FilePath @($script:A) -Algorithm SHA256 6>&1 |
            Out-String | Remove-Ansi)
        $out | Should -Match 'a\.bin\s+unverified'
        $out | Should -Not -Match 'a\.bin\s+missing'
    }

    It 'Shows the unverified count in the summary line only when non-zero' {
        $withYellow = (Invoke-VeriHashBatch -FilePath @($script:A) -Algorithm SHA256 6>&1 |
            Out-String | Remove-Ansi)
        $withYellow | Should -Match '1 unverified'

        Mock -ModuleName VeriHash.Core Get-Clipboard { $null }
        $noYellow = (Invoke-VeriHashBatch -FilePath @($script:B) -Algorithm SHA256 6>&1 |
            Out-String | Remove-Ansi)
        $noYellow | Should -Not -Match 'unverified'
    }
}
