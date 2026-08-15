BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
}
AfterAll {
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
}

Describe 'Format-VeriHashByteSize (FMT)' {
    It 'Formats <bytes> as <expected>' -ForEach @(
        @{ bytes = 512;        expected = '512 B'    }
        @{ bytes = 1024;       expected = '1.00 KB'  }
        @{ bytes = 1709869;    expected = '1.63 MB'  }
        @{ bytes = 47525171;   expected = '45.32 MB' }
        @{ bytes = 2147483648; expected = '2.00 GB'  }
    ) {
        InModuleScope VeriHash.Core -Parameters @{ b = $bytes } {
            param($b) Format-VeriHashByteSize -Bytes $b
        } | Should -BeExactly $expected
    }

    It 'Uses invariant culture so a comma-decimal locale cannot break it' {
        $prev = [Threading.Thread]::CurrentThread.CurrentCulture
        try {
            [Threading.Thread]::CurrentThread.CurrentCulture = [cultureinfo]::GetCultureInfo('de-DE')
            InModuleScope VeriHash.Core {
                Format-VeriHashByteSize -Bytes 1709869
            } | Should -BeExactly '1.63 MB'
        } finally {
            [Threading.Thread]::CurrentThread.CurrentCulture = $prev
        }
    }
}

Describe 'Format-VeriHashThroughput (FMT)' {
    It 'Renders one decimal below 10 MB/s' {
        # 1 MB in 200 ms = 5.0 MB/s
        InModuleScope VeriHash.Core {
            Format-VeriHashThroughput -Bytes 1048576 -ElapsedMs 200
        } | Should -BeExactly '~5.0 MB/s'
    }

    It 'Renders an integer at or above 10 MB/s' {
        # 1709869 B in 42 ms = 38.83 MB/s -> 39
        InModuleScope VeriHash.Core {
            Format-VeriHashThroughput -Bytes 1709869 -ElapsedMs 42
        } | Should -BeExactly '~39 MB/s'
    }

    It 'Switches to GB/s at or above 1000 MB/s' {
        # 2 GB in 1000 ms = 2048 MB/s -> 2.0 GB/s
        InModuleScope VeriHash.Core {
            Format-VeriHashThroughput -Bytes 2147483648 -ElapsedMs 1000
        } | Should -BeExactly '~2.0 GB/s'
    }

    It 'Clamps a 0 ms elapsed to 1 ms instead of dividing by zero' {
        { InModuleScope VeriHash.Core {
            Format-VeriHashThroughput -Bytes 1048576 -ElapsedMs 0
        } } | Should -Not -Throw
    }
}
