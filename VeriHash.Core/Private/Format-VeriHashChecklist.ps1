function Format-VeriHashChecklist {
    <#
    .SYNOPSIS
        Renders the four-row label/value grid: clipboard, sidecar, signature, elapsed.
    .DESCRIPTION
        One glyph plus one clause per row. Labels are padded to 10 characters
        with a 2-space gutter, so every value starts at column 12. Returns
        exactly four strings, always in the same order -- a stable shape is
        what makes the block scannable.
    .PARAMETER ElapsedMs
        Time spent hashing -- the Get-FileHash call alone.
    .PARAMETER TotalMs
        Total wall time for the whole operation, when the caller knows it. Supplying
        it splits the elapsed row into 'N ms total' and 'N ms hashing', because
        hashing is only part of the job and a lone hash figure reads as the cost of
        the entire run. Omit it and the row keeps its hash-only shape.
    .PARAMETER ClipboardMatch
        $true / $false when a clipboard hash was present and compared,
        $null when there was nothing to compare against.
    .PARAMETER ComparatorSource
        Resolve-VeriHashComparator's Source. Only 'unusable' changes rendering
        here -- it selects the clipboard row's fourth shape, which no other
        parameter can distinguish from an empty clipboard.
    .PARAMETER ComparatorReason
        Resolve-VeriHashComparator's Reason, used as the clipboard row's clause
        when the record carries no display Format of its own (an unsupported
        hash length rather than a wrong algorithm).
    .OUTPUTS
        System.String[]
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)] [hashtable]$Palette,
        [Parameter(Mandatory)] [long]$Bytes,
        [Parameter(Mandatory)] [int]$ElapsedMs,
        [nullable[int]]$TotalMs,
        [pscustomobject]$CompareTo,
        [pscustomobject]$SidecarInfo,
        [pscustomobject]$Signature,
        [nullable[bool]]$ClipboardMatch,
        [string]$ComparatorSource,
        [string]$ComparatorReason
    )
    $c = $Palette.Color
    $g = $Palette.Glyph
    $d = $g.Dash

    # 10-char label + 2-space gutter => values align at column 12.
    function Row { param($Label, $Value) return "$($c.Dim)$('{0,-10}' -f $Label)$($c.Reset)  $Value" }

    # --- clipboard ---
    # The weakness belongs to the vendor's choice of algorithm, not to the
    # verification, so it rides the clipboard row on BOTH match and mismatch and
    # never reaches the banner. A green MATCH stays green: the comparison is not
    # uncertain, VeriHash knows the answer. A user whose vendors publish MD5
    # would otherwise see a permanent yellow they can never clear, and a signal
    # that never goes green is wallpaper.
    $weakNote = if ($CompareTo -and $CompareTo.Algorithm -in @('MD5', 'SHA1')) {
        " $d weak; prefer SHA256 if the vendor lists one"
    } else {
        ''
    }

    # Four shapes, not three. 'Unusable' is selected on ComparatorSource rather
    # than on ClipboardMatch, because $null ClipboardMatch means 'not compared'
    # and cannot distinguish 'nothing was on the clipboard' from 'something was
    # and I could not use it'. Telling a user who deliberately copied a hash
    # that their clipboard was empty is its own small lie.
    $clipRow = if ($ComparatorSource -eq 'unusable') {
        $clause = if ($CompareTo -and $CompareTo.Format) {
            "not compared ($($CompareTo.Format)) $d different algorithm than this run"
        } elseif ($ComparatorReason) {
            $ComparatorReason
        } else {
            "not compared $d could not be used"
        }
        "$($c.Yellow)$($g.Warn)$($c.Reset) $clause"
    } elseif ($null -eq $CompareTo) {
        "$($c.Dim)$($g.None) nothing recognizable $d copy the vendor's hash and re-run$($c.Reset)"
    } elseif ($ClipboardMatch) {
        "$($c.Green)$($g.Ok)$($c.Reset) match ($($CompareTo.Format)$weakNote)"
    } else {
        "$($c.Red)$($g.Bad)$($c.Reset) mismatch ($($CompareTo.Format)$weakNote)"
    }

    # --- sidecar ---
    $sideStatus = if ($SidecarInfo) { $SidecarInfo.SidecarStatus } else { $null }
    $sideName   = if ($SidecarInfo) { $SidecarInfo.SidecarName }   else { $null }
    $sideRow = switch ($sideStatus) {
        'matched'  { "$($c.Green)$($g.Ok)$($c.Reset) match $d $sideName" }
        'created'  { "$($c.Green)$($g.Ok)$($c.Reset) created $d $sideName" }
        'updated'  { "$($c.Green)$($g.Ok)$($c.Reset) updated $d $sideName" }
        'mismatch' { "$($c.Red)$($g.Bad)$($c.Reset) sidecar mismatch $d $sideName" }
        'error'    { "$($c.Red)$($g.Bad)$($c.Reset) unreadable $d $sideName" }
        # 'none' means a write was deliberately SUPPRESSED because the file failed
        # verification -- that is worth explaining. An absent record just means
        # nothing is known, and claiming a mismatch there would be a lie.
        'none'     { "$($c.Dim)$($g.None) none found $($g.Sep) not written on mismatch$($c.Reset)" }
        default    { "$($c.Dim)$($g.None) none found$($c.Reset)" }
    }

    # --- signature ---
    $sigStatus = if ($Signature) { $Signature.Status } else { $null }
    $sigRow = switch ($sigStatus) {
        'valid' {
            if ($Signature.Signer) { "$($c.Green)$($g.Ok)$($c.Reset) valid $d $($Signature.Signer)" }
            else                   { "$($c.Green)$($g.Ok)$($c.Reset) valid" }
        }
        'invalid'  { "$($c.Red)$($g.Bad)$($c.Reset) invalid $d $($Signature.Reason)" }
        'unsigned' { "$($c.Yellow)$($g.Warn)$($c.Reset) unsigned" }
        'skipped'  { "$($c.Dim)$($g.None) skipped ($($Signature.Reason))$($c.Reset)" }
        'error'    { "$($c.Red)$($g.Bad)$($c.Reset) error $d $($Signature.Reason)" }
        default    { "$($c.Dim)$($g.None) not checked$($c.Reset)" }
    }

    # --- elapsed ---
    # The rate stays divided by hashing time in both shapes: it is a hash-rate claim
    # sitting next to the hashing figure, not effective end-to-end throughput.
    $size = Format-VeriHashByteSize -Bytes $Bytes
    $rate = Format-VeriHashThroughput -Bytes $Bytes -ElapsedMs $ElapsedMs
    $timing = if ($null -ne $TotalMs) {
        "$TotalMs ms total $($g.Sep) $ElapsedMs ms hashing"
    } else {
        "$ElapsedMs ms"
    }
    $elapsedRow = "$($c.Dim)$timing $($g.Sep) $size $($g.Sep) $rate$($c.Reset)"

    return @(
        (Row 'clipboard' $clipRow)
        (Row 'sidecar'   $sideRow)
        (Row 'signature' $sigRow)
        (Row 'elapsed'   $elapsedRow)
    )
}
