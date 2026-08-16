function Read-ClipboardHash {
    <#
    .SYNOPSIS
        Reads a hash from the clipboard, inferring algorithm by length or prefix.
    .DESCRIPTION
        ConvertTo-VeriHashHexCandidate does the tolerating -- vendor labels,
        display grouping, sha256sum lines -- and hands back one canonical
        string. This function only decides what that string means.

        Recognised forms:
          1. Bare hex (length-inferred): 32 -> MD5, 64 -> SHA256, 128 -> SHA512.
          2. Prefixed: '<algo>:<hex>' where <algo> in md5|sha256|sha512.
          3. Either of the above split into uniform whitespace groups, which is
             how VeriHash's own report prints a digest and how certutil prints
             one.
        Returns $null on non-Windows platforms (cross-platform clipboard is
        deferred to the v2.x backlog) or when no usable hash is present.
    .OUTPUTS
        [pscustomobject]@{ Algorithm; Hash; Format } -- Hash is lowercase hex.
        Format is the ready-made display parenthetical describing which form
        was recognised: 'plain hex, SHA256', 'grouped hex, SHA256', or
        'prefixed, sha256:'.
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

    $candidate = ConvertTo-VeriHashHexCandidate -Text $text
    if (-not $candidate) { return $null }

    # Canonical is deliberately still a string: the prefix-versus-length check
    # ('md5:' carrying 64 characters is not an MD5) lives in exactly one
    # function, and it stays there.
    $algo = ConvertTo-VeriHashAlgorithm -Hash $candidate.Canonical
    if (-not $algo) { return $null }

    if ($candidate.Prefix) {
        $hex    = ($candidate.Canonical -split ':', 2)[1]
        $format = "prefixed, $($candidate.Prefix):"
    } else {
        $hex    = $candidate.Canonical
        $format = if ($candidate.Grouped) { "grouped hex, $algo" } else { "plain hex, $algo" }
    }

    return [pscustomobject]@{
        Algorithm = $algo
        Hash      = $hex.ToLowerInvariant()
        Format    = $format
    }
}
