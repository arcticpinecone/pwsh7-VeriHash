function Invoke-WinVerifyTrust {
    <#
    .SYNOPSIS
        Calls wintrust.dll!WinVerifyTrust with network CRL lookups disabled and returns the raw HRESULT.
    .DESCRIPTION
        Windows-only. Builds a WINTRUST_FILE_INFO + WINTRUST_DATA pair on the unmanaged heap with:
            dwUIChoice          = WTD_UI_NONE                (2)
            fdwRevocationChecks = WTD_REVOKE_NONE            (0)
            dwUnionChoice       = WTD_CHOICE_FILE            (1)
            dwStateAction       = WTD_STATEACTION_VERIFY     (1)
            dwProvFlags         = WTD_REVOCATION_CHECK_NONE (0x10)
                                | WTD_CACHE_ONLY_URL_RETRIEVAL (0x1000)   # no network -- PERF-02
        Pairs every VERIFY call with a STATEACTION_CLOSE call in the finally block to release
        hWVTStateData, then frees the unmanaged WINTRUST_FILE_INFO buffer.
        The Add-Type call is wrapped in a re-import guard so Import-Module -Force is idempotent.

        Struct layout, flag values, and action GUID are pinned in
        .planning/phases/02-hot-path-performance-multi-file-loop/02-01-PINVOKE-PIN.md.
    .PARAMETER Path
        File path to verify.
    .OUTPUTS
        [int] -- raw HRESULT (signed Int32 as PowerShell sees it).
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)] [string] $Path
    )
    if ((Get-VeriHashPlatform) -ne 'Windows') {
        throw 'Invoke-WinVerifyTrust is Windows-only'
    }

    if (-not ('VeriHash.WinTrust' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace VeriHash {

    [StructLayout(LayoutKind.Sequential)]
    public struct WINTRUST_FILE_INFO {
        public uint   cbStruct;
        [MarshalAs(UnmanagedType.LPWStr)] public string pcwszFilePath;
        public IntPtr hFile;
        public IntPtr pgKnownSubject;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct WINTRUST_DATA {
        public uint   cbStruct;
        public IntPtr pPolicyCallbackData;
        public IntPtr pSIPClientData;
        public uint   dwUIChoice;
        public uint   fdwRevocationChecks;
        public uint   dwUnionChoice;
        public IntPtr pFile;
        public uint   dwStateAction;
        public IntPtr hWVTStateData;
        [MarshalAs(UnmanagedType.LPWStr)] public string pwszURLReference;
        public uint   dwProvFlags;
        public uint   dwUIContext;
        public IntPtr pSignatureSettings;
    }

    public static class WinTrust {
        [DllImport("wintrust.dll", CharSet = CharSet.Unicode, SetLastError = false)]
        public static extern int WinVerifyTrust(IntPtr hwnd, [In] ref Guid pgActionID, [In, Out] ref WINTRUST_DATA pWVTData);
    }
}
'@
    }

    $actionGuid = [guid]'00AAC56B-CD44-11D0-8CC2-00C04FC295EE'   # WINTRUST_ACTION_GENERIC_VERIFY_V2

    $fileInfo                = New-Object VeriHash.WINTRUST_FILE_INFO
    $fileInfo.cbStruct       = [System.Runtime.InteropServices.Marshal]::SizeOf([type][VeriHash.WINTRUST_FILE_INFO])
    $fileInfo.pcwszFilePath  = $Path
    $fileInfo.hFile          = [IntPtr]::Zero
    $fileInfo.pgKnownSubject = [IntPtr]::Zero

    $filePtr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($fileInfo.cbStruct)
    [System.Runtime.InteropServices.Marshal]::StructureToPtr($fileInfo, $filePtr, $false)

    $wtd                     = New-Object VeriHash.WINTRUST_DATA
    $wtd.cbStruct            = [System.Runtime.InteropServices.Marshal]::SizeOf([type][VeriHash.WINTRUST_DATA])
    $wtd.pPolicyCallbackData = [IntPtr]::Zero
    $wtd.pSIPClientData      = [IntPtr]::Zero
    $wtd.dwUIChoice          = 2                                # WTD_UI_NONE
    $wtd.fdwRevocationChecks = 0                                # WTD_REVOKE_NONE
    $wtd.dwUnionChoice       = 1                                # WTD_CHOICE_FILE
    $wtd.pFile               = $filePtr
    $wtd.dwStateAction       = 1                                # WTD_STATEACTION_VERIFY
    $wtd.hWVTStateData       = [IntPtr]::Zero
    $wtd.pwszURLReference    = $null
    $wtd.dwProvFlags         = 0x00000010 -bor 0x00001000       # WTD_REVOCATION_CHECK_NONE | WTD_CACHE_ONLY_URL_RETRIEVAL
    $wtd.dwUIContext         = 0
    $wtd.pSignatureSettings  = [IntPtr]::Zero

    try {
        $hresult = [VeriHash.WinTrust]::WinVerifyTrust([IntPtr]::Zero, [ref]$actionGuid, [ref]$wtd)
        return [int]$hresult
    }
    finally {
        $wtd.dwStateAction = 2                                  # WTD_STATEACTION_CLOSE -- releases hWVTStateData
        [void][VeriHash.WinTrust]::WinVerifyTrust([IntPtr]::Zero, [ref]$actionGuid, [ref]$wtd)
        if ($filePtr -ne [IntPtr]::Zero) {
            [System.Runtime.InteropServices.Marshal]::DestroyStructure($filePtr, [type][VeriHash.WINTRUST_FILE_INFO])
            [System.Runtime.InteropServices.Marshal]::FreeHGlobal($filePtr)
        }
    }
}
