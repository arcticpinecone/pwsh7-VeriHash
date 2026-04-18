function Get-PreferredSidecar {
    <#
    .SYNOPSIS
        Returns the strongest existing adjacent sidecar for a target path.
    .DESCRIPTION
        Private helper. Tests for '<TargetPath>.sha512', '<TargetPath>.sha256',
        '<TargetPath>.md5' in that order and returns the first one found as
        @{ Path; Algorithm }. Returns $null when none exist.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$TargetPath
    )
    $null = $PSBoundParameters
    throw 'NotImplemented: Get-PreferredSidecar -- implemented in plan 01-02'
}
