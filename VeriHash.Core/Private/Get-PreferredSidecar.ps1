function Get-PreferredSidecar {
    <#
    .SYNOPSIS
        Picks the strongest adjacent sidecar for a target file.
    .DESCRIPTION
        Precedence: .sha512 > .sha256 > .md5. Returns the first existing
        sidecar adjacent to the target, or $null when none exists.
    .OUTPUTS
        System.Management.Automation.PSCustomObject -- @{ Path; Algorithm } or $null.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$TargetPath
    )
    $algoMap = [ordered]@{
        '.sha512' = 'SHA512'
        '.sha256' = 'SHA256'
        '.md5'    = 'MD5'
    }
    foreach ($ext in $algoMap.Keys) {
        $sidecarPath = "$TargetPath$ext"
        if (Test-Path -LiteralPath $sidecarPath) {
            return [pscustomobject]@{ Path = $sidecarPath; Algorithm = $algoMap[$ext] }
        }
    }
    return $null
}
