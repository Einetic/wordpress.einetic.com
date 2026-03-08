#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

SITE="$1"

if [ -z "$SITE" ]; then
  echo "Usage: fix-wordpress.sh <site_path>"
  exit 1
fi

echo "================================="
echo "Fixing WordPress at $SITE"
echo "================================="

HTACCESS="$SITE/.htaccess"
UPLOADS="$SITE/wp-content/uploads"

# ---------------------------------
# Step 1: Malware cleanup
# ---------------------------------
echo "Step 1: Malware cleanup"

rm -rf "$SITE/wp-content/mu-plugins" 2>/dev/null
rm -rf "$UPLOADS/.tmb" 2>/dev/null
# Remove malicious drop-ins
rm -f "$SITE/wp-content/db.php" 2>/dev/null
rm -f "$SITE/wp-content/advanced-cache.php" 2>/dev/null
rm -f "$SITE/wp-content/object-cache.php" 2>/dev/null
rm -f "$SITE/wp-content/install.php" 2>/dev/null
# remove known malicious upload folders
rm -rf "$UPLOADS/wp-file-manager-pro" 2>/dev/null
rm -rf "$UPLOADS/file-manager" 2>/dev/null
rm -rf "$UPLOADS/wp-file-manager" 2>/dev/null
rm -rf "$UPLOADS/pwned" 2>/dev/null
rm -rf "$SITE/wp-content/plugins-old"* 2>/dev/null
rm -rf "$SITE/wp-content/themes-old"* 2>/dev/null
rm -rf "$SITE/wp-content/uploads-old"* 2>/dev/null
rm -rf "$SITE/wp-content/mu-plugins-old"* 2>/dev/null
rm -rf "$SITE/wp-content/endurance-page-cache" 2>/dev/null
rm -rf "$SITE/wp-content/upgrade" 2>/dev/null
rm -rf "$SITE/wp-content/upgrade-temp-backup" 2>/dev/null
# remove hidden suspicious folders
rm -rf "$SITE/.wp-temp" 2>/dev/null
rm -rf "$SITE/.wp-cache" 2>/dev/null
rm -rf "$SITE/.cache" 2>/dev/null
rm -rf "$SITE/.backups" 2>/dev/null
rm -rf "$SITE/.logs" 2>/dev/null
rm -rf "$SITE/.old" 2>/dev/null
rm -rf "$SITE/.trash" 2>/dev/null
rm -rf "$SITE/.temp" 2>/dev/null
rm -rf "$SITE/.htaccess_old" 2>/dev/null
rm -rf "$SITE/.htaccess.bak" 2>/dev/null
rm -rf "$SITE/.htaccess.backup" 2>/dev/null
rm -rf "$SITE/.htaccess.bak" 2>/dev/null
rm -rf "$SITE/.htaccess_old" 2>/dev/null

# safer php deletion (avoid hostinger kill)
if [ -d "$UPLOADS" ]; then
  echo "Removing PHP files from uploads"
  find "$UPLOADS" -type f -name "*.php" -print -delete 2>/dev/null
fi

echo "Removing common malware files"
find "$SITE" -maxdepth 3 -type f -name "license.php" -print -delete 2>/dev/null
find "$SITE" -maxdepth 3 -type f -name "index1.php" -print -delete 2>/dev/null

echo "Malware cleanup complete"

# ---------------------------------
# Step 2: Resetting .htaccess exists
# ---------------------------------
echo "Resetting .htaccess"
[ -f "$HTACCESS" ] && cp "$HTACCESS" "$HTACCESS.backup"

cat > "$HTACCESS" <<EOF
# BEGIN WordPress
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
# END WordPress
EOF

# Block PHP execution inside uploads
if [ -d "$UPLOADS" ]; then
  cat > "$UPLOADS/.htaccess" <<EOF
<FilesMatch "\.php$">
  Deny from all
</FilesMatch>
EOF
fi

# ---------------------------------
# Step 3: Reinstall WordPress core
# ---------------------------------

echo "Step 2: Reinstall WordPress core"

rm -rf "$SITE/wp-admin" 2>/dev/null
rm -rf "$SITE/wp-includes" 2>/dev/null

wp_exec "$SITE" core download --skip-content --force

# ---------------------------------
# Step 4: Reinstall plugins
# ---------------------------------

echo "Step 3: Reinstall plugins"
bash "$SCRIPT_DIR/reinstall-plugins.sh" "$SITE"

# ---------------------------------
# Step 5: Reinstall themes
# ---------------------------------

echo "Step 4: Reinstall themes"
bash "$SCRIPT_DIR/reinstall-themes.sh" "$SITE"

# ---------------------------------
# Step 6: Security hardening
# ---------------------------------

echo "Step 5: Regenerate salts"
wp_exec "$SITE" config shuffle-salts --skip-plugins --skip-themes

echo "Step 6: Optimize database"
wp_exec "$SITE" db optimize --skip-plugins --skip-themes

# Disable file editor
wp_exec "$SITE" config set DISALLOW_FILE_EDIT true --raw --skip-plugins --skip-themes 2>/dev/null

# Disable user registration if enabled
REG=$(wp_exec "$SITE" option get users_can_register --skip-plugins --skip-themes 2>/dev/null)
if [ "$REG" == "1" ]; then
  wp_exec "$SITE" option update users_can_register 0 --skip-plugins --skip-themes
fi

# ---------------------------------
# Step 6.1: Enabling automatic updates and updating all components
# ---------------------------------
echo "Enabling automatic updates"
safe_wp "$SITE" config set WP_AUTO_UPDATE_CORE true --raw >/dev/null 2>&1
safe_wp "$SITE" plugin auto-updates enable --all >/dev/null 2>&1
safe_wp "$SITE" theme auto-updates enable --all >/dev/null 2>&1
echo "Updating WordPress components"
safe_wp "$SITE" core update >/dev/null 2>&1
safe_wp "$SITE" plugin update --all >/dev/null 2>&1
safe_wp "$SITE" theme update --all >/dev/null 2>&1

# ---------------------------------
# Step 7: Flush permalinks
# ---------------------------------

echo "Step 7: Flush permalinks"
wp_exec "$SITE" rewrite flush --hard --skip-plugins --skip-themes
if wp_exec "$SITE" plugin is-installed elementor >/dev/null 2>&1; then
  echo "Refreshing Elementor cache"
  wp_exec "$SITE" elementor flush_css >/dev/null 2>&1
fi

echo "Flushing WordPress cache"

wp_exec "$SITE" transient delete --all >/dev/null 2>&1
wp_exec "$SITE" cache flush >/dev/null 2>&1
# ---------------------------------
# Step 8: Clear cache
# ---------------------------------

echo "Step 8: Clear cache directories"

rm -rf "$SITE/wp-content/cache" 2>/dev/null
rm -rf "$SITE/wp-content/litespeed" 2>/dev/null
rm -rf "$UPLOADS/cache" 2>/dev/null
rm -rf "$SITE/wp-content/endurance-page-cache" 2>/dev/null
rm -rf "$SITE/wp-content/w3tc-cache" 2>/dev/null
rm -rf "$SITE/wp-content/wp-rocket-cache" 2>/dev/null

echo "================================="
echo "WordPress repair complete"
echo "================================="