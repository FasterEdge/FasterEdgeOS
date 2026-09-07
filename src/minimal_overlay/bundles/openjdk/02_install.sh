#!/bin/sh

set -e

. ../../common.sh

cd $WORK_DIR/overlay/$BUNDLE_NAME
mv * "$BUNDLE_NAME"

mkdir opt
mv openjdk opt

mkdir $WORK_DIR/overlay/$BUNDLE_NAME/bin
cd $WORK_DIR/overlay/$BUNDLE_NAME/bin

for FILE in ../opt/$BUNDLE_NAME/bin/*
do
  [ -e "$FILE" ] || continue
  ln -s "$FILE" "$(basename "$FILE")"
done

# 使用 '--remove-destination' 可正确覆盖
# '$OVERLAY_ROOTFS' 中可能已存在的软链接。
cp -r --remove-destination $WORK_DIR/overlay/$BUNDLE_NAME/* \
  $OVERLAY_ROOTFS

echo "OpenJDK 已安装完成。"

cd $SRC_DIR
