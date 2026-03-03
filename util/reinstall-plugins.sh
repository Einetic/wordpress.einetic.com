#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

SITE_PATH="$1"

WP_CONTENT="$SITE_PATH/wp-content"

# disable problematic dropins
[ -f "$WP_CONTENT/object-cache.php" ] && mv "$WP_CONTENT/object-cache.php" "$WP_CONTENT/object-cache.php.bak"
[ -f "$WP_CONTENT/advanced-cache.php" ] && mv "$WP_CONTENT/advanced-cache.php" "$WP_CONTENT/advanced-cache.php.bak"

# disable mu plugins temporarily
if [ -d "$WP_CONTENT/mu-plugins" ]; then
    mv "$WP_CONTENT/mu-plugins" "$WP_CONTENT/mu-plugins.bak"
fi

PLUGINS=$(wp_exec "$SITE_PATH" plugin list --field=name --skip-plugins --skip-themes)

for plugin in $PLUGINS
do
    echo "Reinstalling $plugin"
    wp_exec "$SITE_PATH" plugin install "$plugin" --force --skip-plugins --skip-themes
done

# restore files
[ -f "$WP_CONTENT/object-cache.php.bak" ] && mv "$WP_CONTENT/object-cache.php.bak" "$WP_CONTENT/object-cache.php"
[ -f "$WP_CONTENT/advanced-cache.php.bak" ] && mv "$WP_CONTENT/advanced-cache.php.bak" "$WP_CONTENT/advanced-cache.php"

[ -d "$WP_CONTENT/mu-plugins.bak" ] && mv "$WP_CONTENT/mu-plugins.bak" "$WP_CONTENT/mu-plugins"

echo "Plugin reinstall complete"