function Test-VeriHashSidecar {
    <#
    .SYNOPSIS
        Verifies a target file against its strongest adjacent sidecar.
    .DESCRIPTION
        Sidecar precedence: .sha512 > .sha256 > .md5. Only the chosen sidecar
        is read and verified (single hash compute). Supports v1 sidecar formats
        ('HASH  filename' two-space and 'HASH *filename' asterisk).
    .PARAMETER Path
        Path to the TARGET file (NOT the sidecar). Resolved with -LiteralPath.
    .OUTPUTS
        VeriHash.Result with an additional 'Sidecar' field describing which
        sidecar was used, or $null when no sidecar exists.
    #>
    [CmdletBinding()]
    [OutputType('VeriHash.Result')]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )
    $null = $PSBoundParameters
    throw 'NotImplemented: Test-VeriHashSidecar -- implemented in plan 01-02'
}
