BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    Import-Module "$PSScriptRoot/../VeriHash.Manifest/VeriHash.Manifest.psd1" -Force
    $env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')

    # Detect WSL availability once
    $script:wslAvailable = $null -ne (Get-Command wsl -ErrorAction SilentlyContinue)
    if ($script:wslAvailable) {
        try {
            $verCheck = wsl -- sha256sum --version 2>&1
            $script:sha256sumAvailable = $LASTEXITCODE -eq 0
        } catch {
            $script:sha256sumAvailable = $false
        }
    } else {
        $script:sha256sumAvailable = $false
    }
    $script:canRunRoundtrip = $script:wslAvailable -and $script:sha256sumAvailable
}
AfterAll {
    Remove-Module VeriHash.Manifest -ErrorAction SilentlyContinue
    Remove-Item Env:VERIHASH_LOG_PATH -ErrorAction SilentlyContinue
}

Describe 'New-VeriHashManifest GNU sha256sum -c round-trip (MANIFEST-08)' {

    It 'Manifest round-trips through sha256sum -c on WSL' {
        if (-not $script:canRunRoundtrip) {
            Set-ItResult -Skipped -Because 'WSL or sha256sum not available'
            return
        }

        $utf8 = [System.Text.UTF8Encoding]::new($false)
        $f1 = Join-Path $TestDrive 'roundtrip1.txt'
        $f2 = Join-Path $TestDrive 'roundtrip2.txt'
        [IO.File]::WriteAllText($f1, "round trip test one`n", $utf8)
        [IO.File]::WriteAllText($f2, "round trip test two`n", $utf8)

        $result = New-VeriHashManifest -Path $f1, $f2
        $result.ManifestPath | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath $result.ManifestPath | Should -BeTrue

        $manifestDir = Split-Path -Parent $result.ManifestPath
        $manifestName = [System.IO.Path]::GetFileName($result.ManifestPath)
        $wslDir = $manifestDir -replace '\\', '/' -replace '^([A-Z]):', { '/mnt/' + $_.Groups[1].Value.ToLower() }

        $wslOutput = wsl -- bash -c "cd '$wslDir' && sha256sum -c '$manifestName'" 2>&1
        $wslExitCode = $LASTEXITCODE

        $wslExitCode | Should -Be 0 -Because "sha256sum -c should accept the VeriHash manifest (output: $wslOutput)"
    }

    It 'Manifest with single file also round-trips' {
        if (-not $script:canRunRoundtrip) {
            Set-ItResult -Skipped -Because 'WSL or sha256sum not available'
            return
        }

        $utf8 = [System.Text.UTF8Encoding]::new($false)
        $f = Join-Path $TestDrive 'single.txt'
        [IO.File]::WriteAllText($f, "single file test`n", $utf8)

        $result = New-VeriHashManifest -Path $f
        $manifestDir = Split-Path -Parent $result.ManifestPath
        $manifestName = [System.IO.Path]::GetFileName($result.ManifestPath)
        $wslDir = $manifestDir -replace '\\', '/' -replace '^([A-Z]):', { '/mnt/' + $_.Groups[1].Value.ToLower() }

        $wslOutput = wsl -- bash -c "cd '$wslDir' && sha256sum -c '$manifestName'" 2>&1
        $LASTEXITCODE | Should -Be 0 -Because "sha256sum -c should verify the single-file manifest (output: $wslOutput)"
    }
}
