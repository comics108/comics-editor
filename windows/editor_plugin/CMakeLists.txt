# SDD sdd-comics-editor-v2.9, Task 4.2 (обвязка).
# Статическая библиотека editor_plugin + публикация C#-слоя
# (Comics.Editor.Flutter, net10.0-windows) рядом с exe.
cmake_minimum_required(VERSION 3.14)

set(PLUGIN_NAME "editor_plugin")

add_library(${PLUGIN_NAME} STATIC
  "editor_plugin.cpp"
)

apply_standard_settings(${PLUGIN_NAME})
target_include_directories(${PLUGIN_NAME} PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin)

# Публикация C#-слоя (WPF-редактор + мост) в подпапку dotnet у exe — ОТКЛЮЧЕНА
# (sdd-comics-editor-build, 2026-07-25). Custom build step (dotnet publish
# Comics.Editor.Flutter.csproj через publish_csharp.cmd) стабильно ломал
# Visual Studio generator (MSB1008 "Only one project can be specified") на
# windows-2025-vs2026 раннере — сгенерированный <Command> в .vcxproj синтаксически
# корректен (сверено построчно с соседним рабочим CMake-правилом в том же
# файле), причина осталась неподтверждённой даже с реальным содержимым vcxproj
# в руках. Решено не чинить это дальше: EditorPlugin::HandleMethodCall
# (editor_plugin.cpp) и WpfEditorView (lib/src/bridge/wpf_editor_view.dart) —
# оба явно помечены как TODO/заглушка ("not_implemented"), hostfxr/nethost
# интеропа, который должен был бы грузить Comics.Editor.Flutter.dll, ещё нет
# нигде в C++-коде — т.е. этот custom target публиковал сборку, которую
# сейчас всё равно никто не потребляет. Публикация не удалена, просто
# отключена от ALL: вернуть, когда появится реальный hostfxr/nethost-вызов в
# editor_plugin.cpp, который эту сборку реально грузит.
#
# find_program(DOTNET_EXECUTABLE dotnet)
# if(DOTNET_EXECUTABLE)
#   add_custom_target(${PLUGIN_NAME}_csharp ALL
#     COMMAND cmd /c call "${CMAKE_CURRENT_SOURCE_DIR}/publish_csharp.cmd" "${CMAKE_BINARY_DIR}/dotnet"
#     COMMENT "Publishing Comics.Editor.Flutter (net10.0-windows)…"
#   )
#   add_dependencies(${PLUGIN_NAME} ${PLUGIN_NAME}_csharp)
# else()
#   message(WARNING ".NET SDK (dotnet) not found — C# layer will not be built.")
# endif()
