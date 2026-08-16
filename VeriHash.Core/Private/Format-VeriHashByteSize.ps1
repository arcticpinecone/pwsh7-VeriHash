function Format-VeriHashByteSize {
    <#
    .SYNOPSIS
        Renders a byte count as a human-readable binary size.
    .DESCRIPTION
        Uses invariant culture explicitly -- PowerShell's -f operator is
        culture-sensitive, and a de-DE CI runner would otherwise emit
        '1,63 MB' and break every golden-text assertion.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [long]$Bytes
    )
    $inv = [cultureinfo]::InvariantCulture
    if ($Bytes -lt 1KB) { return "$Bytes B" }
    if ($Bytes -lt 1MB) { return (([double]$Bytes / 1KB).ToString('N2', $inv) + ' KB') }
    if ($Bytes -lt 1GB) { return (([double]$Bytes / 1MB).ToString('N2', $inv) + ' MB') }
    return (([double]$Bytes / 1GB).ToString('N2', $inv) + ' GB')
}
