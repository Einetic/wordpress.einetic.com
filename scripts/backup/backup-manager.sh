#!/bin/bash

SITE="$1"
BACKUP_BASE="$SITE/wp-content/backups"

if [ ! -d "$BACKUP_BASE" ]; then
  echo "No backups found"
  exit 1
fi

select_backup(){

echo
echo "Available Backups:"
echo

BACKUPS=($(ls -1 "$BACKUP_BASE"))

if [ ${#BACKUPS[@]} -eq 0 ]; then
  echo "No backups available"
  return 1
fi

for i in "${!BACKUPS[@]}"; do
  echo "$((i+1))) ${BACKUPS[$i]}"
done

echo "0) Back"
echo

read -p "Select backup: " IDX

if [ "$IDX" == "0" ]; then
  return 1
fi

IDX=$((IDX-1))

if [ $IDX -lt 0 ] || [ $IDX -ge ${#BACKUPS[@]} ]; then
  echo "Invalid selection"
  return 1
fi

SELECTED_BACKUP="$BACKUP_BASE/${BACKUPS[$IDX]}"
return 0
}

restore_category(){

CATEGORY="$1"
BACKUP_DIR="$2"

echo "Restoring $CATEGORY"

PARTS=$(ls "$BACKUP_DIR"/$CATEGORY*.part* 2>/dev/null)

if [ -z "$PARTS" ]; then
  echo "No $CATEGORY backup found"
  return
fi

cat $PARTS > "$BACKUP_DIR/$CATEGORY.restore.tar.gz"

tar -xzf "$BACKUP_DIR/$CATEGORY.restore.tar.gz" -C "$SITE/wp-content/$CATEGORY"

rm -f "$BACKUP_DIR/$CATEGORY.restore.tar.gz"

echo "$CATEGORY restored"
}

restore_database(){

BACKUP_DIR="$1"

PARTS=$(ls "$BACKUP_DIR"/database.sql.gz.part* 2>/dev/null)

if [ -z "$PARTS" ]; then
  echo "No database backup found"
  return
fi

cat $PARTS > "$BACKUP_DIR/database.restore.sql.gz"
gunzip "$BACKUP_DIR/database.restore.sql.gz"

wp --path="$SITE" db import "$BACKUP_DIR/database.restore.sql"

rm -f "$BACKUP_DIR/database.restore.sql"

echo "Database restored"
}

full_restore(){

BACKUP_DIR="$1"

echo "Entering maintenance mode"
wp --path="$SITE" maintenance-mode activate

restore_database "$BACKUP_DIR"
restore_category "themes" "$BACKUP_DIR"
restore_category "plugins" "$BACKUP_DIR"
restore_category "mu-plugins" "$BACKUP_DIR"
restore_category "uploads" "$BACKUP_DIR"

wp --path="$SITE" rewrite flush --hard
wp --path="$SITE" cache flush

wp --path="$SITE" maintenance-mode deactivate

echo "Full restore complete"
}

# ----------- MAIN ------------

select_backup || exit

echo
echo "1) Full Restore"
echo "2) Database Only"
echo "3) Themes Only"
echo "4) Plugins Only"
echo "5) Uploads Only"
echo "6) Mu-plugins Only"
echo "0) Back"
echo

read -p "Select option: " ACTION

case $ACTION in

1) full_restore "$SELECTED_BACKUP" ;;
2) restore_database "$SELECTED_BACKUP" ;;
3) restore_category "themes" "$SELECTED_BACKUP" ;;
4) restore_category "plugins" "$SELECTED_BACKUP" ;;
5) restore_category "uploads" "$SELECTED_BACKUP" ;;
6) restore_category "mu-plugins" "$SELECTED_BACKUP" ;;
0) exit ;;
*)

echo "Invalid option"
;;

esac