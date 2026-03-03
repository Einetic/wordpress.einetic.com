#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

SITE="$1"

if [ -z "$SITE" ]; then
  echo "Usage: delete-all-admins.sh <site_path>"
  exit 1
fi

echo "WARNING: Deleting ALL administrators on $SITE"

wp_exec "$SITE" user list \
  --role=administrator \
  --field=ID \
  --skip-plugins --skip-themes | while read ID
do
  echo "Deleting admin ID: $ID"
  wp_exec "$SITE" user delete "$ID" --yes --skip-plugins --skip-themes
done

echo "All administrators removed"