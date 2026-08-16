BeforeAll {
    Import-Module "$PSScriptRoot/../VeriHash.Core/VeriHash.Core.psd1" -Force
    . "$PSScriptRoot/../VeriHash.Integrations.ps1"
    $env:VERIHASH_LOG_PATH = (Join-Path $TestDrive 'verihash.log')
}
AfterAll {
    Remove-Module VeriHash.Core -ErrorAction SilentlyContinue
    Remove-Item Env:VERIHASH_LOG_PATH -ErrorAction SilentlyContinue
}

Describe 'VeriHash.Integrations surface (INTEG-01)' {
    It 'Dot-sourcing makes all integration functions available' {
        Get-Command Install-WindowsSendTo | Should -Not -BeNullOrEmpty
        Get-Command Install-LinuxContextMenu | Should -Not -BeNullOrEmpty
        Get-Command Install-KDEContextMenu | Should -Not -BeNullOrEmpty
        Get-Command Get-DesktopEnvironment | Should -Not -BeNullOrEmpty
    }

    It 'No PSFramework references in VeriHash.Integrations.ps1' {
        $hits = Select-String -Path "$PSScriptRoot/../VeriHash.Integrations.ps1" `
            -Pattern 'PSFramework|Write-PSFMessage|PSFrameworkAvailable' -ErrorAction SilentlyContinue
        $hits | Should -BeNullOrEmpty
    }

    It 'No VirusTotal references in VeriHash.Integrations.ps1' {
        $hits = Select-String -Path "$PSScriptRoot/../VeriHash.Integrations.ps1" `
            -Pattern 'virustotal|VERIHASH_VT_' -ErrorAction SilentlyContinue
        $hits | Should -BeNullOrEmpty
    }
}

Describe 'Install-WindowsSendTo (INTEG-02)' {
    It 'Creates both VeriHash.lnk and VeriHash - Manifest.lnk' {
        $funcBody = (Get-Command Install-WindowsSendTo).ScriptBlock.ToString()
        $funcBody | Should -Match 'VeriHash\.lnk'
        $funcBody | Should -Match 'VeriHash - Manifest\.lnk'
    }

    It 'Manifest shortcut includes -Manifest flag in arguments' {
        $funcBody = (Get-Command Install-WindowsSendTo).ScriptBlock.ToString()
        $funcBody | Should -Match '-Manifest'
    }
}

Describe 'Install-KDEContextMenu (INTEG-03)' {
    It 'KDE .desktop content includes ManifestHash action' {
        $funcBody = (Get-Command Install-KDEContextMenu).ScriptBlock.ToString()
        $funcBody | Should -Match 'ManifestHash'
        $funcBody | Should -Match 'Actions=ComputeHash;VerifyHash;ManifestHash;'
    }

    It 'KDE ManifestHash Exec includes -Manifest flag' {
        $funcBody = (Get-Command Install-KDEContextMenu).ScriptBlock.ToString()
        $funcBody | Should -Match '-Manifest'
    }

    It 'Get-DesktopEnvironment returns a string or $null' {
        if ($PSVersionTable.Platform -ne 'Unix') {
            Set-ItResult -Skipped -Because "Not running on Linux"
            return
        }
        $result = Get-DesktopEnvironment
        if ($null -ne $result) { $result | Should -BeOfType [string] }
    }
}

Describe 'Lazy loading (INTEG-01 - integration isolation)' {
    It 'VeriHash.ps1 contains lazy dot-source inside InstallSendTo/InstallKDE block' {
        $mainScript = Get-Content "$PSScriptRoot/../VeriHash.ps1" -Raw
        $mainScript | Should -Match 'if \(\$InstallSendTo[\s\S]*?VeriHash\.Integrations\.ps1'
    }

    It 'Install functions are NOT defined directly in VeriHash.ps1' {
        $mainScript = Get-Content "$PSScriptRoot/../VeriHash.ps1" -Raw
        $mainScript | Should -Not -Match 'function Install-WindowsSendTo'
        $mainScript | Should -Not -Match 'function Install-KDEContextMenu'
        $mainScript | Should -Not -Match 'function Get-DesktopEnvironment'
    }
}
