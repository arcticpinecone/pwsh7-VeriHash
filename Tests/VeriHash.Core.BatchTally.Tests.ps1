BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    . "$PSScriptRoot/TestHelpers.ps1"
    $script:SavedColorEnv = Save-VeriHashColorEnv
    Set-VeriHashColorEnv -Mode Truecolor
    $script:PrevEncoding = [Console]::OutputEncoding
    try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch { }

    $script:Results = @(
        [pscustomobject]@{ FilePath = '/d/setup-x64.exe';   MatchResult = 'matched';  Signature = 'valid'    }
        [pscustomobject]@{ FilePath = '/d/setup-arm64.exe'; MatchResult = 'matched';  Signature = 'valid'    }
        [pscustomobject]@{ FilePath = '/d/langpack.msi';    MatchResult = 'mismatch'; Signature = 'unsigned' }
    )

    function script:Tally {
        param([pscustomobject[]]$Results)
        ((Format-VeriHashBatchTally -Results $Results *>&1 | Out-String) -replace "`r`n", "`n") | Remove-Ansi
    }
}
AfterAll {
    try { [Console]::OutputEncoding = $script:PrevEncoding } catch { }
    Restore-VeriHashColorEnv -Saved $script:SavedColorEnv
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
}

Describe 'Format-VeriHashBatchTally (FMT-06)' {
    BeforeAll {
        $script:Out = script:Tally $script:Results
    }

    It 'Leads with the middot-separated count line' {
        $script:Out | Should -Match ([regex]::Escape('batch of 3 · 2 matched · 1 mismatch · 0 missing'))
    }

    It 'Lists each file with its glyph, name, and status' {
        $script:Out | Should -Match ([regex]::Escape(' ✓ setup-x64.exe      match · signed'))
        $script:Out | Should -Match ([regex]::Escape(' ✓ setup-arm64.exe    match · signed'))
        $script:Out | Should -Match ([regex]::Escape(' ✗ langpack.msi       mismatch'))
    }

    It 'Omits the signed suffix when the signature is not valid' {
        $out = script:Tally @(
            [pscustomobject]@{ FilePath = '/d/plain.zip'; MatchResult = 'matched'; Signature = 'skipped' }
        )
        # 'plain.zip' is 9 chars: 9 chars of padding to 18, plus the 1-space gutter.
        $out | Should -Match ([regex]::Escape(' ✓ plain.zip          match'))
        $out | Should -Not -Match ([regex]::Escape('match · signed'))
    }

    It 'Marks a missing file with the neutral glyph' {
        $out = script:Tally @(
            [pscustomobject]@{ FilePath = '/d/gone.bin'; MatchResult = 'missing'; Signature = 'error' }
        )
        $out | Should -Match ([regex]::Escape('batch of 1 · 0 matched · 0 mismatch · 1 missing'))
        $out | Should -Match ([regex]::Escape(' − gone.bin'))
        $out | Should -Match ([regex]::Escape('missing'))
    }

    It 'Widens the name column for names longer than the 18-char default' {
        $out = script:Tally @(
            [pscustomobject]@{ FilePath = '/d/a-very-long-installer-name.exe'; MatchResult = 'matched'; Signature = 'valid' }
        )
        $out | Should -Match ([regex]::Escape('a-very-long-installer-name.exe match · signed'))
    }
}
