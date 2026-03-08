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

safe_wp() {

SITE="$1"
shift
CMD="$@"

WP_CONTENT="$SITE/wp-content"

[ -f "$WP_CONTENT/object-cache.php" ] && mv "$WP_CONTENT/object-cache.php" "$WP_CONTENT/object-cache.php.bak"
[ -f "$WP_CONTENT/advanced-cache.php" ] && mv "$WP_CONTENT/advanced-cache.php" "$WP_CONTENT/advanced-cache.php.bak"
[ -d "$WP_CONTENT/mu-plugins" ] && mv "$WP_CONTENT/mu-plugins" "$WP_CONTENT/mu-plugins.bak"

wp_exec "$SITE" $CMD --skip-plugins --skip-themes

[ -f "$WP_CONTENT/object-cache.php.bak" ] && mv "$WP_CONTENT/object-cache.php.bak" "$WP_CONTENT/object-cache.php"
[ -f "$WP_CONTENT/advanced-cache.php.bak" ] && mv "$WP_CONTENT/advanced-cache.php.bak" "$WP_CONTENT/advanced-cache.php"
[ -d "$WP_CONTENT/mu-plugins.bak" ] && mv "$WP_CONTENT/mu-plugins.bak" "$WP_CONTENT/mu-plugins"

}