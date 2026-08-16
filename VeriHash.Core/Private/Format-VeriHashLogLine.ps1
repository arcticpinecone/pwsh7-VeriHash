function Format-VeriHashLogLine {
    <#
    .SYNOPSIS
        Builds the locked plain-text log line.
    .DESCRIPTION
        Private helper. Returns:
            "<yyyy-MM-ddTHH:mm:ssZ> <Op> <Algorithm> <Hash> <Bytes> <ElapsedMs> <Result> <Path>"
        Uses the explicit format string (NOT 'o') to avoid sub-second precision
        and '+00:00' offset.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$Op,
        [Parameter(Mandatory)][string]$Algorithm,
        [Parameter(Mandatory)][string]$Hash,
        [Parameter(Mandatory)][long]$Bytes,
        [Parameter(Mandatory)][int]$ElapsedMs,
        [Parameter(Mandatory)][string]$Result,
        [Parameter(Mandatory)][string]$Path
    )
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    return "$ts $Op $Algorithm $Hash $Bytes $ElapsedMs $Result $Path"
}
