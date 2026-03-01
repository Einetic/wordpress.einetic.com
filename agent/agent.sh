#!/bin/bash

UTIL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../util" && pwd)"

get_domain() {

    SITE="$1"

    if [[ "$SITE" == *"/public_html" ]]; then
        basename "$(dirname "$SITE")"
    else
        basename "$SITE"
    fi
}

scan_sites() {

    for SITE in "$HOME"/domains/*/public_html
    do
        if [ -f "$SITE/wp-config.php" ]; then
            DOMAIN=$(basename "$(dirname "$SITE")")

            [[ "$DOMAIN" == *BACKUP* ]] && continue

            echo "$SITE"
        fi
    done

    for SITE in /home/*/htdocs/*
    do
        if [ -f "$SITE/wp-config.php" ]; then
            DOMAIN=$(basename "$SITE")

            [[ "$DOMAIN" == *BACKUP* ]] && continue

            echo "$SITE"
        fi
    done
}

run_bulk() {

    ACTION="$1"

    scan_sites | while read SITE
    do
        DOMAIN=$(get_domain "$SITE")

        echo
        echo "Processing: $DOMAIN"

        case $ACTION in

            verify-core)
                wp --path="$SITE" core verify-checksums > /dev/null 2>&1 \
                && echo "Core OK" || echo "Core FAILED"
            ;;

            verify-plugins)
                wp --path="$SITE" plugin verify-checksums --all > /dev/null 2>&1 \
                && echo "Plugins OK" || echo "Plugins FAILED"
            ;;

            verify-themes)
                wp --path="$SITE" theme verify-checksums --all > /dev/null 2>&1 \
                && echo "Themes OK" || echo "Themes FAILED"
            ;;

            verify-db)
                wp --path="$SITE" db check > /dev/null 2>&1 \
                && echo "DB OK" || echo "DB FAILED"
            ;;

            fix-core)
                bash "$UTIL_DIR/reinstall-core.sh" "$SITE"
            ;;

            fix-plugins)
                bash "$UTIL_DIR/reinstall-plugins.sh" "$SITE"
            ;;

            fix-themes)
                bash "$UTIL_DIR/reinstall-themes.sh" "$SITE"
            ;;

            update-core)
                bash "$UTIL_DIR/update-wordpress.sh" "$SITE"
            ;;

            optimize-db)
                wp --path="$SITE" db optimize > /dev/null
            ;;

            regenerate-salts)
                wp --path="$SITE" config shuffle-salts > /dev/null
            ;;

        esac

    done

}

create_admin() {

    SITE="$1"

    read -p "Admin username: " USER

    PASS=$(openssl rand -base64 18)

    wp --path="$SITE" user create "$USER" "$USER@example.com" \
    --role=administrator --user_pass="$PASS" > /dev/null

    echo
    echo "Admin created"
    echo "Username: $USER"
    echo "Password: $PASS"
}

list_admins() {

    SITE="$1"

    wp --path="$SITE" user list --role=administrator
}

delete_admin() {

    SITE="$1"

    list_admins "$SITE"

    read -p "Enter admin username to delete: " USER

    wp --path="$SITE" user delete "$USER" --yes
}

reset_admin_password() {

    SITE="$1"

    list_admins "$SITE"

    read -p "Admin username: " USER

    PASS=$(openssl rand -base64 18)

    wp --path="$SITE" user update "$USER" --user_pass="$PASS"

    echo "New password: $PASS"
}

while true
do

    echo
    echo "===== Einetic WP Fleet ====="
    echo
    echo "1. Manage Single Site"
    echo "2. Bulk Operations"
    echo "0. Exit"
    echo

    read -p "Choice: " MAIN

    case $MAIN in

    1)

        SITE_PATH=$(bash "$UTIL_DIR/list-sites.sh" | tee /dev/tty | tail -n 1)

        [ -z "$SITE_PATH" ] && continue

        while true
        do

            DOMAIN=$(get_domain "$SITE_PATH")

            echo
            echo "===== $DOMAIN ====="
            echo
            echo "1 Verify Core"
            echo "2 Verify Plugins"
            echo "3 Verify Themes"
            echo "4 Verify DB"
            echo
            echo "5 Fix Core"
            echo "6 Reinstall Plugins"
            echo "7 Reinstall Themes"
            echo "8 Update WordPress"
            echo
            echo "9 Optimize DB"
            echo "10 Regenerate Salts"
            echo
            echo "11 List Admins"
            echo "12 Create Admin"
            echo "13 Delete Admin"
            echo "14 Reset Admin Password"
            echo
            echo "0 Back"
            echo

            read -p "Choice: " CH

            case $CH in

            1) wp --path="$SITE_PATH" core verify-checksums ;;
            2) wp --path="$SITE_PATH" plugin verify-checksums --all ;;
            3) wp --path="$SITE_PATH" theme verify-checksums --all ;;
            4) wp --path="$SITE_PATH" db check ;;

            5) bash "$UTIL_DIR/reinstall-core.sh" "$SITE_PATH" ;;
            6) bash "$UTIL_DIR/reinstall-plugins.sh" "$SITE_PATH" ;;
            7) bash "$UTIL_DIR/reinstall-themes.sh" "$SITE_PATH" ;;
            8) bash "$UTIL_DIR/update-wordpress.sh" "$SITE_PATH" ;;

            9) wp --path="$SITE_PATH" db optimize ;;
            10) wp --path="$SITE_PATH" config shuffle-salts ;;

            11) list_admins "$SITE_PATH" ;;
            12) create_admin "$SITE_PATH" ;;
            13) delete_admin "$SITE_PATH" ;;
            14) reset_admin_password "$SITE_PATH" ;;

            0) break ;;

            esac

        done

    ;;

    2)

        echo
        echo "===== Bulk Operations ====="
        echo
        echo "1 Verify Core"
        echo "2 Verify Plugins"
        echo "3 Verify Themes"
        echo "4 Verify DB"
        echo
        echo "5 Fix Core"
        echo "6 Reinstall Plugins"
        echo "7 Reinstall Themes"
        echo "8 Update WordPress"
        echo
        echo "9 Optimize DB"
        echo "10 Regenerate Salts"
        echo

        read -p "Choice: " BULK

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

        esac

    ;;

    0)
        exit
    ;;

    esac

done