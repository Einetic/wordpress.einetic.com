#!/bin/bash

SEARCH_PATHS=("/home" "/var/www" "/domains")

echo
echo "Scanning for WordPress installations..."
echo

i=1
declare -a SITE_PATHS

for base in "${SEARCH_PATHS[@]}"; do

    [ -d "$base" ] || continue

    while IFS= read -r config; do

        site_path=$(dirname "$config")
        site_name=$(basename "$site_path")

        status="OK"
        version="unknown"

        if [ ! -f "$site_path/wp-config.php" ]; then
            status="BROKEN"
        fi

        if [ -f "$site_path/wp-includes/version.php" ]; then
            version=$(grep "\$wp_version" "$site_path/wp-includes/version.php" | cut -d"'" -f2)
        fi

        printf "%2d) %-25s  %-10s  %-8s\n" "$i" "$site_name" "$version" "$status"

        SITE_PATHS[$i]="$site_path"
        ((i++))

    done < <(find "$base" -maxdepth 4 -type f -name "wp-config.php" 2>/dev/null)

done

echo
read -p "Select site number (0 to cancel): " choice

if [ "$choice" == "0" ]; then
    exit
fi

SELECTED_SITE="${SITE_PATHS[$choice]}"

if [ -z "$SELECTED_SITE" ]; then
    echo "Invalid selection"
    exit
fi

echo
echo "Selected:"
echo "$SELECTED_SITE"