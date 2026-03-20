#!/bin/bash

TOMCAT_DIR="/opt/tomcat"
WEB_DIR="$TOMCAT_DIR/websites"
CATALINA_CONF="$TOMCAT_DIR/conf/Catalina"
NGINX_DIR="/etc/nginx/websites"

validate_domain() {
  DOMAIN=$1
  if [[ -z "$DOMAIN" || ! "$DOMAIN" =~ ^[a-zA-Z0-9.-]+$ ]]; then
    echo "Invalid domain"
    exit 1
  fi
}

is_root_domain() {
  DOMAIN=$1
  PARTS=$(echo $DOMAIN | awk -F'.' '{print NF}')
  [ "$PARTS" -eq 2 ]
}

get_server_names() {
  DOMAIN=$1
  if is_root_domain $DOMAIN; then
    echo "$DOMAIN www.$DOMAIN"
  else
    echo "$DOMAIN"
  fi
}

create_tomcat_conf() {
  DOMAIN=$1
  CONF_FILE="$TOMCAT_DIR/conf/$DOMAIN.conf"

  if [ -f "$CONF_FILE" ]; then
    echo "Tomcat conf exists: $DOMAIN"
    return
  fi

  USER_ID="$DOMAIN@eineticsite.com"
  PASSWORD=$(echo -n "$USER_ID" | md5sum | awk '{print $1}')
  DATABASE=$(echo "$DOMAIN" | tr -d '.')

  cat <<EOF > $CONF_FILE
{"UserId":"$USER_ID","Password":"$PASSWORD","Database":"$DATABASE","API":"https://api.einetic.com/v1/"}
EOF

  echo "Tomcat conf created: $CONF_FILE"
}

add_domain() {
  DOMAIN=$1
  validate_domain $DOMAIN

  if [ -f "$NGINX_DIR/$DOMAIN.conf" ]; then
    echo "Domain already exists: $DOMAIN"
    return
  fi

  SERVER_NAMES=$(get_server_names $DOMAIN)

  mkdir -p $WEB_DIR/$DOMAIN
  mkdir -p $CATALINA_CONF/$DOMAIN

  create_tomcat_conf $DOMAIN

  cat <<EOF > $NGINX_DIR/$DOMAIN.conf
server {
    listen 80;
    server_name $SERVER_NAMES;

    location / {
        proxy_pass http://127.0.0.1:9000;

        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_buffering on;
        proxy_buffers 8 128k;

        proxy_cache STATIC;
        proxy_cache_valid 200 10m;
    }
}
EOF

  nginx -t && systemctl reload nginx
  chown -R tomcat:tomcat $WEB_DIR/$DOMAIN

  echo "Added: $DOMAIN"
}

add_ssl() {
  DOMAIN=$1
  validate_domain $DOMAIN

  # Prevent certbot from touching default block
  if [ -f "$NGINX_DIR/ip_block.conf" ]; then
    mv $NGINX_DIR/ip_block.conf $NGINX_DIR/ip_block.conf.bak
    nginx -t && systemctl reload nginx
  fi

  if is_root_domain $DOMAIN; then
    certbot --nginx -d $DOMAIN -d www.$DOMAIN \
    --agree-tos -m $DOMAIN@eineticsite.com --non-interactive
  else
    certbot --nginx -d $DOMAIN \
    --agree-tos -m $DOMAIN@eineticsite.com --non-interactive
  fi

  # Restore default block
  if [ -f "$NGINX_DIR/ip_block.conf.bak" ]; then
    mv $NGINX_DIR/ip_block.conf.bak $NGINX_DIR/ip_block.conf
    nginx -t && systemctl reload nginx
  fi

  echo "SSL added: $DOMAIN"
}

remove_domain() {
  DOMAIN=$1
  validate_domain $DOMAIN

  rm -rf $WEB_DIR/$DOMAIN
  rm -rf $CATALINA_CONF/$DOMAIN
  rm -f $NGINX_DIR/$DOMAIN.conf

  nginx -t && systemctl reload nginx

  echo "Removed: $DOMAIN"
}

remove_ssl() {
  DOMAIN=$1
  validate_domain $DOMAIN

  certbot delete --cert-name $DOMAIN || true

  echo "SSL removed: $DOMAIN"
}

list_domain() {
  if [ -d "$WEB_DIR" ]; then
    ls -1 $WEB_DIR
  else
    echo "No domains found"
  fi
}

run_menu() {
  clear
  echo "===== EINETIC HOST MANAGER ====="
  echo "1) Add Domain"
  echo "2) Remove Domain"
  echo "3) List Domains"
  echo "4) Add SSL"
  echo "5) Remove SSL"
  echo "0) Exit"
  echo ""

  read -p "Choose option: " OPTION

  case "$OPTION" in
    1)
      read -p "Enter domain: " DOMAIN
      add_domain $DOMAIN
      ;;
    2)
      read -p "Enter domain: " DOMAIN
      remove_domain $DOMAIN
      ;;
    3)
      list_domain
      read -p "Press enter to continue..."
      ;;
    4)
      read -p "Enter domain: " DOMAIN
      add_ssl $DOMAIN
      ;;
    5)
      read -p "Enter domain: " DOMAIN
      remove_ssl $DOMAIN
      ;;
    0)
      exit 0
      ;;
    *)
      echo "Invalid option"
      sleep 1
      ;;
  esac
}

if [ -z "$1" ]; then
  while true; do
    run_menu
  done
else
  case "$1" in
    add) add_domain $2 ;;
    remove) remove_domain $2 ;;
    list) list_domain ;;
    ssl) add_ssl $2 ;;
    ssl-remove) remove_ssl $2 ;;
    *) echo "Usage: $0 add domain | remove domain | list | ssl domain | ssl-remove domain" ;;
  esac
fi