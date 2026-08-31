#!/bin/sh

set -e

. ../../common.sh

cd $WORK_DIR/overlay/$BUNDLE_NAME

# 切换到 libxcrypt 源码目录（由 ls 找到），例如 'libxcrypt-4.4.17'。
cd $(ls -d libxcrypt-*)

echo "正在生成 configure。"
./autogen.sh

rm -rf $DEST_DIR

echo "正在配置 '$BUNDLE_NAME'。"
CFLAGS="$CFLAGS" ./configure \
  --prefix=$DEST_DIR

echo "正在准备 '$BUNDLE_NAME' 的工作目录，这可能需要一些时间。"
make clean

echo "正在编译 '$BUNDLE_NAME'。"
make -j $NUM_JOBS

echo "正在安装 '$BUNDLE_NAME'。"
make -j $NUM_JOBS install

echo "正在精简 '$BUNDLE_NAME' 的体积。"
set +e
strip -g $DEST_DIR/lib/*
set -e

# 使用 '--remove-destination' 可正确覆盖
# '$OVERLAY_ROOTFS' 中可能已存在的软链接。
cp -r --remove-destination $DEST_DIR/lib/libcrypt.so* $OVERLAY_ROOTFS/lib/

echo "bundle '$BUNDLE_NAME' 已安装完成。"

cd $SRC_DIR
