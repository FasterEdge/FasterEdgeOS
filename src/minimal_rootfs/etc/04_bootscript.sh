#!/bin/sh

# FasterEdgeOS 系统启动脚本。
# /init -> /etc/01_prepare.sh -> /etc/02_overlay.sh -> /etc/03_init.sh
#      -> /sbin/init -> 本脚本 -> /etc/autorun/*

echo -e "欢迎使用 FasterEdgeOS (基于 BusyBox init)"

if [ -d /etc/autorun ]; then
  for AUTOSCRIPT in /etc/autorun/*; do
    if [ -f "$AUTOSCRIPT" ] && [ -x "$AUTOSCRIPT" ]; then
      echo -e "正在执行 \e[32m$AUTOSCRIPT\e[0m"
      "$AUTOSCRIPT"
    fi
  done
fi
