#!/usr/bin/env bash
set -euo pipefail

data_home="${XDG_DATA_HOME:-${HOME}/.local/share}"
applications_dir="$data_home/applications"
mime_root="$data_home/mime"

rm -f -- \
  "$applications_dir/net.nativemind.comics.editor.desktop" \
  "$mime_root/packages/net.nativemind.comics.editor.xml"

if command -v update-mime-database >/dev/null 2>&1 && [[ -d "$mime_root" ]]; then
  update-mime-database "$mime_root"
fi
if command -v update-desktop-database >/dev/null 2>&1 && [[ -d "$applications_dir" ]]; then
  update-desktop-database "$applications_dir"
fi

echo "Removed Comics Editor file-association metadata for the current user."
