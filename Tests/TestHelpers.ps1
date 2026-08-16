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

function Set-VeriHashUtf8Console {
    <#
    .SYNOPSIS
        Pins the console to UTF-8 and returns the previous encoding so the
        caller can hand it to Restore-VeriHashUtf8Console.
    .DESCRIPTION
        Test files that assert on Unicode glyphs need a UTF-8 code page: the
        renderers pick their glyphs from [Console]::OutputEncoding, so an
        ASCII code page makes the product emit fallback characters the
        assertions do not expect.

        The setter throws IOException when the process has no console handle
        -- redirected stdout, a CI runner, or a hosted PowerShell host. That
        is environmental and outside any test's control, so it is logged to
        the verbose stream rather than raised: throwing from a BeforeAll
        aborts the whole container and reports the setup failure instead of
        whichever assertion the code page actually affected.
    .OUTPUTS
        System.Text.Encoding -- pass to Restore-VeriHashUtf8Console.
    #>
    [CmdletBinding()]
    [OutputType([System.Text.Encoding])]
    param()
    $previous = [Console]::OutputEncoding
    try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() }
    catch { Write-Verbose "No console attached; output encoding left as-is: $_" }
    return $previous
}

function Restore-VeriHashUtf8Console {
    <#
    .SYNOPSIS
        Restores the console encoding captured by Set-VeriHashUtf8Console.
    .DESCRIPTION
        Null is accepted so a teardown block still runs cleanly when setup
        failed before it could capture an encoding; swallowing the setter
        failure is deliberate for the reasons given on Set-VeriHashUtf8Console.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [System.Text.Encoding]$Encoding
    )
    if ($null -eq $Encoding) { return }
    try { [Console]::OutputEncoding = $Encoding }
    catch { Write-Verbose "No console attached; output encoding not restored: $_" }
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
