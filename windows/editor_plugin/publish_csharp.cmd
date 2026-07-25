@echo off
rem SDD sdd-comics-editor-build. Publishes Comics.Editor.Flutter (net10.0-windows)
rem into the "dotnet" subfolder next to the exe. Invoked from
rem windows/editor_plugin/CMakeLists.txt as a Visual Studio custom build step.
rem
rem History: the original multi-token "dotnet publish <csproj> -c Release -f ...
rem -o ... --verbosity minimal" placed directly in the CMake COMMAND broke the VS
rem generator (MSB1008 "Only one project can be specified"). Moving it into this
rem .cmd (2026-07-24, sdd-comics-editor-v2.9-android-ios) was never actually
rem verified by a real Windows CI run (only "dotnet build"/"flutter test" on
rem macOS, which do not exercise "flutter build windows") -- the same MSB1008
rem error recurred on the next real Windows CI run (2026-07-25,
rem sdd-comics-editor-build), so that diagnosis was unconfirmed guesswork.
rem Root cause is still not confirmed. Below: diagnostics (echo of resolved
rem paths/command) for the next CI run, plus two defensive fixes that are
rem correct regardless of whether they are THE cause:
rem  1) this file previously had LF-only line endings (verified via hex dump),
rem     which is anomalous for a Windows batch file in this repo (compare
rem     android/gradlew.bat, fully CRLF) -- normalized to CRLF.
rem  2) CMakeLists.txt now invokes this script via "cmd /c call ..." instead of
rem     naming it directly -- invoking a .cmd/.bat file by name (no CALL) from
rem     inside another running batch script does not reliably return control to
rem     the caller in cmd.exe; CMake's own generated custom-build-step wrapper
rem     for the Visual Studio generator is itself a batch script.
setlocal
set "SCRIPT_DIR=%~dp0"
set "CSPROJ=%SCRIPT_DIR%..\..\native\Comics.Editor.Flutter\Comics.Editor.Flutter.csproj"
set "OUT_DIR=%~1"
echo [publish_csharp] SCRIPT_DIR=%SCRIPT_DIR%
echo [publish_csharp] CSPROJ=%CSPROJ%
echo [publish_csharp] OUT_DIR=%OUT_DIR%
echo [publish_csharp] dotnet --version:
dotnet --version
echo [publish_csharp] Running: dotnet publish "%CSPROJ%" -c Release -f net10.0-windows -o "%OUT_DIR%" --verbosity normal
dotnet publish "%CSPROJ%" -c Release -f net10.0-windows -o "%OUT_DIR%" --verbosity normal
set "EXITCODE=%ERRORLEVEL%"
echo [publish_csharp] Exit code: %EXITCODE%
exit /b %EXITCODE%
