BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    . "$PSScriptRoot/TestHelpers.ps1"
    $script:SavedColorEnv = Save-VeriHashColorEnv
    Set-VeriHashColorEnv -Mode Truecolor
    $script:PrevEncoding = [Console]::OutputEncoding
    try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch { }

    function script:Rows {
        param([hashtable]$Splat)
        @(InModuleScope VeriHash.Core -Parameters @{ s = $Splat } {
            param($s)
            $s['Palette'] = Get-VeriHashPalette
            Format-VeriHashChecklist @s
        }) | ForEach-Object { Remove-Ansi $_ }
    }
}
AfterAll {
    try { [Console]::OutputEncoding = $script:PrevEncoding } catch { }
    Restore-VeriHashColorEnv -Saved $script:SavedColorEnv
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
}

Describe 'Format-VeriHashChecklist (FMT)' {
    It 'Emits exactly four rows in clipboard/sidecar/signature/elapsed order' {
        $rows = script:Rows @{ Bytes = 1709869; ElapsedMs = 42 }
        $rows | Should -HaveCount 4
        $rows[0] | Should -BeLike 'clipboard*'
        $rows[1] | Should -BeLike 'sidecar*'
        $rows[2] | Should -BeLike 'signature*'
        $rows[3] | Should -BeLike 'elapsed*'
    }

    It 'Starts every value at column 12' {
        $rows = script:Rows @{ Bytes = 1709869; ElapsedMs = 42 }
        foreach ($r in $rows) { $r.Substring(10, 2) | Should -BeExactly '  ' }
    }

    It 'Renders a clipboard match with the detected format parenthetical' {
        $rows = script:Rows @{
            Bytes = 1; ElapsedMs = 1
            CompareTo = [pscustomobject]@{ Algorithm = 'SHA256'; Hash = 'ab'; Format = 'plain hex, SHA256' }
            ClipboardMatch = $true
        }
        $rows[0] | Should -BeExactly 'clipboard   ✓ match (plain hex, SHA256)'
    }

    It 'Renders a clipboard mismatch with the prefixed format parenthetical' {
        $rows = script:Rows @{
            Bytes = 1; ElapsedMs = 1
            CompareTo = [pscustomobject]@{ Algorithm = 'SHA256'; Hash = 'ab'; Format = 'prefixed, sha256:' }
            ClipboardMatch = $false
        }
        $rows[0] | Should -BeExactly 'clipboard   ✗ mismatch (prefixed, sha256:)'
    }

    It 'Tells the user what to do when the clipboard holds nothing usable' {
        $rows = script:Rows @{ Bytes = 1; ElapsedMs = 1 }
        $rows[0] | Should -BeExactly "clipboard   − nothing recognizable — copy the vendor's hash and re-run"
    }

    It 'Renders each sidecar state' -ForEach @(
        @{ status = 'matched';  name = 'installer.exe.sha256'; expected = 'sidecar     ✓ match — installer.exe.sha256'            }
        @{ status = 'created';  name = 'installer.exe.sha256'; expected = 'sidecar     ✓ created — installer.exe.sha256'          }
        @{ status = 'updated';  name = 'installer.exe.sha256'; expected = 'sidecar     ✓ updated — installer.exe.sha256'          }
        @{ status = 'mismatch'; name = 'installer.exe.sha256'; expected = 'sidecar     ✗ sidecar mismatch — installer.exe.sha256' }
    ) {
        $rows = script:Rows @{
            Bytes = 1; ElapsedMs = 1
            SidecarInfo = [pscustomobject]@{ SidecarStatus = $status; SidecarName = $name }
        }
        $rows[1] | Should -BeExactly $expected
    }

    It 'Explains a suppressed sidecar write on mismatch' {
        $rows = script:Rows @{
            Bytes = 1; ElapsedMs = 1
            SidecarInfo = [pscustomobject]@{ SidecarStatus = 'none'; SidecarName = $null }
        }
        $rows[1] | Should -BeExactly 'sidecar     − none found · not written on mismatch'
    }

    It 'Does NOT blame a mismatch when no sidecar record was supplied at all' {
        # Absent info means nothing is known; claiming suppression would be false.
        $rows = script:Rows @{ Bytes = 1; ElapsedMs = 1 }
        $rows[1] | Should -BeExactly 'sidecar     − none found'
    }

    It 'Renders each signature state' -ForEach @(
        @{ st = 'valid';    rs = $null;             sg = 'Contoso Ltd'; expected = 'signature   ✓ valid — Contoso Ltd'       }
        @{ st = 'invalid';  rs = 'chain untrusted'; sg = $null;         expected = 'signature   ✗ invalid — chain untrusted' }
        @{ st = 'unsigned'; rs = $null;             sg = $null;         expected = 'signature   ! unsigned'                  }
        @{ st = 'skipped';  rs = 'not a PE file';   sg = $null;         expected = 'signature   − skipped (not a PE file)'   }
    ) {
        $rows = script:Rows @{
            Bytes = 1; ElapsedMs = 1
            Signature = [pscustomobject]@{ Status = $st; Reason = $rs; Signer = $sg }
        }
        $rows[2] | Should -BeExactly $expected
    }

    It 'Falls back to bare valid when no signer name could be read' {
        $rows = script:Rows @{
            Bytes = 1; ElapsedMs = 1
            Signature = [pscustomobject]@{ Status = 'valid'; Reason = $null; Signer = $null }
        }
        $rows[2] | Should -BeExactly 'signature   ✓ valid'
    }

    It 'Renders elapsed as ms, size, and throughput' {
        $rows = script:Rows @{ Bytes = 1709869; ElapsedMs = 42 }
        $rows[3] | Should -BeExactly 'elapsed     42 ms · 1.63 MB · ~39 MB/s'
    }

    It 'Separates total work from hashing time when TotalMs is supplied' {
        # Hash time alone reads as the cost of the whole run. Naming both scopes is
        # what stops a 42 ms hash inside a 55 ms operation from looking like a lie.
        $rows = script:Rows @{ Bytes = 1709869; ElapsedMs = 42; TotalMs = 55 }
        $rows[3] | Should -BeExactly 'elapsed     55 ms total · 42 ms hashing · 1.63 MB · ~39 MB/s'
    }

    It 'Keeps the throughput figure tied to hashing time, not total time' {
        # ~39 MB/s is a hash-rate claim; dividing by total would understate the hasher.
        $rows = script:Rows @{ Bytes = 1709869; ElapsedMs = 42; TotalMs = 4200 }
        $rows[3] | Should -BeLike '*~39 MB/s'
    }
}
