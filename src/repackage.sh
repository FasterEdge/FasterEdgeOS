#!/bin/sh

set -e

# 此脚本适用于已经构建过 FasterEdgeOS、
# 想要快速重新打包所有组件的情况。
#
# 注意：这也会重建所有 overlay bundles。

./08_prepare_bundles.sh
./09_generate_rootfs.sh
./10_pack_rootfs.sh
./11_generate_overlay.sh
./12_get_syslinux.sh
./12_get_systemd-boot.sh
./13_prepare_iso.sh
./14_generate_iso.sh
./15_generate_image.sh
./16_cleanup.sh
