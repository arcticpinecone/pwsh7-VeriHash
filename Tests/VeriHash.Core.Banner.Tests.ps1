BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    . "$PSScriptRoot/TestHelpers.ps1"
    $script:SavedColorEnv = Save-VeriHashColorEnv
    Set-VeriHashColorEnv -Mode Truecolor
    # Banner text asserts on Unicode glyphs, which need a UTF-8 code page.
    $script:PrevEncoding = [Console]::OutputEncoding
    try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch { }
}
AfterAll {
    try { [Console]::OutputEncoding = $script:PrevEncoding } catch { }
    Restore-VeriHashColorEnv -Saved $script:SavedColorEnv
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
}

Describe 'Format-VeriHashBanner (FMT)' {
    It 'Renders the clipboard MATCH text verbatim' {
        $b = InModuleScope VeriHash.Core {
            Format-VeriHashBanner -State Match -Algorithm SHA256 -Source clipboard -Palette (Get-VeriHashPalette)
        }
        (Remove-Ansi $b).TrimEnd() | Should -BeExactly '  ✓  MATCH — SHA256 matches hash on clipboard'
    }

    It 'Renders the clipboard MISMATCH text verbatim' {
        $b = InModuleScope VeriHash.Core {
            Format-VeriHashBanner -State Mismatch -Algorithm SHA256 -Source clipboard -Palette (Get-VeriHashPalette)
        }
        (Remove-Ansi $b).TrimEnd() | Should -BeExactly '  ✗  MISMATCH — file does NOT match clipboard hash'
    }

    It 'Renders the no-comparator HASHED text verbatim' {
        $b = InModuleScope VeriHash.Core {
            Format-VeriHashBanner -State Hashed -Algorithm SHA256 -Source none -Palette (Get-VeriHashPalette)
        }
        (Remove-Ansi $b).TrimEnd() | Should -BeExactly '  ●  HASHED — no hash on clipboard to compare against'
    }

    It 'Swaps to sidecar wording when the sidecar is the comparator' {
        $m = InModuleScope VeriHash.Core {
            Format-VeriHashBanner -State Match -Algorithm SHA512 -Source sidecar -Palette (Get-VeriHashPalette)
        }
        (Remove-Ansi $m).TrimEnd() | Should -BeExactly '  ✓  MATCH — SHA512 matches sidecar file'

        $x = InModuleScope VeriHash.Core {
            Format-VeriHashBanner -State Mismatch -Algorithm SHA512 -Source sidecar -Palette (Get-VeriHashPalette)
        }
        (Remove-Ansi $x).TrimEnd() | Should -BeExactly '  ✗  MISMATCH — file does NOT match sidecar file'
    }

    It 'Pads the bar to the palette width so it reads as a filled bar' {
        $p = InModuleScope VeriHash.Core { Get-VeriHashPalette }
        $b = InModuleScope VeriHash.Core -Parameters @{ pal = $p } {
            param($pal) Format-VeriHashBanner -State Match -Algorithm SHA256 -Source clipboard -Palette $pal
        }
        (Remove-Ansi $b).Length | Should -Be $p.Width
    }

    It 'Uses a reversed-video background, not coloured text' {
        $b = InModuleScope VeriHash.Core {
            Format-VeriHashBanner -State Match -Algorithm SHA256 -Source clipboard -Palette (Get-VeriHashPalette)
        }
        $b | Should -Match ([regex]::Escape("$([char]27)[48;2;38;200;134m"))
    }
}
