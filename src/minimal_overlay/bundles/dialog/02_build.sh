#!/bin/sh

set -e

. ../../common.sh

cd $WORK_DIR/overlay/$BUNDLE_NAME

# 切换到 dialog 源码目录（由 ls 找到），例如 'dialog-1.3-20170509'。
cd $(ls -d dialog-*)

if [ -f Makefile ] ; then
  echo "正在准备 'dialog' 的工作目录，这可能需要一些时间。"
  make -j $NUM_JOBS clean
else
  echo "已跳过 'dialog' 的清理阶段。"
fi

rm -rf $DEST_DIR

echo "正在配置 'dialog'。"
CFLAGS="$CFLAGS" ./configure \
    --prefix=/usr

echo "正在编译 'dialog'。"
make -j $NUM_JOBS

echo "正在安装 'dialog'。"
make -j $NUM_JOBS install DESTDIR=$DEST_DIR

rm -rf $DEST_DIR/usr/lib $DEST_DIR/usr/share

echo "正在精简 'dialog' 的体积。"
set +e
strip -g $DEST_DIR/usr/bin/*
set -e

# 使用 '--remove-destination' 可正确覆盖
# '$OVERLAY_ROOTFS' 中可能已存在的软链接。
cp -r --remove-destination $DEST_DIR/usr \
  $OVERLAY_ROOTFS

echo "bundle 'dialog' 已安装完成。"

cd $SRC_DIR
