// SDD sdd-comics-editor-v2.9-fixes2, Track A. .NET hosting bootstrap for the
// Windows editor_plugin — loads Comics.Editor.Flutter.dll (framework-dependent,
// published next to the exe by windows/runner/CMakeLists.txt's POST_BUILD
// step) via the hostfxr/nethost hosting API and calls its NativeExports.
//
// hostfxr.dll is resolved manually (DOTNET_ROOT / "C:\Program Files\dotnet" +
// host\fxr\<highest version>) instead of via the Microsoft.NETCore.DotNetAppHost
// NuGet package's nethost.h/nethost.lib — this is a plain CMake C++ project,
// not an MSBuild-based one with PackageReference support, so pulling in a
// NuGet-sourced header/import-lib isn't a natural fit. The hostfxr ABI used
// here (hostfxr_initialize_for_runtime_config / hostfxr_get_runtime_delegate /
// hostfxr_close, and the load_assembly_and_get_function_pointer delegate) is
// small, stable, and documented by Microsoft — declared by hand below rather
// than vendoring the full official header for three functions.

#ifndef COMICS_EDITOR_HOSTFXR_BOOTSTRAP_H_
#define COMICS_EDITOR_HOSTFXR_BOOTSTRAP_H_

#include <string>

namespace comics_editor {

// Resolves the full path to hostfxr.dll. Returns false if it can't be found
// (e.g. no .NET runtime installed). Exposed mainly for testing/diagnostics —
// EnsureHostInitialized() is the normal entry point.
bool ResolveHostFxrPath(std::wstring& outPath);

// Lazily initializes the .NET host and resolves+caches the NativeExports
// function pointers (HandleMethodCall/FreeResultString). Safe to call on
// every method invocation — it's a no-op after the first successful call.
// Returns false and fills outError on any failure (missing runtime, missing
// Comics.Editor.Flutter.dll, failed delegate resolution, etc.) — callers
// should surface this as a method-channel error, not crash.
bool EnsureHostInitialized(std::wstring& outError);

// Calls the cached HandleMethodCall delegate and returns its JSON result.
// EnsureHostInitialized() must have returned true before calling this.
std::wstring CallHandleMethodCall(const std::wstring& method,
                                   const std::wstring* argsJson);

}  // namespace comics_editor

#endif  // COMICS_EDITOR_HOSTFXR_BOOTSTRAP_H_
