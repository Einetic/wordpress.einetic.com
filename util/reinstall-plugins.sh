#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

SITE_PATH="$1"

if [ -z "$SITE_PATH" ]; then
echo "Usage: reinstall-plugins.sh <site_path>"
exit 1
fi

echo "Scanning installed plugins..."

BAD_PLUGINS="wp-file-manager file-manager adminer wp-automatic wp-automatic-pro"

ACTIVE_PLUGINS=$(safe_wp "$SITE_PATH" plugin list --status=active --field=name 2>/dev/null)
INACTIVE_PLUGINS=$(safe_wp "$SITE_PATH" plugin list --status=inactive --field=name 2>/dev/null)

echo "Reinstalling active plugins..."

for plugin in $ACTIVE_PLUGINS
do

if echo "$BAD_PLUGINS" | grep -qw "$plugin"; then
echo "Skipping dangerous plugin $plugin"
safe_wp "$SITE_PATH" plugin deactivate "$plugin" >/dev/null 2>&1
safe_wp "$SITE_PATH" plugin delete "$plugin" >/dev/null 2>&1
continue
fi

echo "Reinstalling active plugin $plugin"
safe_wp "$SITE_PATH" plugin install "$plugin" --force --activate

done

echo "Reinstalling inactive plugins..."

for plugin in $INACTIVE_PLUGINS
do

if echo "$BAD_PLUGINS" | grep -qw "$plugin"; then
echo "Skipping dangerous plugin $plugin"
safe_wp "$SITE_PATH" plugin delete "$plugin" >/dev/null 2>&1
continue
fi

echo "Reinstalling inactive plugin $plugin"
safe_wp "$SITE_PATH" plugin install "$plugin" --force

done

echo "Plugin reinstall complete"