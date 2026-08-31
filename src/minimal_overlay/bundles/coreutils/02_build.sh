#!/bin/sh

set -e

. ../../common.sh

# 切换到 coreutils 源码目录（由 ls 找到），例如 'coreutils-8.28'。
cd `ls -d $OVERLAY_WORK_DIR/$BUNDLE_NAME/coreutils-*`

make_clean

rm -rf $DEST_DIR

echo "正在配置 '$BUNDLE_NAME'。"
CFLAGS="$CFLAGS" ./configure \
  --prefix=/usr

echo "正在编译 '$BUNDLE_NAME'。"
make_target

echo "正在安装 '$BUNDLE_NAME'。"
make_target install DESTDIR=$DEST_DIR

echo "正在精简 '$BUNDLE_NAME' 的体积。"
reduce_size $DEST_DIR/usr/bin

install_to_overlay

echo "bundle '$BUNDLE_NAME' 已安装完成。"

cd $SRC_DIR
