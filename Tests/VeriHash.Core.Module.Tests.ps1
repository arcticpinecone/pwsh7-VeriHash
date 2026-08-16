BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
}
AfterAll {
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
}

Describe 'VeriHash.Core module sanity' {
    It 'Imports without errors' {
        { Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force } | Should -Not -Throw
    }

    It 'Exports exactly the nine locked public function names' {
        # Resolve-VeriHashComparator is public only because VeriHash.HotPath
        # calls it across a module boundary -- same reason as
        # Format-VeriHashBatchTally. Private would resolve inside Core and
        # throw CommandNotFoundException inside the hot path.
        $expected = @(
            'Format-VeriHashBatchTally',
            'Format-VeriHashReport',
            'Get-VeriHashPlatform',
            'Get-VeriHashResult',
            'Invoke-VeriHashSidecarDetect',
            'Read-ClipboardHash',
            'Resolve-VeriHashComparator',
            'Test-VeriHashSidecar',
            'Write-VeriHashLog'
        ) | Sort-Object
        $actual = (Get-Command -Module VeriHash.Core).Name | Sort-Object
        Compare-Object $actual $expected | Should -BeNullOrEmpty
    }

    It 'Manifest pins PowerShellVersion 7.0 and CompatiblePSEditions Core' {
        $manifest = Test-ModuleManifest "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1"
        $manifest.PowerShellVersion | Should -Be ([version]'7.0')
        $manifest.CompatiblePSEditions | Should -Contain 'Core'
    }
}
