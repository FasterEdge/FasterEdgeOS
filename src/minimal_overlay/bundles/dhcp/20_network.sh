#!/bin/sh

# DHCP 网络
for DEVICE in /sys/class/net/* ; do
  echo "发现网络设备 ${DEVICE##*/}"
  ip link set ${DEVICE##*/} up
  [ ${DEVICE##*/} != lo ] && udhcpc -b -i ${DEVICE##*/} -s /etc/05_rc.dhcp
done
