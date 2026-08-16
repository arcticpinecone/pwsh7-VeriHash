function Format-VeriHashBanner {
    <#
    .SYNOPSIS
        Renders the verdict bar -- the one filled element on the screen.
    .DESCRIPTION
        Reversed video (coloured BACKGROUND, not coloured text) padded to the
        palette width, so the verdict is legible at a glance from across a
        room. Every string here is byte-locked by HANDOFF-console-spec.md.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [ValidateSet('Match', 'Mismatch', 'Unverified', 'Hashed')] [string]$State,
        [Parameter(Mandatory)] [string]$Algorithm,
        [Parameter(Mandatory)] [ValidateSet('clipboard', 'sidecar', 'unusable', 'none')] [string]$Source,
        [Parameter(Mandatory)] [hashtable]$Palette,

        # Why the comparator abstained. Required for -State Unverified, which
        # has nothing to say without it.
        [string]$Reason
    )
    $c    = $Palette.Color
    $g    = $Palette.Glyph
    $dash = $g.Dash

    switch ($State) {
        'Match' {
            $glyph = $g.Ok
            $body  = if ($Source -eq 'sidecar') { "MATCH $dash $Algorithm matches sidecar file" }
                     else                       { "MATCH $dash $Algorithm matches hash on clipboard" }
            $sgr   = $c.BannerMatch
        }
        'Mismatch' {
            $glyph = $g.Bad
            $body  = if ($Source -eq 'sidecar') { "MISMATCH $dash file does NOT match sidecar file" }
                     else                       { "MISMATCH $dash file does NOT match clipboard hash" }
            $sgr   = $c.BannerMismatch
        }
        'Unverified' {
            # Yellow marks 'your question went unanswered' -- a condition the
            # user can clear by re-copying the right hash or re-running with a
            # matching algorithm. It never marks 'answered, but weakly': a
            # signal that can never go green is wallpaper, and a matching MD5
            # is not uncertain. Weak-algorithm caveats belong on the checklist.
            $glyph = $g.Warn
            $body  = if ($Reason) { "UNVERIFIED $dash $Reason" }
                     else         { "UNVERIFIED $dash the hash you supplied could not be compared" }
            $sgr   = $c.BannerWarn
        }
        'Hashed' {
            $glyph = $g.Info
            $body  = "HASHED $dash no hash on clipboard to compare against"
            $sgr   = $c.BannerHashed
        }
        default {
            # Unreachable while the ValidateSet above and these arms agree.
            # Present so that widening the set without adding an arm fails
            # loudly: PowerShell does not error on an unmatched switch, it
            # falls through leaving $glyph/$body/$sgr null and renders a blank
            # bar that no test asserting 'does not throw' would ever catch.
            throw "Format-VeriHashBanner: unhandled state '$State'"
        }
    }

    $line = "  $glyph  $body"
    if ($line.Length -lt $Palette.Width) { $line = $line.PadRight($Palette.Width) }
    return "$sgr$line$($c.Reset)"
}
