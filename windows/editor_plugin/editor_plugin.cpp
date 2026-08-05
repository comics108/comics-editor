#include "include/editor_plugin.h"

#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>
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

std::string EscapeJson(const std::string& value) {
  std::ostringstream stream;
  for (const char character : value) {
    switch (character) {
      case '\\': stream << "\\\\"; break;
      case '"': stream << "\\\""; break;
      case '\n': stream << "\\n"; break;
      case '\r': stream << "\\r"; break;
      case '\t': stream << "\\t"; break;
      default: stream << character; break;
    }
  }
  return stream.str();
}

std::string ValueToJson(const flutter::EncodableValue& value) {
  if (std::holds_alternative<std::monostate>(value)) return "null";
  if (const auto* boolean = std::get_if<bool>(&value))
    return *boolean ? "true" : "false";
  if (const auto* integer = std::get_if<int32_t>(&value))
    return std::to_string(*integer);
  if (const auto* integer = std::get_if<int64_t>(&value))
    return std::to_string(*integer);
  if (const auto* number = std::get_if<double>(&value)) {
    std::ostringstream stream;
    stream.precision(17);
    stream << *number;
    return stream.str();
  }
  if (const auto* string = std::get_if<std::string>(&value))
    return "\"" + EscapeJson(*string) + "\"";
  if (const auto* map = std::get_if<flutter::EncodableMap>(&value)) {
    std::ostringstream stream;
    stream << "{";
    bool first = true;
    for (const auto& entry : *map) {
      const auto* key = std::get_if<std::string>(&entry.first);
      if (key == nullptr) continue;
      if (!first) stream << ",";
      first = false;
      stream << "\"" << EscapeJson(*key) << "\":" << ValueToJson(entry.second);
    }
    stream << "}";
    return stream.str();
  }
  return "null";
}

std::string ArgumentsToJson(const flutter::EncodableValue* arguments,
                            HWND parent_window,
                            bool inject_parent) {
  flutter::EncodableMap map;
  if (arguments != nullptr) {
    if (const auto* input = std::get_if<flutter::EncodableMap>(arguments))
      map = *input;
  }
  if (inject_parent) {
    map[flutter::EncodableValue("parentHwnd")] =
        flutter::EncodableValue(static_cast<int64_t>(
            reinterpret_cast<intptr_t>(parent_window)));
  }
  return ValueToJson(flutter::EncodableValue(map));
}

}  // namespace

void EditorPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "comics_editor",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<EditorPlugin>(
      registrar->GetView()->GetNativeWindow());

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

EditorPlugin::EditorPlugin(HWND parent_window) : parent_window_(parent_window) {}

EditorPlugin::~EditorPlugin() {}

void EditorPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  std::wstring initError;
  if (!EnsureHostInitialized(initError)) {
    result->Error("interop_init_failed", WideToUtf8(initError));
    return;
  }

  std::wstring method = Utf8ToWide(method_call.method_name());
  const std::string arguments_json = ArgumentsToJson(
      method_call.arguments(), parent_window_, method_call.method_name() == "create");
  const std::wstring wide_arguments = Utf8ToWide(arguments_json);
  std::wstring json = CallHandleMethodCall(method, &wide_arguments);

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
