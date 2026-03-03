#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

SITE="$1"

if [ -z "$SITE" ]; then
echo "Usage: deep-scan.sh <site_path>"
exit 1
fi

echo "========== DEEP SCAN START =========="
echo "Target: $SITE"
echo

### 1️⃣ Scan for dangerous PHP patterns

echo "Scanning for dangerous PHP patterns..."

grep -RIl \
-e "eval(base64_decode" \
-e "gzinflate(" \
-e "str_rot13(" \
-e "preg_replace.*\/e" \
-e "shell_exec(" \
-e "exec(" \
-e "passthru(" \
-e "system(" \
-e "wp_vcd" \
"$SITE" --exclude-dir=wp-admin --exclude-dir=wp-includes 2>/dev/null > /tmp/deepscan_hits.txt

if [ -s /tmp/deepscan_hits.txt ]; then
echo "Suspicious files detected:"
cat /tmp/deepscan_hits.txt
else
echo "No dangerous PHP patterns detected"
fi

echo

### 2️⃣ Remove PHP inside uploads

echo "Checking uploads for PHP files..."

UPLOAD_PHP=$(find "$SITE/wp-content/uploads" -type f -name "*.php" 2>/dev/null)

if [ -n "$UPLOAD_PHP" ]; then
echo "Removing PHP files from uploads"
find "$SITE/wp-content/uploads" -type f -name "*.php" -delete
else
echo "Uploads clean"
fi

echo

### 3️⃣ Check fake admin users

echo "Checking admin users..."

ADMINS=$(safe_wp "$SITE" user list --role=administrator --field=user_login)

echo "$ADMINS"

echo
echo "Review admin list manually if suspicious."

echo

### 4️⃣ Check cron malware

echo "Checking suspicious cron jobs..."

safe_wp "$SITE" cron event list --fields=hook 2>/dev/null | \
grep -E "wp_vcd|malware|spam|inject" || echo "No suspicious cron jobs"

echo

### 5️⃣ Detect modified core files

echo "Checking WordPress core integrity..."

wp_exec "$SITE" core verify-checksums > /tmp/corecheck.txt 2>&1

if grep -q "Warning" /tmp/corecheck.txt; then
echo "Core integrity warnings found:"
cat /tmp/corecheck.txt
else
echo "Core integrity OK"
fi

echo

### 6️⃣ Detect injected SEO spam in database

echo "Scanning database for SEO spam..."

SPAM=$(safe_wp "$SITE" db query "
SELECT ID FROM wp_posts 
WHERE post_content LIKE '%href=http%' 
AND post_status='publish'
LIMIT 5;
" 2>/dev/null)

if [ -n "$SPAM" ]; then
echo "Potential injected posts detected"
echo "$SPAM"
else
echo "No obvious SEO spam detected"
fi

echo
echo "========== DEEP SCAN COMPLETE =========="