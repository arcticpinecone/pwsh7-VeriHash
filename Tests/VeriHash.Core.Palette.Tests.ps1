BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    . "$PSScriptRoot/TestHelpers.ps1"
    # This file deliberately toggles colour env vars; save the developer's real
    # values up front and restore them once, so nothing leaks into later files.
    $script:SavedColorEnv = Save-VeriHashColorEnv
}
AfterAll {
    Restore-VeriHashColorEnv -Saved $script:SavedColorEnv
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
}

Describe 'Get-VeriHashPalette (FMT)' {
    BeforeEach {
        Set-VeriHashColorEnv -Mode Truecolor
    }

    It 'Returns SGR escape strings when colour is enabled' {
        $p = InModuleScope VeriHash.Core { Get-VeriHashPalette }
        $p.UseColor          | Should -BeTrue
        $p.Color.Reset       | Should -Be "$([char]27)[0m"
        $p.Color.Blue        | Should -Be "$([char]27)[38;2;121;184;255m"
        $p.Color.Dim         | Should -Be "$([char]27)[38;2;110;118;129m"
        $p.Color.Green       | Should -Be "$([char]27)[38;2;63;222;134m"
        $p.Color.Red         | Should -Be "$([char]27)[38;2;229;83;75m"
        $p.Color.Yellow      | Should -Be "$([char]27)[38;2;210;153;34m"
    }

    It 'Emits banner background codes matching the spec palette' {
        $p = InModuleScope VeriHash.Core { Get-VeriHashPalette }
        $p.Color.BannerMatch    | Should -Be "$([char]27)[48;2;38;200;134m$([char]27)[38;2;8;23;13m"
        $p.Color.BannerMismatch | Should -Be "$([char]27)[48;2;211;69;49m$([char]27)[38;2;255;255;255m"
        $p.Color.BannerHashed   | Should -Be "$([char]27)[48;2;48;54;61m"
        $p.Color.Diff           | Should -Be "$([char]27)[48;2;92;30;25m$([char]27)[38;2;255;160;150m"
    }

    It 'Blanks every colour when NO_COLOR is set' {
        Set-VeriHashColorEnv -Mode None
        $p = InModuleScope VeriHash.Core { Get-VeriHashPalette }
        $p.UseColor | Should -BeFalse
        foreach ($k in $p.Color.Keys) { $p.Color[$k] | Should -BeExactly '' }
    }

    It 'Falls back to 16-colour SGR when truecolor is unavailable' {
        Set-VeriHashColorEnv -Mode Sixteen
        $p = InModuleScope VeriHash.Core { Get-VeriHashPalette }
        $p.UseColor     | Should -BeTrue
        $p.UseTruecolor | Should -BeFalse
        # Still colour, but no 24-bit sequences anywhere.
        foreach ($k in $p.Color.Keys) { $p.Color[$k] | Should -Not -BeLike '*38;2;*' }
        $p.Color.Green       | Should -Be "$([char]27)[92m"
        $p.Color.BannerMatch | Should -Be "$([char]27)[42m$([char]27)[30m"
    }

    It 'Never throws and yields a sane width with no console attached' {
        # CI has no console; this must not throw and must not return 0.
        $p = InModuleScope VeriHash.Core { Get-VeriHashPalette }
        $p.Width | Should -BeGreaterOrEqual 40
        $p.Width | Should -BeLessOrEqual 76
    }

    It 'Supplies ASCII fallbacks for every Unicode glyph' {
        $p = InModuleScope VeriHash.Core { Get-VeriHashPalette }
        foreach ($k in @('Ok', 'Bad', 'Info', 'Warn', 'None', 'Sep', 'Dash', 'Rule')) {
            $p.Glyph[$k] | Should -Not -BeNullOrEmpty
        }
    }
}
