#!/bin/bash

APP_NAME="einetic-wp-fleet"
if [ "$EUID" -eq 0 ]; then
    INSTALL_DIR="/opt/$APP_NAME"
else
    INSTALL_DIR="$HOME/$APP_NAME"
fi
REPO_URL="https://github.com/Einetic/wordpress.einetic.com.git"

echo "Installing $APP_NAME..."

if [ -d "$INSTALL_DIR" ]; then
  echo "Removing existing installation..."
  rm -rf "$INSTALL_DIR"
fi

echo "Cloning repository..."
git clone "$REPO_URL" "$INSTALL_DIR"

mkdir -p "$INSTALL_DIR/logs"
mkdir -p "$INSTALL_DIR/tmp"

chmod -R 750 "$INSTALL_DIR"

echo "$APP_NAME installed at $INSTALL_DIR"