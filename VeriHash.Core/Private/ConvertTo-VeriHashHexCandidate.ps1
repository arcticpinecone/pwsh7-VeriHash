function ConvertTo-VeriHashHexCandidate {
    <#
    .SYNOPSIS
        Normalises pasted text into one canonical hash string, or $null.
    .DESCRIPTION
        The same digest reaches the clipboard a dozen ways: bare hex, a vendor
        page's 'SHA-256: <hex>' label, a sha256sum line's '<hex> *name',
        certutil's 2-character groups, and VeriHash's own 8-character display
        groups. They are all the same question. Only the bare form parsed, so
        Phase 7 shipped a report that PRINTS grouped hex without teaching
        anything to READ it -- copying VeriHash's own output back into VeriHash
        reported an empty clipboard.

        Whitespace is joined ONLY when the tokens read as one digest split into
        uniform groups. Two separate 64-hex digests sitting on the clipboard
        would otherwise concatenate to 128 characters and infer as a single
        SHA512: a comparator assembled out of two unrelated hashes, which the
        file would then be judged against. That is the fail-green failure this
        phase exists to prevent, and it is worth refusing a few legitimate
        pastes to keep it impossible.

        A token that is ITSELF a full digest length is the tell. Groups are
        fragments -- 2, 4, or 8 characters -- so a 32-character token means the
        clipboard holds a list, not a grouping, and the text is refused rather
        than joined.
    .PARAMETER Text
        Raw clipboard text, already joined across lines by the caller.
    .OUTPUTS
        [pscustomobject]@{ Canonical; Prefix; Grouped } or $null.

        Canonical is '<hex>' or '<algo>:<hex>' -- shaped so it can be handed
        straight to ConvertTo-VeriHashAlgorithm, which keeps sole ownership of
        the prefix-versus-length validation. Restating that rule here is how
        the comparator bug in 09-01 happened, one call site at a time.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    $t = $Text.Trim()
    if (-not $t) { return $null }

    # Vendor label, e.g. 'SHA-256: abc...', 'md5 = abc...'. The hyphen is how
    # humans write it; the colon-with-no-space form is the only one that parsed
    # before. Normalised to the bare token so the display string stays stable.
    $prefix = $null
    if ($t -match '^(?<algo>md5|sha-?1|sha-?256|sha-?512)\s*[:=]\s*(?<rest>.+)$') {
        $prefix = ($matches.algo -replace '-', '').ToLowerInvariant()
        $t      = $matches.rest.Trim()
    }

    $tokens = @($t -split '\s+' | Where-Object { $_ })
    if ($tokens.Count -eq 0) { return $null }

    # Stop at the first non-hex token rather than rejecting the whole paste:
    # a sha256sum line is '<hex> *filename', and the filename is not a reason
    # to refuse the hash in front of it.
    $hex = [System.Collections.Generic.List[string]]::new()
    foreach ($tok in $tokens) {
        if ($tok -notmatch '^[A-Fa-f0-9]+$') { break }
        $hex.Add($tok)
    }
    if ($hex.Count -eq 0) { return $null }

    $grouped = $hex.Count -gt 1
    if ($grouped) {
        $size = $hex[0].Length

        # A full-digest-length token means this is a list of hashes, not one
        # hash in groups. Refuse; never concatenate.
        if ((Get-VeriHashHexLength -Algorithm 'MD5') -le $size) { return $null }

        # Every group but the last is exactly $size; the last may be shorter
        # because a digest length need not divide evenly by the group size.
        for ($i = 1; $i -lt $hex.Count - 1; $i++) {
            if ($hex[$i].Length -ne $size) { return $null }
        }
        if ($hex[$hex.Count - 1].Length -gt $size) { return $null }
    }

    $joined = -join $hex
    return [pscustomobject]@{
        Canonical = if ($prefix) { "${prefix}:$joined" } else { $joined }
        Prefix    = $prefix
        Grouped   = $grouped
    }
}
