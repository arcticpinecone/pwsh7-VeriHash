function ConvertTo-VeriHashAlgorithm {
    <#
    .SYNOPSIS
        Infers the hash algorithm from a hex string (length or '<algo>:' prefix).
    .OUTPUTS
        System.String -- 'MD5', 'SHA256', 'SHA512', or $null on rejection.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Hash
    )

    if ($Hash -match '^(?<algo>md5|sha256|sha512):(?<hex>[A-Fa-f0-9]+)$') {
        $algo = $matches.algo.ToUpperInvariant()
        if ($matches.hex.Length -ne (Get-VeriHashHexLength -Algorithm $algo)) { return $null }
        return $algo
    }

    if ($Hash -match '^[A-Fa-f0-9]+$') {
        switch ($Hash.Length) {
            32  { return 'MD5'    }
            64  { return 'SHA256' }
            128 { return 'SHA512' }
        }
    }
    return $null
}
