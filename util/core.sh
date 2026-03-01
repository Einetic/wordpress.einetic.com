#!/bin/bash

wp_exec() {

    SITE_PATH="$1"
    shift

    COMMAND="$@"

    if [[ "$SITE_PATH" == /home/*/htdocs/* ]]; then
        # CloudPanel style
        USER=$(echo "$SITE_PATH" | cut -d'/' -f3)

        sudo -u "$USER" -- wp $COMMAND --path="$SITE_PATH"

    elif [[ "$SITE_PATH" == */domains/*/public_html ]]; then
        # Hostinger style
        wp $COMMAND --path="$SITE_PATH"

    else
        echo "Unknown hosting structure for $SITE_PATH"
        exit 1
    fi
}