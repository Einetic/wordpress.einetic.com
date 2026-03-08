#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

SITE_PATH="$1"

if [ -z "$SITE_PATH" ]; then
echo "Usage: reinstall-plugins.sh <site_path>"
exit 1
fi

echo "Scanning installed plugins..."

ACTIVE_PLUGINS=$(safe_wp "$SITE_PATH" plugin list --status=active --field=name 2>/dev/null)
INACTIVE_PLUGINS=$(safe_wp "$SITE_PATH" plugin list --status=inactive --field=name 2>/dev/null)

echo "Reinstalling active plugins..."

for plugin in $ACTIVE_PLUGINS
do
echo "Reinstalling active plugin $plugin"
safe_wp "$SITE_PATH" plugin install "$plugin" --force --activate
done

echo "Reinstalling inactive plugins..."

for plugin in $INACTIVE_PLUGINS
do
echo "Reinstalling inactive plugin $plugin"
safe_wp "$SITE_PATH" plugin install "$plugin" --force
done

echo "Plugin reinstall complete"