BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    Import-Module "$PSScriptRoot/../VeriHash.Manifest/VeriHash.Manifest.psd1" -Force
    $env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')
}
AfterAll {
    Remove-Module VeriHash.Manifest -ErrorAction SilentlyContinue
    Remove-Item Env:VERIHASH_LOG_PATH -ErrorAction SilentlyContinue
}

Describe 'New-VeriHashManifest (MANIFEST-01, -02, -03)' {

    BeforeEach {
        Remove-Item (Join-Path $TestDrive '*_manifest*') -Force -ErrorAction SilentlyContinue
        $script:f1 = Join-Path $TestDrive 'alpha.txt'
        $script:f2 = Join-Path $TestDrive 'bravo.txt'
        [System.IO.File]::WriteAllText($script:f1, "hello alpha`n", [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText($script:f2, "hello bravo`n", [System.Text.UTF8Encoding]::new($false))
    }

    Context 'MANIFEST-01: Creates manifest in common parent with correct format' {
        It 'Returns VeriHash.ManifestCreateResult with ManifestPath, FileCount, Algorithm, ElapsedMs' {
            $r = New-VeriHashManifest -Path $script:f1, $script:f2
            $r.PSTypeNames | Should -Contain 'VeriHash.ManifestCreateResult'
            $r.ManifestPath | Should -Not -BeNullOrEmpty
            $r.FileCount | Should -Be 2
            $r.Algorithm | Should -Be 'SHA256'
            $r.ElapsedMs | Should -BeOfType [int]
        }

        It 'Manifest file physically exists at ManifestPath' {
            $r = New-VeriHashManifest -Path $script:f1, $script:f2
            Test-Path -LiteralPath $r.ManifestPath | Should -BeTrue
        }

        It 'Manifest filename matches D-01 format: *_manifest.sha256' {
            $r = New-VeriHashManifest -Path $script:f1, $script:f2
            [System.IO.Path]::GetFileName($r.ManifestPath) | Should -Match '^\d{4}-\d{2}-\d{2}T\d{6}Z_manifest\.sha256$'
        }

        It 'Each line is GNU sha256sum format: 64hex *filename' {
            $r = New-VeriHashManifest -Path $script:f1, $script:f2
            $lines = [System.IO.File]::ReadAllLines($r.ManifestPath) | Where-Object { $_ -ne '' }
            $lines.Count | Should -Be 2
            foreach ($line in $lines) {
                $line | Should -Match '^[0-9a-f]{64} \*.+$'
            }
        }

        It 'Manifest is in the common parent directory of inputs' {
            $r = New-VeriHashManifest -Path $script:f1, $script:f2
            Split-Path -Parent $r.ManifestPath | Should -Be $TestDrive
        }
    }

    Context 'MANIFEST-02: Mixed-root inputs rejected' {
        It 'Throws with locked error message when files span multiple directories' {
            $otherDir = Join-Path $TestDrive 'subdir'
            New-Item -Path $otherDir -ItemType Directory -Force | Out-Null
            $f3 = Join-Path $otherDir 'charlie.txt'
            [System.IO.File]::WriteAllText($f3, "hello charlie`n", [System.Text.UTF8Encoding]::new($false))
            { New-VeriHashManifest -Path $script:f1, $f3 } | Should -Throw '*Selected files span multiple directories*'
        }
    }

    Context 'MANIFEST-03: Hash-extension files silently filtered (D-18)' {
        It 'Excludes .sha256 files from manifest; FileCount reflects only non-filtered' {
            $hashFile = Join-Path $TestDrive 'data.sha256'
            [System.IO.File]::WriteAllText($hashFile, "fake hash file`n", [System.Text.UTF8Encoding]::new($false))
            $r = New-VeriHashManifest -Path $script:f1, $hashFile, $script:f2
            $r.FileCount | Should -Be 2
            $content = [System.IO.File]::ReadAllText($r.ManifestPath)
            $content | Should -Not -Match 'data\.sha256'
        }

        It 'Filters all hash extensions: .sha256, .sha512, .sha384, .sha1, .md5, .sha2_256, .sha2' {
            $exts = @('.sha256', '.sha512', '.sha384', '.sha1', '.md5', '.sha2_256', '.sha2')
            foreach ($ext in $exts) {
                $hf = Join-Path $TestDrive "noise$ext"
                [System.IO.File]::WriteAllText($hf, 'x', [System.Text.UTF8Encoding]::new($false))
            }
            $allPaths = @($script:f1) + ($exts | ForEach-Object { Join-Path $TestDrive "noise$_" })
            $r = New-VeriHashManifest -Path $allPaths
            $r.FileCount | Should -Be 1
        }

        It 'Throws when all inputs are hash-extension files (nothing to hash)' {
            $hf = Join-Path $TestDrive 'only.sha256'
            [System.IO.File]::WriteAllText($hf, 'x', [System.Text.UTF8Encoding]::new($false))
            { New-VeriHashManifest -Path $hf } | Should -Throw
        }
    }

    Context 'D-02: Collision handling' {
        It 'Appends -1 suffix when manifest filename already exists' {
            $r1 = New-VeriHashManifest -Path $script:f1
            $r2 = New-VeriHashManifest -Path $script:f2
            ($r1.ManifestPath -ne $r2.ManifestPath) | Should -BeTrue
            Test-Path -LiteralPath $r1.ManifestPath | Should -BeTrue
            Test-Path -LiteralPath $r2.ManifestPath | Should -BeTrue
        }
    }

    Context 'D-10: Abort on first error - no partial manifest' {
        It 'Throws when input file does not exist; no manifest file written' {
            $bogus = Join-Path $TestDrive 'nonexistent.bin'
            $manifestsBefore = Get-ChildItem $TestDrive -Filter '*_manifest*' | Measure-Object
            { New-VeriHashManifest -Path $script:f1, $bogus } | Should -Throw
            $manifestsAfter = Get-ChildItem $TestDrive -Filter '*_manifest*' | Measure-Object
            $manifestsAfter.Count | Should -Be $manifestsBefore.Count
        }
    }

    Context 'D-06: UTF-8 NoBOM encoding' {
        It 'Manifest file does not start with UTF-8 BOM bytes' {
            $r = New-VeriHashManifest -Path $script:f1
            $bytes = [System.IO.File]::ReadAllBytes($r.ManifestPath)
            if ($bytes.Length -ge 3) {
                ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -BeFalse
            }
        }
    }
}
