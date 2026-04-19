function Get-VeriHashResult {
    <#
    .SYNOPSIS
        Computes a single file hash and returns a VeriHash.Result object.
    .DESCRIPTION
        Pure hash compute. Returns a [pscustomobject] with PSTypeName
        'VeriHash.Result' carrying FilePath, Size, Algorithm, Hash (lowercase
        hex), and ElapsedMs.
    .PARAMETER Path
        Filesystem path to the file to hash. Resolved with -LiteralPath.
    .PARAMETER Algorithm
        One of 'MD5', 'SHA256', 'SHA512'. Default 'SHA256'.
    .OUTPUTS
        VeriHash.Result
    #>
    [CmdletBinding()]
    [OutputType('VeriHash.Result')]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [ValidateSet('MD5', 'SHA256', 'SHA512')]
        [string]$Algorithm = 'SHA256'
    )
    $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    $info = Get-Item -LiteralPath $resolved
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $hash = (Get-FileHash -LiteralPath $resolved -Algorithm $Algorithm).Hash.ToLowerInvariant()
    $sw.Stop()
    return [pscustomobject]@{
        PSTypeName    = 'VeriHash.Result'
        FilePath      = $resolved
        Size          = [long]$info.Length
        CreationTime  = $info.CreationTime
        LastWriteTime = $info.LastWriteTime
        Algorithm     = $Algorithm
        Hash          = $hash
        ElapsedMs     = [int]$sw.ElapsedMilliseconds
    }
}
