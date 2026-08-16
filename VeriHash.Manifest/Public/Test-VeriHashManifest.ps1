function Test-VeriHashManifest {
    <#
    .SYNOPSIS
        Verifies a GNU sha256sum-compatible manifest file.
    .DESCRIPTION
        Parses each manifest line with strict regex (MANIFEST-04), resolves
        paths relative to the manifest directory (MANIFEST-05), rejects
        path traversal (D-13), and returns a VeriHash.ManifestVerifyResult
        with machine-readable exit code (MANIFEST-06).
        Structured output only (D-17).

        Exit code precedence (MANIFEST-06 + D-11):
        3 = parse error or path traversal (highest priority)
        1 = at least one hash mismatch
        2 = at least one missing file (only when no mismatches)
        0 = all pass
    .PARAMETER Path
        Path to the manifest file to verify.
    .OUTPUTS
        VeriHash.ManifestVerifyResult
    .EXAMPLE
        Test-VeriHashManifest -Path '2026-04-18T143022Z_manifest.sha256'
    #>
    [CmdletBinding()]
    [OutputType('VeriHash.ManifestVerifyResult')]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedManifest = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    $manifestDir = Split-Path -Parent $resolvedManifest

    $rawLines = [System.IO.File]::ReadAllLines($resolvedManifest)

    $entries = [System.Collections.Generic.List[object]]::new()
    $hasParseError = $false
    $hasMismatch   = $false
    $hasMissing    = $false

    foreach ($rawLine in $rawLines) {
        $parsed = Read-ManifestLine -Line $rawLine
        if ($null -eq $parsed) { continue }

        # Malformed line
        if ($parsed.ContainsKey('Malformed') -and $parsed.Malformed) {
            $hasParseError = $true
            $entries.Add([pscustomobject]@{
                PSTypeName   = 'VeriHash.ManifestEntry'
                Path         = $parsed.RawLine
                ExpectedHash = $null
                ActualHash   = $null
                Status       = 'parse-error'
            })
            continue
        }

        $entryFilename = $parsed.Filename

        # ── Path traversal guard (D-13, MANIFEST-05) ────────────────
        $isSafe = Test-PathTraversal -EntryPath $entryFilename -BaseDirectory $manifestDir
        if (-not $isSafe) {
            $hasParseError = $true
            $entries.Add([pscustomobject]@{
                PSTypeName   = 'VeriHash.ManifestEntry'
                Path         = $entryFilename
                ExpectedHash = $parsed.Hash
                ActualHash   = $null
                Status       = 'traversal-rejected'
            })
            continue
        }

        # ── Resolve file path relative to manifest directory ─────────
        $resolvedPath = [System.IO.Path]::GetFullPath(
            [System.IO.Path]::Combine($manifestDir, $entryFilename)
        )

        # ── Hash and compare ─────────────────────────────────────────
        if (-not (Test-Path -LiteralPath $resolvedPath)) {
            $hasMissing = $true
            $entries.Add([pscustomobject]@{
                PSTypeName   = 'VeriHash.ManifestEntry'
                Path         = $entryFilename
                ExpectedHash = $parsed.Hash
                ActualHash   = $null
                Status       = 'missing'
            })
            continue
        }

        try {
            $result = Get-VeriHashResult -Path $resolvedPath -Algorithm SHA256
            $actualHash = $result.Hash
        } catch {
            $hasMissing = $true
            $entries.Add([pscustomobject]@{
                PSTypeName   = 'VeriHash.ManifestEntry'
                Path         = $entryFilename
                ExpectedHash = $parsed.Hash
                ActualHash   = $null
                Status       = 'missing'
            })
            continue
        }

        if ($actualHash -eq $parsed.Hash) {
            $entries.Add([pscustomobject]@{
                PSTypeName   = 'VeriHash.ManifestEntry'
                Path         = $entryFilename
                ExpectedHash = $parsed.Hash
                ActualHash   = $actualHash
                Status       = 'pass'
            })
        } else {
            $hasMismatch = $true
            $entries.Add([pscustomobject]@{
                PSTypeName   = 'VeriHash.ManifestEntry'
                Path         = $entryFilename
                ExpectedHash = $parsed.Hash
                ActualHash   = $actualHash
                Status       = 'mismatch'
            })
        }
    }

    # ── Compute exit code with correct precedence (MANIFEST-06) ──────
    $exitCode = if ($hasParseError) { 3 }
                elseif ($hasMismatch) { 1 }
                elseif ($hasMissing) { 2 }
                else { 0 }

    # ── Build summary counts ─────────────────────────────────────────
    # Counted by walking the entries once and incrementing exactly one bucket
    # each, so Total and the buckets cannot drift apart. Deriving them
    # independently is what let 'parse-error' and 'traversal-rejected' sit in
    # Total but in no bucket, making the rendered line fail to add up.
    #
    # An unrecognised status throws rather than being absorbed: a status nobody
    # counts is a bug in this function, and a silent fallback here is exactly
    # the failure class CMP-14 exists to prevent.
    $statusCounts = [ordered]@{
        'pass'               = 0
        'mismatch'           = 0
        'missing'            = 0
        'parse-error'        = 0
        'traversal-rejected' = 0
    }
    foreach ($entry in $entries) {
        if (-not $statusCounts.Contains($entry.Status)) {
            throw "Test-VeriHashManifest produced entry status '$($entry.Status)', which maps to no summary bucket. Every status must be counted."
        }
        $statusCounts[$entry.Status]++
    }

    # parse-error and traversal-rejected share one bucket but stay out of
    # Failed: a rejection is not a hash disagreement. A traversal entry tried to
    # escape the manifest directory, and folding it into a mismatch count would
    # disguise a security rejection as a corrupted file.
    $rejectedCount = $statusCounts['parse-error'] + $statusCounts['traversal-rejected']

    return [pscustomobject]@{
        PSTypeName   = 'VeriHash.ManifestVerifyResult'
        ManifestPath = $resolvedManifest
        Entries      = $entries.ToArray()
        ExitCode     = $exitCode
        Summary      = [pscustomobject]@{
            Total    = $entries.Count
            Passed   = $statusCounts['pass']
            Failed   = $statusCounts['mismatch']
            Missing  = $statusCounts['missing']
            Rejected = $rejectedCount
        }
    }
}
