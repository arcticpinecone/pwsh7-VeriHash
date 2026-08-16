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

        Or [pscustomobject]@{ Algorithm = $null; Hash = $null; Format = $null;
        Detail } for hex that is digest-shaped but of a length VeriHash does not
        implement (CMP-10). Resolve-VeriHashComparator turns this into an
        'unusable' comparator and the checklist renders Detail in the clipboard
        row. Algorithm and Hash are null so nothing can compare against it.

        Or $null when the clipboard holds nothing hash-shaped at all.
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
    if (-not $algo) {
        # Hash-shaped, but not a digest length VeriHash implements. Returning
        # $null here would render as 'nothing recognizable', telling a user who
        # deliberately copied a vendor's SHA-384 that their clipboard was empty
        # -- and leaving them to conclude the file was fine because nothing
        # contradicted it. Instead this returns an UNUSABLE record: no
        # Algorithm and no Hash, so no comparison can ever be built from it,
        # plus a Detail the clipboard row renders verbatim (CMP-10).
        #
        # Floored at the shortest digest VeriHash knows. Below that, 'deadbeef'
        # and every other short hex word would be announced as an unsupported
        # digest, and a row that cries wolf on ordinary clipboards is worse
        # than one that stays quiet.
        $minPlausible = Get-VeriHashHexLength -Algorithm 'MD5'
        if (-not $candidate.Prefix -and $candidate.Canonical.Length -ge $minPlausible) {
            $len = $candidate.Canonical.Length

            # Lengths a vendor plausibly published. Naming the algorithm is the
            # difference between 'this did not work' and 'this is a SHA-384,
            # go find the SHA-256 on the same page'.
            $likely = @{ 56 = 'SHA-224'; 96 = 'SHA-384' }[$len]

            $detail = if ($likely) {
                "clipboard holds $len hex characters (likely $likely); VeriHash does not support it"
            } else {
                "clipboard holds $len hex characters; VeriHash does not support that digest length"
            }

            return [pscustomobject]@{
                Algorithm = $null
                Hash      = $null
                Format    = $null
                Detail    = $detail
            }
        }
        return $null
    }

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
