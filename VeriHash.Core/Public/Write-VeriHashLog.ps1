function Write-VeriHashLog {
    <#
    .SYNOPSIS
        Appends one plain-text log line to the VeriHash log file.
    .DESCRIPTION
        Writes when -Log is set OR $env:VERIHASH_LOG=1. Otherwise no-op.
        Line format (locked for v2):
            <ISO8601-UTC> <op> <algo> <hash> <bytes> <elapsed_ms> <result> <path>
        Path is always last so spaces in paths cannot break splitting on the
        first 7 columns. Honors $env:VERIHASH_LOG_PATH override (env > default
        ~/.verihash/verihash.log). UTF-8 no BOM, append-only, no rotation.
    .OUTPUTS
        None.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('hash', 'verify')]
        [string]$Op,

        [ValidateSet('MD5', 'SHA256', 'SHA512', 'n/a')]
        [string]$Algorithm = 'n/a',

        [string]$Hash = 'n/a',

        [long]$Bytes = 0,

        [int]$ElapsedMs = 0,

        [Parameter(Mandatory)]
        [ValidateSet('ok', 'mismatch', 'missing', 'error', 'n/a')]
        [string]$Result,

        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$Log
    )

    if (-not ($Log -or $env:VERIHASH_LOG -eq '1')) { return }

    $logPath = Resolve-VeriHashLogPath
    $parent = Split-Path -Parent $logPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $line = Format-VeriHashLogLine -Op $Op -Algorithm $Algorithm -Hash $Hash -Bytes $Bytes -ElapsedMs $ElapsedMs -Result $Result -Path $Path
    Add-Content -LiteralPath $logPath -Value $line -Encoding utf8
}
