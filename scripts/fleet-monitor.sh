#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UTIL_DIR="$BASE_DIR/util"
LOG_DIR="$BASE_DIR/logs"
CONFIG_DIR="$BASE_DIR/config"

mkdir -p "$LOG_DIR"
mkdir -p "$CONFIG_DIR"

TODAY=$(date +"%Y%m%d")

MONITOR_LOG="$LOG_DIR/monitor-$TODAY.log"
FIX_LOG="$LOG_DIR/fix-$TODAY.log"
ERROR_LOG="$LOG_DIR/error-$TODAY.log"
ALERT_FILE="$CONFIG_DIR/alerts.txt"

touch "$MONITOR_LOG"
touch "$FIX_LOG"
touch "$ERROR_LOG"
touch "$ALERT_FILE"

echo "===== Fleet Monitor Run $(date) =====" >> "$MONITOR_LOG"

scan_sites() {

for SITE in "$HOME"/domains/*/public_html
do
[ -f "$SITE/wp-config.php" ] && echo "$SITE"
done

for SITE in /home/*/htdocs/*
do
[ -f "$SITE/wp-config.php" ] && echo "$SITE"
done
}

scan_sites | while read SITE
do

DOMAIN=$(basename "$(dirname "$SITE")")

echo "Checking $DOMAIN" >> "$MONITOR_LOG"

wp --path="$SITE" core verify-checksums --skip-plugins --skip-themes > /dev/null 2>&1

if [ $? -ne 0 ]; then

echo "Core issue detected on $DOMAIN" >> "$FIX_LOG"

bash "$UTIL_DIR/fix-wordpress.sh" "$SITE" >> "$FIX_LOG" 2>> "$ERROR_LOG"

# re-check
wp --path="$SITE" core verify-checksums --skip-plugins --skip-themes > /dev/null 2>&1

if [ $? -ne 0 ]; then
echo "$DOMAIN" >> "$ALERT_FILE"
echo "Manual attention required for $DOMAIN" >> "$ERROR_LOG"
fi

fi

done

echo "===== Fleet Monitor Finished =====" >> "$MONITOR_LOG"