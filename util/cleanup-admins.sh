#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

SITE="$1"

if [ -z "$SITE" ]; then
  echo "Usage: cleanup-admins.sh <site_path>"
  exit 1
fi

echo "Cleaning admins for $SITE"

# Get oldest admin ID
OLDEST=$(wp_exec "$SITE" user list \
  --role=administrator \
  --orderby=registered \
  --order=ASC \
  --field=ID \
  --skip-plugins --skip-themes | head -n1)

if [ -z "$OLDEST" ]; then
  echo "No administrators found."
  exit 0
fi

echo "Keeping oldest admin ID: $OLDEST"

# Delete others
wp_exec "$SITE" user list \
  --role=administrator \
  --field=ID \
  --skip-plugins --skip-themes | while read ID
do
  if [ "$ID" != "$OLDEST" ]; then
    echo "Deleting admin ID: $ID"
    wp_exec "$SITE" user delete "$ID" --yes --skip-plugins --skip-themes
  fi
done

echo "Admin cleanup complete"