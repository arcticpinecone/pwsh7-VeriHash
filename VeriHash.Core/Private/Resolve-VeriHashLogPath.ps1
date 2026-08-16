function Resolve-VeriHashLogPath {
    <#
    .SYNOPSIS
        Resolves the active log file path.
    .DESCRIPTION
        Private helper. Precedence:
            $env:VERIHASH_LOG_PATH > "$HOME/.verihash/verihash.log"
        No platform-conditional logic -- single universal default.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    if ($env:VERIHASH_LOG_PATH) { return $env:VERIHASH_LOG_PATH }
    return (Join-Path $HOME '.verihash/verihash.log')
}
