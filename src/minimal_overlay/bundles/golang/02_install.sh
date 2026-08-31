#!/bin/sh

set -e

. ../../common.sh

cd $WORK_DIR/overlay/$BUNDLE_NAME
mv `ls -d *` $BUNDLE_NAME

mkdir opt
mv $BUNDLE_NAME opt

mkdir -p usr/local
cd $WORK_DIR/overlay/$BUNDLE_NAME/usr/local
ln -s ../../opt/$BUNDLE_NAME go

mkdir $WORK_DIR/overlay/$BUNDLE_NAME/bin
cd $WORK_DIR/overlay/$BUNDLE_NAME/bin

for FILE in $(ls ../usr/local/go/bin)
do
  ln -s ../usr/local/go/bin/$FILE $FILE
done

# 使用 '--remove-destination' 可正确覆盖
# '$OVERLAY_ROOTFS' 中可能已存在的软链接。
cp -r --remove-destination $WORK_DIR/overlay/$BUNDLE_NAME/* \
  $OVERLAY_ROOTFS

echo "Golang 已安装完成。"

cd $SRC_DIR
