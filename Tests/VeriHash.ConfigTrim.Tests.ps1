BeforeAll {
    # Static-analysis regression tests — no module import needed.
    # These guard against re-introduction of removed VirusTotal and PSFramework code.
    $script:ProjectRoot = (Resolve-Path "$PSScriptRoot/..").Path

    # Files that legitimately contain the search-pattern strings as negative assertions
    $script:ExcludedTestFiles = @(
        'VeriHash.ConfigTrim.Tests.ps1'      # this file (self-reference)
        'VeriHash.Integrations.Tests.ps1'     # lines 19-29: targeted negative-assertion checks
    )
}

Describe 'VirusTotal references removed from source files (CFG-01)' {
    It 'Zero virustotal or VERIHASH_VT_ matches in production source files' {
        $sourceFiles = Get-ChildItem -Path $script:ProjectRoot `
            -Include '*.ps1','*.psm1','*.psd1' -Recurse |
            Where-Object { $_.FullName -notmatch '[\\/]Tests[\\/]' }

        $sourceFiles.Count | Should -BeGreaterThan 0 `
            -Because 'sanity: production source files must exist'

        $hits = $sourceFiles |
            Select-String -Pattern 'virustotal|VERIHASH_VT_' -ErrorAction SilentlyContinue

        $hits | Should -BeNullOrEmpty `
            -Because 'all VirusTotal references must be removed from production source (CFG-01)'
    }
}

Describe 'VirusTotal references removed from test files (CFG-02)' {
    It 'Zero virustotal or VERIHASH_VT_ matches in test files' {
        $testFiles = Get-ChildItem -Path "$script:ProjectRoot\Tests" -Filter '*.ps1' |
            Where-Object { $_.Name -notin $script:ExcludedTestFiles }

        $testFiles.Count | Should -BeGreaterThan 0 `
            -Because 'sanity: scannable test files must exist'

        $hits = $testFiles |
            Select-String -Pattern 'virustotal|VERIHASH_VT_' -ErrorAction SilentlyContinue

        $hits | Should -BeNullOrEmpty `
            -Because 'all VirusTotal references must be removed from test files (CFG-02)'
    }
}

Describe 'PSFramework references removed from all files (CFG-03)' {
    It 'Zero PSFramework, Write-PSFMessage, or PSFrameworkAvailable matches across the project' {
        $allFiles = Get-ChildItem -Path $script:ProjectRoot `
            -Include '*.ps1','*.psm1','*.psd1' -Recurse |
            Where-Object { $_.Name -notin $script:ExcludedTestFiles }

        $allFiles.Count | Should -BeGreaterThan 0 `
            -Because 'sanity: project files must exist'

        $hits = $allFiles |
            Select-String -Pattern 'PSFramework|Write-PSFMessage|PSFrameworkAvailable' `
                -ErrorAction SilentlyContinue

        $hits | Should -BeNullOrEmpty `
            -Because 'all PSFramework references must be removed from all project files (CFG-03)'
    }
}
