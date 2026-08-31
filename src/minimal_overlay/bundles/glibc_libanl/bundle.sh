#!/bin/sh

set -e

. ../../common.sh

if [ ! -d $SYSROOT ] ; then
  echo "无法继续 - GLIBC 缺失，请先构建 GLIBC。"
  exit 1
fi

mkdir -p "$WORK_DIR/overlay/$BUNDLE_NAME"
cd $WORK_DIR/overlay/$BUNDLE_NAME

rm -rf $DEST_DIR

mkdir -p $DEST_DIR/lib
cp $SYSROOT/lib/libanl.so.1 $DEST_DIR/lib/
ln -s libanl.so.1 $DEST_DIR/lib/libanl.so

echo "正在精简 '$BUNDLE_NAME' 的体积。"
set +e
strip -g $DEST_DIR/lib/*
set -e

# 使用 '--remove-destination' 可正确覆盖
# '$OVERLAY_ROOTFS' 中可能已存在的软链接。
cp -r --remove-destination $DEST_DIR/* \
  $OVERLAY_ROOTFS

echo "bundle '$BUNDLE_NAME' 已安装完成。"

cd $SRC_DIR
