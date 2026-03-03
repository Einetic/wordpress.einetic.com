#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

SITE_PATH="$1"

if [ -z "$SITE_PATH" ]; then
echo "Usage: reinstall-themes.sh <site_path>"
exit 1
fi

echo "Scanning themes..."

ACTIVE_THEME=$(safe_wp "$SITE_PATH" theme list --status=active --field=name 2>/dev/null | head -n1)

THEMES=$(safe_wp "$SITE_PATH" theme list --field=name 2>/dev/null)

if [ -z "$THEMES" ]; then
echo "No themes detected"
exit 0
fi

echo "Reinstalling themes..."

for theme in $THEMES
do
echo "Reinstalling $theme"
safe_wp "$SITE_PATH" theme install "$theme" --force
done

echo "Removing old default themes..."

for theme in $THEMES
do
if [[ "$theme" == twentytwenty* && "$theme" != "twentytwentyfive" ]]; then
echo "Removing $theme"
safe_wp "$SITE_PATH" theme delete "$theme" 2>/dev/null
fi
done

echo "Ensuring fallback theme exists"
safe_wp "$SITE_PATH" theme install twentytwentyfive --force

if [ -n "$ACTIVE_THEME" ]; then
echo "Refreshing active theme"
safe_wp "$SITE_PATH" theme activate twentytwentyfive
safe_wp "$SITE_PATH" theme activate "$ACTIVE_THEME"
else
echo "No active theme detected — activating twentytwentyfive"
safe_wp "$SITE_PATH" theme activate twentytwentyfive
fi

echo "Themes repaired"