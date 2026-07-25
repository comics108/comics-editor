#include "hostfxr_bootstrap.h"

#include <windows.h>

#include <algorithm>
#include <cstdint>
#include <cwchar>
#include <vector>

namespace comics_editor {

namespace {

// ---- hostfxr ABI (stable, documented by Microsoft) ----
// https://github.com/dotnet/runtime/blob/main/src/native/corehost/hostfxr.h
using hostfxr_handle = void*;

struct hostfxr_initialize_parameters {
  size_t size;
  const wchar_t* host_path;
  const wchar_t* dotnet_root;
};

enum hostfxr_delegate_type {
  hdt_com_activation = 0,
  hdt_load_in_memory_assembly = 1,
  hdt_winrt_activation = 2,
  hdt_com_register = 3,
  hdt_com_unregister = 4,
  hdt_load_assembly_and_get_function_pointer = 5,
  hdt_get_function_pointer = 6,
  hdt_load_assembly = 7,
  hdt_load_assembly_bytes = 8,
};

using hostfxr_initialize_for_runtime_config_fn = int32_t(__cdecl*)(
    const wchar_t* runtime_config_path,
    const hostfxr_initialize_parameters* parameters,
    hostfxr_handle* host_context_handle);

using hostfxr_get_runtime_delegate_fn = int32_t(__cdecl*)(
    hostfxr_handle host_context_handle, hostfxr_delegate_type type,
    void** delegate_out);

using hostfxr_close_fn = int32_t(__cdecl*)(hostfxr_handle host_context_handle);

// Signature of the hdt_load_assembly_and_get_function_pointer delegate.
using load_assembly_and_get_function_pointer_fn = int32_t(__cdecl*)(
    const wchar_t* assembly_path, const wchar_t* type_name,
    const wchar_t* method_name, const wchar_t* delegate_type_name,
    void* reserved, void** delegate_out);

// Sentinel meaning "the target method is [UnmanagedCallersOnly], don't look
// up a named delegate type" — documented value, not a real pointer.
const wchar_t* const kUnmanagedCallersOnlyMethod =
    reinterpret_cast<const wchar_t*>(static_cast<intptr_t>(-1));

// Our two exports (native/Comics.Editor.Flutter/NativeExports.cs). Both are
// `IntPtr` on the C# side, which is a raw pointer-sized value at the ABI
// level — declared as `void*` here and reinterpreted as a wide-char buffer
// only where we actually read/write string contents.
using handle_method_call_fn = void*(__cdecl*)(const void* method,
                                               const void* args_json);
using free_result_string_fn = void(__cdecl*)(void* ptr);

bool g_initialized = false;
handle_method_call_fn g_handle_method_call = nullptr;
free_result_string_fn g_free_result_string = nullptr;

std::wstring ExeDirectory() {
  wchar_t path[MAX_PATH];
  DWORD len = GetModuleFileNameW(nullptr, path, MAX_PATH);
  std::wstring full(path, len);
  auto pos = full.find_last_of(L"\\/");
  return pos == std::wstring::npos ? L"." : full.substr(0, pos);
}

}  // namespace

bool ResolveHostFxrPath(std::wstring& outPath) {
  std::wstring root;
  wchar_t envBuf[MAX_PATH];
  DWORD envLen = GetEnvironmentVariableW(L"DOTNET_ROOT", envBuf, MAX_PATH);
  if (envLen > 0 && envLen < MAX_PATH) {
    root = envBuf;
  } else {
    root = L"C:\\Program Files\\dotnet";
  }

  std::wstring fxrDir = root + L"\\host\\fxr";
  std::wstring searchPattern = fxrDir + L"\\*";
  WIN32_FIND_DATAW findData;
  HANDLE hFind = FindFirstFileW(searchPattern.c_str(), &findData);
  if (hFind == INVALID_HANDLE_VALUE) return false;

  std::vector<std::wstring> versions;
  do {
    if ((findData.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) &&
        wcscmp(findData.cFileName, L".") != 0 &&
        wcscmp(findData.cFileName, L"..") != 0) {
      versions.push_back(findData.cFileName);
    }
  } while (FindNextFileW(hFind, &findData));
  FindClose(hFind);

  if (versions.empty()) return false;
  // Lexicographic max is good enough: version folder names are consistently
  // formatted (e.g. "10.0.302"), and this repo pins a single .NET SDK
  // version (see tool/build_headless.ps1), so there's normally exactly one
  // candidate anyway.
  std::sort(versions.begin(), versions.end());
  outPath = fxrDir + L"\\" + versions.back() + L"\\hostfxr.dll";
  return true;
}

bool EnsureHostInitialized(std::wstring& outError) {
  if (g_initialized) return true;

  std::wstring hostfxrPath;
  if (!ResolveHostFxrPath(hostfxrPath)) {
    outError = L"hostfxr.dll not found (checked DOTNET_ROOT / "
               L"C:\\Program Files\\dotnet\\host\\fxr)";
    return false;
  }

  HMODULE hostfxrModule = LoadLibraryW(hostfxrPath.c_str());
  if (!hostfxrModule) {
    outError = L"failed to load hostfxr.dll at " + hostfxrPath;
    return false;
  }

  auto init_fn = reinterpret_cast<hostfxr_initialize_for_runtime_config_fn>(
      GetProcAddress(hostfxrModule, "hostfxr_initialize_for_runtime_config"));
  auto get_delegate_fn = reinterpret_cast<hostfxr_get_runtime_delegate_fn>(
      GetProcAddress(hostfxrModule, "hostfxr_get_runtime_delegate"));
  auto close_fn = reinterpret_cast<hostfxr_close_fn>(
      GetProcAddress(hostfxrModule, "hostfxr_close"));
  if (!init_fn || !get_delegate_fn || !close_fn) {
    outError = L"hostfxr.dll at " + hostfxrPath + L" is missing expected exports";
    return false;
  }

  std::wstring exeDir = ExeDirectory();
  std::wstring runtimeConfigPath =
      exeDir + L"\\dotnet\\Comics.Editor.Flutter.runtimeconfig.json";
  std::wstring assemblyPath = exeDir + L"\\dotnet\\Comics.Editor.Flutter.dll";

  hostfxr_handle hostContext = nullptr;
  int32_t rc = init_fn(runtimeConfigPath.c_str(), nullptr, &hostContext);
  if (rc != 0 || hostContext == nullptr) {
    outError = L"hostfxr_initialize_for_runtime_config failed (rc=" +
               std::to_wstring(rc) + L"), config=" + runtimeConfigPath;
    if (hostContext) close_fn(hostContext);
    return false;
  }

  void* loadAssemblyDelegate = nullptr;
  rc = get_delegate_fn(hostContext, hdt_load_assembly_and_get_function_pointer,
                        &loadAssemblyDelegate);
  if (rc != 0 || loadAssemblyDelegate == nullptr) {
    outError =
        L"hostfxr_get_runtime_delegate failed (rc=" + std::to_wstring(rc) + L")";
    close_fn(hostContext);
    return false;
  }

  auto load_assembly_and_get_function_pointer =
      reinterpret_cast<load_assembly_and_get_function_pointer_fn>(
          loadAssemblyDelegate);

  // The context handle isn't needed once we have the delegate — the runtime
  // stays loaded for the process lifetime regardless (documented hostfxr
  // behavior; matches Microsoft's own native hosting sample).
  close_fn(hostContext);

  const wchar_t* typeName = L"Comics.Editor.Flutter.NativeExports, Comics.Editor.Flutter";

  void* handleMethodCallPtr = nullptr;
  rc = load_assembly_and_get_function_pointer(
      assemblyPath.c_str(), typeName, L"HandleMethodCall",
      kUnmanagedCallersOnlyMethod, nullptr, &handleMethodCallPtr);
  if (rc != 0 || handleMethodCallPtr == nullptr) {
    outError = L"failed to resolve NativeExports.HandleMethodCall (rc=" +
               std::to_wstring(rc) + L"), assembly=" + assemblyPath;
    return false;
  }

  void* freeResultStringPtr = nullptr;
  rc = load_assembly_and_get_function_pointer(
      assemblyPath.c_str(), typeName, L"FreeResultString",
      kUnmanagedCallersOnlyMethod, nullptr, &freeResultStringPtr);
  if (rc != 0 || freeResultStringPtr == nullptr) {
    outError = L"failed to resolve NativeExports.FreeResultString (rc=" +
               std::to_wstring(rc) + L")";
    return false;
  }

  g_handle_method_call =
      reinterpret_cast<handle_method_call_fn>(handleMethodCallPtr);
  g_free_result_string =
      reinterpret_cast<free_result_string_fn>(freeResultStringPtr);
  g_initialized = true;
  return true;
}

std::wstring CallHandleMethodCall(const std::wstring& method,
                                   const std::wstring* argsJson) {
  if (!g_handle_method_call) {
    return L"{\"error\":\"interop_not_initialized\"}";
  }
  void* resultPtr = g_handle_method_call(
      method.c_str(), argsJson ? argsJson->c_str() : nullptr);
  if (!resultPtr) {
    return L"{\"error\":\"interop_null_result\"}";
  }
  std::wstring result(reinterpret_cast<const wchar_t*>(resultPtr));
  if (g_free_result_string) g_free_result_string(resultPtr);
  return result;
}

}  // namespace comics_editor
