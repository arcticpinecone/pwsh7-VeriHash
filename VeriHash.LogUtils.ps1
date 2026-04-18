<#
    VeriHash.LogUtils.ps1 - Utilities for working with VeriHash log files

    Copyright (C) 2024-2025 arcticpinecone <arcticpinecone@arcticpinecone.eu>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    DATA MINIMIZATION NOTICE:
    VeriHash logs are designed with privacy in mind (GDPR Article 5(1)(c)).
    - Paths are sanitized: %USERPROFILE% (Windows) or ~ (Linux/macOS)
    - PSFramework adds ComputerName/Username metadata (cannot be disabled)
    - Use ConvertFrom-SanitizedPath to expand paths for local debugging
#>

$verihashCoreManifest = Join-Path (Split-Path -Parent $PSCommandPath) 'VeriHash.Core/VeriHash.Core.psd1'
if (Test-Path -LiteralPath $verihashCoreManifest) {
    Import-Module $verihashCoreManifest -Force -Global
}

function Get-VeriHashLogPath {
    <#
    .SYNOPSIS
        Returns the default VeriHash log directory path.
    .DESCRIPTION
        Returns the platform-appropriate log directory path for VeriHash.
    .OUTPUTS
        String - The path to the VeriHash logs directory.
    .EXAMPLE
        Get-VeriHashLogPath
        # Returns: C:\Users\<user>\AppData\Roaming\VeriHash\logs (Windows)
        # Returns: /home/<user>/.verihash/logs (Linux)
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if ((Get-VeriHashPlatform) -eq 'Windows') {
        Join-Path $env:APPDATA "VeriHash\logs"
    } else {
        Join-Path $HOME ".verihash/logs"
    }
}

function ConvertTo-SanitizedPath {
    <#
    .SYNOPSIS
        Replaces user profile paths with platform-appropriate placeholders.
    .DESCRIPTION
        Implements data minimization by removing personally identifiable
        information from file paths before logging (GDPR Article 5(1)(c)).

        On Windows, replaces the user profile path with %USERPROFILE%.
        On Linux/macOS, replaces the home directory with ~.
    .PARAMETER Path
        The file path to sanitize.
    .OUTPUTS
        String - The sanitized path with user-specific segments replaced.
    .EXAMPLE
        'C:\Users\john\Downloads\file.exe' | ConvertTo-SanitizedPath
        # Returns: %USERPROFILE%\Downloads\file.exe
    .EXAMPLE
        '/home/john/Documents/file.tar.gz' | ConvertTo-SanitizedPath
        # Returns: ~/Documents/file.tar.gz
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(ValueFromPipeline)]
        [string]$Path
    )
    process {
        if ([string]::IsNullOrEmpty($Path)) { return $Path }

        if ((Get-VeriHashPlatform) -eq 'Windows') {
            # Replace C:\Users\username with %USERPROFILE%
            $Path -replace [regex]::Escape($env:USERPROFILE), '%USERPROFILE%'
        } else {
            # Replace /home/username or /Users/username with ~
            $Path -replace [regex]::Escape($HOME), '~'
        }
    }
}

function ConvertFrom-SanitizedPath {
    <#
    .SYNOPSIS
        Expands sanitized paths back to full paths for local debugging.
    .DESCRIPTION
        VeriHash logs sanitize paths for privacy (GDPR Article 5(1)(c)).
        This function expands %USERPROFILE% or ~ back to the current user's
        home directory for local debugging purposes.

        Note: This only works on the same machine where logs were created.
    .PARAMETER Path
        The sanitized path to expand.
    .OUTPUTS
        String - The expanded path.
    .EXAMPLE
        ConvertFrom-SanitizedPath -Path '%USERPROFILE%\Downloads\file.exe'
        # Returns: C:\Users\YourName\Downloads\file.exe
    .EXAMPLE
        '~/Downloads/file.tar.gz' | ConvertFrom-SanitizedPath
        # Returns: /home/yourname/Downloads/file.tar.gz
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(ValueFromPipeline)]
        [string]$Path
    )
    process {
        if ([string]::IsNullOrEmpty($Path)) { return $Path }

        if ((Get-VeriHashPlatform) -eq 'Windows') {
            $Path -replace '%USERPROFILE%', $env:USERPROFILE
        } else {
            $Path -replace '^~', $HOME
        }
    }
}

function ConvertFrom-VeriHashLog {
    <#
    .SYNOPSIS
        Converts VeriHash JSON log files to PowerShell objects or CSV format.
    .DESCRIPTION
        Reads VeriHash JSON log files (JSON lines format) and converts them to
        PowerShell objects for analysis or export to CSV for human-readable reports.
    .PARAMETER Path
        Path to a specific log file, or a directory containing log files.
        If not specified, uses the default VeriHash log directory.
    .PARAMETER Days
        Only include logs from the last N days. Default: all logs.
    .PARAMETER Level
        Filter by log level (Debug, Verbose, Warning, Host). Default: all levels.
    .PARAMETER Tag
        Filter by tag. Logs must contain this tag.
    .PARAMETER ExportCsv
        Export the results to a CSV file at the specified path.
    .OUTPUTS
        PSCustomObject[] - Array of log entry objects.
    .EXAMPLE
        ConvertFrom-VeriHashLog
        # Returns all log entries from the default log directory

    .EXAMPLE
        ConvertFrom-VeriHashLog -Days 7 -Level Warning
        # Returns warning-level logs from the last 7 days

    .EXAMPLE
        ConvertFrom-VeriHashLog -ExportCsv "C:\reports\verihash-logs.csv"
        # Exports all logs to CSV format
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Position = 0)]
        [string]$Path,

        [Parameter()]
        [int]$Days,

        [Parameter()]
        [ValidateSet('Debug', 'Verbose', 'Warning', 'Host', 'Information')]
        [string]$Level,

        [Parameter()]
        [string]$Tag,

        [Parameter()]
        [string]$ExportCsv
    )

    # Determine log path
    if (-not $Path) {
        $Path = Get-VeriHashLogPath
    }

    if (-not (Test-Path $Path)) {
        Write-Warning "Log path not found: $Path"
        return [PSCustomObject[]]@()
    }

    # Get log files
    if (Test-Path $Path -PathType Container) {
        $logFiles = Get-ChildItem -Path $Path -Filter "verihash-*.jsonl" | Sort-Object LastWriteTime -Descending
    } else {
        $logFiles = Get-Item $Path
    }

    if ($logFiles.Count -eq 0) {
        Write-Warning "No VeriHash log files found in: $Path"
        return [PSCustomObject[]]@()
    }

    # Filter by age if Days specified
    if ($Days -gt 0) {
        $cutoffDate = (Get-Date).AddDays(-$Days)
        $logFiles = $logFiles | Where-Object { $_.LastWriteTime -ge $cutoffDate }
    }

    # Read and parse log entries
    $logEntries = @()
    foreach ($file in $logFiles) {
        # Use -Raw and split to handle UTF-8 BOM properly, then trim BOM from first line if present
        $rawContent = Get-Content $file.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        if ([string]::IsNullOrEmpty($rawContent)) { continue }
        # Remove UTF-8 BOM if present (appears as character at start)
        if ($rawContent[0] -eq [char]0xFEFF) {
            $rawContent = $rawContent.Substring(1)
        }
        $lines = $rawContent -split "`r?`n"
        foreach ($line in $lines) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            # Skip lines that are just commas (PSFramework JSON array format artifact)
            if ($line.Trim() -eq ',') { continue }
            # Strip trailing comma from JSON lines (PSFramework appends commas for array format)
            $jsonLine = $line.TrimEnd(',')

            try {
                $entry = $jsonLine | ConvertFrom-Json -ErrorAction Stop

                # Apply filters
                if ($Level -and $entry.Level -ne $Level) { continue }
                if ($Tag -and $entry.Tags -notcontains $Tag) { continue }

                # Flatten Data property for CSV compatibility
                $flatEntry = [PSCustomObject]@{
                    Timestamp    = $entry.Timestamp
                    Level        = $entry.Level
                    Message      = $entry.Message
                    FunctionName = $entry.FunctionName
                    ModuleName   = $entry.ModuleName
                    Tags         = if ($entry.Tags) { $entry.Tags -join ',' } else { '' }
                    File         = $entry.File
                    Line         = $entry.Line
                    Data         = if ($entry.Data) { ($entry.Data | ConvertTo-Json -Compress) } else { '' }
                    SourceFile   = $file.Name
                }

                $logEntries += $flatEntry
            }
            catch {
                # Skip malformed JSON lines
                continue
            }
        }
    }

    # Export to CSV if requested
    if ($ExportCsv) {
        $logEntries | Export-Csv -Path $ExportCsv -NoTypeInformation -Encoding UTF8
        Write-Host "Exported $($logEntries.Count) log entries to: $ExportCsv" -ForegroundColor Green
    }

    return [PSCustomObject[]]$logEntries
}

function Get-VeriHashLogSummary {
    <#
    .SYNOPSIS
        Provides a summary of VeriHash log activity.
    .DESCRIPTION
        Analyzes VeriHash logs and returns statistics about operations,
        errors, and activity patterns.
    .PARAMETER Days
        Number of days to analyze. Default: 7.
    .OUTPUTS
        PSCustomObject - Summary statistics.
    .EXAMPLE
        Get-VeriHashLogSummary -Days 30
        # Returns a summary of the last 30 days of activity
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [int]$Days = 7
    )

    $logs = ConvertFrom-VeriHashLog -Days $Days

    if ($logs.Count -eq 0) {
        return [PSCustomObject]@{
            TotalEntries    = 0
            Period          = "$Days days"
            Message         = "No log entries found"
        }
    }

    # Count by level
    $byLevel = $logs | Group-Object Level | ForEach-Object {
        @{ $_.Name = $_.Count }
    }

    # Count by tag (most common)
    $allTags = $logs | ForEach-Object { $_.Tags -split ',' } | Where-Object { $_ }
    $topTags = $allTags | Group-Object | Sort-Object Count -Descending | Select-Object -First 5

    # Hash operations
    $hashOps = ($logs | Where-Object { $_.Tags -match 'Hash' }).Count
    $verifyOps = ($logs | Where-Object { $_.Tags -match 'Verify' }).Count
    $installOps = ($logs | Where-Object { $_.Tags -match 'Install' }).Count

    return [PSCustomObject]@{
        TotalEntries    = $logs.Count
        Period          = "$Days days"
        ByLevel         = $byLevel
        TopTags         = $topTags | ForEach-Object { "$($_.Name): $($_.Count)" }
        HashOperations  = $hashOps
        VerifyOperations = $verifyOps
        InstallOperations = $installOps
        OldestEntry     = ($logs | Sort-Object Timestamp | Select-Object -First 1).Timestamp
        NewestEntry     = ($logs | Sort-Object Timestamp -Descending | Select-Object -First 1).Timestamp
    }
}
