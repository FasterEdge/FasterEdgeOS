#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# 本脚本由 GitHub 工作流调用。

set -e

# 应用 GitHub 工作流专属补丁
mkdir -p ../src/minimal_overlay/rootfs/etc/autorun
cp 99_autoshutdown.sh ../src/minimal_overlay/rootfs/etc/autorun
chmod +x ../src/minimal_overlay/rootfs/etc/autorun/99_autoshutdown.sh
cp -f syslinux.cfg ../src/minimal_boot/bios/boot/syslinux/syslinux.cfg
# 注意: 必须锚定行首(^), 否则会把注释样例行(# OVERLAY_LOCATION=...)也改写,
# 产生两个匹配行, read_property 会返回多值导致构建判断失效。
sed -i "s|^OVERLAY_LOCATION.*|OVERLAY_LOCATION=rootfs|" ../src/.config
# CI 构建启用 fasteredgeos bundle(系统初始工具: DontCrack-Manager 根管理器)。
sed -i "s|^OVERLAY_BUNDLES=.*|OVERLAY_BUNDLES=dhcp,fasteredgeos|" ../src/.config

sudo apt-get -qq -y update
sudo apt-get -qq -y upgrade
# rsync 用于内核 6.6+ 的 headers_install。（另需 gawk/bc 等编译依赖）
sudo apt-get -qq -y install wget make gawk gcc bc xz-utils bison flex xorriso libelf-dev libssl-dev rsync qemu-system-x86-64

set +e
