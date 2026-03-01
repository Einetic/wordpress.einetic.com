#!/bin/bash

SITE_PATH="$1"
shift

WP_COMMAND="$@"

if [[ "$SITE_PATH" == /home/*/htdocs/* ]]; then
    # CloudPanel style
    USER=$(echo "$SITE_PATH" | cut -d'/' -f3)

    sudo -u "$USER" -- wp $WP_COMMAND --path="$SITE_PATH"

elif [[ "$SITE_PATH" == */domains/*/public_html ]]; then
    # Hostinger style
    wp $WP_COMMAND --path="$SITE_PATH"

else
    echo "Unknown hosting structure"
    exit 1
fi