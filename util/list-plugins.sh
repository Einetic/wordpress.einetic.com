#!/bin/bash

SITE_PATH="$1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/wp-cli.sh" "$SITE_PATH" plugin list