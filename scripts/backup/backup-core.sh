#!/bin/bash

SITE="$1"
CHUNK_SIZE_BYTES=262144000   # 250MB

if [ -z "$SITE" ]; then
  echo "Usage: backup-core.sh <site_path>"
  exit 1
fi

if [ ! -f "$SITE/wp-config.php" ]; then
  echo "Invalid WordPress path"
  exit 1
fi

SITE_URL=$(wp --path="$SITE" option get siteurl --skip-plugins --skip-themes 2>/dev/null)
SITE_IDENTIFIER=$(echo "$SITE_URL" | sed -E 's#https?://##' | sed 's#/.*##')

TIMESTAMP=$(date -u +"%Y-%m-%dT%H-%M-%SZ")
BACKUP_ID="${SITE_IDENTIFIER}-${TIMESTAMP}-$(openssl rand -hex 3)"

BACKUP_BASE="$SITE/wp-content/backups"
BACKUP_DIR="$BACKUP_BASE/$BACKUP_ID"
LOCK_FILE="$BACKUP_BASE/backup.lock"

mkdir -p "$BACKUP_BASE"

if [ -f "$LOCK_FILE" ]; then
  echo "Backup already running"
  exit 1
fi

touch "$LOCK_FILE"

mkdir -p "$BACKUP_DIR"

echo "Backup ID: $BACKUP_ID"
echo "Creating backup at $BACKUP_DIR"

# -----------------------
# DATABASE BACKUP
# -----------------------

echo "Exporting database"
wp --path="$SITE" db export "$BACKUP_DIR/database.sql" --skip-plugins --skip-themes
gzip "$BACKUP_DIR/database.sql"

# -----------------------
# ARCHIVE FUNCTIONS
# -----------------------

archive_category() {
  SRC_PATH="$1"
  ARCHIVE_NAME="$2"

  if [ -d "$SRC_PATH" ]; then
    tar -czf "$BACKUP_DIR/$ARCHIVE_NAME" -C "$SRC_PATH" .
  fi
}

echo "Archiving themes"
archive_category "$SITE/wp-content/themes" "themes.tar.gz"

echo "Archiving plugins"
archive_category "$SITE/wp-content/plugins" "plugins.tar.gz"

echo "Archiving mu-plugins"
archive_category "$SITE/wp-content/mu-plugins" "mu-plugins.tar.gz"

echo "Archiving uploads"
tar --exclude="$SITE/wp-content/uploads/cache" \
    --exclude="$SITE/wp-content/uploads/litespeed" \
    -czf "$BACKUP_DIR/uploads.tar.gz" \
    -C "$SITE/wp-content/uploads" .

# -----------------------
# SPLIT FUNCTION
# -----------------------

split_archive() {
  FILE="$1"

  if [ -f "$FILE" ]; then
    split -b $CHUNK_SIZE_BYTES -d -a 2 "$FILE" "$FILE.part"
    rm -f "$FILE"
  fi
}

echo "Splitting archives"
for FILE in "$BACKUP_DIR"/*.gz; do
  split_archive "$FILE"
done

# -----------------------
# MANIFEST GENERATION
# -----------------------

MANIFEST="$BACKUP_DIR/manifest.json"

echo "Generating manifest"

echo "{" > "$MANIFEST"
echo "  \"backup_format_version\": 1," >> "$MANIFEST"
echo "  \"backup_id\": \"$BACKUP_ID\"," >> "$MANIFEST"
echo "  \"site_identifier\": \"$SITE_IDENTIFIER\"," >> "$MANIFEST"
echo "  \"backup_type\": \"full\"," >> "$MANIFEST"
echo "  \"created_at_utc\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"," >> "$MANIFEST"
echo "  \"chunk_size_bytes\": $CHUNK_SIZE_BYTES," >> "$MANIFEST"
echo "  \"parts\": [" >> "$MANIFEST"

FIRST=true
for PART in "$BACKUP_DIR"/*.part*; do
  SIZE=$(stat -c%s "$PART")
  NAME=$(basename "$PART")

  if [ "$FIRST" = true ]; then
    FIRST=false
  else
    echo "," >> "$MANIFEST"
  fi

  echo -n "    { \"part_name\": \"$NAME\", \"size_bytes\": $SIZE, \"uploaded\": false }" >> "$MANIFEST"
done

echo "" >> "$MANIFEST"
echo "  ]" >> "$MANIFEST"
echo "}" >> "$MANIFEST"

rm -f "$LOCK_FILE"

echo "Backup completed successfully"
echo "Backup location: $BACKUP_DIR"