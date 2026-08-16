BeforeAll {
    $script:harnessPath = "$PSScriptRoot/../Test-All.ps1"
    $script:harness = Get-Content $script:harnessPath -Raw
}

Describe 'Test-All.ps1 can actually observe a test failure' {

    # The defect this guards, found 2026-08-16: the harness built a
    # PesterConfiguration without Run.PassThru, so Invoke-Pester returned
    # nothing. $testResults was $null, $null.FailedCount was $null, and
    # `$null -gt 0` is $false -- so the harness took its success branch on every
    # run, printed "All  tests PASSED" (with the empty count showing as a double
    # space), and exited 0 with failing tests. The quality gate could not fail.

    It 'requests the result object from Invoke-Pester' {
        # Without this, Invoke-Pester -Configuration returns $null and every
        # downstream check silently compares against nothing.
        $script:harness | Should -Match 'PassThru\s*=\s*\$true'
    }

    It 'captures the result of Invoke-Pester rather than discarding it' {
        $script:harness | Should -Match '\$testResults\s*=\s*Invoke-Pester'
    }

    It 'guards against a null result before trusting the counts' {
        # PassThru alone is not enough: if Invoke-Pester throws or returns
        # nothing for any other reason, a null result must fail the run rather
        # than pass it. Reading a count off $null is what made this fail green.
        $script:harness | Should -Match '\$null\s+-eq\s+\$testResults'
    }

    It 'reports the failing count when tests fail' {
        $script:harness | Should -Match 'FailedCount\s+-gt\s+0'
    }
}
