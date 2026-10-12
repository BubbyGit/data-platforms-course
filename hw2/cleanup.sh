#!/bin/bash
set -uo pipefail
source "$(dirname "$0")/common.sh"

read -r -p "stop yarn, rm nginx site [y/N] " answer
[ "$answer" = "y" ] || exit 0

sudo rm -f /etc/nginx/sites-enabled/hadoop /etc/nginx/sites-available/hadoop /etc/nginx/.htpasswd
sudo systemctl restart nginx

as_hadoop "mapred --daemon stop historyserver"
as_hadoop "stop-yarn.sh" 2> /dev/null
