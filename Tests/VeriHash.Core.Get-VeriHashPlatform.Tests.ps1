BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
}
AfterAll {
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
}

Describe 'Get-VeriHashPlatform (CORE-08)' {
    It 'Returns one of Windows, Linux, or macOS' {
        Get-VeriHashPlatform | Should -BeIn @('Windows', 'Linux', 'macOS')
    }

    It 'Returns a string type' {
        Get-VeriHashPlatform | Should -BeOfType [string]
    }

    It 'Has zero duplicate platform-detection definitions outside Core' {
        $hits = Select-String -Path "$PSScriptRoot/../*.ps1" `
            -Pattern '\$(?:script:)?RunningOn(?:Windows|Linux|MacOS)\s*=' `
            -ErrorAction SilentlyContinue
        $hits | Should -BeNullOrEmpty
    }
}
