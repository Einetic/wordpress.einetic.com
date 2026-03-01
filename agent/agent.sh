#!/bin/bash

BACKUP_DIR="$HOME/wp-backups"
mkdir -p "$BACKUP_DIR"

run_wp() {
    SITE="$1"
    shift
    CMD="$@"

    if [[ "$SITE" == "$HOME/domains/"* ]]; then
        wp $CMD --path="$SITE" > /dev/null 2>&1
    else
        OWNER=$(stat -c '%U' "$SITE")
        sudo -u "$OWNER" -- wp $CMD --path="$SITE" > /dev/null 2>&1
    fi
}

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

backup_site() {

    SITE="$1"
    DOMAIN=$(get_domain "$SITE")

    DATE=$(date +"%Y%m%d_%H%M%S")

    FILE="$BACKUP_DIR/${DOMAIN}_${DATE}.tar.gz"

    echo
    echo "Creating backup: $DOMAIN"

    tar -czf "$FILE" -C "$SITE" . 2>/dev/null

    if [ -f "$FILE" ]; then
        echo "Backup created: $FILE"
    else
        echo "Backup failed"
    fi
}

install_ssl() {

    SITE="$1"
    DOMAIN=$(get_domain "$SITE")

    echo
    echo "Installing SSL for: $DOMAIN"

    if command -v clpctl >/dev/null 2>&1; then
        clpctl lets-encrypt:install:certificate --domainName="$DOMAIN"
        echo "SSL request sent"
    else
        echo "SSL install not supported on this server"
    fi
}

fix_wordpress() {

    SITE="$1"
    DOMAIN=$(get_domain "$SITE")

    echo
    echo "Repairing WordPress: $DOMAIN"

    echo "Reinstalling core..."
    run_wp "$SITE" core download --force

    echo "Updating database..."
    run_wp "$SITE" core update-db

    echo "Clearing cache folders..."
    rm -rf "$SITE/wp-content/cache" 2>/dev/null
    rm -rf "$SITE/wp-content/uploads/cache" 2>/dev/null

    echo "Repair complete"
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

    read -p "Enter choice: " main_choice

    case $main_choice in

        1)

            SITE_PATH=$(bash util/list-sites.sh | tee /dev/tty | tail -n 1)

            [ -z "$SITE_PATH" ] && continue

            while true
            do
                DOMAIN=$(get_domain "$SITE_PATH")

                echo
                echo "Selected: $DOMAIN"
                echo
                echo "1. Backup"
                echo "2. SSL"
                echo "3. Fix WordPress"
                echo "0. Back"
                echo

                read -p "Enter choice: " choice

                case $choice in

                    1)
                        backup_site "$SITE_PATH"
                        ;;

                    2)
                        install_ssl "$SITE_PATH"
                        ;;

                    3)
                        fix_wordpress "$SITE_PATH"
                        ;;

                    0)
                        break
                        ;;

                    *)
                        echo "Invalid option"
                        ;;

                esac
            done

        ;;

        2)

            while true
            do

                echo
                echo "===== Bulk Operations ====="
                echo
                echo "1. Verify WordPress Core"
                echo "2. Verify Plugins"
                echo "3. Verify Themes"
                echo "4. Verify Database"
                echo "5. Run All Checks"
                echo "0. Back"
                echo

                read -p "Enter choice: " bulk_choice

                case $bulk_choice in

                    1)

                        scan_sites | while read SITE
                        do
                            DOMAIN=$(get_domain "$SITE")

                            echo
                            echo "Checking core: $DOMAIN"

                            if run_wp "$SITE" core verify-checksums
                            then
                                echo "Status: OK"
                            else
                                echo "Status: FAILED"
                            fi
                        done

                    ;;

                    2)

                        scan_sites | while read SITE
                        do
                            DOMAIN=$(get_domain "$SITE")

                            echo
                            echo "Checking plugins: $DOMAIN"

                            if run_wp "$SITE" plugin verify-checksums --all
                            then
                                echo "Status: OK"
                            else
                                echo "Status: FAILED"
                            fi
                        done

                    ;;

                    3)

                        scan_sites | while read SITE
                        do
                            DOMAIN=$(get_domain "$SITE")

                            echo
                            echo "Checking themes: $DOMAIN"

                            if run_wp "$SITE" theme verify-checksums --all
                            then
                                echo "Status: OK"
                            else
                                echo "Status: FAILED"
                            fi
                        done

                    ;;

                    4)

                        scan_sites | while read SITE
                        do
                            DOMAIN=$(get_domain "$SITE")

                            echo
                            echo "Checking database: $DOMAIN"

                            if run_wp "$SITE" db check
                            then
                                echo "Status: OK"
                            else
                                echo "Status: FAILED"
                            fi
                        done

                    ;;

                    5)

                        scan_sites | while read SITE
                        do
                            DOMAIN=$(get_domain "$SITE")

                            echo
                            echo "Running full check: $DOMAIN"

                            run_wp "$SITE" core verify-checksums
                            run_wp "$SITE" plugin verify-checksums --all
                            run_wp "$SITE" theme verify-checksums --all
                            run_wp "$SITE" db check

                            echo "Completed: $DOMAIN"
                        done

                    ;;

                    0)
                        break
                        ;;

                    *)
                        echo "Invalid option"
                        ;;

                esac

            done

        ;;

        0)
            exit
        ;;

        *)
            echo "Invalid option"
        ;;

    esac

done