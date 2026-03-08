#!/bin/bash
shopt -s globstar nullglob

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
# Step 2: Ensure .htaccess exists
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

echo "Checking plugin health"

safe_wp "$SITE" plugin list --field=name | while read plugin
do

  UPDATED=$(safe_wp "$SITE" plugin get "$plugin" --field=last_updated 2>/dev/null)
  VERSION=$(safe_wp "$SITE" plugin get "$plugin" --field=version 2>/dev/null)
  STATUS=$(safe_wp "$SITE" plugin get "$plugin" --field=status 2>/dev/null)
  SOURCE=$(safe_wp "$SITE" plugin get "$plugin" --field=update_source 2>/dev/null)

  # -------------------------------------------------
  # Detect plugins not from WordPress repo
  # -------------------------------------------------

  if [ "$SOURCE" != "wordpress.org" ]; then

    echo "Plugin $plugin not from WordPress.org"

    safe_wp "$SITE" plugin deactivate "$plugin" >/dev/null 2>&1
    safe_wp "$SITE" plugin auto-updates disable "$plugin" >/dev/null 2>&1

    echo "Plugin $plugin deactivated and auto-update disabled"

    continue
  fi

  # -------------------------------------------------
  # Detect abandoned plugins (2+ years)
  # -------------------------------------------------

  if [ -n "$UPDATED" ]; then

    YEARS=$(( ($(date +%s) - $(date -d "$UPDATED" +%s)) / 31536000 ))

    if [ "$YEARS" -ge 2 ]; then
      safe_wp "$SITE" plugin deactivate "$plugin" >/dev/null 2>&1
      echo "Plugin $plugin appears abandoned (last update: $UPDATED)"
    fi

  fi

done

# ---------------------------------
# Step 5: Reinstall themes
# ---------------------------------

echo "Step 4: Reinstall themes"
bash "$SCRIPT_DIR/reinstall-themes.sh" "$SITE"

echo "Checking active theme"
THEME=$(safe_wp "$SITE" option get template --skip-plugins --skip-themes 2>/dev/null)

if [ -n "$THEME" ]; then
  if [ ! -d "$SITE/wp-content/themes/$THEME" ]; then
    echo "Theme $THEME missing — installing"
    safe_wp "$SITE" theme install "$THEME" --activate
  else
    safe_wp "$SITE" theme activate "$THEME"
  fi
fi

# ---------------------------------
# Step 6: Security hardening
# ---------------------------------

echo "Step 5: Regenerate salts"
safe_wp "$SITE" config shuffle-salts --skip-plugins --skip-themes

echo "Step 6: Optimize database"
safe_wp "$SITE" db optimize --skip-plugins --skip-themes

ATTACH=$(safe_wp "$SITE" post list --post_type=attachment --format=count 2>/dev/null)

if [ "$ATTACH" == "0" ]; then
  echo "Rebuilding media library"
  safe_wp "$SITE" media import "$UPLOADS"/**/* --skip-copy >/dev/null 2>&1
fi

echo "Running WordPress database upgrade"
safe_wp "$SITE" core update-db --skip-plugins --skip-themes

if safe_wp "$SITE" plugin is-installed elementor >/dev/null 2>&1; then
  echo "Refreshing Elementor cache"
  safe_wp "$SITE" elementor flush_css >/dev/null 2>&1
fi

echo "Flushing WordPress cache"

safe_wp "$SITE" transient delete --all >/dev/null 2>&1
safe_wp "$SITE" cache flush >/dev/null 2>&1

# Disable file editor
safe_wp "$SITE" config set DISALLOW_FILE_EDIT true --raw --skip-plugins --skip-themes 2>/dev/null

# Disable user registration if enabled
REG=$(safe_wp "$SITE" option get users_can_register --skip-plugins --skip-themes 2>/dev/null)
if [ "$REG" == "1" ]; then
  safe_wp "$SITE" option update users_can_register 0 --skip-plugins --skip-themes
fi

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
safe_wp "$SITE" rewrite flush --hard --skip-plugins --skip-themes

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