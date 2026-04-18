BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force
    $env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')

    $script:PEFixture    = Join-Path $PSScriptRoot 'Fixtures/tiny-pe.bin'
    $script:NotPEFixture = Join-Path $PSScriptRoot 'Fixtures/tiny-not-pe.bin'
    $script:F1 = $script:PEFixture
    $script:F2 = $script:NotPEFixture
    $script:F3 = Join-Path $TestDrive 'extra.bin'
    [IO.File]::WriteAllBytes($script:F3, [byte[]](1..16))

    Remove-Item Env:VERIHASH_LOG -ErrorAction SilentlyContinue
}
AfterAll {
    Remove-Module VeriHash.HotPath -ErrorAction SilentlyContinue
    Remove-Item Env:VERIHASH_LOG_PATH -ErrorAction SilentlyContinue
}

Describe 'Invoke-VeriHashBatch surface (MULTI-01)' {
    It 'Module exports Invoke-VeriHashBatch' {
        (Get-Command -Module VeriHash.HotPath).Name | Should -Contain 'Invoke-VeriHashBatch'
    }

    It 'Accepts [string[]] $FilePath and returns Results.Count == input count' {
        $r = Invoke-VeriHashBatch -FilePath @($script:F1, $script:F2, $script:F3) -Algorithm SHA256
        $r.PSTypeNames | Should -Contain 'VeriHash.BatchResult'
        $r.Results.Count | Should -Be 3
    }

    It 'Single-file batch still emits a tally line (Open Question 5: always emit)' {
        $r = Invoke-VeriHashBatch -FilePath @($script:F1) -Algorithm SHA256
        $r.TallyLine | Should -Be '1/1 matched, 0 mismatch, 0 missing'
    }
}

Describe 'Invoke-VeriHashBatch tally byte-lock (MULTI-02)' {
    It 'TallyLine matches the locked regex shape' {
        $r = Invoke-VeriHashBatch -FilePath @($script:F1, $script:F2, $script:F3) -Algorithm SHA256
        $r.TallyLine | Should -Match '^\d+/\d+ matched, \d+ mismatch, \d+ missing$'
    }

    It 'TallyLine for {match, match, match} is exactly "3/3 matched, 0 mismatch, 0 missing"' {
        $r = Invoke-VeriHashBatch -FilePath @($script:F1, $script:F2, $script:F3) -Algorithm SHA256
        $r.TallyLine | Should -Be '3/3 matched, 0 mismatch, 0 missing'
        $r.Tally.Total    | Should -Be 3
        $r.Tally.Matched  | Should -Be 3
        $r.Tally.Mismatch | Should -Be 0
        $r.Tally.Missing  | Should -Be 0
    }

    It 'TallyLine for one mismatch is exactly "2/3 matched, 1 mismatch, 0 missing" (mocked Invoke-VeriHashHotPath)' {
        InModuleScope VeriHash.HotPath {
            $script:i = 0
            Mock Invoke-VeriHashHotPath {
                $script:i++
                $bucket = if ($script:i -eq 2) { 'mismatch' } else { 'matched' }
                [pscustomobject]@{
                    PSTypeName       = 'VeriHash.HotPathResult'
                    FilePath         = $Path
                    Hash             = 'deadbeef'
                    HashAlgorithm    = $Algorithm
                    HashElapsedMs    = 1
                    Signature        = 'unsigned'
                    SignatureReason  = 'not signed'
                    SigElapsedMs     = 1
                    WallClockMs      = 2
                    IsPE             = $false
                    MatchResult      = $bucket
                }
            }
            $r = Invoke-VeriHashBatch -FilePath @('a', 'b', 'c') -Algorithm SHA256
            $r.TallyLine | Should -Be '2/3 matched, 1 mismatch, 0 missing'
        }
    }

    It 'TallyLine for one missing (nonexistent path) is exactly "2/3 matched, 0 mismatch, 1 missing" -- continue-and-tally (D-A4-3)' {
        $missing = Join-Path $TestDrive 'definitely-does-not-exist.bin'
        $r = Invoke-VeriHashBatch -FilePath @($script:F1, $missing, $script:F2) -Algorithm SHA256
        $r.Results.Count | Should -Be 3
        $r.TallyLine | Should -Be '2/3 matched, 0 mismatch, 1 missing'
        $r.Tally.Missing | Should -Be 1
    }

    It 'Continue-and-tally: bad file FIRST does not abort batch (D-A4-3)' {
        $missing = Join-Path $TestDrive 'first-bad.bin'
        $r = Invoke-VeriHashBatch -FilePath @($missing, $script:F1, $script:F2) -Algorithm SHA256
        $r.Results.Count | Should -Be 3
        $r.Tally.Missing | Should -Be 1
        $r.Tally.Matched | Should -Be 2
    }
}

Describe 'Invoke-VeriHashBatch preserves single-file features (MULTI-03)' {
    It 'Per-file Results entry has IsPE, Signature enum, HashElapsedMs, SigElapsedMs (parallel sig ran per file)' {
        $r = Invoke-VeriHashBatch -FilePath @($script:F1) -Algorithm SHA256
        $r.Results[0].IsPE | Should -BeOfType ([bool])
        $r.Results[0].Signature | Should -BeIn @('valid', 'invalid', 'unsigned', 'skipped', 'error')
        $r.Results[0].HashElapsedMs | Should -BeGreaterOrEqual 0
        $r.Results[0].SigElapsedMs  | Should -BeGreaterOrEqual 0
        $r.Results[0].WallClockMs   | Should -BeGreaterOrEqual 0
    }
}

Describe 'Profile-VeriHashTiming.ps1 -Strict gate (D-A7-1)' {
    It 'Without -Strict: existing callers (Test-All.ps1 step 3/3) keep working' {
        $script = Join-Path $PSScriptRoot '..' 'Profile-VeriHashTiming.ps1'
        { & $script -FilePath $script:F1 -Algorithm SHA256 -Quiet } | Should -Not -Throw
    }

    It 'With -Strict: completes without throwing on a fast path (no false positives)' {
        $script = Join-Path $PSScriptRoot '..' 'Profile-VeriHashTiming.ps1'
        { & $script -FilePath $script:F1 -Algorithm SHA256 -Quiet -Strict } | Should -Not -Throw
    }

    It '-Strict parameter exists in the script' {
        $script = Join-Path $PSScriptRoot '..' 'Profile-VeriHashTiming.ps1'
        $cmd = Get-Command $script
        $cmd.Parameters.Keys | Should -Contain 'Strict'
    }
}
