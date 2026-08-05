param([switch]$WhatIf)

$ErrorActionPreference = "Stop"
$ProgId = "NativeMind.ComicsEditor.comics"
$ClassesRoot = "HKCU:\Software\Classes"
$CapabilitiesRoot = "HKCU:\Software\NativeMind\ComicsEditor\Capabilities"
$RegisteredApplications = "HKCU:\Software\RegisteredApplications"

function Remove-OwnedItem {
    param([string]$Path)
    if ($WhatIf) {
        Write-Host "REMOVE $Path"
    } elseif (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }
}

if ($WhatIf) {
    Write-Host "REMOVE VALUE $ClassesRoot\.comics\OpenWithProgids [$ProgId]"
    Write-Host "REMOVE VALUE $RegisteredApplications [Comics Editor]"
} else {
    Remove-ItemProperty -LiteralPath "$ClassesRoot\.comics\OpenWithProgids" -Name $ProgId -ErrorAction SilentlyContinue
    Remove-ItemProperty -LiteralPath $RegisteredApplications -Name "Comics Editor" -ErrorAction SilentlyContinue
}

Remove-OwnedItem "$ClassesRoot\$ProgId"
Remove-OwnedItem $CapabilitiesRoot

if (-not $WhatIf) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class ComicsEditorShellNotification {
    [DllImport("shell32.dll")]
    public static extern void SHChangeNotify(uint eventId, uint flags, IntPtr item1, IntPtr item2);
}
"@
    [ComicsEditorShellNotification]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
}
