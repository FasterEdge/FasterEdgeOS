#!/bin/sh

# 本脚本由 GitHub 工作流调用。

set -e

# 应用 GitHub 工作流专属补丁
mkdir -p ../src/minimal_overlay/rootfs/etc/autorun
cp 99_autoshutdown.sh ../src/minimal_overlay/rootfs/etc/autorun
chmod +x ../src/minimal_overlay/rootfs/etc/autorun/99_autoshutdown.sh
cp -f syslinux.cfg ../src/minimal_boot/bios/boot/syslinux/syslinux.cfg
sed -i "s|OVERLAY_LOCATION.*|OVERLAY_LOCATION=rootfs|" ../src/.config

sudo apt-get -qq -y update
sudo apt-get -qq -y upgrade
sudo apt-get -qq -y install wget make gawk gcc bc xz-utils bison flex xorriso libelf-dev libssl-dev qemu-system-x86-64

set +e
