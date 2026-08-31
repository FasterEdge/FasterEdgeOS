#!/bin/sh

nweb 80 /srv/www

cat << CEOF
[1m  'nweb' 已在 80 端口启动，服务目录 '/srv/www'。[0m
CEOF
