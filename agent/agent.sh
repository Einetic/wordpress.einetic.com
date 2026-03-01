SITE_PATH=$(bash util/list-sites.sh)

if [ -z "$SITE_PATH" ]; then
    return
fi

echo "Selected: $SITE_PATH"

echo "1. Backup"
echo "2. SSL"
echo "3. Fix"
echo "0. Back"

read choice

case $choice in
1)
    bash util/backup-site.sh "$SITE_PATH"
    ;;
2)
    bash util/install-ssl.sh "$SITE_PATH"
    ;;
3)
    bash util/fix-site.sh "$SITE_PATH"
    ;;
esac