function Format-VeriHashReport {
    <#
    .SYNOPSIS
        Renders a VeriHash.Result to the host in the v1-compatible layout.
    .DESCRIPTION
        Pure renderer -- no I/O, no Get-Item, no Get-FileHash. All data must
        already be on the supplied result object. Hash is rendered lowercase
        per the v2 contract. Optional CompareTo and SidecarInfo extend the
        rendered report.
    .PARAMETER Result
        A VeriHash.Result object (pipeline-bound).
    .PARAMETER CompareTo
        Optional comparison hash record (e.g. clipboard) to render alongside.
    .PARAMETER SidecarInfo
        Optional sidecar-verification record to render alongside.
    .OUTPUTS
        None -- writes to the host stream.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [pscustomobject]$Result,

        [pscustomobject]$CompareTo,

        [pscustomobject]$SidecarInfo
    )
    process {
        $null = $PSBoundParameters
        throw 'NotImplemented: Format-VeriHashReport -- implemented in plan 01-02'
    }
}
