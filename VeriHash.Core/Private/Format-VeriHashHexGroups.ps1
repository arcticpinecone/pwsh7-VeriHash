function Format-VeriHashHexGroups {
    <#
    .SYNOPSIS
        Renders a hex hash as space-separated 8-character groups, wrapped to width.
    .DESCRIPTION
        Groups are the unit of both wrapping and diff highlighting, so the
        expected and computed lines always break at identical points and the
        two hashes read as aligned columns. Returns one string per display
        line with ANSI already embedded.
    .PARAMETER DiffFromGroup
        Zero-based group index from which to apply the mismatch colours.
        -1 (default) renders every group in the normal blue.
    .OUTPUTS
        System.String[]
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)] [string]$Hash,
        [Parameter(Mandatory)] [hashtable]$Palette,
        [int]$DiffFromGroup = -1
    )
    $c = $Palette.Color

    $groups = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $Hash.Length; $i += 8) {
        $groups.Add($Hash.Substring($i, [Math]::Min(8, $Hash.Length - $i)))
    }

    # Each rendered group costs 8 chars + 1 separating space (the last one on a
    # line has no trailing space, hence the +1 on the available width).
    $perLine = [Math]::Max(1, [Math]::Floor(($Palette.Width + 1) / 9))

    $lines = [System.Collections.Generic.List[string]]::new()
    for ($start = 0; $start -lt $groups.Count; $start += $perLine) {
        $sb  = [System.Text.StringBuilder]::new()
        $end = [Math]::Min($start + $perLine, $groups.Count)
        for ($g = $start; $g -lt $end; $g++) {
            if ($g -gt $start) { [void]$sb.Append(' ') }
            $sgr = if ($DiffFromGroup -ge 0 -and $g -ge $DiffFromGroup) { $c.Diff } else { $c.Blue }
            [void]$sb.Append($sgr).Append($groups[$g]).Append($c.Reset)
        }
        $lines.Add($sb.ToString())
    }
    return $lines.ToArray()
}
