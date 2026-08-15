BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    . "$PSScriptRoot/TestHelpers.ps1"
    $script:SavedColorEnv = Save-VeriHashColorEnv
    Set-VeriHashColorEnv -Mode Truecolor
    $script:PrevEncoding = [Console]::OutputEncoding
    try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch { }

    $script:Sha256    = '71792c028e07b0fdd30f4e2a9c1b3d5e8a46f1c29d073bb5e6c48d90a2f1e3b7'
    # Diverges from $Sha256 at index 16 (start of group 2).
    $script:Divergent = '71792c028e07b0fdffffffff9c1b3d5e8a46f1c29d073bb5e6c48d90a2f1e3b7'

    function script:NewResult {
        param($Hash = $script:Sha256, $Algorithm = 'SHA256')
        [pscustomobject]@{
            PSTypeName    = 'VeriHash.Result'
            FilePath      = '/tmp/installer.exe'
            Size          = 47525171
            Algorithm     = $Algorithm
            Hash          = $Hash
            ElapsedMs     = 52
            LastWriteTime = [datetime]::new(2026, 4, 20, 15, 4, 0, [System.DateTimeKind]::Utc)
        }
    }

    function script:Render {
        param([hashtable]$Splat)
        ((Format-VeriHashReport @Splat *>&1 | Out-String) -replace "`r`n", "`n") | Remove-Ansi
    }
}
AfterAll {
    try { [Console]::OutputEncoding = $script:PrevEncoding } catch { }
    Restore-VeriHashColorEnv -Saved $script:SavedColorEnv
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
}

Describe 'Format-VeriHashReport header (FMT-01)' {
    It 'Names the tool, algorithm, filename, and size on one line' {
        $out = script:Render @{ Result = (script:NewResult) }
        $out | Should -Match ([regex]::Escape('VeriHash 2.0 · SHA256 · installer.exe (45.32 MB)'))
    }
}

Describe 'Format-VeriHashReport elapsed scope (FMT)' {
    It 'Reports total work alongside hashing time when TotalMs is supplied' {
        $out = script:Render @{ Result = (script:NewResult); TotalMs = 118 }
        $out | Should -Match ([regex]::Escape('elapsed     118 ms total · 52 ms hashing'))
    }

    It 'Keeps the hash-only elapsed row when the caller has no total to report' {
        $out = script:Render @{ Result = (script:NewResult) }
        $out | Should -Match ([regex]::Escape('elapsed     52 ms · 45.32 MB'))
    }
}

Describe 'Format-VeriHashReport banner (FMT-02)' {
    It 'Shows HASHED when there is nothing to compare against' {
        $out = script:Render @{ Result = (script:NewResult) }
        $out | Should -Match ([regex]::Escape('●  HASHED — no hash on clipboard to compare against'))
    }

    It 'Shows MATCH when the clipboard hash agrees' {
        $out = script:Render @{
            Result    = (script:NewResult)
            CompareTo = [pscustomobject]@{ Algorithm = 'SHA256'; Hash = $script:Sha256; Format = 'plain hex, SHA256' }
        }
        $out | Should -Match ([regex]::Escape('✓  MATCH — SHA256 matches hash on clipboard'))
    }

    It 'Shows MISMATCH when the clipboard hash disagrees' {
        $out = script:Render @{
            Result    = (script:NewResult)
            CompareTo = [pscustomobject]@{ Algorithm = 'SHA256'; Hash = $script:Divergent; Format = 'plain hex, SHA256' }
        }
        $out | Should -Match ([regex]::Escape('✗  MISMATCH — file does NOT match clipboard hash'))
    }

    It 'Falls back to sidecar wording when only a sidecar is available' {
        $out = script:Render @{
            Result      = (script:NewResult)
            SidecarInfo = [pscustomobject]@{
                SidecarStatus = 'matched'; SidecarName = 'installer.exe.sha256'
                Algorithm = 'SHA256'; ExpectedHash = $script:Sha256
            }
        }
        $out | Should -Match ([regex]::Escape('✓  MATCH — SHA256 matches sidecar file'))
    }

    It 'Shows MISMATCH with both hashes when a sidecar disagrees' {
        $out = script:Render @{
            Result      = (script:NewResult)
            SidecarInfo = [pscustomobject]@{
                SidecarStatus = 'mismatch'; SidecarName = 'installer.exe.sha256'
                Algorithm = 'SHA256'; ExpectedHash = $script:Divergent
            }
        }
        $out | Should -Match ([regex]::Escape('✗  MISMATCH — file does NOT match sidecar file'))
        $out | Should -Match ([regex]::Escape('expected  sidecar'))
        $out | Should -Match ([regex]::Escape('computed  52 ms'))
    }

    It 'Does NOT treat a different-algorithm sidecar as a mismatch' {
        # A .sha512 sidecar next to a SHA256 compute is not evidence of tampering.
        $out = script:Render @{
            Result      = (script:NewResult)
            SidecarInfo = [pscustomobject]@{
                SidecarStatus = 'matched'; SidecarName = 'installer.exe.sha512'
                Algorithm = 'SHA512'; ExpectedHash = ('a' * 128)
            }
        }
        $out | Should -Match ([regex]::Escape('●  HASHED'))
        $out | Should -Not -Match ([regex]::Escape('MISMATCH'))
        $out | Should -Not -Match ([regex]::Escape('Do not run this file.'))
    }
}

Describe 'Format-VeriHashReport hash comparison block (FMT-03)' {
    It 'Stacks expected above computed so agreement reads as columns' {
        $out = script:Render @{
            Result    = (script:NewResult)
            CompareTo = [pscustomobject]@{ Algorithm = 'SHA256'; Hash = $script:Sha256; Format = 'plain hex, SHA256' }
        }
        $out | Should -Match ([regex]::Escape('expected  clipboard'))
        $out | Should -Match ([regex]::Escape('computed  52 ms'))
        ([regex]::Matches($out, [regex]::Escape('71792c02 8e07b0fd'))).Count | Should -Be 2
    }

    It 'Labels a sidecar comparison as the expected source' {
        $out = script:Render @{
            Result      = (script:NewResult)
            SidecarInfo = [pscustomobject]@{
                SidecarStatus = 'matched'; SidecarName = 'installer.exe.sha256'
                Algorithm = 'SHA256'; ExpectedHash = $script:Sha256
            }
        }
        $out | Should -Match ([regex]::Escape('expected  sidecar'))
    }

    It 'Reports the divergence point on a mismatch' {
        $out = script:Render @{
            Result    = (script:NewResult)
            CompareTo = [pscustomobject]@{ Algorithm = 'SHA256'; Hash = $script:Divergent; Format = 'plain hex, SHA256' }
        }
        $out | Should -Match ([regex]::Escape('first 16 of 64 characters agree — divergence starts at character 17'))
    }

    It 'Collapses to a single labelled hash line when there is no comparator' {
        $out = script:Render @{ Result = (script:NewResult) }
        $out | Should -Match ([regex]::Escape('sha256'))
        $out | Should -Not -Match ([regex]::Escape('expected'))
        $out | Should -Not -Match ([regex]::Escape('computed'))
    }
}

Describe 'Format-VeriHashReport checklist and footer (FMT-04, FMT-05)' {
    It 'Emits all four checklist rows' {
        $out = script:Render @{ Result = (script:NewResult) }
        $out | Should -Match '(?m)^clipboard   '
        $out | Should -Match '(?m)^sidecar     '
        $out | Should -Match '(?m)^signature   '
        $out | Should -Match '(?m)^elapsed     '
    }

    It 'Footers with the full path and UTC modified time' {
        $out = script:Render @{ Result = (script:NewResult) }
        $out | Should -Match ([regex]::Escape('/tmp/installer.exe · modified 2026-04-20 15:04 UTC'))
    }

    It 'Adds the do-not-run advisory on mismatch only' {
        $bad = script:Render @{
            Result    = (script:NewResult)
            CompareTo = [pscustomobject]@{ Algorithm = 'SHA256'; Hash = $script:Divergent; Format = 'plain hex, SHA256' }
        }
        $bad | Should -Match ([regex]::Escape('Do not run this file. Re-download it, then verify again.'))

        $good = script:Render @{ Result = (script:NewResult) }
        $good | Should -Not -Match ([regex]::Escape('Do not run this file.'))
    }
}

Describe 'Format-VeriHashReport compact mode (FMT-06)' {
    It 'Drops the hash block and footer for a matching file' {
        $out = script:Render @{
            Result    = (script:NewResult)
            CompareTo = [pscustomobject]@{ Algorithm = 'SHA256'; Hash = $script:Sha256; Format = 'plain hex, SHA256' }
            Compact   = $true
        }
        $out | Should -Match ([regex]::Escape('✓  MATCH'))
        $out | Should -Match '(?m)^clipboard   '
        $out | Should -Not -Match ([regex]::Escape('expected  clipboard'))
        $out | Should -Not -Match ([regex]::Escape('modified 2026-04-20'))
    }

    It 'Keeps the hash block for a mismatching file so the user can see the divergence' {
        $out = script:Render @{
            Result    = (script:NewResult)
            CompareTo = [pscustomobject]@{ Algorithm = 'SHA256'; Hash = $script:Divergent; Format = 'plain hex, SHA256' }
            Compact   = $true
        }
        $out | Should -Match ([regex]::Escape('expected  clipboard'))
    }
}

Describe 'Format-VeriHashReport algorithm widths (FMT-07)' {
    It 'Renders MD5 as four groups' {
        $out = script:Render @{ Result = (script:NewResult -Hash '441b45a2052b1f74aa946ba587a8f4f7' -Algorithm 'MD5') }
        $out | Should -Match ([regex]::Escape('441b45a2 052b1f74 aa946ba5 87a8f4f7'))
    }

    It 'Wraps SHA512 across two lines' {
        $sha512 = '06d679a0ea464b9226ec3f981acad6cc6cd0f42dbdec78e3a3e4e58c880749a77daf4317b037208c73657b2f120f9b192fdb93803606d39059c887c7087c59a2'
        $out = script:Render @{ Result = (script:NewResult -Hash $sha512 -Algorithm 'SHA512') }
        $out | Should -Match ([regex]::Escape('06d679a0 ea464b92'))
        $out | Should -Match ([regex]::Escape('7daf4317 b037208c'))
    }
}
