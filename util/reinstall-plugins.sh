#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

SITE_PATH="$1"

if [ -z "$SITE_PATH" ]; then
echo "Usage: reinstall-plugins.sh <site_path>"
exit 1
fi

PLUGINS=$(safe_wp "$SITE_PATH" plugin list --field=name)

for plugin in $PLUGINS
do
echo "Reinstalling $plugin"
safe_wp "$SITE_PATH" plugin install "$plugin" --force
done

echo "Plugin reinstall complete"