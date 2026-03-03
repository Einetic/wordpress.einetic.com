#!/bin/bash

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UTIL_DIR="$BASE_DIR/util"

# auto-fix execute permissions
chmod +x "$BASE_DIR"/agent/*.sh 2>/dev/null
chmod +x "$UTIL_DIR"/*.sh 2>/dev/null
chmod +x "$BASE_DIR"/scripts/*.sh 2>/dev/null

pause(){
read -p "Press Enter to continue..."
}

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

echo
printf "%-40s %s\n" "SITE" "STATUS"
echo "--------------------------------------------------------------"

scan_sites | while read SITE
do

DOMAIN=$(get_domain "$SITE")
printf "%-40s" "$DOMAIN"

case $ACTION in

verify-core)
wp --path="$SITE" core verify-checksums --skip-plugins --skip-themes > /dev/null 2>&1 \
&& echo "OK" || echo "FAILED"
;;

verify-plugins)
wp --path="$SITE" plugin verify-checksums --all --skip-plugins --skip-themes > /dev/null 2>&1 \
&& echo "OK" || echo "FAILED"
;;

verify-themes)
wp --path="$SITE" theme verify-checksums --all --skip-plugins --skip-themes > /dev/null 2>&1 \
&& echo "OK" || echo "FAILED"
;;

verify-db)
wp --path="$SITE" db check --skip-plugins --skip-themes > /dev/null 2>&1 \
&& echo "OK" || echo "FAILED"
;;

fix-core)
bash "$UTIL_DIR/reinstall-core.sh" "$SITE" > /dev/null
echo "CORE FIXED"
;;

fix-plugins)
bash "$UTIL_DIR/reinstall-plugins.sh" "$SITE" > /dev/null
echo "PLUGINS FIXED"
;;

fix-themes)
bash "$UTIL_DIR/reinstall-themes.sh" "$SITE" > /dev/null
echo "THEMES FIXED"
;;

update-core)
bash "$UTIL_DIR/update-wordpress.sh" "$SITE" > /dev/null
echo "UPDATED"
;;

optimize-db)
wp --path="$SITE" db optimize --skip-plugins --skip-themes > /dev/null
echo "OPTIMIZED"
;;

regenerate-salts)
wp --path="$SITE" config shuffle-salts --skip-plugins --skip-themes > /dev/null
echo "SALTS RESET"
;;

fix-wordpress)
bash "$UTIL_DIR/fix-wordpress.sh" "$SITE" > /dev/null
echo "FULL REPAIR DONE"
;;

esac

done

pause
}

create_admin(){

SITE="$1"

read -p "Admin username: " USER
PASS=$(openssl rand -base64 18)

wp --path="$SITE" user create "$USER" "$USER@example.com" \
--role=administrator --user_pass="$PASS" \
--skip-plugins --skip-themes > /dev/null

echo
echo "Admin Created"
echo "Username : $USER"
echo "Password : $PASS"

pause
}

list_admins(){
SITE="$1"
wp --path="$SITE" user list --role=administrator --skip-plugins --skip-themes
pause
}

delete_admin(){

SITE="$1"

wp --path="$SITE" user list --role=administrator --skip-plugins --skip-themes

read -p "Delete username: " USER

wp --path="$SITE" user delete "$USER" --yes --skip-plugins --skip-themes

echo "Deleted $USER"

pause
}

reset_admin_password(){

SITE="$1"

wp --path="$SITE" user list --role=administrator --skip-plugins --skip-themes

read -p "Username: " USER

PASS=$(openssl rand -base64 18)

wp --path="$SITE" user update "$USER" --user_pass="$PASS" \
--skip-plugins --skip-themes

echo
echo "New password: $PASS"

pause
}

while true
do

clear

echo "======================================="
echo "        EINETIC WP FLEET MANAGER"
echo "======================================="
echo
echo "1) Manage Single Site"
echo "2) Bulk Operations"
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

echo "======================================="
echo " SITE : $DOMAIN"
echo "======================================="
echo
echo "VERIFY"
echo " 1) Verify Core"
echo " 2) Verify Plugins"
echo " 3) Verify Themes"
echo " 4) Verify Database"
echo
echo "REPAIR"
echo " 5) Fix WordPress Core"
echo " 6) Reinstall Plugins"
echo " 7) Reinstall Themes"
echo " 8) Update WordPress"
echo
echo "SECURITY"
echo " 9) Optimize Database"
echo "10) Regenerate Security Salts"
echo
echo "ADMIN USERS"
echo "11) List Admins"
echo "12) Create Admin"
echo "13) Delete Admin"
echo "14) Reset Admin Password"
echo
echo "15) Full WordPress Repair"
echo
echo "0) Back"
echo

read -p "Select option: " CH

case $CH in

1) wp --path="$SITE_PATH" core verify-checksums --skip-plugins --skip-themes ; pause ;;
2) wp --path="$SITE_PATH" plugin verify-checksums --all --skip-plugins --skip-themes ; pause ;;
3) wp --path="$SITE_PATH" theme verify-checksums --all --skip-plugins --skip-themes ; pause ;;
4) wp --path="$SITE_PATH" db check --skip-plugins --skip-themes ; pause ;;

5) bash "$UTIL_DIR/reinstall-core.sh" "$SITE_PATH" ; pause ;;
6) bash "$UTIL_DIR/reinstall-plugins.sh" "$SITE_PATH" ; pause ;;
7) bash "$UTIL_DIR/reinstall-themes.sh" "$SITE_PATH" ; pause ;;
8) bash "$UTIL_DIR/update-wordpress.sh" "$SITE_PATH" ; pause ;;

9) wp --path="$SITE_PATH" db optimize --skip-plugins --skip-themes ; pause ;;
10) wp --path="$SITE_PATH" config shuffle-salts --skip-plugins --skip-themes ; pause ;;

11) list_admins "$SITE_PATH" ;;
12) create_admin "$SITE_PATH" ;;
13) delete_admin "$SITE_PATH" ;;
14) reset_admin_password "$SITE_PATH" ;;
15) bash "$UTIL_DIR/fix-wordpress.sh" "$SITE_PATH" ; pause ;;

0) break ;;

esac

done

;;

2)

clear

echo "======================================="
echo "          BULK OPERATIONS"
echo "======================================="
echo
echo "VERIFY"
echo "1) Verify Core"
echo "2) Verify Plugins"
echo "3) Verify Themes"
echo "4) Verify Database"
echo
echo "REPAIR"
echo "5) Fix Core"
echo "6) Reinstall Plugins"
echo "7) Reinstall Themes"
echo "8) Update WordPress"
echo
echo "SECURITY"
echo "9) Optimize Database"
echo "10) Regenerate Salts"
echo
echo "11) Full WordPress Repair"
echo

read -p "Select option: " BULK

case $BULK in

1) run_bulk verify-core ;;
2) run_bulk verify-plugins ;;
3) run_bulk verify-themes ;;
4) run_bulk verify-db ;;

5) run_bulk fix-core ;;
6) run_bulk fix-plugins ;;
7) run_bulk fix-themes ;;
8) run_bulk update-core ;;

9) run_bulk optimize-db ;;
10) run_bulk regenerate-salts ;;
11) run_bulk fix-wordpress ;;

esac

;;

0)
exit
;;

esac

done