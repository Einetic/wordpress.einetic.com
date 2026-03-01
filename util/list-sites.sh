#!/bin/bash

SITE_PATHS=()
i=1

for dir in "$HOME"/domains/*/public_html; do
    if [ -f "$dir/wp-config.php" ]; then
        domain=$(basename "$(dirname "$dir"))
        echo "$i. $domain"
        SITE_PATHS+=("$dir")
        ((i++))
    fi
done

if [ ${#SITE_PATHS[@]} -eq 0 ]; then
    echo "No WordPress sites found."
    exit
fi

echo "0. Back"
echo "====================="
read -p "Select site: " choice

if [ "$choice" -eq 0 ]; then
    exit
fi

SELECTED_SITE="${SITE_PATHS[$((choice-1))]}"

echo "$SELECTED_SITE"