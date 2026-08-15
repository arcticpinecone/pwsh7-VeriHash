function Get-VeriHashPalette {
    <#
    .SYNOPSIS
        Single source of truth for console colour, glyphs, and bar width.
    .DESCRIPTION
        Returns SGR escape strings for the truecolor palette pinned in
        HANDOFF-console-spec.md. Degrades in three independent directions, so
        callers can concatenate palette values unconditionally and never branch
        on terminal capability themselves:

          - Colour off  (NO_COLOR / VERIHASH_NO_COLOR): every Color value
            becomes ''.
          - Truecolor off (VERIHASH_NO_TRUECOLOR, or a TERM that cannot do
            24-bit): the same keys carry 16-colour SGR codes instead.
          - Unicode off (console code page is not UTF-8): Glyph values fall
            back to ASCII.

        Width is min(76, WindowWidth - 4), floored at 40. [Console]::WindowWidth
        throws when no console is attached (CI, redirected stdout), so the read
        is guarded.
    .OUTPUTS
        System.Collections.Hashtable
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $e = [char]27

    $useColor = -not ($env:NO_COLOR -or $env:VERIHASH_NO_COLOR)

    # Truecolor is the safe assumption on Windows Terminal, VS Code, and every
    # modern *nix emulator -- none of which advertise it reliably, so absence of
    # a signal is NOT evidence against. Only opt out on an explicit request or a
    # TERM known to be limited.
    $useTruecolor = $true
    if ($env:VERIHASH_NO_TRUECOLOR)       { $useTruecolor = $false }
    if ($env:TERM -in @('dumb', 'linux')) { $useTruecolor = $false }

    $useUnicode = $false
    try { $useUnicode = ([Console]::OutputEncoding.CodePage -eq 65001) } catch { $useUnicode = $false }

    $width = 76
    try {
        $w = [Console]::WindowWidth
        if ($w -gt 0) { $width = [Math]::Min(76, $w - 4) }
    } catch {
        $width = 76
    }
    if ($width -lt 40) { $width = 40 }

    $color = if ($useTruecolor) {
        [ordered]@{
            Reset          = "$e[0m"
            Dim            = "$e[38;2;110;118;129m"
            Faint          = "$e[38;2;72;79;88m"
            Green          = "$e[38;2;63;222;134m"
            Red            = "$e[38;2;229;83;75m"
            Yellow         = "$e[38;2;210;153;34m"
            Blue           = "$e[38;2;121;184;255m"
            BannerMatch    = "$e[48;2;38;200;134m$e[38;2;8;23;13m"
            BannerMismatch = "$e[48;2;211;69;49m$e[38;2;255;255;255m"
            BannerHashed   = "$e[48;2;48;54;61m"
            Diff           = "$e[48;2;92;30;25m$e[38;2;255;160;150m"
        }
    } else {
        [ordered]@{
            Reset          = "$e[0m"
            Dim            = "$e[90m"        # bright black
            Faint          = "$e[90m"
            Green          = "$e[92m"
            Red            = "$e[91m"
            Yellow         = "$e[93m"
            Blue           = "$e[94m"
            BannerMatch    = "$e[42m$e[30m"  # green bg, black fg
            BannerMismatch = "$e[41m$e[97m"  # red bg, white fg
            BannerHashed   = "$e[100m"       # bright black bg
            Diff           = "$e[41m$e[97m"
        }
    }
    if (-not $useColor) {
        foreach ($k in @($color.Keys)) { $color[$k] = '' }
    }

    $glyph = if ($useUnicode) {
        [ordered]@{ Ok = '✓'; Bad = '✗'; Info = '●'; Warn = '!'; None = '−'; Sep = '·'; Dash = '—'; Rule = '─' }
    } else {
        [ordered]@{ Ok = '+'; Bad = 'x'; Info = '*'; Warn = '!'; None = '-'; Sep = '-'; Dash = '--'; Rule = '-' }
    }

    return @{
        Color        = $color
        Glyph        = $glyph
        Width        = $width
        UseColor     = $useColor
        UseTruecolor = $useTruecolor
        UseUnicode   = $useUnicode
    }
}
