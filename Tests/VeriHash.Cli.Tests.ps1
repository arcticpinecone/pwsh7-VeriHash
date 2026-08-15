BeforeAll {
    # Pre-load modules for in-process use (e.g. Get-VeriHashResult in test setup)
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force
    Import-Module "$PSScriptRoot/../VeriHash.Manifest/VeriHash.Manifest.psd1" -Force
    $env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')

    $script:cliScript = "$PSScriptRoot/../VeriHash.ps1"

    # The report is rendered with ANSI SGR colour, so end-to-end assertions run
    # against Remove-Ansi'd text. Stripping is idempotent, which matters here:
    # the child pwsh may already have emitted plain text under NO_COLOR.
    . "$PSScriptRoot/TestHelpers.ps1"

    # Glyphs degrade to ASCII when the console code page is not UTF-8
    # (Get-VeriHashPalette). A child process's OutputEncoding is not something
    # these tests can pin, so every glyph assertion must accept both tables:
    # Unicode em-dash/check/cross, or ASCII '--'/'+'/'x'.
    $script:Dash = '(?:--|—)'
}

AfterAll {
    Remove-Module VeriHash.Manifest -ErrorAction SilentlyContinue
    Remove-Module VeriHash.HotPath -ErrorAction SilentlyContinue
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
    Remove-Item Env:VERIHASH_LOG_PATH -ErrorAction SilentlyContinue
}

Describe 'CLI param surface (CLI-01)' {
    BeforeAll {
        $script:cliContent = Get-Content $script:cliScript -Raw
    }

    It 'Has [string[]]$FilePath parameter' {
        $script:cliContent | Should -Match '\[string\[\]\]\$FilePath'
    }

    It 'Has -Manifest switch' {
        $script:cliContent | Should -Match '\[switch\]\$Manifest'
    }

    It 'Has -InstallSendTo switch (not -SendTo)' {
        $script:cliContent | Should -Match '\[switch\]\$InstallSendTo'
        $script:cliContent | Should -Not -Match '\[switch\]\$SendTo[^T]'
    }

    It 'Has -InstallKDE switch' {
        $script:cliContent | Should -Match '\[switch\]\$InstallKDE'
    }

    It 'Has -NoPause switch' {
        $script:cliContent | Should -Match '\[switch\]\$NoPause'
    }

    It 'Has -Log switch' {
        $script:cliContent | Should -Match '\[switch\]\$Log'
    }

    It 'Has -Help switch with aliases h and ?' {
        $script:cliContent | Should -Match "Alias\('h',\s*'\?'\)"
    }

    It 'Does NOT have dropped v1 params: -Hash, -Algorithm, -OnlyVerify, -SkipSignatureCheck, -LogLevel, -Force' {
        $script:cliContent | Should -Not -Match '\[switch\]\$OnlyVerify'
        $script:cliContent | Should -Not -Match '\[switch\]\$SkipSignatureCheck'
        $script:cliContent | Should -Not -Match '\[switch\]\$Force'
        $script:cliContent | Should -Not -Match '\$LogLevel'
        $script:cliContent | Should -Not -Match '\[string\]\$Hash'
        $script:cliContent | Should -Not -Match '\[string\[\]\]\$Algorithm'
    }
}

Describe 'CLI dispatch routing (CLI-01)' {
    BeforeAll {
        $script:cliContent = Get-Content $script:cliScript -Raw
    }

    It 'Routes single file to Invoke-VeriHashHotPath' {
        $script:cliContent | Should -Match 'Invoke-VeriHashHotPath\s+-Path'
    }

    It 'Routes multi-file to Invoke-VeriHashBatch' {
        $script:cliContent | Should -Match 'Invoke-VeriHashBatch\s+-FilePath'
    }

    It 'Routes sidecar candidates to Invoke-VeriHashSidecarDetect' {
        $script:cliContent | Should -Match 'Invoke-VeriHashSidecarDetect\s+-Path'
    }

    It 'Routes -Manifest create to New-VeriHashManifest' {
        $script:cliContent | Should -Match 'New-VeriHashManifest\s+-Path'
    }

    It 'Lazy-loads VeriHash.Integrations.ps1 only for InstallSendTo/InstallKDE' {
        $script:cliContent | Should -Match 'if \(\$InstallSendTo -or \$InstallKDE\)[\s\S]*?VeriHash\.Integrations\.ps1'
    }

    It 'Does NOT define any v1 monolith functions' {
        $script:cliContent | Should -Not -Match 'function Select-File'
        $script:cliContent | Should -Not -Match 'function Invoke-HashFile'
        $script:cliContent | Should -Not -Match 'function Get-And-SaveHash'
        $script:cliContent | Should -Not -Match 'function Test-InputHash'
        $script:cliContent | Should -Not -Match 'function Get-ClipboardHash'
    }
}

Describe 'Centralized pause (CLI-02)' {
    BeforeAll {
        $script:cliContent = Get-Content $script:cliScript -Raw
    }

    It 'Defines Test-VeriHashInteractive function' {
        $script:cliContent | Should -Match 'function Test-VeriHashInteractive'
    }

    It 'No module file references -NoPause' {
        $moduleFiles = Get-ChildItem "$PSScriptRoot/../VeriHash.Core", "$PSScriptRoot/../VeriHash.HotPath", "$PSScriptRoot/../VeriHash.Manifest" -Recurse -Filter '*.ps1' -File
        $hits = $moduleFiles | Select-String -Pattern '-NoPause|NoPause' -ErrorAction SilentlyContinue
        $hits | Should -BeNullOrEmpty
    }
}

Describe 'Help banner (D-03)' {
    It 'Shows help banner with -Help' {
        $output = & pwsh -NoProfile -NonInteractive -File $script:cliScript -Help *>&1 | Out-String
        $output | Should -Match 'VeriHash v2\.0'
        $output | Should -Match '-Manifest'
        $output | Should -Match '-InstallSendTo'
    }

    It 'Shows help for --help passed as FilePath' {
        $output = & pwsh -NoProfile -NonInteractive -File $script:cliScript '--help' -NoPause *>&1 | Out-String
        $output | Should -Match 'VeriHash v2\.0'
    }

    It 'Shows short banner when invoked with no args' {
        $output = & pwsh -NoProfile -NonInteractive -File $script:cliScript -NoPause *>&1 | Out-String
        $output | Should -Match 'VeriHash v2\.0'
        $output | Should -Match '-Help'
    }
}

Describe 'End-to-end: single-file hash (CLI-03)' {
    It 'Computes SHA256 hash for a single file' {
        $testFile = Join-Path $TestDrive 'hashme.txt'
        Set-Content $testFile 'single file hash test'
        $expected = (Get-VeriHashResult -Path $testFile -Algorithm SHA256).Hash
        $output = & pwsh -NoProfile -NonInteractive -File $script:cliScript -FilePath $testFile -NoPause *>&1 | Out-String
        $plain = $output | Remove-Ansi
        $plain | Should -Match 'SHA256'
        # The digest renders in 8-character groups, so no 64-run exists in the
        # raw text. Collapsing whitespace asserts the WHOLE digest reached the
        # user -- and pins the actual value, which '[0-9a-f]{64}' never did.
        ($plain -replace '\s', '') | Should -BeLike "*$expected*"
    }
}

Describe 'End-to-end: clipboard match (CLI-03)' -Skip:(-not $IsWindows) {
    AfterAll {
        Set-Clipboard -Value '' -ErrorAction SilentlyContinue
    }

    It 'Matches clipboard hash in plain hex form' {
        $testFile = Join-Path $TestDrive 'cliptest.txt'
        Set-Content $testFile 'clipboard plain hex test'
        $hash = (Get-VeriHashResult -Path $testFile -Algorithm SHA256).Hash
        Set-Clipboard -Value $hash
        $output = & pwsh -NoProfile -NonInteractive -File $script:cliScript -FilePath $testFile -NoPause *>&1 | Out-String
        $plain = $output | Remove-Ansi
        $plain | Should -Match "MATCH\s+$script:Dash\s+SHA256 matches hash on clipboard"
        # The detected clipboard FORMAT is the only thing separating this test
        # from the algo:hex one below; assert it or the two are duplicates.
        $plain | Should -Match 'clipboard[^\r\n]*match \(plain hex, SHA256\)'
    }

    It 'Matches clipboard hash in algo:hex prefix form' {
        $testFile = Join-Path $TestDrive 'clipprefix.txt'
        Set-Content $testFile 'clipboard prefix test'
        $hash = (Get-VeriHashResult -Path $testFile -Algorithm SHA256).Hash
        Set-Clipboard -Value "sha256:$hash"
        $output = & pwsh -NoProfile -NonInteractive -File $script:cliScript -FilePath $testFile -NoPause *>&1 | Out-String
        $plain = $output | Remove-Ansi
        $plain | Should -Match "MATCH\s+$script:Dash\s+SHA256 matches hash on clipboard"
        $plain | Should -Match 'clipboard[^\r\n]*match \(prefixed, sha256:\)'
    }
}

Describe 'End-to-end: sidecar match and mismatch (CLI-03)' {
    It 'Detects sidecar match' {
        $testFile = Join-Path $TestDrive 'sidecar-ok.txt'
        Set-Content $testFile 'sidecar match test'
        $hash = (Get-VeriHashResult -Path $testFile -Algorithm SHA256).Hash
        $sidecarPath = "$testFile.sha256"
        Set-Content $sidecarPath "$hash *sidecar-ok.txt"
        $output = & pwsh -NoProfile -NonInteractive -File $script:cliScript -FilePath $testFile -NoPause *>&1 | Out-String
        $plain = $output | Remove-Ansi
        $plain | Should -Match "MATCH\s+$script:Dash\s+SHA256 matches sidecar file"
        $plain | Should -Match "sidecar[^\r\n]*match\s+$script:Dash\s+sidecar-ok\.txt\.sha256"
    }

    It 'Detects sidecar mismatch' {
        $testFile = Join-Path $TestDrive 'sidecar-bad.txt'
        Set-Content $testFile 'sidecar mismatch test'
        $sidecarPath = "$testFile.sha256"
        Set-Content $sidecarPath "0000000000000000000000000000000000000000000000000000000000000000 *sidecar-bad.txt"
        $output = & pwsh -NoProfile -NonInteractive -File $script:cliScript -FilePath $testFile -NoPause *>&1 | Out-String
        $plain = $output | Remove-Ansi
        $plain | Should -Match "MISMATCH\s+$script:Dash\s+file does NOT match sidecar file"
        $plain | Should -Match "sidecar[^\r\n]*sidecar mismatch\s+$script:Dash\s+sidecar-bad\.txt\.sha256"
        # The actionable instruction is the whole point of a mismatch render.
        $plain | Should -Match 'Do not run this file'
    }
}

Describe 'End-to-end: multi-file loop (CLI-03)' {
    It 'Processes multiple files with tally' {
        $f1 = Join-Path $TestDrive 'multi1.txt'
        $f2 = Join-Path $TestDrive 'multi2.txt'
        Set-Content $f1 'file one'
        Set-Content $f2 'file two'
        # Files are passed positionally, exactly as SendTo/drag-drop invokes the
        # CLI. Naming -FilePath explicitly stops ValueFromRemainingArguments from
        # collecting $f2, which is a binding error rather than a product bug.
        $output = & pwsh -NoProfile -NonInteractive -File $script:cliScript $f1 $f2 -NoPause *>&1 | Out-String
        $output | Should -Match '\d+/2 matched, \d+ mismatch, \d+ missing'
    }
}

Describe 'End-to-end: manifest create (CLI-03)' {
    It 'Creates manifest for files with -Manifest flag' {
        $dir = Join-Path $TestDrive 'manifest-create'
        New-Item $dir -ItemType Directory -Force | Out-Null
        $f1 = Join-Path $dir 'a.txt'
        $f2 = Join-Path $dir 'b.txt'
        Set-Content $f1 'alpha'
        Set-Content $f2 'bravo'
        $output = & pwsh -NoProfile -NonInteractive -File $script:cliScript $f1 $f2 -Manifest -NoPause *>&1 | Out-String
        $output | Should -Match 'Manifest created:'
        $output | Should -Match '2 files'
        (Get-ChildItem $dir -Filter '*.sha256').Count | Should -BeGreaterOrEqual 1
    }
}

Describe 'End-to-end: manifest verify (CLI-03)' {
    BeforeAll {
        $script:mDir = Join-Path $TestDrive 'manifest-verify'
        New-Item $script:mDir -ItemType Directory -Force | Out-Null

        $script:goodFile = Join-Path $script:mDir 'good.txt'
        Set-Content $script:goodFile 'good content'
    }

    It 'Sidecar verify pass — single-line match shows Sidecar verify' {
        $manifestPath = Join-Path $script:mDir 'pass.sha256'
        $hash = (Get-VeriHashResult -Path $script:goodFile -Algorithm SHA256).Hash
        Set-Content $manifestPath "$hash *good.txt"
        $output = & pwsh -NoProfile -NonInteractive -File $script:cliScript -FilePath $manifestPath -Manifest -NoPause *>&1 | Out-String
        $output | Should -Match 'Sidecar verify:'
        $output | Should -Match 'PASS'
    }

    It 'Manifest verify fail — hash mismatch detected' {
        $manifestPath = Join-Path $script:mDir 'fail.sha256'
        Set-Content $manifestPath "0000000000000000000000000000000000000000000000000000000000000000 *good.txt"
        $output = & pwsh -NoProfile -NonInteractive -File $script:cliScript -FilePath $manifestPath -Manifest -NoPause *>&1 | Out-String
        $LASTEXITCODE | Should -Be 1
        $output | Should -Match 'mismatch'
    }

    It 'Sidecar verify missing — companion file not found returns exit code 1' {
        $manifestPath = Join-Path $script:mDir 'missing.sha256'
        Set-Content $manifestPath "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa *nonexistent.txt"
        $output = & pwsh -NoProfile -NonInteractive -File $script:cliScript -FilePath $manifestPath -Manifest -NoPause *>&1 | Out-String
        $LASTEXITCODE | Should -Be 1
        $output | Should -Match 'Companion file not found'
    }
}

Describe 'Dead code removal (CLEAN-01, CLEAN-02)' {
    It 'QuickHash.ps1 is not tracked in git' {
        $tracked = git ls-files -- 'QuickHash.ps1' *>&1
        $tracked | Should -BeNullOrEmpty
    }

    It 'VeriHash.LogUtils.ps1 is not tracked in git' {
        $tracked = git ls-files -- 'VeriHash.LogUtils.ps1' *>&1
        $tracked | Should -BeNullOrEmpty
    }

    It 'VeriHash.Config.ps1 is not tracked in git' {
        $tracked = git ls-files -- 'VeriHash.Config.ps1' *>&1
        $tracked | Should -BeNullOrEmpty
    }

    It 'Tests for deleted files are not tracked' {
        $files = @('Tests/QuickHash.Tests.ps1', 'Tests/VeriHash.LogUtils.Tests.ps1', 'Tests/VeriHash.Config.Tests.ps1', 'Tests/VeriHash.Tests.ps1')
        foreach ($f in $files) {
            $tracked = git ls-files -- $f *>&1
            $tracked | Should -BeNullOrEmpty -Because "$f should be deleted"
        }
    }

    It 'No PSFramework references anywhere in source' {
        $hits = Select-String -Path "$PSScriptRoot/../*.ps1", "$PSScriptRoot/../VeriHash.Core/**/*.ps1", "$PSScriptRoot/../VeriHash.HotPath/**/*.ps1", "$PSScriptRoot/../VeriHash.Manifest/**/*.ps1" -Pattern 'PSFramework|Write-PSFMessage|PSFrameworkAvailable' -ErrorAction SilentlyContinue
        $hits | Should -BeNullOrEmpty
    }
}

