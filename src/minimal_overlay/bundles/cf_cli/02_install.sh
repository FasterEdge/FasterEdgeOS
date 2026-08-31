#!/bin/sh

set -e

. ../../common.sh

echo "正在移除旧的 'Cloud Foundry CLI' 构建产物，这可能需要一些时间。"
rm -rf $DEST_DIR
mkdir -p $DEST_DIR/opt/$BUNDLE_NAME
mkdir -p $DEST_DIR/usr/bin

cd $WORK_DIR/overlay/$BUNDLE_NAME

cp $MAIN_SRC_DIR/source/overlay/cf-cli.tgz .

tar -xvf cf-cli.tgz
rm -f LICENSE NOTICE cf-cli.tgz
chmod +rx cf

cp cf $DEST_DIR/opt/$BUNDLE_NAME/cf

cd $DEST_DIR/usr/bin

ln -s ../../opt/$BUNDLE_NAME/cf cf

# 使用 '--remove-destination' 可正确覆盖
# '$OVERLAY_ROOTFS' 中可能已存在的软链接。
cp -r --remove-destination $DEST_DIR/* \
  $OVERLAY_ROOTFS

echo "bundle 'Cloud Foundry CLI' 已安装完成。"

cd $SRC_DIR
