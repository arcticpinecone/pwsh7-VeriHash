function Get-VeriHashPlatform {
    <#
    .SYNOPSIS
        Returns the running platform as a string.
    .DESCRIPTION
        Canonical platform-detection helper for VeriHash.Core. The single
        authoritative definition (CORE-08); all other modules consume this.
    .OUTPUTS
        System.String -- 'Windows', 'Linux', or 'macOS'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    if ($IsWindows) { return 'Windows' }
    if ($IsLinux)   { return 'Linux'   }
    if ($IsMacOS)   { return 'macOS'   }
    if ($null -eq $PSVersionTable.Platform -or $PSVersionTable.Platform -eq 'Win32NT') { return 'Windows' }
    throw "Unable to detect platform: PSVersionTable.Platform=$($PSVersionTable.Platform), OS=$($PSVersionTable.OS)"
}
