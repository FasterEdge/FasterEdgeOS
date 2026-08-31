#!/bin/sh

set -e

. ../../common.sh

cd $WORK_DIR/overlay/$BUNDLE_NAME

# 切换到 zlib 源码目录（由 ls 找到），例如 'zlib-1.2.11'。
cd $(ls -d zlib-*)

echo "正在准备 '$BUNDLE_NAME' 的工作目录，这可能需要一些时间。"
make -j $NUM_JOBS distclean

rm -rf $DEST_DIR

echo "正在配置 '$BUNDLE_NAME'。"
CFLAGS="$CFLAGS" ./configure \
  --prefix=$DEST_DIR

echo "正在编译 '$BUNDLE_NAME'。"
make -j $NUM_JOBS

echo "正在安装 '$BUNDLE_NAME'。"
make -j $NUM_JOBS install

echo "正在精简 '$BUNDLE_NAME' 的体积。"
set +e
strip -g $DEST_DIR/lib/*
set -e

mkdir -p "$OVERLAY_ROOTFS/lib"
cp -r $DEST_DIR/lib/libz.so.1.* $OVERLAY_ROOTFS/lib/libz.so.1

echo "bundle '$BUNDLE_NAME' 已安装完成。"

cd $SRC_DIR
