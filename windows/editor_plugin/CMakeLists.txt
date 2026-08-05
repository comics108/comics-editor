# SDD sdd-comics-editor-v2.9, Task 4.2 (обвязка).
# Статическая библиотека editor_plugin + публикация C#-слоя
# (Comics.Editor.Flutter, net10.0-windows) рядом с exe.
cmake_minimum_required(VERSION 3.14)

set(PLUGIN_NAME "editor_plugin")

add_library(${PLUGIN_NAME} STATIC
  "editor_plugin.cpp"
  "hostfxr_bootstrap.cpp"
)

apply_standard_settings(${PLUGIN_NAME})
target_include_directories(${PLUGIN_NAME} PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

# C#-layer publication (WPF editor + bridge) is intentionally not a CMake
# custom command. Visual Studio 2026's MSBuild fails with MSB1008 before the
# command can run, both for a standalone custom target and for POST_BUILD on
# this library. The Windows CI workflow publishes directly into the packaged
# runner/Release/dotnet directory after `flutter build windows` instead.
# Full investigation history and the six failed CMake variants are recorded in
# flows/sdd-comics-editor-build/04-implementation-log.md.
