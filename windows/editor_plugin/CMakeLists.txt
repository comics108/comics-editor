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

# Публикация C#-слоя (WPF-редактор + мост) в подпапку dotnet у exe.
find_program(DOTNET_EXECUTABLE dotnet)
if(DOTNET_EXECUTABLE)
  add_custom_target(${PLUGIN_NAME}_csharp ALL
    COMMAND ${DOTNET_EXECUTABLE} publish
      "${CMAKE_CURRENT_SOURCE_DIR}/../../native/Comics.Editor.Flutter/Comics.Editor.Flutter.csproj"
      -c Release
      -f net10.0-windows
      -o "${CMAKE_BINARY_DIR}/dotnet"
      --verbosity minimal
    COMMENT "Publishing Comics.Editor.Flutter (net10.0-windows)…"
  )
  add_dependencies(${PLUGIN_NAME} ${PLUGIN_NAME}_csharp)
else()
  message(WARNING ".NET SDK (dotnet) not found — C# layer will not be built.")
endif()
