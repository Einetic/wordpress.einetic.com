#!/bin/bash

SITE_LIST=()

i=1

# CloudPanel
for dir in /home/*/htdocs/*/; do
    if [ -f "$dir/wp-config.php" ]; then
        echo "$i. $(basename "$dir")"
        SITE_LIST+=("$dir")
        ((i++))
    fi
done

# Hostinger
for dir in /home/*/domains/*/public_html; do
    if [ -f "$dir/wp-config.php" ]; then
        echo "$i. $(basename $(dirname "$dir"))"
        SITE_LIST+=("$dir")
        ((i++))
    fi
done