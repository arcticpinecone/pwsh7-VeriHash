function Test-IsPEFile {
    <#
    .SYNOPSIS
        Returns $true iff the file at $Path begins with the PE/MZ magic bytes (0x4D 0x5A).
    .DESCRIPTION
        Content-based PE detection. Opens the file with [System.IO.File]::OpenRead,
        reads two bytes, and immediately disposes the stream so the subsequent hash
        and signature ThreadJobs do not contend for the file handle.
        Any I/O error (missing file, directory path, ACL block, broken symlink,
        less than 2 bytes) returns $false rather than throwing -- the caller's hash
        job will surface the actual error.
    .PARAMETER Path
        File path to inspect. May be missing or invalid; this function never throws.
    .OUTPUTS
        [bool]
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)] [string] $Path
    )
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            $buf  = [byte[]]::new(2)
            $read = $stream.Read($buf, 0, 2)
            return ($read -eq 2 -and $buf[0] -eq 0x4D -and $buf[1] -eq 0x5A)
        }
        finally {
            $stream.Dispose()
        }
    }
    catch {
        return $false
    }
}
