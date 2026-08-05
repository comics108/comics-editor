#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
executable="${1:-}"
if [[ "$executable" != /* || ! -f "$executable" ]]; then
  echo "Usage: $0 /absolute/path/to/comics_editor" >&2
  exit 2
fi
if [[ "$executable" == *'"'* || "$executable" == *'\\'* || "$executable" == *$'\n'* ]]; then
  echo "Unsupported character in executable path" >&2
  exit 2
fi

data_home="${XDG_DATA_HOME:-${HOME}/.local/share}"
applications_dir="$data_home/applications"
mime_packages_dir="$data_home/mime/packages"
desktop_target="$applications_dir/net.nativemind.comics.editor.desktop"
mime_target="$mime_packages_dir/net.nativemind.comics.editor.xml"

mkdir -p "$applications_dir" "$mime_packages_dir"
escaped_executable="${executable//&/\\&}"
escaped_executable="${escaped_executable//|/\\|}"
sed "s|@EXECUTABLE@|$escaped_executable|g" \
  "$script_dir/net.nativemind.comics.editor.desktop.in" > "$desktop_target"
chmod 0644 "$desktop_target"
install -m 0644 "$script_dir/net.nativemind.comics.editor.xml" "$mime_target"

if command -v update-mime-database >/dev/null 2>&1; then
  update-mime-database "$data_home/mime"
fi
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$applications_dir"
fi

echo "Registered Comics Editor for the current user."
