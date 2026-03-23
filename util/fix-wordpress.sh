#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

SITE="$1"

if [ -z "$SITE" ]; then
  echo "Usage: fix-wordpress.sh <site_path>"
  exit 1
fi

if [ ! -d "$SITE/wp-content" ]; then
  echo "Invalid WordPress path"
  exit 1
fi

WP_CONFIG="$SITE/wp-config.php"
HTACCESS="$SITE/.htaccess"
UPLOADS="$SITE/wp-content/uploads"

if [ ! -f "$WP_CONFIG" ]; then
  echo "Not Found wp-config.php"
  exit 1
fi

echo "================================="
echo "Fixing WordPress at $SITE"
echo "================================="

echo "Step 1: Cleaning core files"
find "$SITE" -mindepth 1 -maxdepth 1 ! -name "wp-content" ! -name "wp-config.php" -exec rm -rf {} + 2>/dev/null
echo "Core cleanup complete"

echo "Step 2: Setting file permissions"
find "$SITE" -type d -exec chmod 755 {} \; 2>/dev/null
find "$SITE" -type f -exec chmod 644 {} \; 2>/dev/null
chmod 600 "$SITE/wp-config.php" 2>/dev/null

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

  # safer php deletion (avoid hostinger kill)
  if [ -d "$UPLOADS" ]; then
    find "$UPLOADS" -type f -name "*.php" -exec rm -f {} \; 2>/dev/null
  fi

  find "$SITE" -type f -name "license.php" -exec rm -f {} \; 2>/dev/null
  find "$SITE" -type f -name "index1.php" -exec rm -f {} \; 2>/dev/null

  echo "Malware cleanup complete"

  # ---------------------------------
  # Step 2: Resetting .htaccess
  # ---------------------------------
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

  wp_exec "$SITE" core download --skip-content --force >/dev/null 2>&1

  if [ ! -f "$SITE/wp-includes/version.php" ]; then
    echo "Core installation failed"
    exit 1
  fi

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
wp_exec "$SITE" config set DISALLOW_FILE_MODS true --raw --skip-plugins --skip-themes 2>/dev/null
wp_exec "$SITE" config set AUTOMATIC_UPDATER_DISABLED true --raw --skip-plugins --skip-themes 2>/dev/null
wp_exec "$SITE" config set WP_AUTO_UPDATE_CORE false --raw --skip-plugins --skip-themes 2>/dev/null

  # Disable user registration if enabled
  REG=$(wp_exec "$SITE" option get users_can_register --skip-plugins --skip-themes 2>/dev/null)
  if [ "$REG" == "1" ]; then
    wp_exec "$SITE" option update users_can_register 0 --skip-plugins --skip-themes
  fi

  # ---------------------------------
  # Step 7: Flush permalinks
  # ---------------------------------

  echo "Step 7: Flush permalinks"
  wp_exec "$SITE" rewrite flush --hard --skip-plugins --skip-themes

  # ---------------------------------
  # Step 8: Clear cache
  # ---------------------------------

  echo "Step 8: Clear cache directories"

  rm -rf "$SITE/wp-content/cache" 2>/dev/null
  rm -rf "$SITE/wp-content/litespeed" 2>/dev/null
  rm -rf "$UPLOADS/cache" 2>/dev/null

  echo "================================="
  echo "WordPress repair complete"
  echo "================================="