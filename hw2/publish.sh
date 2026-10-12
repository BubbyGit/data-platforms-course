#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

SITE="/etc/nginx/sites-available/hadoop"
HTPASSWD="/etc/nginx/.htpasswd"

if ! command -v nginx > /dev/null; then
    sudo apt-get -o DPkg::Lock::Timeout=300 update -qq
    sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_SUSPEND=1 \
        apt-get -o DPkg::Lock::Timeout=300 install -y -qq nginx > /dev/null
fi

if ! sudo test -s "$HTPASSWD"; then
    read -r -s -p "password for $UI_USER: " PASS
    echo
    [ -n "$PASS" ] || { echo "empty password" >&2; exit 1; }
    echo "$UI_USER:$(openssl passwd -apr1 -stdin <<< "$PASS")" | sudo tee "$HTPASSWD" > /dev/null
    sudo chown root:www-data "$HTPASSWD"
    sudo chmod 640 "$HTPASSWD"
fi

for ui in $UIS; do
    sed -e "s|__HOST__|${ui%:*}|g" -e "s|__PORT__|${ui#*:}|g" conf/nginx-site.conf
done | sudo tee "$SITE" > /dev/null
sudo ln -sf "$SITE" /etc/nginx/sites-enabled/hadoop
sudo rm -f /etc/nginx/sites-enabled/default

sudo nginx -t -q
sudo systemctl restart nginx
