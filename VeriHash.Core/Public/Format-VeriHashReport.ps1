function Format-VeriHashReport {
    <#
    .SYNOPSIS
        Renders a VeriHash.Result to the host in the v1-compatible layout.
    .DESCRIPTION
        Pure renderer -- no I/O, no Get-Item, no Get-FileHash. All data must
        already be on the supplied result object. Hash is rendered lowercase
        per the v2 contract. Optional CompareTo and SidecarInfo extend the
        rendered report.
    .PARAMETER Result
        A VeriHash.Result object (pipeline-bound).
    .PARAMETER CompareTo
        Optional comparison hash record (e.g. clipboard) to render alongside.
    .PARAMETER SidecarInfo
        Optional sidecar-verification record to render alongside.
    .OUTPUTS
        None -- writes to the host stream.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [pscustomobject]$Result,

        [pscustomobject]$CompareTo,

        [pscustomobject]$SidecarInfo
    )
    process {
        $fileName = Split-Path -Leaf $Result.FilePath
        Write-Host ("File selected:    " + $fileName) -ForegroundColor Green
        Write-Host "---" -ForegroundColor Cyan
        $currentUTC = (Get-Date).ToUniversalTime()
        Write-Host ("Start UTC:    " + $currentUTC.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")) -ForegroundColor Cyan
        Write-Host "---" -ForegroundColor Cyan
        Write-Host "[Metadata]" -ForegroundColor White
        Write-Host ("File Path:    " + $Result.FilePath) -ForegroundColor Cyan
        $formattedBytes = $Result.Size.ToString("N0").Replace(",", " ")
        $sizeMb = "{0:N2}" -f ($Result.Size / 1MB)
        Write-Host ("File Size:    " + $sizeMb + " MB  (" + $formattedBytes + " bytes)") -ForegroundColor Yellow
        $createdStr  = if ($Result.CreationTime)  { $Result.CreationTime.ToString("yyyy-MM-dd HH:mm:ss UTC") } else { '<CREATED>' }
        $modifiedStr = if ($Result.LastWriteTime) { $Result.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss UTC") } else { '<MODIFIED>' }
        Write-Host ("Created:      " + $createdStr) -ForegroundColor Cyan
        Write-Host ("Modified:     " + $modifiedStr) -ForegroundColor Cyan
        Write-Host "---" -ForegroundColor Cyan
        Write-Host "[Hash]" -ForegroundColor White
        Write-Host ("Algorithm:    " + $Result.Algorithm) -ForegroundColor Cyan
        Write-Host ("Hash:         " + $Result.Hash) -ForegroundColor Cyan
        Write-Host ("Elapsed:      " + $Result.ElapsedMs + " ms") -ForegroundColor Cyan

        if ($CompareTo) {
            $match = ($Result.Hash -eq $CompareTo.Hash.ToLowerInvariant())
            $verdict = if ($match) { 'MATCH' } else { 'MISMATCH' }
            Write-Host ("Compare:      " + $verdict + " (" + $CompareTo.Algorithm + ")") -ForegroundColor Cyan
        }
        if ($SidecarInfo) {
            Write-Host ("Sidecar:      " + $SidecarInfo.Sidecar) -ForegroundColor Cyan
        }
    }
}
