#!/bin/sh

# 启用 'mdev' 热插拔管理器。
echo /sbin/mdev > /proc/sys/kernel/hotplug

# 初次执行 'mdev' 热插拔管理器。
/sbin/mdev -s

cat << CEOF
[1m  'mdev' 热插拔管理器已启用。[0m
CEOF
