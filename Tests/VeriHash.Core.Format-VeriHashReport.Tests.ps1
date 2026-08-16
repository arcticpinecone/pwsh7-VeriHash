BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    $script:Fixture = Join-Path $PSScriptRoot 'Fixtures/VeriHash_1024.ico'
    $script:Size    = (Get-Item $script:Fixture).Length
    $script:Md5     = '441b45a2052b1f74aa946ba587a8f4f7'
    $script:Sha256  = '3eb53e022fc03d61dffe2aff3244103daef28166b9c538cabbf04462fa59c775'
    $script:Sha512  = '06d679a0ea464b9226ec3f981acad6cc6cd0f42dbdec78e3a3e4e58c880749a77daf4317b037208c73657b2f120f9b192fdb93803606d39059c887c7087c59a2'
}
AfterAll {
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
}

Describe 'Format-VeriHashReport (CORE-06)' {
    It 'Renders MD5 result matching golden text' {
        $r = [pscustomobject]@{
            PSTypeName = 'VeriHash.Result'
            FilePath   = 'Tests/Fixtures/VeriHash_1024.ico'
            Size       = $script:Size
            Algorithm  = 'MD5'
            Hash       = $script:Md5
            ElapsedMs  = 42
        }
        $expected = ((Get-Content -Raw -LiteralPath "$PSScriptRoot/Fixtures/format-report-golden-md5.txt") -replace "`r`n","`n")
        $actual = (Format-VeriHashReport $r *>&1 | Out-String) -replace "`r`n","`n"
        $actualNorm = $actual `
            -replace 'Start UTC:\s+\S+','Start UTC:    <TIMESTAMP>' `
            -replace 'Created:\s+[^\r\n]+','Created:      <CREATED>' `
            -replace 'Modified:\s+[^\r\n]+','Modified:     <MODIFIED>' `
            -replace 'Elapsed:\s+\d+ ms','Elapsed:      <ELAPSED_MS> ms'
        $actualNorm | Should -BeExactly $expected
    }

    It 'Renders SHA256 result matching golden text' {
        $r = [pscustomobject]@{
            PSTypeName = 'VeriHash.Result'
            FilePath   = 'Tests/Fixtures/VeriHash_1024.ico'
            Size       = $script:Size
            Algorithm  = 'SHA256'
            Hash       = $script:Sha256
            ElapsedMs  = 42
        }
        $expected = ((Get-Content -Raw -LiteralPath "$PSScriptRoot/Fixtures/format-report-golden-sha256.txt") -replace "`r`n","`n")
        $actual = (Format-VeriHashReport $r *>&1 | Out-String) -replace "`r`n","`n"
        $actualNorm = $actual `
            -replace 'Start UTC:\s+\S+','Start UTC:    <TIMESTAMP>' `
            -replace 'Created:\s+[^\r\n]+','Created:      <CREATED>' `
            -replace 'Modified:\s+[^\r\n]+','Modified:     <MODIFIED>' `
            -replace 'Elapsed:\s+\d+ ms','Elapsed:      <ELAPSED_MS> ms'
        $actualNorm | Should -BeExactly $expected
    }

    It 'Renders SHA512 result matching golden text' {
        $r = [pscustomobject]@{
            PSTypeName = 'VeriHash.Result'
            FilePath   = 'Tests/Fixtures/VeriHash_1024.ico'
            Size       = $script:Size
            Algorithm  = 'SHA512'
            Hash       = $script:Sha512
            ElapsedMs  = 42
        }
        $expected = ((Get-Content -Raw -LiteralPath "$PSScriptRoot/Fixtures/format-report-golden-sha512.txt") -replace "`r`n","`n")
        $actual = (Format-VeriHashReport $r *>&1 | Out-String) -replace "`r`n","`n"
        $actualNorm = $actual `
            -replace 'Start UTC:\s+\S+','Start UTC:    <TIMESTAMP>' `
            -replace 'Created:\s+[^\r\n]+','Created:      <CREATED>' `
            -replace 'Modified:\s+[^\r\n]+','Modified:     <MODIFIED>' `
            -replace 'Elapsed:\s+\d+ ms','Elapsed:      <ELAPSED_MS> ms'
        $actualNorm | Should -BeExactly $expected
    }
}
