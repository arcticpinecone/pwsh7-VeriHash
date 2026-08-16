BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force
    $env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')

    $script:PerfFixture = Join-Path $TestDrive 'perf-fixture.bin'
    $bytes = [byte[]]::new(150 * 1MB)
    (New-Object System.Random 42).NextBytes($bytes)
    # Force PE detection so sig job actually runs (Plan 02-02 PERF-03: needs both jobs doing work).
    $bytes[0] = 0x4D  # 'M'
    $bytes[1] = 0x5A  # 'Z'
    [System.IO.File]::WriteAllBytes($script:PerfFixture, $bytes)
}
AfterAll {
    Remove-Module VeriHash.HotPath -ErrorAction SilentlyContinue
    Remove-Item Env:VERIHASH_LOG_PATH -ErrorAction SilentlyContinue
}

Describe 'Invoke-VeriHashHotPath parallelism (PERF-03)' -Tag 'Performance' {
    It 'WallClockMs < 0.85 * (HashElapsedMs + SigElapsedMs) on 150MB fixture' -Skip:(-not $IsWindows) {
        $r = Invoke-VeriHashHotPath -Path $script:PerfFixture -Algorithm SHA256 6>$null
        $sumMs = $r.HashElapsedMs + $r.SigElapsedMs
        $bound = [int](0.85 * $sumMs)
        $r.WallClockMs | Should -BeLessThan $bound -Because "wallClock=$($r.WallClockMs) hashMs=$($r.HashElapsedMs) sigMs=$($r.SigElapsedMs)"
    }
}

Describe 'Invoke-VeriHashHotPath single-pass hashing (PERF)' -Tag 'Performance' {
    It 'Does not pay a second full hash when a same-algorithm sidecar already exists' -Skip:(-not $IsWindows) {
        # Test-VeriHashSidecar runs BEFORE the sidecar is written, so a first run over a
        # bare file never reaches the re-hash branch -- only a run that FINDS a sidecar
        # does. Comparing the two runs cancels the fixed ThreadJob/import overhead, so
        # what is left is the cost of the sidecar check itself.
        $bare     = Invoke-VeriHashHotPath -Path $script:PerfFixture -Algorithm SHA256 6>$null
        $withSide = Invoke-VeriHashHotPath -Path $script:PerfFixture -Algorithm SHA256 6>$null

        $budget = [int]($bare.WallClockMs + (0.5 * $withSide.HashElapsedMs))
        $withSide.WallClockMs | Should -BeLessThan $budget -Because (
            "finding a sidecar must not cost another pass over the file: " +
            "bare=$($bare.WallClockMs)ms withSidecar=$($withSide.WallClockMs)ms hash=$($withSide.HashElapsedMs)ms")
    }
}
