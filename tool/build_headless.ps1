# SDD sdd-comics-editor-v2.9: публикация headless-ядра (self-contained) на Windows.
# Использование: powershell -File tool/build_headless.ps1 [-Rid win-x64]

param([string]$Rid = "win-x64")

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$out = "native/Comics.Editor.Headless/publish/$Rid"
dotnet publish native/Comics.Editor.Headless/Comics.Editor.Headless.csproj `
  -c Release -r $Rid --self-contained true `
  -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true `
  -o $out

Write-Host "Published: $out/Comics.Editor.exe"
