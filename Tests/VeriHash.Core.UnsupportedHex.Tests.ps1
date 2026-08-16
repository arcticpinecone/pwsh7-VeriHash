BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
}
AfterAll {
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
}

Describe 'Read-ClipboardHash reports plausible but unsupported hex (CMP-10)' {

    BeforeEach {
        Mock -ModuleName VeriHash.Core Get-VeriHashPlatform { 'Windows' }
    }

    It 'names SHA-224 for a 56-character paste' {
        $hex = 'c' * 56
        Mock -ModuleName VeriHash.Core Get-Clipboard { $hex }
        $r = Read-ClipboardHash
        $r | Should -Not -BeNullOrEmpty
        $r.Detail | Should -Match '56 hex'
        $r.Detail | Should -Match 'SHA-224'
    }

    It 'names SHA-384 for a 96-character paste' {
        $hex = 'd' * 96
        Mock -ModuleName VeriHash.Core Get-Clipboard { $hex }
        $r = Read-ClipboardHash
        $r.Detail | Should -Match '96 hex'
        $r.Detail | Should -Match 'SHA-384'
    }

    It 'reports the length without naming an algorithm when the length is not well known' {
        $hex = 'e' * 72
        Mock -ModuleName VeriHash.Core Get-Clipboard { $hex }
        $r = Read-ClipboardHash
        $r.Detail | Should -Match '72 hex'
        $r.Detail | Should -Not -Match 'SHA-224|SHA-384'
    }

    It 'carries no comparator, so an unsupported paste can never be compared' {
        # The whole point of the record is to be reportable but unusable. A
        # Hash here would be a 56-character string a 64-character digest could
        # be compared against.
        $hex = 'c' * 56
        Mock -ModuleName VeriHash.Core Get-Clipboard { $hex }
        $r = Read-ClipboardHash
        $r.Algorithm | Should -BeNullOrEmpty
        $r.Hash | Should -BeNullOrEmpty
    }

    It 'still returns nothing for hex too short to be a digest' {
        # 'deadbeef' is valid hex and means nothing. Reporting it as an
        # unsupported digest would make the row noise on ordinary clipboards.
        Mock -ModuleName VeriHash.Core Get-Clipboard { 'deadbeef' }
        Read-ClipboardHash | Should -BeNullOrEmpty
    }

    It 'still returns nothing when the clipboard holds no hex at all' {
        Mock -ModuleName VeriHash.Core Get-Clipboard { 'just some prose' }
        Read-ClipboardHash | Should -BeNullOrEmpty
    }
}

Describe 'An unsupported paste reaches the report as unusable, not absent (CMP-10)' {

    It 'resolves to an unusable comparator carrying the explanation' {
        # CMP-10 in full: the user asked a question VeriHash cannot answer, and
        # must be told that -- not told their clipboard was empty.
        $unsupported = [pscustomobject]@{
            Algorithm = $null
            Hash      = $null
            Format    = $null
            Detail    = 'clipboard holds 56 hex characters (likely SHA-224); VeriHash does not support it'
        }
        $c = Resolve-VeriHashComparator -CompareTo $unsupported -SidecarInfo $null -ComputedAlgorithm 'SHA256'
        $c.Source | Should -Be 'unusable'
        $c.ExpectedHash | Should -BeNullOrEmpty
        $c.Reason | Should -Match 'SHA-224'
    }

    It 'does not fall back to the sidecar when the paste is unsupported' {
        # A sidecar answers a different question. Substituting it would fail
        # green against the question actually asked.
        $unsupported = [pscustomobject]@{
            Algorithm = $null
            Hash      = $null
            Format    = $null
            Detail    = 'clipboard holds 56 hex characters (likely SHA-224); VeriHash does not support it'
        }
        $sidecar = [pscustomobject]@{
            ExpectedHash = 'f' * 64
            Algorithm    = 'SHA256'
        }
        $c = Resolve-VeriHashComparator -CompareTo $unsupported -SidecarInfo $sidecar -ComputedAlgorithm 'SHA256'
        $c.Source | Should -Be 'unusable'
    }
}
