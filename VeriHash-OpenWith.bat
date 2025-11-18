@echo off
setlocal EnableDelayedExpansion

rem VeriHash-OpenWith.bat
rem Wrapper script for VeriHash.ps1 to handle Windows Send To functionality
rem Version 1.1.0

rem Find PowerShell 7
set PWSH=
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" (
    set PWSH="%ProgramFiles%\PowerShell\7\pwsh.exe"
) else if exist "%ProgramFiles(x86)%\PowerShell\7\pwsh.exe" (
    set PWSH="%ProgramFiles(x86)%\PowerShell\7\pwsh.exe"
) else (
    rem Try to find pwsh in PATH
    where pwsh.exe >nul 2>&1
    if !ERRORLEVEL! == 0 (
        set PWSH=pwsh.exe
    ) else (
        echo ERROR: PowerShell 7 not found. Please install it from:
        echo https://github.com/PowerShell/PowerShell/releases
        pause
        exit /b 1
    )
)

rem Get the script path
set SCRIPT="%~dp0VeriHash.ps1"

rem Check if the script exists
if not exist %SCRIPT% (
    echo ERROR: VeriHash.ps1 not found in the same directory as this batch file.
    echo Expected location: %SCRIPT%
    pause
    exit /b 1
)

rem Handle the file path passed as first argument
set FILEPATH=%1

rem If no argument provided, launch VeriHash interactively
if "%FILEPATH%"=="" (
    %PWSH% -NoProfile -ExecutionPolicy Bypass -File %SCRIPT%
    goto :end
)

rem Remove quotes from filepath if they exist
set FILEPATH=%FILEPATH:"=%

rem Re-add quotes to handle spaces in path
set FILEPATH="%FILEPATH%"

rem Forward the file path to VeriHash.ps1 with NoPause flag
%PWSH% -NoProfile -ExecutionPolicy Bypass -File %SCRIPT% -FilePath %FILEPATH% -NoPause

:end
set EXITCODE=%ERRORLEVEL%

rem If launched from explorer (Send To), pause to show results
if "%~2"=="" (
    if %EXITCODE% NEQ 0 (
        echo.
        echo Process completed with code: %EXITCODE%
    )
    pause
)

endlocal
exit /b %EXITCODE%