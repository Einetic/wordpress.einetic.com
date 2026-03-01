#!/bin/bash

run_wp() {
    SITE="$1"
    shift
    CMD="$@"

    if [[ "$SITE" == "$HOME/domains/"* ]]; then
        wp $CMD --path="$SITE"
    else
        OWNER=$(stat -c '%U' "$SITE")
        sudo -u "$OWNER" -- wp $CMD --path="$SITE"
    fi
}

scan_sites() {

    for SITE in "$HOME"/domains/*/public_html
    do
        if [ -f "$SITE/wp-config.php" ]; then
            DOMAIN=$(basename "$(dirname "$SITE")")

            if [[ "$DOMAIN" == *BACKUP* ]]; then
                continue
            fi

            echo "$SITE"
        fi
    done

    for SITE in /home/*/htdocs/*
    do
        if [ -f "$SITE/wp-config.php" ]; then
            DOMAIN=$(basename "$SITE")

            if [[ "$DOMAIN" == *BACKUP* ]]; then
                continue
            fi

            echo "$SITE"
        fi
    done
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
            SITE_PATH=$(bash util/list-sites.sh | tail -n 1)

            if [ -z "$SITE_PATH" ]; then
                continue
            fi

            while true
            do
                echo
                echo "Selected: $SITE_PATH"
                echo
                echo "1. Backup"
                echo "2. SSL"
                echo "3. Fix"
                echo "0. Back"
                echo

                read -p "Enter choice: " choice

                case $choice in
                    1)
                        echo "Backup site: $SITE_PATH"
                        ;;
                    2)
                        echo "Install SSL for: $SITE_PATH"
                        ;;
                    3)
                        echo "Fix WordPress: $SITE_PATH"
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
                echo "1. Verify WordPress Core (All Sites)"
                echo "2. Verify Plugins (All Sites)"
                echo "3. Verify Themes (All Sites)"
                echo "4. Verify Database (All Sites)"
                echo "5. Run All Checks"
                echo "0. Back"
                echo

                read -p "Enter choice: " bulk_choice

                case $bulk_choice in

                    1)
                        scan_sites | while read SITE
                        do
                            DOMAIN=$(basename "$SITE")

                            echo
                            echo "Checking core: $DOMAIN"

                            run_wp "$SITE" core verify-checksums
                        done
                        ;;

                    2)
                        scan_sites | while read SITE
                        do
                            DOMAIN=$(basename "$SITE")

                            echo
                            echo "Checking plugins: $DOMAIN"

                            run_wp "$SITE" plugin verify-checksums --all
                        done
                        ;;

                    3)
                        scan_sites | while read SITE
                        do
                            DOMAIN=$(basename "$SITE")

                            echo
                            echo "Checking themes: $DOMAIN"

                            run_wp "$SITE" theme verify-checksums --all
                        done
                        ;;

                    4)
                        scan_sites | while read SITE
                        do
                            DOMAIN=$(basename "$SITE")

                            echo
                            echo "Checking database: $DOMAIN"

                            run_wp "$SITE" db check
                        done
                        ;;

                    5)
                        scan_sites | while read SITE
                        do
                            DOMAIN=$(basename "$SITE")

                            echo
                            echo "Running full check: $DOMAIN"

                            run_wp "$SITE" core verify-checksums
                            run_wp "$SITE" plugin verify-checksums --all
                            run_wp "$SITE" theme verify-checksums --all
                            run_wp "$SITE" db check
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