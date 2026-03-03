#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

SITE_PATH="$1"

LATEST_TWENTY="twentytwentyfive"

ACTIVE_THEME=$(safe_wp "$SITE_PATH" theme list --status=active --field=name)

THEMES=$(safe_wp "$SITE_PATH" theme list --field=name)

for theme in $THEMES
do
safe_wp "$SITE_PATH" theme install "$theme" --force
done

safe_wp "$SITE_PATH" theme install "$LATEST_TWENTY" > /dev/null 2>&1

THEMES=$(safe_wp "$SITE_PATH" theme list --field=name)

for theme in $THEMES
do

if [[ "$theme" == twentytwenty* && "$theme" != "$LATEST_TWENTY" ]]; then
safe_wp "$SITE_PATH" theme delete "$theme"
fi

done

safe_wp "$SITE_PATH" theme activate "$ACTIVE_THEME"

safe_wp "$SITE_PATH" rewrite flush --hard

echo "Themes repaired"