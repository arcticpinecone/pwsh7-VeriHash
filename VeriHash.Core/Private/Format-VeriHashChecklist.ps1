function Format-VeriHashChecklist {
    <#
    .SYNOPSIS
        Renders the four-row label/value grid: clipboard, sidecar, signature, elapsed.
    .DESCRIPTION
        One glyph plus one clause per row. Labels are padded to 10 characters
        with a 2-space gutter, so every value starts at column 12. Returns
        exactly four strings, always in the same order -- a stable shape is
        what makes the block scannable.
    .PARAMETER ClipboardMatch
        $true / $false when a clipboard hash was present and compared,
        $null when there was nothing to compare against.
    .OUTPUTS
        System.String[]
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)] [hashtable]$Palette,
        [Parameter(Mandatory)] [long]$Bytes,
        [Parameter(Mandatory)] [int]$ElapsedMs,
        [pscustomobject]$CompareTo,
        [pscustomobject]$SidecarInfo,
        [pscustomobject]$Signature,
        [nullable[bool]]$ClipboardMatch
    )
    $c = $Palette.Color
    $g = $Palette.Glyph
    $d = $g.Dash

    # 10-char label + 2-space gutter => values align at column 12.
    function Row { param($Label, $Value) return "$($c.Dim)$('{0,-10}' -f $Label)$($c.Reset)  $Value" }

    # --- clipboard ---
    $clipRow = if ($null -eq $CompareTo) {
        "$($c.Dim)$($g.None) nothing recognizable $d copy the vendor's hash and re-run$($c.Reset)"
    } elseif ($ClipboardMatch) {
        "$($c.Green)$($g.Ok)$($c.Reset) match ($($CompareTo.Format))"
    } else {
        "$($c.Red)$($g.Bad)$($c.Reset) mismatch ($($CompareTo.Format))"
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
    $size = Format-VeriHashByteSize -Bytes $Bytes
    $rate = Format-VeriHashThroughput -Bytes $Bytes -ElapsedMs $ElapsedMs
    $elapsedRow = "$($c.Dim)$ElapsedMs ms $($g.Sep) $size $($g.Sep) $rate$($c.Reset)"

    return @(
        (Row 'clipboard' $clipRow)
        (Row 'sidecar'   $sideRow)
        (Row 'signature' $sigRow)
        (Row 'elapsed'   $elapsedRow)
    )
}
