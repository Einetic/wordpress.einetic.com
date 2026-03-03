#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

SITE_PATH="$1"

if [ -z "$SITE_PATH" ]; then
    echo "Usage: fix-wordpress.sh <site_path>"
    exit 1
fi

WP_CONTENT="$SITE_PATH/wp-content"

echo "Fixing WordPress at $SITE_PATH"

echo "Step 1: Reinstall WordPress core"
safe_wp "$SITE_PATH" core download --skip-content --force

echo "Step 2: Remove suspicious MU plugins"
rm -f "$WP_CONTENT/mu-plugins/"*.php 2>/dev/null

echo "Step 3: Reinstall plugins"
PLUGINS=$(safe_wp "$SITE_PATH" plugin list --field=name)

for plugin in $PLUGINS
do
    echo "Reinstalling plugin: $plugin"
    safe_wp "$SITE_PATH" plugin install "$plugin" --force
done

echo "Step 4: Reinstall themes"
THEMES=$(safe_wp "$SITE_PATH" theme list --field=name)

for theme in $THEMES
do
    echo "Reinstalling theme: $theme"
    safe_wp "$SITE_PATH" theme install "$theme" --force
done

echo "Step 5: Regenerate salts"
safe_wp "$SITE_PATH" config shuffle-salts

echo "Step 6: Optimize database"
safe_wp "$SITE_PATH" db optimize

echo "Step 7: Clear cache directories"
rm -rf "$WP_CONTENT/cache" 2>/dev/null
rm -rf "$WP_CONTENT/litespeed" 2>/dev/null
rm -rf "$WP_CONTENT/uploads/cache" 2>/dev/null

echo "WordPress repair complete"