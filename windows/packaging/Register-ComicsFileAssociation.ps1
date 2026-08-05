param(
    [Parameter(Mandatory = $true)]
    [string]$ExecutablePath,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
$ProgId = "NativeMind.ComicsEditor.comics"
$ClassesRoot = "HKCU:\Software\Classes"
$CapabilitiesRoot = "HKCU:\Software\NativeMind\ComicsEditor\Capabilities"
$RegisteredApplications = "HKCU:\Software\RegisteredApplications"

if (-not [System.IO.Path]::IsPathFullyQualified($ExecutablePath)) {
    throw "ExecutablePath must be absolute."
}
$ExecutablePath = [System.IO.Path]::GetFullPath($ExecutablePath)
if (-not $WhatIf -and -not (Test-Path -LiteralPath $ExecutablePath -PathType Leaf)) {
    throw "Comics Editor executable does not exist: $ExecutablePath"
}

function Set-OwnedString {
    param([string]$Path, [string]$Name, [string]$Value)
    if ($WhatIf) {
        Write-Host "SET $Path [$Name] = $Value"
        return
    }
    New-Item -Path $Path -Force | Out-Null
    if ($Name -eq "(Default)") {
        Set-Item -LiteralPath $Path -Value $Value
    } else {
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType String -Force | Out-Null
    }
}

Set-OwnedString "$ClassesRoot\.comics\OpenWithProgids" $ProgId ""
Set-OwnedString "$ClassesRoot\$ProgId" "(Default)" "Comics Document"
Set-OwnedString "$ClassesRoot\$ProgId\DefaultIcon" "(Default)" "`"$ExecutablePath`",0"
Set-OwnedString "$ClassesRoot\$ProgId\shell\open\command" "(Default)" "`"$ExecutablePath`" `"%1`""
Set-OwnedString $CapabilitiesRoot "ApplicationName" "Comics Editor"
Set-OwnedString $CapabilitiesRoot "ApplicationDescription" "Create and edit Comics documents"
Set-OwnedString "$CapabilitiesRoot\FileAssociations" ".comics" $ProgId
Set-OwnedString $RegisteredApplications "Comics Editor" "Software\NativeMind\ComicsEditor\Capabilities"

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
