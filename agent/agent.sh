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

chmod +x "$BASE_DIR"/agent/*.sh 2>/dev/null
chmod +x "$UTIL_DIR"/*.sh 2>/dev/null
chmod +x "$BASE_DIR"/scripts/*.sh 2>/dev/null

pause(){ read -p "Press Enter to continue..."; }

# ---------------- AUTO UPDATE ----------------

check_update(){
TODAY=$(date +%Y-%m-%d)
[ "$LAST_UPDATE" == "$TODAY" ] && return

cd "$BASE_DIR" || return

git fetch origin >/dev/null 2>&1

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/master)

if [ "$LOCAL" != "$REMOTE" ]; then
echo "Updating Fleet..."
git reset --hard origin/master >/dev/null 2>&1
chmod +x agent/*.sh util/*.sh scripts/*.sh 2>/dev/null
sed -i "s/^LAST_UPDATE=.*/LAST_UPDATE=\"$TODAY\"/" "$CONFIG_FILE"
exec "$BASE_DIR/agent/agent.sh"
else
sed -i "s/^LAST_UPDATE=.*/LAST_UPDATE=\"$TODAY\"/" "$CONFIG_FILE"
fi
}

check_update

# ---------------- SYSTEMD SUPPORT ----------------

supports_systemd(){
command -v systemctl >/dev/null 2>&1 || return 1
command -v sudo >/dev/null 2>&1 || return 1
return 0
}

install_service(){

supports_systemd || return 1

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
sudo systemctl enable "$SERVICE_NAME.timer" >/dev/null 2>&1

rm -f "$TMP_SERVICE"

echo "$(date) - Service installed" >> "$LOG_DIR/service.log"
fi
}

start_service(){

if ! supports_systemd; then
echo
echo "Monitor Service not supported on this server"
pause
return
fi

install_service

sudo systemctl start "$SERVICE_NAME.timer"

if [ $? -eq 0 ]; then
echo "Monitor Service started successfully"
echo "$(date) - Service started" >> "$LOG_DIR/service.log"
else
echo "Failed to start Monitor Service"
fi

pause
}

stop_service(){

if ! supports_systemd; then
echo
echo "Monitor Service not supported on this server"
pause
return
fi

if ! sudo systemctl is-active --quiet "$SERVICE_NAME.timer"; then
echo "Monitor Service is not running"
pause
return
fi

sudo systemctl stop "$SERVICE_NAME.timer"

echo "Monitor Service stopped"
echo "$(date) - Service stopped" >> "$LOG_DIR/service.log"

pause
}

restart_service(){

if ! supports_systemd; then
echo
echo "Monitor Service not supported on this server"
pause
return
fi

install_service

sudo systemctl restart "$SERVICE_NAME.timer"

echo "Monitor Service restarted"
echo "$(date) - Service restarted" >> "$LOG_DIR/service.log"

pause
}

service_status(){

if ! supports_systemd; then
echo
echo "Monitor Service not supported on this server"
pause
return
fi

if [ ! -f "$SYSTEMD_SERVICE" ]; then
echo "Monitor Service not installed"
pause
return
fi

sudo systemctl status "$SERVICE_NAME.timer" --no-pager
pause
}

# ---------------- SITE FUNCTIONS ----------------

get_domain(){
SITE="$1"
[[ "$SITE" == *"/public_html" ]] && basename "$(dirname "$SITE")" || basename "$SITE"
}

scan_sites(){

for SITE in "$HOME"/domains/*/public_html
do
[ -f "$SITE/wp-config.php" ] || continue
echo "$SITE"
done

for SITE in /home/*/htdocs/*
do
[ -f "$SITE/wp-config.php" ] || continue
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

verify-all)
wp --path="$SITE" core verify-checksums --skip-plugins --skip-themes >/dev/null 2>&1
CORE_STATUS=$?
wp --path="$SITE" plugin verify-checksums --all --skip-plugins --skip-themes >/dev/null 2>&1
PLUGIN_STATUS=$?

if [ $CORE_STATUS -eq 0 ] && [ $PLUGIN_STATUS -eq 0 ]; then
echo "OK"
else
echo "FAILED"
fi
;;

update-all)
wp --path="$SITE" core update --quiet
wp --path="$SITE" plugin update --all --quiet
wp --path="$SITE" theme update --all --quiet
wp --path="$SITE" rewrite flush --hard --quiet
echo "UPDATED"
;;

fix-wordpress)
bash "$UTIL_DIR/fix-wordpress.sh" "$SITE" >/dev/null && echo "REPAIRED"
;;

deep-scan)
bash "$UTIL_DIR/deep-scan.sh" "$SITE" >/dev/null && echo "SCANNED"
;;

cleanup-admins)
bash "$UTIL_DIR/cleanup-admins.sh" "$SITE" > /dev/null && echo "ADMINS CLEANED"
;;

delete-all-admins)
bash "$UTIL_DIR/delete-all-admins.sh" "$SITE" > /dev/null && echo "ALL ADMINS DELETED"
;;

esac

done

pause
}

generate_login_link(){

SITE="$1"

ADMINS=$(wp --path="$SITE" user list --role=administrator --field=user_login --skip-plugins --skip-themes 2>/dev/null)

if [ -z "$ADMINS" ]; then

echo "No admin found. Creating recovery admin: einetic"

NEW_PASS=$(openssl rand -base64 18)

wp --path="$SITE" user create einetic wp@eineticsite.com \
--role=administrator \
--user_pass="$NEW_PASS" \
--skip-plugins --skip-themes >/dev/null 2>&1

if [ $? -ne 0 ]; then
echo "Failed to create recovery admin"
pause
return
fi

LOGIN_URL=$(wp --path="$SITE" option get siteurl --skip-plugins --skip-themes)

echo
echo "Recovery Admin Created"
echo "Login URL : $LOGIN_URL/wp-login.php"
echo "Username  : einetic"
echo "Password  : $NEW_PASS"
echo

pause
return
fi

echo "Available Admin Users:"
echo "$ADMINS"
echo

read -p "Enter admin username: " USER

if ! echo "$ADMINS" | grep -qx "$USER"; then
echo "Invalid admin username"
pause
return
fi

NEW_PASS=$(openssl rand -base64 18)

wp --path="$SITE" user update "$USER" \
--user_pass="$NEW_PASS" \
--skip-plugins --skip-themes >/dev/null 2>&1

LOGIN_URL=$(wp --path="$SITE" option get siteurl --skip-plugins --skip-themes)

echo
echo "Admin Login URL:"
echo "$LOGIN_URL/wp-login.php"
echo
echo "Username : $USER"
echo "Password : $NEW_PASS"
echo

pause
}

manage_admins(){

SITE="$1"

COUNT=$(wp --path="$SITE" user list \
  --role=administrator \
  --format=count \
  --skip-plugins --skip-themes)

if [ "$COUNT" -eq 0 ]; then
  echo "No administrators found"
  pause
  return
fi

echo
wp --path="$SITE" user list \
  --role=administrator \
  --fields=ID,user_login,user_email \
  --format=table \
  --skip-plugins --skip-themes
echo

read -p "Enter Admin ID to manage: " ADMIN_ID

EXISTS=$(wp --path="$SITE" user get "$ADMIN_ID" --field=ID 2>/dev/null)

if [ -z "$EXISTS" ]; then
  echo "Invalid Admin ID"
  pause
  return
fi

echo
echo "1) Reset Password"
echo "2) Disable Admin"
echo "0) Back"
echo
read -p "Select option: " ACTION

case $ACTION in

1)
NEW_PASS=$(openssl rand -base64 18)

wp --path="$SITE" user update "$ADMIN_ID" \
  --user_pass="$NEW_PASS" \
  --skip-plugins --skip-themes

echo
echo "Password Reset Successful"
echo "New Password: $NEW_PASS"
;;

2)

if [ "$COUNT" -le 1 ]; then
  echo "Cannot disable last administrator"
  pause
  return
fi

# set random password
RAND_PASS=$(openssl rand -base64 24)

# downgrade role
wp --path="$SITE" user update "$ADMIN_ID" \
  --role=subscriber \
  --user_pass="$RAND_PASS" \
  --skip-plugins --skip-themes

echo
echo "Admin Disabled Successfully"
echo "User downgraded to subscriber"
;;

0)
return
;;

esac

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
echo "1) Verify Integrity (Core + Plugins)"
echo "2) Check Themes"
echo "3) Update Everything"
echo "4) Full WordPress Repair"
echo "5) Deep Scan"
echo "6) Verify Database"
echo "7) Generate One-Time Admin Login Link"
echo "8) Cleanup Admins (Keep Oldest)"
echo "10) Manage Admins"
echo "0) Back"
echo

read -p "Select option: " CH

case $CH in

1)
wp --path="$SITE_PATH" core verify-checksums --skip-plugins --skip-themes
wp --path="$SITE_PATH" plugin verify-checksums --all --skip-plugins --skip-themes
pause
;;

2)
wp --path="$SITE_PATH" theme list --fields=name,status,update,version --skip-plugins --skip-themes
pause
;;

3)
wp --path="$SITE_PATH" core update
wp --path="$SITE_PATH" plugin update --all
wp --path="$SITE_PATH" theme update --all
wp --path="$SITE_PATH" rewrite flush --hard
pause
;;

4)
bash "$UTIL_DIR/fix-wordpress.sh" "$SITE_PATH"
pause
;;

5)
bash "$UTIL_DIR/deep-scan.sh" "$SITE_PATH"
pause
;;

6)
wp --path="$SITE_PATH" db check --skip-plugins --skip-themes
pause
;;

7)
generate_login_link "$SITE_PATH"
;;

8)
bash "$UTIL_DIR/cleanup-admins.sh" "$SITE_PATH"
pause
;;

10) manage_admins "$SITE_PATH" ;;

0) break ;;

esac

done
;;

2)

echo "1) Verify Integrity All Sites"
echo "2) Update All Sites"
echo "3) Full Repair All"
echo "4) Deep Scan All"
echo "5) Cleanup Admins (Keep Oldest) All Sites"
read -p "Select option: " BULK

case $BULK in
1) run_bulk verify-all ;;
2) run_bulk update-all ;;
3) run_bulk fix-wordpress ;;
4) run_bulk deep-scan ;;
5) run_bulk cleanup-admins ;;
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