#!/bin/bash

SITE_PATHS=()
i=1

# Hostinger structure
for dir in "$HOME"/domains/*/public_html
do
    if [ -f "$dir/wp-config.php" ]; then

        domain=$(basename "$(dirname "$dir")")

        if [[ "$domain" == *BACKUP* ]]; then
            continue
        fi

        echo "$i. $domain"
        SITE_PATHS+=("$dir")
        ((i++))
    fi
done

# CloudPanel structure
for dir in /home/*/htdocs/*
do
    if [ -f "$dir/wp-config.php" ]; then

        domain=$(basename "$dir")

        if [[ "$domain" == *BACKUP* ]]; then
            continue
        fi

        echo "$i. $domain"
        SITE_PATHS+=("$dir")
        ((i++))
    fi
done


if [ ${#SITE_PATHS[@]} -eq 0 ]; then
    echo "No WordPress sites found."
    exit 0
fi

echo "0. Back"
echo "====================="

read -p "Select site: " choice

# Validate numeric
if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
    exit 0
fi

if [ "$choice" -eq 0 ]; then
    exit 0
fi

if [ "$choice" -gt "${#SITE_PATHS[@]}" ]; then
    exit 0
fi

SELECTED_SITE="${SITE_PATHS[$((choice-1))]}"

echo "$SELECTED_SITE"