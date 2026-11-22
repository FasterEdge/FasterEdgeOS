#!/bin/sh
# 运行环境: 本脚本在 FasterEdgeOS 目标机上由 BusyBox ash(/bin/sh) 执行,
# 不是 POSIX 参考 shell。下列 read 用法依赖 BusyBox ash 的扩展:
#   read -t N      带超时读键(用于"等待 5 秒或任意按键")
#   read -n1 -s    无回显读单字符
# 它们是刻意保留的运行期行为(去掉会改变启动交互体验); shellcheck 按 POSIX
# sh 判定 SC3045 / SC3061 在此不适用, 故只在保留的那几行加带理由的 disable,
# 不在文件头整体关闭规则。彩色输出统一用 POSIX 的 printf '%b\n', 不依赖 echo -e。
# shellcheck shell=sh

# FasterEdgeOS 系统启动脚本。
# /init -> /etc/01_prepare.sh -> /etc/02_overlay.sh -> /etc/03_init.sh
#      -> /sbin/init -> 本脚本 -> /etc/autorun/*

printf '%b\n' "欢迎使用 FasterEdgeOS (基于 BusyBox init)"

if [ -d /etc/autorun ]; then
  for AUTOSCRIPT in /etc/autorun/*; do
    if [ -f "$AUTOSCRIPT" ] && [ -x "$AUTOSCRIPT" ]; then
      printf '%b\n' "正在执行 \e[32m$AUTOSCRIPT\e[0m"
      "$AUTOSCRIPT"
    elif [ -f "$AUTOSCRIPT" ]; then
      printf '%b\n' "\e[33m警告: $AUTOSCRIPT 存在但不可执行, 已跳过\e[0m"
    fi
  done
fi
