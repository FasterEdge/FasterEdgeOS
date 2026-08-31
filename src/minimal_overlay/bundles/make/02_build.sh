#!/bin/sh

set -e

. ../../common.sh

cd $WORK_DIR/overlay/$BUNDLE_NAME

# 切换到 make 源码目录（由 ls 找到），例如 'make-4.2.1'。
cd $(ls -d make-*)

if [ "${PWD##*/}" = "make-4.2.1" ] ; then
  # TODO - 不再需要时请移除这部分。
  # 为版本 "4.2.1" 应用补丁。
  patch glob/glob.c $SRC_DIR/make-4.2.1.patch
fi

if [ -f Makefile ] ; then
  echo "正在准备 '$BUNDLE_NAME' 的工作目录，这可能需要一些时间。"
  make -j $NUM_JOBS clean
else
  echo "已跳过 '$BUNDLE_NAME' 的清理阶段。"
fi

rm -rf $DEST_DIR

echo "正在配置 '$BUNDLE_NAME'。"
CFLAGS="$CFLAGS" ./configure \
  --prefix=/usr

echo "正在编译 '$BUNDLE_NAME'。"
make -j $NUM_JOBS

echo "正在安装 '$BUNDLE_NAME'。"
make -j $NUM_JOBS install DESTDIR=$DEST_DIR

mkdir -p $DEST_DIR/lib
cp $SYSROOT/lib/libdl.so.2 $DEST_DIR/lib/

echo "正在精简 '$BUNDLE_NAME' 的体积。"
set +e
strip -g $DEST_DIR/usr/bin/*
set -e

# 使用 '--remove-destination' 可正确覆盖
# '$OVERLAY_ROOTFS' 中可能已存在的软链接。
cp -r --remove-destination $DEST_DIR/* \
  $OVERLAY_ROOTFS

echo "bundle '$BUNDLE_NAME' 已安装完成。"

cd $SRC_DIR
