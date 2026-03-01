#!/bin/bash

domain="$1"

find / -type f -path "*/$domain/wp-config.php" 2>/dev/null | while read file; do
    dirname "$file"
done | head -n 1