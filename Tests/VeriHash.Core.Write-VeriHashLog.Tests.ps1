BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
}
AfterAll {
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
}

Describe 'Write-VeriHashLog (CORE-07)' {
    BeforeEach {
        $script:LogPath = Join-Path $TestDrive 'verihash.log'
        $env:VERIHASH_LOG_PATH = $script:LogPath
        Remove-Item Env:VERIHASH_LOG -ErrorAction SilentlyContinue
    }
    AfterEach {
        Remove-Item Env:VERIHASH_LOG_PATH -ErrorAction SilentlyContinue
        Remove-Item Env:VERIHASH_LOG      -ErrorAction SilentlyContinue
    }

    It 'Writes nothing when neither -Log nor $env:VERIHASH_LOG is set' {
        Write-VeriHashLog -Op hash -Algorithm SHA256 -Hash 'deadbeef' -Bytes 1024 -ElapsedMs 5 -Result ok -Path '/tmp/x'
        Test-Path $script:LogPath | Should -BeFalse
    }

    It 'Writes exactly one line when -Log is passed' {
        Write-VeriHashLog -Op hash -Algorithm SHA256 -Hash 'deadbeef' -Bytes 1024 -ElapsedMs 5 -Result ok -Path '/tmp/x' -Log
        (Get-Content -LiteralPath $script:LogPath).Count | Should -Be 1
    }

    It 'Writes exactly one line when $env:VERIHASH_LOG=1' {
        $env:VERIHASH_LOG = '1'
        Write-VeriHashLog -Op hash -Algorithm SHA256 -Hash 'deadbeef' -Bytes 1024 -ElapsedMs 5 -Result ok -Path '/tmp/x'
        (Get-Content -LiteralPath $script:LogPath).Count | Should -Be 1
    }

    It 'Line shape is "<ts> <op> <algo> <hash> <bytes> <ms> <result> <path>"' {
        Write-VeriHashLog -Op hash -Algorithm SHA256 -Hash 'deadbeef' -Bytes 1024 -ElapsedMs 5 -Result ok -Path '/tmp/some path/file.bin' -Log
        $line = Get-Content -LiteralPath $script:LogPath -Raw
        $line.TrimEnd() | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z hash SHA256 deadbeef 1024 5 ok /tmp/some path/file\.bin$'
    }

    It 'Writes UTF-8 without BOM' {
        Write-VeriHashLog -Op hash -Algorithm SHA256 -Hash 'deadbeef' -Bytes 1024 -ElapsedMs 5 -Result ok -Path '/tmp/x' -Log
        $bytes = [System.IO.File]::ReadAllBytes($script:LogPath)
        ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -BeFalse
    }

    It 'Honors $env:VERIHASH_LOG_PATH override' {
        $custom = Join-Path $TestDrive 'custom-spot.log'
        $env:VERIHASH_LOG_PATH = $custom
        $env:VERIHASH_LOG = '1'
        Write-VeriHashLog -Op hash -Algorithm SHA256 -Hash 'deadbeef' -Bytes 1024 -ElapsedMs 5 -Result ok -Path '/tmp/x'
        Test-Path $custom | Should -BeTrue
        Test-Path (Join-Path $HOME '.verihash/verihash.log') | Should -BeFalse
    }

    It 'Writes path verbatim (no privacy redaction)' {
        $litPath = 'C:\Users\test\file.bin'
        Write-VeriHashLog -Op hash -Algorithm SHA256 -Hash 'deadbeef' -Bytes 1024 -ElapsedMs 5 -Result ok -Path $litPath -Log
        $line = (Get-Content -LiteralPath $script:LogPath -Raw).TrimEnd()
        $line | Should -BeLike "*$litPath"
        $line | Should -Not -Match '%USERPROFILE%'
    }
}
