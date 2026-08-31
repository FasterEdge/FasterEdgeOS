#!/bin/sh

set -e

. ../../common.sh

echo "正在移除旧的 'static-get' 构建产物，这可能需要一些时间。"
rm -rf $DEST_DIR
mkdir -p $DEST_DIR/opt/$BUNDLE_NAME
mkdir -p $DEST_DIR/bin

cd $WORK_DIR/overlay/$BUNDLE_NAME

cp $MAIN_SRC_DIR/source/overlay/static-get.sh .

chmod +rx static-get.sh

cp static-get.sh $DEST_DIR/opt/$BUNDLE_NAME

cd $DEST_DIR

ln -s ../opt/$BUNDLE_NAME/static-get.sh bin/static-get
ln -s ../opt/$BUNDLE_NAME/static-get.sh bin/fasteredgeos-get

# 使用 '--remove-destination' 可以正确覆盖 '$OVERLAY_ROOTFS'
# 中可能已存在的软链接。
cp -r --remove-destination $DEST_DIR/* \
  $OVERLAY_ROOTFS

echo "Bundle 'static-get' 已安装。"

cd $SRC_DIR