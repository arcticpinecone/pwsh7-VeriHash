function Get-VeriHashDiffIndex {
    <#
    .SYNOPSIS
        Returns the index of the first differing character of two hex strings.
    .DESCRIPTION
        Returns -1 when the strings are identical. When one string is a strict
        prefix of the other (which happens if the clipboard holds an MD5 and
        VeriHash computed a SHA256), the divergence point is the shorter
        length -- everything from there on is "extra" and gets highlighted.
    .OUTPUTS
        System.Int32
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [string]$Expected,
        [Parameter(Mandatory)] [AllowEmptyString()] [string]$Actual
    )
    $min = [Math]::Min($Expected.Length, $Actual.Length)
    for ($i = 0; $i -lt $min; $i++) {
        if ($Expected[$i] -ne $Actual[$i]) { return $i }
    }
    if ($Expected.Length -ne $Actual.Length) { return $min }
    return -1
}
