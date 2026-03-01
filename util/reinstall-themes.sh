#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

SITE_PATH="$1"

THEMES=$(wp_exec "$SITE_PATH" theme list --field=name --skip-plugins --skip-themes)

for theme in $THEMES
do
    wp_exec "$SITE_PATH" theme install "$theme" --force --skip-plugins --skip-themes
done