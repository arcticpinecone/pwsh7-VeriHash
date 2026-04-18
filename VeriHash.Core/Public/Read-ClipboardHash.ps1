function Read-ClipboardHash {
    <#
    .SYNOPSIS
        Reads a hash from the clipboard, inferring algorithm by length or prefix.
    .DESCRIPTION
        Supports two forms:
          1. Bare hex (length-inferred): 32 -> MD5, 64 -> SHA256, 128 -> SHA512.
          2. Prefixed: '<algo>:<hex>' where <algo> in md5|sha256|sha512.
        Returns $null on non-Windows platforms (cross-platform clipboard is
        deferred to the v2.x backlog) or when no usable hash is present.
    .OUTPUTS
        [pscustomobject]@{ Algorithm; Hash } -- Hash is lowercase hex.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    if ((Get-VeriHashPlatform) -ne 'Windows') {
        Write-Verbose 'Clipboard reading not supported on this platform yet.'
        return $null
    }

    $raw = Get-Clipboard -ErrorAction SilentlyContinue
    if (-not $raw) { return $null }

    $text = ($raw -join "`n").Trim()
    if (-not $text) { return $null }

    $algo = ConvertTo-VeriHashAlgorithm -Hash $text
    if (-not $algo) { return $null }

    if ($text -match '^(?:md5|sha256|sha512):(?<hex>[A-Fa-f0-9]+)$') {
        $hex = $matches.hex
    } else {
        $hex = $text
    }

    return [pscustomobject]@{
        Algorithm = $algo
        Hash      = $hex.ToLowerInvariant()
    }
}
