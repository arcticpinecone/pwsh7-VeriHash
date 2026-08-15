function Remove-Ansi {
    <#
    .SYNOPSIS
        Strips ANSI SGR escape sequences so tests can assert on plain text.
    .DESCRIPTION
        PowerShell 7.2+ may itself strip ANSI when output is redirected
        ($PSStyle.OutputRendering = 'Host'), so this is deliberately
        idempotent: stripping already-plain text is a no-op.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Text
    )
    process { return ($Text -replace "$([char]27)\[[0-9;]*m", '') }
}
