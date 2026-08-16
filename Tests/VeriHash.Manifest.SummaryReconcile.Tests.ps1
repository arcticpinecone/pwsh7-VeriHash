BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    Import-Module "$PSScriptRoot/../VeriHash.Manifest/VeriHash.Manifest.psd1" -Force
    $env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')
}
AfterAll {
    Remove-Module VeriHash.Manifest -ErrorAction SilentlyContinue
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
    Remove-Item Env:VERIHASH_LOG_PATH -ErrorAction SilentlyContinue
}

Describe 'Test-VeriHashManifest summary reconciles with entry count' {

    BeforeEach {
        # A manifest exercising every status the verifier can produce:
        # pass, mismatch, missing, parse-error, traversal-rejected.
        $script:testDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -Path $script:testDir -ItemType Directory -Force | Out-Null
        $utf8 = [System.Text.UTF8Encoding]::new($false)

        $good = Join-Path $script:testDir 'good.txt'
        $bad  = Join-Path $script:testDir 'bad.txt'
        [System.IO.File]::WriteAllText($good, "good content`n", $utf8)
        [System.IO.File]::WriteAllText($bad, "bad content`n", $utf8)

        $goodHash = (Get-VeriHashResult -Path $good -Algorithm SHA256).Hash
        $wrongHash = '0' * 64

        $lines = @(
            "$goodHash *good.txt"          # pass
            "$wrongHash *bad.txt"          # mismatch
            "$wrongHash *nowhere.txt"      # missing
            'not a manifest line at all'   # parse-error
            "$wrongHash *../escape.txt"    # traversal-rejected
        )

        $script:manifestPath = Join-Path $script:testDir 'all_statuses.sha256'
        [System.IO.File]::WriteAllText($script:manifestPath, (($lines -join "`n") + "`n"), $utf8)
        $script:result = Test-VeriHashManifest -Path $script:manifestPath
    }

    It 'produces all five entry statuses' {
        $statuses = $script:result.Entries | ForEach-Object { $_.Status } | Sort-Object -Unique
        $statuses | Should -Be @('mismatch', 'missing', 'parse-error', 'pass', 'traversal-rejected')
    }

    It 'counts rejected entries in a Rejected bucket' {
        # parse-error and traversal-rejected are both rejections, and both are
        # security-relevant: a traversal entry is an attempt to escape the
        # manifest directory, not a hash disagreement.
        $script:result.Summary.Rejected | Should -Be 2
    }

    It 'reconciles every bucket against Total' {
        # The original defect: Total was $entries.Count while the buckets named
        # three of five statuses, so two entries vanished from the accounting
        # and the rendered line did not add up.
        $s = $script:result.Summary
        ($s.Passed + $s.Failed + $s.Missing + $s.Rejected) | Should -Be $s.Total
    }

    It 'still exits 3 when an entry is rejected' {
        # Rejections outrank mismatch and missing; adding a bucket must not
        # disturb the exit-code precedence.
        $script:result.ExitCode | Should -Be 3
    }
}

Describe 'Manifest verify tally line accounts for every entry (CLI)' {

    BeforeAll {
        $script:cliScript = "$PSScriptRoot/../VeriHash.ps1"
        $script:cliDir = Join-Path $TestDrive 'tally-render'
        New-Item -Path $script:cliDir -ItemType Directory -Force | Out-Null
        $utf8 = [System.Text.UTF8Encoding]::new($false)

        $good = Join-Path $script:cliDir 'good.txt'
        [System.IO.File]::WriteAllText($good, "good content`n", $utf8)
        $goodHash = (Get-VeriHashResult -Path $good -Algorithm SHA256).Hash
        $wrongHash = '0' * 64

        # 4 entries: 1 pass, 1 missing, 2 rejected. The rendered line must
        # account for all four, not silently report on two of them.
        $lines = @(
            "$goodHash *good.txt"
            "$wrongHash *nowhere.txt"
            'not a manifest line at all'
            "$wrongHash *../escape.txt"
        )
        $script:cliManifest = Join-Path $script:cliDir 'render.sha256'
        [System.IO.File]::WriteAllText($script:cliManifest, (($lines -join "`n") + "`n"), $utf8)

        $script:output = & pwsh -NoProfile -NonInteractive -File $script:cliScript `
            -FilePath $script:cliManifest -Manifest -NoPause *>&1 | Out-String
    }

    It 'names the rejected entries in the tally line' {
        $script:output | Should -Match '2 rejected'
    }

    It 'reports a total that matches the number of entries' {
        # The defect this guards: the line read "1/4 passed, 0 mismatch,
        # 1 missing" -- two entries a security guard rejected simply vanished.
        $script:output | Should -Match '1/4 passed'
    }
}
