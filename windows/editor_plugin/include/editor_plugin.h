// SDD sdd-comics-editor-v2.9, Task 4.2 (обвязка, по образцу
// libs/comics_editor/flutter_comics_editor/windows).
//
// Плагин канала `comics_editor`: мост Flutter → .NET
// (native/Comics.Editor.Flutter/MethodChannelHandler.HandleMethodCall).
// Interop-слой (.NET hosting / C++/CLI) дописывается на Windows-машине —
// см. README, раздел «Windows».

#ifndef COMICS_EDITOR_PLUGIN_H_
#define COMICS_EDITOR_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

#if defined(__cplusplus)
extern "C" {
#endif

// Регистрация из runner (вызывается в flutter_window.cpp после RegisterPlugins).
__declspec(dllexport) void EditorPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
}  // extern "C"
#endif

namespace comics_editor {

class EditorPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  EditorPlugin();
  virtual ~EditorPlugin();

  EditorPlugin(const EditorPlugin&) = delete;
  EditorPlugin& operator=(const EditorPlugin&) = delete;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace comics_editor

#endif  // COMICS_EDITOR_PLUGIN_H_
