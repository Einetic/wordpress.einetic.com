#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

SITE_PATH="$1"

if [ -z "$SITE_PATH" ]; then
    echo "Usage: update-wordpress.sh <site_path>"
    exit 1
fi

wp_exec "$SITE_PATH" core update