#!/bin/bash

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
                        for SITE in $(bash util/find-sites.sh)
                        do
                            echo "Checking core: $SITE"
                            wp core verify-checksums --path="$SITE"
                        done
                        ;;

                    2)
                        for SITE in $(bash util/find-sites.sh)
                        do
                            echo "Checking plugins: $SITE"
                            wp plugin verify-checksums --all --path="$SITE"
                        done
                        ;;

                    3)
                        for SITE in $(bash util/find-sites.sh)
                        do
                            echo "Checking themes: $SITE"
                            wp theme verify-checksums --all --path="$SITE"
                        done
                        ;;

                    4)
                        for SITE in $(bash util/find-sites.sh)
                        do
                            echo "Checking database: $SITE"
                            wp db check --path="$SITE"
                        done
                        ;;

                    5)
                        for SITE in $(bash util/find-sites.sh)
                        do
                            echo "Running full check: $SITE"
                            wp core verify-checksums --path="$SITE"
                            wp plugin verify-checksums --all --path="$SITE"
                            wp theme verify-checksums --all --path="$SITE"
                            wp db check --path="$SITE"
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