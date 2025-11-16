# PSScriptAnalyzer settings for VeriHash
# This customizes the rules to fit VeriHash's use case as an interactive CLI tool

@{
    # Enable all rules by default
    IncludeDefaultRules = $true

    # Severity levels to include (Error, Warning, Information)
    Severity = @('Error', 'Warning')

    # Rules to exclude
    ExcludeRules = @(
        # VeriHash is an interactive console application that relies on colored
        # output for user experience. Write-Host is appropriate here since:
        # 1. It's designed to run interactively in a PowerShell console
        # 2. The colored output is a core feature, not an afterthought
        # 3. It's not a module that needs to be pipeline-friendly
        'PSAvoidUsingWriteHost'
    )

    # Custom rule arguments (optional)
    Rules = @{
        PSAvoidUsingCmdletAliases = @{
            # Allow common aliases in scripts (set to $false to be strict)
            allowlist = @()
        }

        PSUseCompatibleSyntax = @{
            # Ensure compatibility with PowerShell 7+
            Enable = $true
            TargetVersions = @('7.0')
        }
    }
}
