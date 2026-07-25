@echo off
rem SDD sdd-comics-editor-v2.9, Task 4.2 (обвязка). Публикует Comics.Editor.Flutter
rem (net10.0-windows) в подпапку dotnet у exe.
rem
rem Вынесен из CMakeLists.txt в отдельный скрипt: многотокенная команда
rem "dotnet publish <csproj> -c Release -f ... -o ... --verbosity minimal",
rem переданная напрямую в CMake add_custom_target COMMAND, ломалась генератором
rem Visual Studio (MSB1008 "Only one project can be specified") — похоже на
rem баг сериализации аргументов custom-build-step, когда путь к dotnet.exe
rem содержит пробел (C:\Program Files\dotnet). Здесь CMake передаёт скрипту
rem всего один аргумент (выходную папку), а кавычки для dotnet publish
rem однозначно расставляет cmd.exe.
setlocal
set "SCRIPT_DIR=%~dp0"
dotnet publish "%SCRIPT_DIR%..\..\native\Comics.Editor.Flutter\Comics.Editor.Flutter.csproj" -c Release -f net10.0-windows -o "%~1" --verbosity minimal
exit /b %ERRORLEVEL%
