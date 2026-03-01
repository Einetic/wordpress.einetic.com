#!/bin/bash

SITE_PATH=$(bash util/list-sites.sh | tail -n 1)

if [ -z "$SITE_PATH" ]; then
    exit
fi

echo
echo "Selected: $SITE_PATH"
echo

echo "1. Backup"
echo "2. SSL"
echo "3. Fix"
echo "0. Back"

read choice

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
    exit
    ;;
*)
    echo "Invalid option"
    ;;
esac