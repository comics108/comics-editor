#!/usr/bin/env bash
# SDD sdd-comics-editor-v2.9-android-ios: публикация NativeAOT-библиотек ядра
# (Comics.Editor.Native) для FFI.
#
# Использование:
#   tool/build_native.sh osx       # dylib для AOT-тестов на хосте (обязательный шаг)
#   tool/build_native.sh android   # .so → android/app/src/main/jniLibs/{arm64-v8a,x86_64}
#                                  #   требует Android NDK: export ANDROID_NDK_HOME=…
#   tool/build_native.sh ios       # static .a → ios/ComicsCore/ (требует Xcode;
#                                  #   при ошибке SDK: dotnet workload install ios)

set -euo pipefail
cd "$(dirname "$0")/.."

proj=native/Comics.Editor.Native/Comics.Editor.Native.csproj
out_base=native/Comics.Editor.Native/publish

publish() { # rid, NativeLib kind, extra props...
  local rid="$1" kind="$2"; shift 2
  dotnet publish "$proj" -c Release -r "$rid" -p:NativeLib="$kind" "$@" \
    -o "$out_base/$rid"
}

case "${1:-osx}" in
  osx)
    case "$(uname -m)" in
      arm64) rid=osx-arm64 ;;
      *) rid=osx-x64 ;;
    esac
    publish "$rid" Shared
    echo "Published: $out_base/$rid/Comics.Editor.dylib"
    ;;

  android)
    : "${ANDROID_NDK_HOME:?Set ANDROID_NDK_HOME to your NDK path}"
    for pair in "linux-bionic-arm64:arm64-v8a" "linux-bionic-x64:x86_64"; do
      rid="${pair%%:*}"; abi="${pair##*:}"
      publish "$rid" Shared -p:DisableUnsupportedError=true
      dst="android/app/src/main/jniLibs/$abi"
      mkdir -p "$dst"
      cp "$out_base/$rid/Comics.Editor.so" "$dst/libcomicscore.so"
      echo "Copied: $dst/libcomicscore.so"
    done
    ;;

  ios)
    # ЗАБЛОКИРОВАНО (проверено эмпирически, .NET 10 SDK 10.0.302 + `dotnet workload
    # install ios`): CoreCLR NativeAOT (ILCompiler, нужен для UnmanagedCallersOnly
    # C-экспортов comics_call/comics_free) НЕ поддерживает RID ios-arm64 в публично
    # доступной поставке .NET 10 — `dotnet publish -r ios-arm64 -p:PublishAot=true`
    # на TargetFramework=net10.0 падает с NETSDK1203 даже после установки workload.
    # `dotnet workload install ios` ставит ДРУГОЙ пайплайн — Mono-AOT для приложений
    # (Microsoft.iOS.Sdk, TargetFramework=net10.0-ios) — им нельзя собрать голую
    # статическую библиотеку с нужными C-экспортами; отдельного пакета
    # Microsoft.DotNet.ILCompiler.LLVM (cross-компилятор для Apple-mobile RID) на
    # публичном nuget.org нет. Т.е. это архитектурный вопрос (см. Open Questions в
    # 01-requirements.md flows/sdd-comics-editor-v2.9-android-ios), а не команда сборки.
    echo "iOS NativeAOT недоступен в текущей поставке .NET 10 — см. README (раздел iOS)" >&2
    exit 1
    ;;

  *)
    echo "Unknown target: $1 (osx|android|ios)" >&2; exit 1 ;;
esac
