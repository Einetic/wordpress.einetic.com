#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

SITE_PATH="$1"

if [ -z "$SITE_PATH" ]; then
echo "Usage: reinstall-themes.sh <site_path>"
exit 1
fi

THEMES_DIR="$SITE_PATH/wp-content/themes"
BACKUP_DIR="$SITE_PATH/wp-content/themes-old"
LIST_FILE="$SITE_PATH/wp-content/theme-list.txt"

FLEET_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FALLBACK_DIR="$FLEET_ROOT/theme"

mkdir -p "$BACKUP_DIR"
touch "$LIST_FILE"

echo "Step 1: Save theme list (append + unique)"
safe_wp "$SITE_PATH" theme list --field=name 2>/dev/null >> "$LIST_FILE"
sort -u "$LIST_FILE" -o "$LIST_FILE"

ACTIVE_THEME=$(safe_wp "$SITE_PATH" theme list --status=active --field=name 2>/dev/null | head -n1)

echo "Step 2: Backup + zip themes"
while IFS= read -r theme
do
  [ -z "$theme" ] && continue

  SRC="$THEMES_DIR/$theme"
  DEST="$BACKUP_DIR/$theme"

  if [ -d "$SRC" ]; then
    rm -rf "$DEST"
    mv "$SRC" "$DEST"

    rm -f "$DEST.zip"
    zip -rq "$DEST.zip" "$DEST"
  fi
done < "$LIST_FILE"

echo "Step 3: Clean themes directory FULL"
rm -rf "$THEMES_DIR"
mkdir -p "$THEMES_DIR"

echo "Step 4: Reinstall themes"
while IFS= read -r theme
do
  [ -z "$theme" ] && continue

  echo "Installing $theme"

  safe_wp "$SITE_PATH" theme install "$theme" --force >/dev/null 2>&1

  if [ $? -ne 0 ]; then
    FALLBACK="$FALLBACK_DIR/$theme"

    if [ -d "$FALLBACK" ]; then
      echo "Fallback install $theme"
      cp -r "$FALLBACK" "$THEMES_DIR/"
    else
      echo "Missing theme $theme"
      continue
    fi
  fi

done < "$LIST_FILE"

echo "Step 5: Ensure fallback theme"
safe_wp "$SITE_PATH" theme install twentytwentyfive --force >/dev/null 2>&1

echo "Step 6: Activate theme safely"
safe_wp "$SITE_PATH" theme activate twentytwentyfive >/dev/null 2>&1

if [ -n "$ACTIVE_THEME" ]; then
  safe_wp "$SITE_PATH" theme activate "$ACTIVE_THEME" >/dev/null 2>&1
fi

echo "Step 7: Cleanup old default themes"
while IFS= read -r theme
do
  [ -z "$theme" ] && continue

  if [[ "$theme" == twentytwenty* && "$theme" != "twentytwentyfive" ]]; then
    safe_wp "$SITE_PATH" theme delete "$theme" >/dev/null 2>&1
  fi
done < "$LIST_FILE"

echo "Step 8: Flush cache"
safe_wp "$SITE_PATH" rewrite flush --hard >/dev/null 2>&1
safe_wp "$SITE_PATH" elementor flush_css >/dev/null 2>&1

echo "Themes reinstall complete"