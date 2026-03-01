#!/bin/bash

echo
echo "Scanning for WordPress installations..."
echo

i=1
SITE_PATHS=()

# Hostinger structure
for dir in "$HOME"/domains/*/public_html; do
    if [ -f "$dir/wp-config.php" ]; then
        SITE_PATHS+=("$dir")
        domain=$(basename "$(dirname "$dir")")
        echo "$i. $domain"
        ((i++))
    fi
done

# CloudPanel structure
for dir in /home/*/htdocs/*; do
    if [ -f "$dir/wp-config.php" ]; then
        SITE_PATHS+=("$dir")
        domain=$(basename "$dir")
        echo "$i. $domain"
        ((i++))
    fi
done

echo
echo "Select site number (0 to cancel):"
read choice

if [ "$choice" -eq 0 ]; then
    exit
fi

SELECTED_SITE="${SITE_PATHS[$((choice-1))]}"

echo "$SELECTED_SITE"