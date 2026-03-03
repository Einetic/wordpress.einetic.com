#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

SITE="$1"

if [ -z "$SITE" ]; then
echo "Usage: fix-wordpress.sh <site_path>"
exit 1
fi


malware_cleanup(){

SITE_PATH="$1"
WP_CONTENT="$SITE_PATH/wp-content"

echo "Step 2: Malware cleanup"

# remove php shells in uploads
find "$WP_CONTENT/uploads" -type f \( -name "*.php" -o -name "*.phtml" -o -name "*.php7" \) -delete 2>/dev/null

# remove hidden php shells
find "$SITE_PATH" -type f -name ".*.php" -delete 2>/dev/null

# remove rogue cache loaders
rm -f "$WP_CONTENT/object-cache.php"
rm -f "$WP_CONTENT/advanced-cache.php"

# remove suspicious mu plugins
rm -rf "$WP_CONTENT/mu-plugins" 2>/dev/null

# remove suspicious tiny php in core dirs
find "$SITE_PATH/wp-includes" -type f -name "*.php" -size -5k -delete 2>/dev/null
find "$SITE_PATH/wp-admin" -type f -name "*.php" -size -5k -delete 2>/dev/null

# clean htaccess injections
if [ -f "$SITE_PATH/.htaccess" ]; then
sed -i '/base64_decode/d' "$SITE_PATH/.htaccess"
sed -i '/gzinflate/d' "$SITE_PATH/.htaccess"
sed -i '/eval(/d' "$SITE_PATH/.htaccess"
fi

echo "Malware cleanup complete"

}



echo "Fixing WordPress at $SITE"

echo "Step 1: Reinstall WordPress core"
safe_wp "$SITE" core download --skip-content --force


malware_cleanup "$SITE"


echo "Step 3: Reinstall plugins"
bash "$SCRIPT_DIR/reinstall-plugins.sh" "$SITE"


echo "Step 4: Reinstall themes"
bash "$SCRIPT_DIR/reinstall-themes.sh" "$SITE"


echo "Step 5: Regenerate salts"
safe_wp "$SITE" config shuffle-salts


echo "Step 6: Optimize database"
safe_wp "$SITE" db optimize


echo "Step 7: Clear cache directories"
rm -rf "$SITE/wp-content/cache" 2>/dev/null
rm -rf "$SITE/wp-content/litespeed" 2>/dev/null
rm -rf "$SITE/wp-content/uploads/cache" 2>/dev/null


echo "WordPress repair complete"