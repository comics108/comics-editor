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
    # Требуется: sudo dotnet workload install ios
    dotnet publish "$proj" -c Release -r ios-arm64 -f net10.0-ios \
      -p:IncludeIos=true -p:NativeLib=Static -p:PublishAot=true \
      -o "$out_base/ios-arm64"
    mkdir -p ios/ComicsCore
    cp "$out_base/ios-arm64/Comics.Editor.a" ios/ComicsCore/libComicsCore.a
    echo "Copied: ios/ComicsCore/libComicsCore.a"
    ;;

  *)
    echo "Unknown target: $1 (osx|android|ios)" >&2; exit 1 ;;
esac
