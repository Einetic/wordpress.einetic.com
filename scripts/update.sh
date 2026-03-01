#!/bin/bash

APP_NAME="einetic-wp-fleet"

# Detect install location
if [ -d "/opt/$APP_NAME" ]; then
    INSTALL_DIR="/opt/$APP_NAME"
else
    INSTALL_DIR="$HOME/$APP_NAME"
fi

if [ ! -d "$INSTALL_DIR/.git" ]; then
    echo "$APP_NAME not installed correctly."
    exit 1
fi

cd "$INSTALL_DIR" || exit

echo "Checking for updates..."

git fetch origin

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/master)

if [ "$LOCAL" = "$REMOTE" ]; then
    echo "Already up to date."
    exit 0
fi

echo "Update found. Updating..."

git reset --hard origin/master

echo "Update complete."