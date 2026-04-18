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
    throw 'NotImplemented: Get-VeriHashPlatform -- implemented in plan 01-02'
}
