#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

SITE_PATH="$1"

if [ -z "$SITE_PATH" ]; then
echo "Usage: reinstall-themes.sh <site_path>"
exit 1
fi

ACTIVE_THEME=$(safe_wp "$SITE_PATH" theme list --status=active --field=name)

THEMES=$(safe_wp "$SITE_PATH" theme list --field=name)

for theme in $THEMES
do
echo "Reinstalling $theme"
safe_wp "$SITE_PATH" theme install "$theme" --force
done

# remove old default themes
for theme in $THEMES
do
if [[ "$theme" == twentytwenty* && "$theme" != "twentytwentyfive" ]]; then
safe_wp "$SITE_PATH" theme delete "$theme"
fi
done

# ensure fallback theme exists
safe_wp "$SITE_PATH" theme install twentytwentyfive --force

# force refresh theme activation
safe_wp "$SITE_PATH" theme activate twentytwentyfive
safe_wp "$SITE_PATH" theme activate "$ACTIVE_THEME"

echo "Themes repaired"