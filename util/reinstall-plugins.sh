#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

SITE_PATH="$1"

if [ -z "$SITE_PATH" ]; then
echo "Usage: reinstall-plugins.sh <site_path>"
exit 1
fi

PLUGINS_DIR="$SITE_PATH/wp-content/plugins"
BACKUP_DIR="$SITE_PATH/wp-content/plugins-old"
LIST_FILE="$SITE_PATH/wp-content/plugin-list.txt"

FLEET_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FALLBACK_DIR="$FLEET_ROOT/plugin"

mkdir -p "$BACKUP_DIR"

echo "Step 1: Saving plugin list (append + unique)"
safe_wp "$SITE_PATH" plugin list --field=name >> "$LIST_FILE"
sort -u "$LIST_FILE" -o "$LIST_FILE"

echo "Step 2: Backup + zip plugins"
while read plugin
do
  SRC="$PLUGINS_DIR/$plugin"
  DEST="$BACKUP_DIR/$plugin"

  if [ -d "$SRC" ]; then
    rm -rf "$DEST"
    mv "$SRC" "$DEST"

    rm -f "$DEST.zip"
    zip -rq "$DEST.zip" "$DEST"
  fi
done < "$LIST_FILE"

echo "Step 3: Clean plugins directory FULL"
rm -rf "$PLUGINS_DIR"
mkdir -p "$PLUGINS_DIR"

echo "Step 4: Reinstall plugins"
while read plugin
do
  echo "Installing $plugin"

  safe_wp "$SITE_PATH" plugin install "$plugin" --force --activate >/dev/null 2>&1

  if [ $? -ne 0 ]; then
    FALLBACK="$FALLBACK_DIR/$plugin"

    if [ -d "$FALLBACK" ]; then
      echo "Fallback install $plugin"
      cp -r "$FALLBACK" "$PLUGINS_DIR/"
      safe_wp "$SITE_PATH" plugin activate "$plugin" >/dev/null 2>&1
    else
      echo "Missing plugin $plugin"
    fi
  fi

done < "$LIST_FILE"

echo "Plugin reinstall complete"