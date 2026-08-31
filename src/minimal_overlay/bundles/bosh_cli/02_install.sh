#!/bin/sh

set -e

. ../../common.sh

echo "正在移除旧的 'BOSH CLI' 构建产物，这可能需要一些时间。"
rm -rf $DEST_DIR
mkdir -p $DEST_DIR/opt/$BUNDLE_NAME
mkdir -p $DEST_DIR/usr/bin

cd $DEST_DIR

cp $MAIN_SRC_DIR/source/overlay/bosh-cli opt/$BUNDLE_NAME/bosh

chmod +rx opt/$BUNDLE_NAME/bosh

cd $DEST_DIR/usr/bin

ln -s ../../opt/$BUNDLE_NAME/bosh bosh

# 使用 '--remove-destination' 可正确覆盖
# '$OVERLAY_ROOTFS' 中可能已存在的软链接。
cp -r --remove-destination $DEST_DIR/* \
  $OVERLAY_ROOTFS

echo "bundle 'BOSH CLI' 已安装完成。"

cd $SRC_DIR
