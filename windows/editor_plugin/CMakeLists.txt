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
# (hostfxr_bootstrap.cpp) — т.е. публикация снова нужна, и MSB1008 воспроизвёлся
# заново на первом же реальном Windows CI-прогоне после реактивации
# (sdd-comics-editor-build, round 5, 2026-07-30).
#
# Round 5 находка: у этого add_custom_target() не было VERBATIM. Flutter's
# собственный flutter_tools содержит миграцию (cmake_custom_command_migration.dart),
# которая добавляет VERBATIM ко ВСЕМ add_custom_command() в СВОЁМ сгенерированном
# CMakeLists.txt со ссылкой именно на баг Visual Studio generator'а с
# экранированием команд без VERBATIM (flutter/flutter#67270) — то есть Flutter
# сам уже наступал на этот класс бага и официально задокументировал VERBATIM
# как фикс. Round 5 применён (2026-07-30), но MSB1008 повторился на первом же
# реальном прогоне БЕЗ каких-либо диагностических echo из publish_csharp.cmd в
# логе — т.е. падение происходит ДО того, как наша команда вообще начинает
# выполняться, ещё на этапе обработки самого custom-build-step MSBuild'ом.
#
# Round 6 (2026-07-31): пересмотрен сам механизм, а не содержимое команды.
# `add_custom_target(... ALL ...)` заставляет CMake сгенерировать ОТДЕЛЬНЫЙ
# .vcxproj для editor_plugin_csharp, чьи единственные "исходники" — служебный
# .rule-файл (нет ни одного реального ClCompile-элемента). На раннере
# windows-2025-vs2026 (VS "18"/2026 — совсем новый/preview тулсет) именно
# такие "пустые" custom-target-only vcxproj давали сбой ещё до исполнения
# команды — судя по всему, баг в обработке MSBuild'ом этого класса проектов на
# этом тулсете, а не в содержимом COMMAND (5 раундов фиксов содержимого не
# помогли). Переведено на add_custom_command(TARGET ... POST_BUILD ...),
# прикреплённый к УЖЕ существующему editor_plugin (обычная статическая
# библиотека с реальными исходниками, свой vcxproj заведомо собирается) —
# отдельный vcxproj для публикации C#-слоя больше не создаётся вообще, вместо
# починки бага мы обходим сам класс проекта, в котором он проявляется.
# windows/runner/CMakeLists.txt копирует ${CMAKE_BINARY_DIR}/dotnet рядом с
# exe отдельным POST_BUILD-шагом на ${BINARY_NAME} — порядок сохраняется, т.к.
# runner собирается после editor_plugin (target_link_libraries), а значит и
# после его POST_BUILD публикации. Не проверено реальным Windows CI (агент
# работает на macOS) — история багов (sdd-comics-editor-build/
# 04-implementation-log.md) содержит 5 предыдущих раундов на содержимом
# команды, ни один не подтверждён реальным прогоном.
find_program(DOTNET_EXECUTABLE dotnet)
if(DOTNET_EXECUTABLE)
  add_custom_command(TARGET ${PLUGIN_NAME} POST_BUILD
    COMMAND cmd /c call "${CMAKE_CURRENT_SOURCE_DIR}/publish_csharp.cmd" "${CMAKE_BINARY_DIR}/dotnet"
    COMMENT "Publishing Comics.Editor.Flutter (net10.0-windows)…"
    VERBATIM
  )
else()
  message(WARNING ".NET SDK (dotnet) not found — C# layer will not be built.")
endif()
