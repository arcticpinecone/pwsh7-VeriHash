function Format-VeriHashBatchTally {
    <#
    .SYNOPSIS
        Renders the batch summary: a dim rule, a count line, then one line per file.
    .DESCRIPTION
        Public because VeriHash.HotPath's Invoke-VeriHashBatch calls it across a
        module boundary -- VeriHash.Core owns all rendering, VeriHash.HotPath owns
        orchestration.

        Counts are colour-coded: matched green, mismatch red only when non-zero
        (a zero mismatch count in red would be alarming and wrong), missing dim.
    .PARAMETER Results
        VeriHash.HotPathResult objects. Each needs FilePath, MatchResult
        (matched|mismatch|missing), and Signature.
    .OUTPUTS
        None -- writes to the host stream.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject[]]$Results
    )
    $p = Get-VeriHashPalette
    $c = $p.Color
    $g = $p.Glyph

    $matched    = @($Results | Where-Object { $_.MatchResult -eq 'matched'    }).Count
    $mismatch   = @($Results | Where-Object { $_.MatchResult -eq 'mismatch'   }).Count
    $missing    = @($Results | Where-Object { $_.MatchResult -eq 'missing'    }).Count
    $unverified = @($Results | Where-Object { $_.MatchResult -eq 'unverified' }).Count

    Write-Host ("{0}{1}{2}" -f $c.Dim, ($g.Rule * $p.Width), $c.Reset)

    $mismatchColor = if ($mismatch -gt 0) { $c.Red } else { $c.Dim }
    $summary = "{0}batch of {1} {2} {3}{4} matched{0} {2} {5}{6} mismatch{0} {2} {7} missing" -f `
        $c.Dim, $Results.Count, $g.Sep, $c.Green, $matched, $mismatchColor, $mismatch, $missing
    # Appended only when non-zero: a permanent '0 unverified' is wallpaper, and
    # a signal that is always present stops being read.
    if ($unverified -gt 0) {
        $summary += "{0} {1} {2}{3} unverified" -f $c.Dim, $g.Sep, $c.Yellow, $unverified
    }
    Write-Host ($summary + $c.Reset)

    # Column width: the spec's example pads to 18 + 1 space; widen for longer names.
    $nameWidth = 18
    foreach ($r in $Results) {
        $len = (Split-Path -Leaf $r.FilePath).Length
        if ($len -gt $nameWidth) { $nameWidth = $len }
    }

    foreach ($r in $Results) {
        switch ($r.MatchResult) {
            'matched'    { $glyph = "$($c.Green)$($g.Ok)$($c.Reset)";   $status = 'match'      }
            'mismatch'   { $glyph = "$($c.Red)$($g.Bad)$($c.Reset)";    $status = 'mismatch'   }
            # Without this arm an unverified file falls to default and prints
            # 'missing' -- a file that exists and hashed fine, reported absent.
            'unverified' { $glyph = "$($c.Yellow)$($g.Warn)$($c.Reset)"; $status = 'unverified' }
            default      { $glyph = "$($c.Dim)$($g.None)$($c.Reset)";   $status = 'missing'    }
        }
        if ($r.MatchResult -eq 'matched' -and $r.Signature -eq 'valid') {
            $status = "match $($g.Sep) signed"
        }
        $name = (Split-Path -Leaf $r.FilePath).PadRight($nameWidth)
        Write-Host (" {0} {1} {2}{3}{4}" -f $glyph, $name, $c.Dim, $status, $c.Reset)
    }
}
