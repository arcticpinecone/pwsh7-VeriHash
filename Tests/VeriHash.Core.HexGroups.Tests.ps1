BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    . "$PSScriptRoot/TestHelpers.ps1"
    # Colour assertions below require truecolor; do not inherit the developer's
    # NO_COLOR preference or leakage from an earlier test file.
    $script:SavedColorEnv = Save-VeriHashColorEnv
    Set-VeriHashColorEnv -Mode Truecolor
    $script:Sha256 = '71792c028e07b0fdd30f4e2a9c1b3d5e8a46f1c29d073bb5e6c48d90a2f1e3b7'
}
AfterAll {
    Restore-VeriHashColorEnv -Saved $script:SavedColorEnv
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
}

Describe 'Get-VeriHashDiffIndex (FMT)' {
    It 'Returns -1 for identical strings' {
        InModuleScope VeriHash.Core -Parameters @{ h = $script:Sha256 } {
            param($h) Get-VeriHashDiffIndex -Expected $h -Actual $h
        } | Should -Be -1
    }

    It 'Returns 0 when the very first character differs' {
        InModuleScope VeriHash.Core {
            Get-VeriHashDiffIndex -Expected 'abcd' -Actual 'zbcd'
        } | Should -Be 0
    }

    It 'Returns the index of the first differing character' {
        InModuleScope VeriHash.Core {
            Get-VeriHashDiffIndex -Expected 'abcdef' -Actual 'abcXef'
        } | Should -Be 3
    }

    It 'Returns min length when one string is a prefix of the other' {
        InModuleScope VeriHash.Core {
            Get-VeriHashDiffIndex -Expected 'abcd' -Actual 'abcdef'
        } | Should -Be 4
    }
}

Describe 'Format-VeriHashHexGroups (FMT)' {
    BeforeAll {
        # SGR sequences contain [ and ; which -BeLike would read as a wildcard
        # character class, so colour assertions go through escaped regex.
        $script:BlueSgr = [regex]::Escape("$([char]27)[38;2;121;184;255m")
        $script:DiffSgr = [regex]::Escape("$([char]27)[48;2;92;30;25m")
    }

    It 'Chunks SHA256 into eight space-separated 8-char groups on one line' {
        # @() is required: PowerShell unrolls a single-element array through the
        # pipeline, which would make $lines[0] the first CHARACTER.
        $lines = @(InModuleScope VeriHash.Core -Parameters @{ h = $script:Sha256 } {
            param($h) Format-VeriHashHexGroups -Hash $h -Palette (Get-VeriHashPalette)
        })
        $lines | Should -HaveCount 1
        (Remove-Ansi $lines[0]) | Should -BeExactly '71792c02 8e07b0fd d30f4e2a 9c1b3d5e 8a46f1c2 9d073bb5 e6c48d90 a2f1e3b7'
    }

    It 'Chunks MD5 into four groups' {
        $lines = @(InModuleScope VeriHash.Core {
            Format-VeriHashHexGroups -Hash '441b45a2052b1f74aa946ba587a8f4f7' -Palette (Get-VeriHashPalette)
        })
        $lines | Should -HaveCount 1
        (Remove-Ansi $lines[0]) | Should -BeExactly '441b45a2 052b1f74 aa946ba5 87a8f4f7'
    }

    It 'Wraps SHA512 into two lines of eight groups, preserving group boundaries' {
        $sha512 = '0' * 128
        $lines = @(InModuleScope VeriHash.Core -Parameters @{ h = $sha512 } {
            param($h) Format-VeriHashHexGroups -Hash $h -Palette (Get-VeriHashPalette)
        })
        $lines | Should -HaveCount 2
        foreach ($l in $lines) {
            (Remove-Ansi $l).Length | Should -Be 71   # 8 groups * 8 chars + 7 spaces
        }
    }

    It 'Colours every group blue when no diff is requested' {
        $lines = @(InModuleScope VeriHash.Core -Parameters @{ h = $script:Sha256 } {
            param($h) Format-VeriHashHexGroups -Hash $h -Palette (Get-VeriHashPalette)
        })
        $lines[0] | Should -Match $script:BlueSgr
        $lines[0] | Should -Not -Match $script:DiffSgr
    }

    It 'Applies diff colours from the requested group onward, leaving the prefix blue' {
        $lines = @(InModuleScope VeriHash.Core -Parameters @{ h = $script:Sha256 } {
            param($h) Format-VeriHashHexGroups -Hash $h -Palette (Get-VeriHashPalette) -DiffFromGroup 2
        })
        $lines[0] | Should -Match $script:DiffSgr
        $lines[0] | Should -Match $script:BlueSgr
        # Plain text is unchanged by highlighting.
        (Remove-Ansi $lines[0]) | Should -BeExactly '71792c02 8e07b0fd d30f4e2a 9c1b3d5e 8a46f1c2 9d073bb5 e6c48d90 a2f1e3b7'
    }
}
