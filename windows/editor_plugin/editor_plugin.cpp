#include "include/editor_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>

namespace comics_editor {

// TODO(Windows): interop к .NET — вариант A (рекомендуемый): hostfxr /
// nethost загружает net10.0-windows сборку Comics.Editor.Flutter.dll и
// вызывает MethodChannelHandler.HandleMethodCall(method, argsJson);
// вариант B: C++/CLI-прослойка (как планировалось в
// libs/comics_editor/flutter_comics_editor). До реализации методы
// возвращают ошибку "not_implemented" — Dart-сторона показывает заглушку.

void EditorPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "comics_editor",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<EditorPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

EditorPlugin::EditorPlugin() {}

EditorPlugin::~EditorPlugin() {}

void EditorPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // TODO(Windows): method_call.method_name() → JSON →
  //   Comics.Editor.Flutter.MethodChannelHandler.HandleMethodCall(...)
  // "create" должен показать полный WPF-редактор (EditorHost.ShowMainWindow).
  result->Error("not_implemented",
                "Comics.Editor.Flutter interop is not built yet; "
                "see README (Windows) for build steps");
}

}  // namespace comics_editor

void EditorPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  comics_editor::EditorPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
