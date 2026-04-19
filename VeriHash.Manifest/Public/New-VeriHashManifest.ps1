function New-VeriHashManifest {
    <#
    .SYNOPSIS
        Creates a GNU sha256sum-compatible manifest for the specified files.
    .DESCRIPTION
        Hashes each input file sequentially using Get-VeriHashResult (D-09),
        writes the manifest atomically via temp-file-then-rename (D-10),
        and returns a VeriHash.ManifestCreateResult object.
        SHA256-only for MVP (D-07). Structured output only (D-17).
    .PARAMETER Path
        One or more file paths to include in the manifest. All files must
        share a single parent directory (MANIFEST-02). Files with hash
        extensions are silently filtered (MANIFEST-03, D-18).
    .OUTPUTS
        VeriHash.ManifestCreateResult
    .EXAMPLE
        New-VeriHashManifest -Path file1.txt, file2.txt
    #>
    [CmdletBinding()]
    [OutputType('VeriHash.ManifestCreateResult')]
    param(
        [Parameter(Mandatory)]
        [string[]]$Path
    )

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    # ── Step 1: Resolve all input paths ──────────────────────────────────
    $resolvedPaths = $Path | ForEach-Object {
        (Resolve-Path -LiteralPath $_ -ErrorAction Stop).ProviderPath
    }

    # ── Step 2: Filter out hash-extension files (D-18, MANIFEST-03) ─────
    $hashExtensions = @('.sha256', '.sha512', '.sha384', '.sha1', '.md5', '.sha2_256', '.sha2')
    $filtered = @($resolvedPaths | Where-Object {
        [System.IO.Path]::GetExtension($_).ToLowerInvariant() -notin $hashExtensions
    })
    if ($filtered.Count -eq 0) {
        throw 'No files to hash — all inputs were filtered (hash-extension files).'
    }

    # ── Step 3: Validate single common parent (MANIFEST-02) ─────────────
    $parents = $filtered | ForEach-Object { Split-Path -Parent $_ }
    $uniqueParents = @($parents | Select-Object -Unique)
    if ($uniqueParents.Count -ne 1) {
        throw 'Selected files span multiple directories. Manifests use relative paths — select files under one root.'
    }
    $commonParent = $uniqueParents[0]

    # ── Step 4: Determine manifest target path (D-01, D-02) ─────────────
    $manifestPath = Resolve-ManifestTargetPath -Directory $commonParent -Algorithm 'sha256'

    # ── Step 5: Hash files sequentially, build manifest lines (D-08, D-09)
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($file in $filtered) {
        $result = Get-VeriHashResult -Path $file -Algorithm SHA256
        $fileName = [System.IO.Path]::GetFileName($file)
        # D-03 future-proof: normalize any backslashes to forward slashes (no-op for single-dir MVP)
        $fileName = $fileName -replace '\\', '/'
        $line = "$($result.Hash) *$fileName"        # D-05: binary mode
        $lines.Add($line)
    }

    # ── Step 6: Atomic write (D-10, D-06) ────────────────────────────────
    Write-ManifestAtomically -Lines $lines.ToArray() -TargetPath $manifestPath

    $sw.Stop()

    # ── Step 7: Return result object (D-15) ──────────────────────────────
    return [pscustomobject]@{
        PSTypeName   = 'VeriHash.ManifestCreateResult'
        ManifestPath = $manifestPath
        FileCount    = $filtered.Count
        Algorithm    = 'SHA256'
        ElapsedMs    = [int]$sw.ElapsedMilliseconds
    }
}
