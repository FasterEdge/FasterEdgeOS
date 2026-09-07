#!/bin/sh

set -e

. ../../common.sh

cd $WORK_DIR/overlay/$BUNDLE_NAME
mv * "$BUNDLE_NAME"

mkdir opt
mv $BUNDLE_NAME opt

mkdir -p usr/local
cd $WORK_DIR/overlay/$BUNDLE_NAME/usr/local
ln -s ../../opt/$BUNDLE_NAME go

mkdir $WORK_DIR/overlay/$BUNDLE_NAME/bin
cd $WORK_DIR/overlay/$BUNDLE_NAME/bin

for FILE in ../usr/local/go/bin/*
do
  [ -e "$FILE" ] || continue
  ln -s "$FILE" "$(basename "$FILE")"
done

# 使用 '--remove-destination' 可正确覆盖
# '$OVERLAY_ROOTFS' 中可能已存在的软链接。
cp -r --remove-destination $WORK_DIR/overlay/$BUNDLE_NAME/* \
  $OVERLAY_ROOTFS

echo "Golang 已安装完成。"

cd $SRC_DIR
