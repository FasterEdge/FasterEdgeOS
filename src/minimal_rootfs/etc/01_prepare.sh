#!/bin/sh

# 系统初始化序列：
#
# /init
#  |
#  +--(1) /etc/01_prepare.sh （本文件）
#  |
#  +--(2) /etc/02_overlay.sh
#          |
#          +-- /etc/03_init.sh
#               |
#               +-- /sbin/init
#                    |
#                    +--(1) /etc/04_bootscript.sh
#                    |       |
#                    |       +-- /etc/autorun/* （所有脚本）
#                    |
#                    +--(2) /bin/sh （Alt + F1，主控制台）
#                    |
#                    +--(2) /bin/sh （Alt + F2）
#                    |
#                    +--(2) /bin/sh （Alt + F3）
#                    |
#                    +--(2) /bin/sh （Alt + F4）

dmesg -n 1
echo "大多数内核消息已被抑制。"

mount -t devtmpfs none /dev
mount -t proc none /proc
mount -t tmpfs none /tmp -o mode=1777
mount -t sysfs none /sys

mkdir -p /dev/pts

mount -t devpts none /dev/pts

echo "已挂载所有核心文件系统，可以继续。"