#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/core.sh"

SITE="$1"

if [ -z "$SITE" ]; then
  echo "Usage: cleanup-admins.sh <site_path>"
  exit 1
fi

echo "================================="
echo "Admin Cleanup for $SITE"
echo "================================="
echo

# List admins
ADMINS=$(wp_exec "$SITE" user list \
  --role=administrator \
  --fields=ID,user_login,user_email \
  --format=table \
  --skip-plugins --skip-themes)

COUNT=$(wp_exec "$SITE" user list \
  --role=administrator \
  --format=count \
  --skip-plugins --skip-themes)

if [ "$COUNT" -eq 0 ]; then
  echo "No administrators found."
  exit 0
fi

echo "Current administrators:"
echo
echo "$ADMINS"
echo

echo "Enter admin ID(s) to KEEP (space separated)"
read -p "Keep IDs: " KEEP_IDS

if [ -z "$KEEP_IDS" ]; then
  echo "No IDs entered. Aborting."
  exit 1
fi

# First ID will be used for reassignment
REASSIGN=$(echo "$KEEP_IDS" | awk '{print $1}')

echo
echo "Content from removed admins will be reassigned to: $REASSIGN"
echo

# Loop all admins
wp_exec "$SITE" user list \
  --role=administrator \
  --field=ID \
  --skip-plugins --skip-themes | while read ID
do

KEEP=false

for k in $KEEP_IDS
do
  if [ "$ID" == "$k" ]; then
    KEEP=true
  fi
done

if [ "$KEEP" = false ]; then
  echo "Deleting admin ID $ID → reassigned to $REASSIGN"
  wp_exec "$SITE" user delete "$ID" --reassign="$REASSIGN" --yes --skip-plugins --skip-themes
fi

done

echo
echo "Admin cleanup complete"