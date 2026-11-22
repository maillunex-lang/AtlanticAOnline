#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
archive="$work/addons.zip"
if [ "$#" -eq 1 ]; then
    cp "$1" "$archive"
else
    curl --fail --location --silent --show-error --retry 3 \
        https://github.com/2shady4u/godot-sqlite/releases/download/v4.9/addons.zip -o "$archive"
fi
printf '%s  %s\n' 95e91b72fe32984a84edaf6357a78753661f37a170cb362f5b948e0ede7c2cb0 "$archive" | sha256sum -c -
unzip -q "$archive" 'addons/godot-sqlite/bin/libgdsqlite.linux.*.x86_64.so' \
    'addons/godot-sqlite/LICENSE.md' -d "$work"
addon="$root/addons/godot-sqlite"
mkdir -p "$addon/bin"
cp "$work"/addons/godot-sqlite/bin/*.so "$addon/bin/"
cp "$work/addons/godot-sqlite/LICENSE.md" "$addon/"
cat > "$addon/gdsqlite.gdextension" <<'EXT'
[configuration]
entry_symbol = "sqlite_library_init"
compatibility_minimum = "4.7"

[libraries]
linux.debug.x86_64 = "res://addons/godot-sqlite/bin/libgdsqlite.linux.template_debug.x86_64.so"
linux.release.x86_64 = "res://addons/godot-sqlite/bin/libgdsqlite.linux.template_release.x86_64.so"
EXT
