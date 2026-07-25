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

# Публикация C#-слоя (WPF-редактор + мост) в подпапку dotnet у exe.
#
# История: этот custom target ломал Visual Studio generator (MSB1008 "Only
# one project can be specified") на windows-2025-vs2026 раннере — причина
# осталась неподтверждённой даже с реальным содержимым сгенерированного
# .vcxproj в руках (sdd-comics-editor-build, 2026-07-25). Тогда же выяснилось,
# что C++-плагин (editor_plugin.cpp) вообще не потреблял эту публикацию
# (заглушка not_implemented) — поэтому target был отключён (закомментирован)
# вместо продолжения починки несвязанного с использованием бага.
#
# Реактивировано в sdd-comics-editor-v2.9-fixes2 (Track A): editor_plugin.cpp
# теперь реально грузит Comics.Editor.Flutter.dll через hostfxr
# (hostfxr_bootstrap.cpp) — т.е. публикация снова нужна. MSB1008 сам по себе
# не был исправлен (root cause не найден) — если он повторится, здесь есть
# история трёх раундов диагностики в sdd-comics-editor-build/04-implementation-log.md.
find_program(DOTNET_EXECUTABLE dotnet)
if(DOTNET_EXECUTABLE)
  add_custom_target(${PLUGIN_NAME}_csharp ALL
    COMMAND cmd /c call "${CMAKE_CURRENT_SOURCE_DIR}/publish_csharp.cmd" "${CMAKE_BINARY_DIR}/dotnet"
    COMMENT "Publishing Comics.Editor.Flutter (net10.0-windows)…"
  )
  add_dependencies(${PLUGIN_NAME} ${PLUGIN_NAME}_csharp)
else()
  message(WARNING ".NET SDK (dotnet) not found — C# layer will not be built.")
endif()
