#!/bin/sh

set -e

. ../../common.sh

# 使用 '--remove-destination' 可正确覆盖
# '$OVERLAY_ROOTFS' 中可能已存在的软链接。
cp -r --remove-destination $DEST_DIR/* \
  $OVERLAY_ROOTFS

echo "bundle '$BUNDLE_NAME' 已安装完成。"

cd $SRC_DIR
