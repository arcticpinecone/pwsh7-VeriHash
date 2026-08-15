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
        [Parameter(Mandatory)] [ValidateSet('Match', 'Mismatch', 'Hashed')] [string]$State,
        [Parameter(Mandatory)] [string]$Algorithm,
        [Parameter(Mandatory)] [ValidateSet('clipboard', 'sidecar', 'none')] [string]$Source,
        [Parameter(Mandatory)] [hashtable]$Palette
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
        'Hashed' {
            $glyph = $g.Info
            $body  = "HASHED $dash no hash on clipboard to compare against"
            $sgr   = $c.BannerHashed
        }
    }

    $line = "  $glyph  $body"
    if ($line.Length -lt $Palette.Width) { $line = $line.PadRight($Palette.Width) }
    return "$sgr$line$($c.Reset)"
}
