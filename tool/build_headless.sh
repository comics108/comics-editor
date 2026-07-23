#!/usr/bin/env bash
# SDD sdd-comics-editor-v2.9: публикация headless-ядра (self-contained).
#
# Использование:
#   tool/build_headless.sh            # RID текущей машины
#   tool/build_headless.sh linux-x64  # явный RID (osx-arm64|osx-x64|linux-x64|linux-arm64|win-x64)
#
# Результат: native/Comics.Editor.Headless/publish/<rid>/Comics.Editor
# Если рядом есть собранный Flutter-бандл (flutter build macos/linux),
# бинарник дополнительно копируется в его ресурсы.

set -euo pipefail
cd "$(dirname "$0")/.."

rid="${1:-}"
if [[ -z "$rid" ]]; then
  case "$(uname -s)-$(uname -m)" in
    Darwin-arm64) rid=osx-arm64 ;;
    Darwin-x86_64) rid=osx-x64 ;;
    Linux-x86_64) rid=linux-x64 ;;
    Linux-aarch64) rid=linux-arm64 ;;
    *) echo "Unknown host, pass RID explicitly" >&2; exit 1 ;;
  esac
fi

out="native/Comics.Editor.Headless/publish/$rid"
dotnet publish native/Comics.Editor.Headless/Comics.Editor.Headless.csproj \
  -c Release -r "$rid" --self-contained true \
  -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true \
  -o "$out"

echo "Published: $out/Comics.Editor"

# Копия в готовые Flutter-бандлы (если уже собраны)
mac_app=$(ls -d build/macos/Build/Products/*/comics_editor.app 2>/dev/null | head -1 || true)
if [[ -n "$mac_app" && "$rid" == osx-* ]]; then
  mkdir -p "$mac_app/Contents/Resources/comics-core"
  cp "$out/Comics.Editor" "$mac_app/Contents/Resources/comics-core/"
  echo "Copied into $mac_app/Contents/Resources/comics-core/"
fi

linux_bundle=$(ls -d build/linux/*/release/bundle 2>/dev/null | head -1 || true)
if [[ -n "$linux_bundle" && "$rid" == linux-* ]]; then
  mkdir -p "$linux_bundle/data/comics-core"
  cp "$out/Comics.Editor" "$linux_bundle/data/comics-core/"
  echo "Copied into $linux_bundle/data/comics-core/"
fi
