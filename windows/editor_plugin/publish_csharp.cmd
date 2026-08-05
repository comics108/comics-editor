@echo off
rem SDD sdd-comics-editor-build. Publishes Comics.Editor.Flutter (net10.0-windows)
rem into the "dotnet" subfolder next to the exe. Invoked directly by the
rem Windows GitHub Actions workflow after Flutter has built the application.
rem
rem History: the original multi-token "dotnet publish <csproj> -c Release -f ...
rem -o ... --verbosity minimal" placed directly in the CMake COMMAND broke the VS
rem generator (MSB1008 "Only one project can be specified"). Moving it into this
rem .cmd (2026-07-24, sdd-comics-editor-v2.9-android-ios) was never actually
rem verified by a real Windows CI run (only "dotnet build"/"flutter test" on
rem macOS, which do not exercise "flutter build windows") -- the same MSB1008
rem error recurred on the next real Windows CI run (2026-07-25,
rem sdd-comics-editor-build), so that diagnosis was unconfirmed guesswork.
rem Publication now runs outside CMake. The 2026-08-05 workflow reached this
rem script and exposed the remaining failure: SDK 10.0.302 forwarded `-o` as a
rem bare `PublishDir=...` MSBuild token, which MSBuild counted as a project.
rem Keep this file CRLF-normalized and retain the diagnostics below for CI.
setlocal
set "SCRIPT_DIR=%~dp0"
set "CSPROJ=%SCRIPT_DIR%..\..\native\Comics.Editor.Flutter\Comics.Editor.Flutter.csproj"
set "OUT_DIR=%~1"
echo [publish_csharp] SCRIPT_DIR=%SCRIPT_DIR%
echo [publish_csharp] CSPROJ=%CSPROJ%
echo [publish_csharp] OUT_DIR=%OUT_DIR%
echo [publish_csharp] dotnet --version:
dotnet --version
rem .NET SDK 10.0.302 on the Windows 2025 runner forwarded `-o` as a bare
rem `PublishDir=...` MSBuild token. MSBuild then treated it as a second project
rem and failed with MSB1008. Pass the property explicitly so it remains an
rem MSBuild property rather than another positional argument.
echo [publish_csharp] Running: dotnet publish "%CSPROJ%" -c Release -f net10.0-windows -p:PublishDir="%OUT_DIR%" --verbosity normal
dotnet publish "%CSPROJ%" -c Release -f net10.0-windows -p:PublishDir="%OUT_DIR%" --verbosity normal
set "EXITCODE=%ERRORLEVEL%"
echo [publish_csharp] Exit code: %EXITCODE%
exit /b %EXITCODE%
