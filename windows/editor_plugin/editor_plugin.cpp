#include "include/editor_plugin.h"

#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

#include "hostfxr_bootstrap.h"

namespace comics_editor {

namespace {

// UTF-8 (Flutter's std::string method names) <-> UTF-16 (.NET string ABI,
// what hostfxr_bootstrap.h works in) conversions. Small enough to keep local
// rather than pulling in a JSON/text-encoding library for this alone.
std::wstring Utf8ToWide(const std::string& s) {
  if (s.empty()) return std::wstring();
  int size = MultiByteToWideChar(CP_UTF8, 0, s.c_str(), static_cast<int>(s.size()),
                                  nullptr, 0);
  std::wstring result(size, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, s.c_str(), static_cast<int>(s.size()), &result[0],
                       size);
  return result;
}

std::string WideToUtf8(const std::wstring& s) {
  if (s.empty()) return std::string();
  int size = WideCharToMultiByte(CP_UTF8, 0, s.c_str(), static_cast<int>(s.size()),
                                 nullptr, 0, nullptr, nullptr);
  std::string result(size, '\0');
  WideCharToMultiByte(CP_UTF8, 0, s.c_str(), static_cast<int>(s.size()), &result[0],
                      size, nullptr, nullptr);
  return result;
}

// MethodChannelHandler.HandleMethodCall (C#) always returns one of exactly
// two shapes: {"success":true} or {"error":"...","message":"..."} — see
// native/Comics.Editor.Flutter/MethodChannelHandler.cs and NativeExports.cs's
// catch-fallback. Checking for a literal leading `{"error"` is enough; this
// isn't parsing arbitrary/untrusted JSON, both ends of this protocol are ours.
bool IsErrorResult(const std::wstring& json) {
  const std::wstring prefix = L"{\"error\"";
  return json.compare(0, prefix.size(), prefix) == 0;
}

}  // namespace

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
  std::wstring initError;
  if (!EnsureHostInitialized(initError)) {
    result->Error("interop_init_failed", WideToUtf8(initError));
    return;
  }

  // sdd-comics-editor-v2.9-fixes2 (Track A): the only two methods the Dart
  // side currently calls (see lib/src/bridge/wpf_editor_view.dart) are
  // "create"/"dispose", both invoked with no arguments — so a full
  // EncodableValue -> JSON serializer for method_call.arguments() isn't
  // implemented here (see 02-specifications.md, Won't Have). Once a real
  // caller needs to pass arguments, this is the place to add it.
  std::wstring method = Utf8ToWide(method_call.method_name());
  std::wstring json = CallHandleMethodCall(method, nullptr);

  if (IsErrorResult(json)) {
    result->Error("comics_editor_flutter_error", WideToUtf8(json));
  } else {
    result->Success(flutter::EncodableValue(WideToUtf8(json)));
  }
}

}  // namespace comics_editor

void EditorPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  comics_editor::EditorPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
