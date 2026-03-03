#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UTIL_DIR="$BASE_DIR/util"
SERVICE_TEMPLATE="$BASE_DIR/service/einetic-wp-fleet.service"
TIMER_TEMPLATE="$BASE_DIR/service/einetic-wp-fleet.timer"

SERVICE_NAME="einetic-wp-fleet"
SYSTEMD_SERVICE="/etc/systemd/system/$SERVICE_NAME.service"
SYSTEMD_TIMER="/etc/systemd/system/$SERVICE_NAME.timer"

MONITOR_SCRIPT="$BASE_DIR/scripts/fleet-monitor.sh"
LOG_DIR="$BASE_DIR/logs"
CONFIG_FILE="$BASE_DIR/agent/config.env"

mkdir -p "$BASE_DIR/agent" "$LOG_DIR"

[ -f "$CONFIG_FILE" ] || echo 'LAST_UPDATE=""' > "$CONFIG_FILE"
source "$CONFIG_FILE"

# Auto-fix permissions
chmod +x "$BASE_DIR"/agent/*.sh 2>/dev/null
chmod +x "$UTIL_DIR"/*.sh 2>/dev/null
chmod +x "$BASE_DIR"/scripts/*.sh 2>/dev/null

# ---------------- AUTO UPDATE ----------------

check_update(){

TODAY=$(date +%Y-%m-%d)
[ "$LAST_UPDATE" == "$TODAY" ] && return

cd "$BASE_DIR" || return

git fetch origin > /dev/null 2>&1

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/master)

if [ "$LOCAL" != "$REMOTE" ]; then
echo "Updating Fleet..."
git reset --hard origin/master > /dev/null 2>&1
chmod +x agent/*.sh util/*.sh scripts/*.sh 2>/dev/null
sed -i "s/^LAST_UPDATE=.*/LAST_UPDATE=\"$TODAY\"/" "$CONFIG_FILE"
exec "$BASE_DIR/agent/agent.sh"
else
sed -i "s/^LAST_UPDATE=.*/LAST_UPDATE=\"$TODAY\"/" "$CONFIG_FILE"
fi
}

check_update

# ---------------- SERVICE MANAGEMENT ----------------

install_service(){

if [ ! -f "$SYSTEMD_SERVICE" ]; then

echo "Installing monitor service..."

TMP_SERVICE=$(mktemp)
cp "$SERVICE_TEMPLATE" "$TMP_SERVICE"

sed -i "s#__USER__#$(whoami)#g" "$TMP_SERVICE"
sed -i "s#__BASE_DIR__#$BASE_DIR#g" "$TMP_SERVICE"
sed -i "s#__MONITOR_SCRIPT__#$MONITOR_SCRIPT#g" "$TMP_SERVICE"

sudo cp "$TMP_SERVICE" "$SYSTEMD_SERVICE"
sudo cp "$TIMER_TEMPLATE" "$SYSTEMD_TIMER"

sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME.timer"

rm -f "$TMP_SERVICE"

echo "$(date) - Service installed" >> "$LOG_DIR/service.log"
fi
}

start_service(){
install_service
sudo systemctl start "$SERVICE_NAME.timer"
echo "$(date) - Service started" >> "$LOG_DIR/service.log"
}

stop_service(){
sudo systemctl stop "$SERVICE_NAME.timer" 2>/dev/null
echo "$(date) - Service stopped" >> "$LOG_DIR/service.log"
}

restart_service(){
install_service
sudo systemctl restart "$SERVICE_NAME.timer"
echo "$(date) - Service restarted" >> "$LOG_DIR/service.log"
}

service_status(){
sudo systemctl status "$SERVICE_NAME.timer" --no-pager
read -p "Press Enter..."
}

# ---------------- COMMON FUNCTIONS ----------------

pause(){ read -p "Press Enter to continue..."; }

get_domain(){
SITE="$1"
[[ "$SITE" == *"/public_html" ]] && basename "$(dirname "$SITE")" || basename "$SITE"
}

scan_sites(){

for SITE in "$HOME"/domains/*/public_html
do
[ -f "$SITE/wp-config.php" ] || continue
DOMAIN=$(basename "$(dirname "$SITE")")
[[ "$DOMAIN" == *BACKUP* ]] && continue
echo "$SITE"
done

for SITE in /home/*/htdocs/*
do
[ -f "$SITE/wp-config.php" ] || continue
DOMAIN=$(basename "$SITE")
[[ "$DOMAIN" == *BACKUP* ]] && continue
echo "$SITE"
done

}

run_bulk(){

ACTION="$1"

clear
printf "%-40s %s\n" "SITE" "STATUS"
echo "-------------------------------------------------------------"

scan_sites | while read SITE
do
DOMAIN=$(get_domain "$SITE")
printf "%-40s" "$DOMAIN"

case $ACTION in

verify-core)
wp --path="$SITE" core verify-checksums --skip-plugins --skip-themes > /dev/null 2>&1 && echo "OK" || echo "FAILED"
;;

verify-plugins)
wp --path="$SITE" plugin verify-checksums --all --skip-plugins --skip-themes > /dev/null 2>&1 && echo "OK" || echo "FAILED"
;;

verify-themes)
wp --path="$SITE" theme verify-checksums --all --skip-plugins --skip-themes > /dev/null 2>&1 && echo "OK" || echo "FAILED"
;;

verify-db)
wp --path="$SITE" db check --skip-plugins --skip-themes > /dev/null 2>&1 && echo "OK" || echo "FAILED"
;;

fix-wordpress)
bash "$UTIL_DIR/fix-wordpress.sh" "$SITE" > /dev/null && echo "REPAIRED"
;;

deep-scan)
bash "$UTIL_DIR/deep-scan.sh" "$SITE" > /dev/null && echo "SCANNED"
;;

esac

done

pause
}

# ---------------- MAIN MENU ----------------

while true
do

clear

echo "================================="
echo "        EINETIC WP FLEET"
echo "================================="
echo
echo "1) Manage Single Site"
echo "2) Bulk Operations"
echo "3) Update Fleet"
echo "4) Start Monitor Service"
echo "5) Stop Monitor Service"
echo "6) Restart Monitor Service"
echo "7) Service Status"
echo "0) Exit"
echo

read -p "Select option: " MAIN

case $MAIN in

1)

SITE_PATH=$(bash "$UTIL_DIR/list-sites.sh" | tee /dev/tty | tail -n 1)
[ -z "$SITE_PATH" ] && continue

while true
do

clear
DOMAIN=$(get_domain "$SITE_PATH")

echo "================================="
echo "SITE : $DOMAIN"
echo "================================="
echo
echo "1) Full WordPress Repair"
echo "2) Deep Scan"
echo "3) Verify Core"
echo "4) Verify Plugins"
echo "5) Verify Themes"
echo "6) Verify Database"
echo "0) Back"
echo

read -p "Select option: " CH

case $CH in
1) bash "$UTIL_DIR/fix-wordpress.sh" "$SITE_PATH" ; pause ;;
2) bash "$UTIL_DIR/deep-scan.sh" "$SITE_PATH" ; pause ;;
3) wp --path="$SITE_PATH" core verify-checksums --skip-plugins --skip-themes ; pause ;;
4) wp --path="$SITE_PATH" plugin verify-checksums --all --skip-plugins --skip-themes ; pause ;;
5) wp --path="$SITE_PATH" theme verify-checksums --all --skip-plugins --skip-themes ; pause ;;
6) wp --path="$SITE_PATH" db check --skip-plugins --skip-themes ; pause ;;
0) break ;;
esac

done
;;

2)

echo "1) Verify Core All"
echo "2) Full Repair All"
echo "3) Deep Scan All"
read -p "Select option: " BULK

case $BULK in
1) run_bulk verify-core ;;
2) run_bulk fix-wordpress ;;
3) run_bulk deep-scan ;;
esac
;;

3)
cd "$BASE_DIR" || exit
git fetch origin
git reset --hard origin/master
chmod +x agent/*.sh util/*.sh scripts/*.sh 2>/dev/null
exec "$BASE_DIR/agent/agent.sh"
;;

4) start_service ;;
5) stop_service ;;
6) restart_service ;;
7) service_status ;;
0) exit ;;

esac

done