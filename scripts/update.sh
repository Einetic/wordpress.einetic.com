#!/bin/bash

APP_NAME="einetic-wp-fleet"
INSTALL_DIR="/opt/$APP_NAME"

if [ ! -d "$INSTALL_DIR" ]; then
  echo "$APP_NAME not installed."
  exit 1
fi

cd "$INSTALL_DIR" || exit

echo "Checking for updates..."

git fetch origin

LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" = "$REMOTE" ]; then
  echo "Already up to date."
  exit 0
fi

echo "Update found. Pulling latest code..."

git pull origin main

echo "Update complete."