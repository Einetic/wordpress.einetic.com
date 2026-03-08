#!/bin/bash

# -------------------------------------------------
# WP-CLI global performance configuration
# -------------------------------------------------

export WP_CLI_DISABLE_AUTO_CHECK_UPDATE=1
export WP_CLI_PHP_ARGS="-d memory_limit=1024M"
export WP_CLI_CACHE_DIR="$HOME/.wp-cli/cache"

# -------------------------------------------------
# Execute WP-CLI respecting hosting environment
# -------------------------------------------------

wp_exec() {

    SITE_PATH="$1"
    shift

    if [[ "$SITE_PATH" == /home/*/htdocs/* ]]; then
        USER=$(echo "$SITE_PATH" | cut -d'/' -f3)
        sudo -u "$USER" -- wp "$@" --path="$SITE_PATH"

    elif [[ "$SITE_PATH" == */domains/*/public_html ]]; then
        wp "$@" --path="$SITE_PATH"

    else
        echo "Unknown hosting structure for: $SITE_PATH"
        return 1
    fi
}

# -------------------------------------------------
# Safe WP-CLI execution for hacked/broken sites
# -------------------------------------------------

safe_wp() {

SITE="$1"
shift

WP_CONTENT="$SITE/wp-content"
TMP_DISABLED="$WP_CONTENT/.wp-disabled-$$"

mkdir -p "$TMP_DISABLED"

# -----------------------------------
# Disable dangerous drop-ins
# -----------------------------------

if [ -f "$WP_CONTENT/db.php" ]; then
mv "$WP_CONTENT/db.php" "$TMP_DISABLED/db.php"
fi

if [ -f "$WP_CONTENT/object-cache.php" ]; then
mv "$WP_CONTENT/object-cache.php" "$TMP_DISABLED/object-cache.php"
fi

if [ -f "$WP_CONTENT/advanced-cache.php" ]; then
mv "$WP_CONTENT/advanced-cache.php" "$TMP_DISABLED/advanced-cache.php"
fi

if [ -f "$WP_CONTENT/sunrise.php" ]; then
mv "$WP_CONTENT/sunrise.php" "$TMP_DISABLED/sunrise.php"
fi

if [ -d "$WP_CONTENT/mu-plugins" ]; then
mv "$WP_CONTENT/mu-plugins" "$TMP_DISABLED/mu-plugins"
fi

# -----------------------------------
# Execute WP-CLI safely
# -----------------------------------

wp_exec "$SITE" "$@" --skip-plugins --skip-themes
RESULT=$?

# -----------------------------------
# Restore disabled components
# -----------------------------------

if [ -f "$TMP_DISABLED/db.php" ]; then
mv "$TMP_DISABLED/db.php" "$WP_CONTENT/db.php"
fi

if [ -f "$TMP_DISABLED/object-cache.php" ]; then
mv "$TMP_DISABLED/object-cache.php" "$WP_CONTENT/object-cache.php"
fi

if [ -f "$TMP_DISABLED/advanced-cache.php" ]; then
mv "$TMP_DISABLED/advanced-cache.php" "$WP_CONTENT/advanced-cache.php"
fi

if [ -f "$TMP_DISABLED/sunrise.php" ]; then
mv "$TMP_DISABLED/sunrise.php" "$WP_CONTENT/sunrise.php"
fi

if [ -d "$TMP_DISABLED/mu-plugins" ]; then
mv "$TMP_DISABLED/mu-plugins" "$WP_CONTENT/mu-plugins"
fi

rmdir "$TMP_DISABLED" 2>/dev/null

return $RESULT
}