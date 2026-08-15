function Format-VeriHashReport {
    <#
    .SYNOPSIS
        Renders a VeriHash.Result to the host in the v2.1 console layout.
    .DESCRIPTION
        Pure renderer -- no I/O, no Get-Item, no Get-FileHash. Every fact must
        already be on the objects passed in. Composes the private block
        renderers in a fixed order: header, verdict banner, hash comparison,
        checklist grid, footer.

        The comparator is the clipboard when one is present, otherwise the
        sidecar, otherwise nothing (the HASHED state).
    .PARAMETER Result
        A VeriHash.Result object (pipeline-bound).
    .PARAMETER CompareTo
        Clipboard hash record: @{ Algorithm; Hash; Format }.
    .PARAMETER SidecarInfo
        Sidecar record: @{ SidecarStatus; SidecarName; Algorithm; ExpectedHash }.
    .PARAMETER Signature
        Signature record: @{ Status; Reason; Signer }.
    .PARAMETER TotalMs
        Total wall time for the operation, when the caller can supply it. Forwarded
        to the checklist so the elapsed row names both scopes instead of showing a
        hash time that reads as the whole run's cost.
    .PARAMETER Compact
        Batch mode. Emits header, banner, and checklist only -- the hash
        comparison block is kept only for mismatches, and the footer and
        advisory are suppressed (the batch tally carries the summary instead).
    .OUTPUTS
        None -- writes to the host stream.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [pscustomobject]$Result,

        [pscustomobject]$CompareTo,
        [pscustomobject]$SidecarInfo,
        [pscustomobject]$Signature,
        [nullable[int]]$TotalMs,
        [switch]$Compact
    )
    process {
        $p = Get-VeriHashPalette
        $c = $p.Color
        $g = $p.Glyph

        # --- resolve the comparator -------------------------------------------
        # The clipboard wins when present -- it is what the user just deliberately
        # copied. A sidecar is the fallback comparator, not a competitor.
        $expectedHash   = $null
        $comparatorName = 'none'
        if ($CompareTo -and $CompareTo.Hash) {
            $expectedHash   = ([string]$CompareTo.Hash).ToLowerInvariant()
            $comparatorName = 'clipboard'
        } elseif ($SidecarInfo -and $SidecarInfo.ExpectedHash -and
                  $SidecarInfo.Algorithm -eq $Result.Algorithm) {
            # Algorithm guard: Test-VeriHashSidecar prefers .sha512 > .sha256 > .md5
            # and hashes with WHICHEVER it found, while the hot path hashes with the
            # requested algorithm. Comparing a SHA512 sidecar against a SHA256
            # compute would report a false MISMATCH on a perfectly good file.
            $expectedHash   = ([string]$SidecarInfo.ExpectedHash).ToLowerInvariant()
            $comparatorName = 'sidecar'
        }

        $clipboardMatch = $null
        if ($comparatorName -eq 'clipboard') { $clipboardMatch = ($Result.Hash -eq $expectedHash) }

        $state = if ($comparatorName -eq 'none') { 'Hashed' }
                 elseif ($Result.Hash -eq $expectedHash) { 'Match' }
                 else { 'Mismatch' }

        # --- 1. header ---------------------------------------------------------
        $fileName = Split-Path -Leaf $Result.FilePath
        $size     = Format-VeriHashByteSize -Bytes ([long]$Result.Size)
        Write-Host ("{0}VeriHash 2.0 {1} {2} {1} {3}{4}{0} ({5}){3}" -f `
            $c.Dim, $g.Sep, $Result.Algorithm, $c.Reset, $fileName, $size)

        # --- 2. verdict banner (blank line above and below) --------------------
        Write-Host ''
        Write-Host (Format-VeriHashBanner -State $state -Algorithm $Result.Algorithm -Source $comparatorName -Palette $p)
        Write-Host ''

        # --- 3. hash comparison block ------------------------------------------
        $showHashBlock = (-not $Compact) -or ($state -eq 'Mismatch')
        if ($showHashBlock) {
            if ($expectedHash) {
                $diffIndex     = Get-VeriHashDiffIndex -Expected $expectedHash -Actual $Result.Hash
                $diffFromGroup = if ($diffIndex -lt 0) { -1 } else { [int][Math]::Floor($diffIndex / 8) }

                Write-Host ("{0}expected  {1}{2}" -f $c.Dim, $comparatorName, $c.Reset)
                foreach ($l in (Format-VeriHashHexGroups -Hash $expectedHash -Palette $p -DiffFromGroup $diffFromGroup)) {
                    Write-Host $l
                }
                Write-Host ("{0}computed  {1} ms{2}" -f $c.Dim, $Result.ElapsedMs, $c.Reset)
                foreach ($l in (Format-VeriHashHexGroups -Hash $Result.Hash -Palette $p -DiffFromGroup $diffFromGroup)) {
                    Write-Host $l
                }
                if ($diffIndex -ge 0) {
                    Write-Host ("{0}first {1} of {2} characters agree {3} divergence starts at character {4}{5}" -f `
                        $c.Dim, $diffIndex, $Result.Hash.Length, $g.Dash, ($diffIndex + 1), $c.Reset)
                }
            } else {
                Write-Host ("{0}{1}{2}" -f $c.Dim, $Result.Algorithm.ToLowerInvariant(), $c.Reset)
                foreach ($l in (Format-VeriHashHexGroups -Hash $Result.Hash -Palette $p)) {
                    Write-Host $l
                }
            }
            Write-Host ''
        }

        # --- 4. checklist grid --------------------------------------------------
        $checklistSplat = @{
            Palette   = $p
            Bytes     = [long]$Result.Size
            ElapsedMs = [int]$Result.ElapsedMs
        }
        if ($null -ne $TotalMs)        { $checklistSplat['TotalMs']        = $TotalMs }
        if ($CompareTo)                { $checklistSplat['CompareTo']      = $CompareTo }
        if ($SidecarInfo)              { $checklistSplat['SidecarInfo']    = $SidecarInfo }
        if ($Signature)                { $checklistSplat['Signature']      = $Signature }
        if ($null -ne $clipboardMatch) { $checklistSplat['ClipboardMatch'] = $clipboardMatch }
        foreach ($row in (Format-VeriHashChecklist @checklistSplat)) { Write-Host $row }

        if ($Compact) { return }

        Write-Host ''

        # --- mismatch advisory (before the footer) ------------------------------
        if ($state -eq 'Mismatch') {
            $rule = $g.Rule * $p.Width
            Write-Host ("{0}{1}{2}" -f $c.Red, $rule, $c.Reset)
            Write-Host ("{0}Do not run this file. Re-download it, then verify again.{1}" -f $c.Red, $c.Reset)
            Write-Host ("{0}{1}{2}" -f $c.Red, $rule, $c.Reset)
            Write-Host ''
        }

        # --- 5. footer ----------------------------------------------------------
        $modified = if ($Result.LastWriteTime) {
            ([datetime]$Result.LastWriteTime).ToUniversalTime().ToString('yyyy-MM-dd HH:mm', [cultureinfo]::InvariantCulture)
        } else { '<unknown>' }
        Write-Host ("{0}{1} {2} modified {3} UTC{4}" -f $c.Dim, $Result.FilePath, $g.Sep, $modified, $c.Reset)
        Write-Host ''
    }
}
