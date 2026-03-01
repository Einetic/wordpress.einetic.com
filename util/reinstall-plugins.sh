#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

SITE_PATH="$1"

PLUGINS=$(wp_exec "$SITE_PATH" plugin list --field=name)

for plugin in $PLUGINS
do
    wp_exec "$SITE_PATH" plugin install "$plugin" --force
done