BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force

    function New-Clip {
        param($Algorithm, $Hash, $Format = 'plain hex, TEST', $Detail = $null)
        [pscustomobject]@{ Algorithm = $Algorithm; Hash = $Hash; Format = $Format; Detail = $Detail }
    }
    function New-Side {
        param($Algorithm, $ExpectedHash, $Status = 'matched')
        [pscustomobject]@{
            SidecarStatus = $Status; SidecarName = 'f.sha256'
            Algorithm     = $Algorithm; ExpectedHash = $ExpectedHash
        }
    }
    $script:Sha256A = 'a' * 64
    $script:Sha256B = 'b' * 64
    $script:Md5A    = 'c' * 32
}
AfterAll {
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
}

Describe 'Resolve-VeriHashComparator (CMP-01, CMP-02, CMP-03)' {

    Context 'Source selection' {
        It 'Selects the clipboard when its algorithm matches the run' {
            $r = Resolve-VeriHashComparator -CompareTo (New-Clip 'SHA256' $script:Sha256A) -ComputedAlgorithm 'SHA256'
            $r.Source       | Should -Be 'clipboard'
            $r.ExpectedHash | Should -Be $script:Sha256A
            $r.Reason       | Should -BeNullOrEmpty
        }

        It 'Selects the sidecar when nothing is on the clipboard' {
            $r = Resolve-VeriHashComparator -SidecarInfo (New-Side 'SHA256' $script:Sha256A) -ComputedAlgorithm 'SHA256'
            $r.Source       | Should -Be 'sidecar'
            $r.ExpectedHash | Should -Be $script:Sha256A
        }

        It 'Returns none when there is nothing to compare against' {
            (Resolve-VeriHashComparator -ComputedAlgorithm 'SHA256').Source | Should -Be 'none'
        }

        It 'Prefers the clipboard over the sidecar when both are comparable' {
            $r = Resolve-VeriHashComparator -CompareTo (New-Clip 'SHA256' $script:Sha256A) `
                                            -SidecarInfo (New-Side 'SHA256' $script:Sha256B) `
                                            -ComputedAlgorithm 'SHA256'
            $r.Source       | Should -Be 'clipboard'
            $r.ExpectedHash | Should -Be $script:Sha256A
        }

        It 'Ignores a sidecar whose algorithm differs from the run' {
            $r = Resolve-VeriHashComparator -SidecarInfo (New-Side 'SHA512' ('d' * 128)) -ComputedAlgorithm 'SHA256'
            $r.Source | Should -Be 'none'
        }
    }

    Context 'unusable — the user asked and we cannot answer' {
        It 'Returns unusable for a clipboard MD5 during a SHA256 run (the field-report bug)' {
            $r = Resolve-VeriHashComparator -CompareTo (New-Clip 'MD5' $script:Md5A) -ComputedAlgorithm 'SHA256'
            $r.Source       | Should -Be 'unusable'
            $r.ExpectedHash | Should -BeNullOrEmpty
            $r.Reason       | Should -Be 'clipboard holds MD5; this run computed SHA256'
        }

        It 'Returns unusable for a recognised-but-unsupported clipboard hash, carrying its Detail' {
            $clip = New-Clip $null $null -Format $null -Detail '40 hex characters — looks like SHA-1, which VeriHash does not support'
            $r = Resolve-VeriHashComparator -CompareTo $clip -ComputedAlgorithm 'SHA256'
            $r.Source | Should -Be 'unusable'
            $r.Reason | Should -Match 'SHA-1'
        }

        It 'Does NOT substitute the sidecar for a question it cannot answer' {
            # The crux of the design. A green MATCH here would answer a
            # different question than the one the user asked, and they would
            # read it as an answer to theirs. Failing green is worse than the
            # bug being fixed.
            $r = Resolve-VeriHashComparator -CompareTo (New-Clip 'MD5' $script:Md5A) `
                                            -SidecarInfo (New-Side 'SHA256' $script:Sha256A) `
                                            -ComputedAlgorithm 'SHA256'
            $r.Source       | Should -Be 'unusable'
            $r.ExpectedHash | Should -BeNullOrEmpty
        }
    }

    Context 'Defensive length assertion' {
        It 'Throws when an algorithm name disagrees with its hex length' {
            # Equal algorithm names must imply equal length. Disagreement is a
            # parsing bug, and reporting it as a MISMATCH would blame the
            # user's download for our defect.
            { Resolve-VeriHashComparator -CompareTo (New-Clip 'SHA256' ('a' * 63)) -ComputedAlgorithm 'SHA256' } |
                Should -Throw '*63 hex characters*'
        }
    }

    Context 'Reachable across the module boundary (CMP-01)' {
        It 'Is exported from VeriHash.Core' {
            (Get-Command -Module VeriHash.Core).Name | Should -Contain 'Resolve-VeriHashComparator'
        }

        It 'Resolves from inside VeriHash.HotPath, not just when dot-sourced' {
            # Both modules dot-source their own Private/ into their own scope,
            # which PowerShell does not share. A unit test that dot-sourced the
            # file directly would pass while the shipped module threw
            # CommandNotFoundException inside the hot path.
            Import-Module "$PSScriptRoot/../VeriHash.HotPath/VeriHash.HotPath.psd1" -Force
            $probe = {
                & (Get-Module VeriHash.HotPath) {
                    (Resolve-VeriHashComparator -ComputedAlgorithm 'SHA256').Source
                }
            }
            & $probe | Should -Be 'none'
        }
    }
}
