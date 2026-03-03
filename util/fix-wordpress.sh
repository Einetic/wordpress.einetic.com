#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

SITE="$1"

if [ -z "$SITE" ]; then
echo "Usage: fix-wordpress.sh <site_path>"
exit 1
fi

echo "Fixing WordPress at $SITE"

echo "Step 1: Reinstall WordPress core"
safe_wp "$SITE" core download --skip-content --force

echo "Step 2: Remove suspicious MU plugins"
rm -rf "$SITE/wp-content/mu-plugins" 2>/dev/null

echo "Step 3: Reinstall plugins"
bash "$SCRIPT_DIR/reinstall-plugins.sh" "$SITE"

echo "Step 4: Reinstall themes"
bash "$SCRIPT_DIR/reinstall-themes.sh" "$SITE"

echo "Step 5: Regenerate salts"
safe_wp "$SITE" config shuffle-salts

echo "Step 6: Optimize database"
safe_wp "$SITE" db optimize

echo "Step 7: Clear cache directories"
rm -rf "$SITE/wp-content/cache" 2>/dev/null
rm -rf "$SITE/wp-content/litespeed" 2>/dev/null
rm -rf "$SITE/wp-content/uploads/cache" 2>/dev/null

echo "WordPress repair complete"