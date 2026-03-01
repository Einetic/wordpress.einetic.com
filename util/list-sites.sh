#!/bin/bash

SITE_PATHS=()
i=1

# Hostinger
for dir in "$HOME"/domains/*/public_html; do
    if [ -f "$dir/wp-config.php" ]; then
        domain=$(basename "$(dirname "$dir")")
        echo "$i. $domain"
        SITE_PATHS+=("$dir")
        ((i++))
    fi
done

# CloudPanel
for dir in /home/*/htdocs/*/; do
    if [ -f "$dir/wp-config.php" ]; then
        domain=$(basename "$dir")
        echo "$i. $domain"
        SITE_PATHS+=("$dir")
        ((i++))
    fi
done

echo "0. Back"

read -p "Select site: " choice

if [ "$choice" -eq 0 ]; then
    exit
fi

SELECTED_SITE="${SITE_PATHS[$((choice-1))]}"

echo "$SELECTED_SITE"