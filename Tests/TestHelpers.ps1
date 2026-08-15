function Remove-Ansi {
    <#
    .SYNOPSIS
        Strips ANSI SGR escape sequences so tests can assert on plain text.
    .DESCRIPTION
        PowerShell 7.2+ may itself strip ANSI when output is redirected
        ($PSStyle.OutputRendering = 'Host'), so this is deliberately
        idempotent: stripping already-plain text is a no-op.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]$Text
    )
    process { return ($Text -replace "$([char]27)\[[0-9;]*m", '') }
}

$script:VeriHashColorVars = @('NO_COLOR', 'VERIHASH_NO_COLOR', 'VERIHASH_NO_TRUECOLOR')

function Save-VeriHashColorEnv {
    <#
    .SYNOPSIS
        Captures the colour-capability environment variables so a test file can
        restore whatever the developer had set.
    .DESCRIPTION
        Colour behaviour is driven by environment variables, so any test that
        asserts on ANSI output is only deterministic if it pins that
        environment. A developer who legitimately sets NO_COLOR=1 must not see
        spurious failures, and a test that sets it must not leak into the rest
        of the Pester run (all files share one process).
    .OUTPUTS
        System.Collections.Hashtable -- pass to Restore-VeriHashColorEnv.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    $saved = @{}
    foreach ($v in $script:VeriHashColorVars) { $saved[$v] = [Environment]::GetEnvironmentVariable($v) }
    return $saved
}

function Restore-VeriHashColorEnv {
    <#
    .SYNOPSIS
        Restores the environment captured by Save-VeriHashColorEnv.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Saved
    )
    foreach ($v in $script:VeriHashColorVars) {
        if ($null -eq $Saved[$v]) { Remove-Item "Env:\$v" -ErrorAction SilentlyContinue }
        else                      { Set-Item "Env:\$v" -Value $Saved[$v] }
    }
}

function Set-VeriHashColorEnv {
    <#
    .SYNOPSIS
        Forces colour capability to a known state for the duration of a test.
    .PARAMETER Mode
        Truecolor -- full 24-bit palette (the default assertion baseline).
        Sixteen   -- 16-colour SGR fallback.
        None      -- NO_COLOR, every colour blanked.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [ValidateSet('Truecolor', 'Sixteen', 'None')]
        [string]$Mode = 'Truecolor'
    )
    foreach ($v in $script:VeriHashColorVars) { Remove-Item "Env:\$v" -ErrorAction SilentlyContinue }
    switch ($Mode) {
        'Sixteen' { $env:VERIHASH_NO_TRUECOLOR = '1' }
        'None'    { $env:NO_COLOR = '1' }
    }
}
