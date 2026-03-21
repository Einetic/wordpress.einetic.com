#!/bin/bash

TOMCAT_DIR="/opt/tomcat"
WEB_DIR="$TOMCAT_DIR/websites"
NGINX_DIR="/etc/nginx/websites"

validate_domain() {
  local DOMAIN="$1"

  [[ -z "$DOMAIN" ]] && return 1

  if [[ "$DOMAIN" =~ ^([a-zA-Z0-9](-?[a-zA-Z0-9])*\.)+[a-zA-Z]{2,}$ ]]; then
    return 0
  fi

  return 1
}

is_root_domain() {
  local DOMAIN="$1"
  local DOTS=${DOMAIN//[^.]}

  [[ ${#DOTS} -eq 1 ]]
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
  PASSWORD=$(printf "%s" "$USER_ID" | md5sum | awk '{print $1}')
  DATABASE=$(echo "$DOMAIN" | tr -cd 'a-zA-Z0-9')

  cat <<EOF > "$CONF_FILE"
{"UserId":"$USER_ID","Password":"$PASSWORD","Database":"$DATABASE","API":"https://api.einetic.com/v1/"}
EOF

  echo "Tomcat conf created: $CONF_FILE"
}

add_domain() {
  DOMAIN=$1
  validate_domain $DOMAIN || { echo "Invalid domain"; return; }

  if [ -f "$NGINX_DIR/$DOMAIN.conf" ]; then
    echo "Domain already exists: $DOMAIN"
    return
  fi

  mkdir -p $WEB_DIR/$DOMAIN
  
  if is_root_domain $DOMAIN; then
    SERVER_NAME="$DOMAIN www.$DOMAIN"
  else
    SERVER_NAME="$DOMAIN"
  fi

  create_tomcat_conf $DOMAIN

  cat <<EOF > $NGINX_DIR/$DOMAIN.conf
server {
    listen 80;
    server_name $SERVER_NAME;

    location / {
        proxy_pass http://127.0.0.1:9000;

        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_set_header Connection "";
    }
}
EOF

  nginx -t && systemctl reload nginx
  chown -R tomcat:tomcat $WEB_DIR/$DOMAIN

SERVER_XML="$TOMCAT_DIR/conf/server.xml"

if is_root_domain $DOMAIN; then
  HOST_NAME="www.$DOMAIN"
  ALIAS="$DOMAIN"
else
  HOST_NAME="$DOMAIN"
  ALIAS="$DOMAIN"
fi

if ! grep -q "<Host name=\"$HOST_NAME\"" $SERVER_XML; then

  sed -i "/<\/Engine>/i <Host name=\"$HOST_NAME\" appBase=\"websites/$DOMAIN\" unpackWARs=\"true\" autoDeploy=\"true\"><Alias>$ALIAS</Alias></Host>" $SERVER_XML

  systemctl restart tomcat
  echo "Tomcat host added"
fi

  echo "HTTP live: $DOMAIN"
}

add_ssl() {
  DOMAIN=$1
  validate_domain $DOMAIN || { echo "Invalid domain"; return; }

  if is_root_domain $DOMAIN; then
    certbot certonly --nginx -d $DOMAIN -d www.$DOMAIN --agree-tos -m $DOMAIN@eineticsite.com --non-interactive
  else
    certbot certonly --nginx -d $DOMAIN --agree-tos -m $DOMAIN@eineticsite.com --non-interactive
  fi

  if [ $? -ne 0 ]; then
    echo "SSL failed"
    return
  fi

  if is_root_domain $DOMAIN; then
cat <<EOF > $NGINX_DIR/$DOMAIN.conf
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    return 301 https://www.$DOMAIN\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    return 301 https://www.$DOMAIN\$request_uri;
}

server {
    listen 443 ssl;
    server_name www.$DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        proxy_pass http://127.0.0.1:9000;

        proxy_http_version 1.1;
        proxy_set_header Host \$host;

        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;

        proxy_set_header Connection "";
    }
}
EOF

  else

cat <<EOF > $NGINX_DIR/$DOMAIN.conf
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://$DOMAIN\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        proxy_pass http://127.0.0.1:9000;

        proxy_http_version 1.1;
        proxy_set_header Host \$host;

        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;

        proxy_set_header Connection "";
    }
}
EOF

  fi

  nginx -t && systemctl reload nginx

  echo "HTTPS enforced: $DOMAIN"
}

remove_domain() {
  DOMAIN=$1
  validate_domain $DOMAIN || { echo "Invalid domain"; return; }

  rm -rf $WEB_DIR/$DOMAIN
  rm -f $NGINX_DIR/$DOMAIN.conf

  nginx -t && systemctl reload nginx

  SERVER_XML="$TOMCAT_DIR/conf/server.xml"

if is_root_domain $DOMAIN; then
  HOST_NAME="www.$DOMAIN"
else
  HOST_NAME="$DOMAIN"
fi

sed -i "/<Host name=\"$HOST_NAME\".*websites\/$DOMAIN.*>/d" $SERVER_XML

systemctl restart tomcat
echo "Tomcat host removed"

  echo "Removed: $DOMAIN"
}

remove_ssl() {
  DOMAIN=$1
  validate_domain $DOMAIN || { echo "Invalid domain"; return; }

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
  echo "1) List Domains"
  echo "2) Add Domain"
  echo "3) Remove Domain"
  echo "4) Add SSL"
  echo "0) Exit"
  echo ""

  read -p "Choose option: " OPTION

  case "$OPTION" in
    1) list_domain; read -p "Enter..." ;;
    2) read -p "Domain: " DOMAIN; add_domain $DOMAIN ;;
    3) read -p "Domain: " DOMAIN; remove_domain $DOMAIN ;;
    4) read -p "Domain: " DOMAIN; add_ssl $DOMAIN ;;
    0) exit 0 ;;
    *) echo "Invalid"; sleep 1 ;;
  esac
}

if [ -z "$1" ]; then
  while true; do run_menu; done
else
  case "$1" in
    add) add_domain $2 ;;
    remove) remove_domain $2 ;;
    list) list_domain ;;
    ssl) add_ssl $2 ;;
    ssl-remove) remove_ssl $2 ;;
    *) echo "Usage: $0 add/remove/list/ssl domain" ;;
  esac
fi