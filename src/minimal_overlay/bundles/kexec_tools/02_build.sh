#!/bin/sh

set -e

. ../../common.sh

cd $WORK_DIR/overlay/$BUNDLE_NAME

# 切换到 kexec-tools 源码目录（由 ls 找到），例如 'kexec-tools-2.0.15'。
cd $(ls -d kexec-tools-*)

if [ -f Makefile ] ; then
  echo "正在准备 '$BUNDLE_NAME' 的工作目录，这可能需要一些时间。"
  make -j $NUM_JOBS clean
else
  echo "已跳过 '$BUNDLE_NAME' 的清理阶段。"
fi

rm -rf $DEST_DIR

echo "正在编译 '$BUNDLE_NAME'。"
CFLAGS="$CFLAGS" ./configure \
  --prefix=/usr \
  --without-lzama

make -j $NUM_JOBS

make -j $NUM_JOBS install DESTDIR="$DEST_DIR"

echo "正在精简 '$BUNDLE_NAME' 的体积。"
set +e
strip -g $DEST_DIR/usr/bin/* \
  $DEST_DIR/usr/lib/* 2>/dev/null
set -e

mkdir -p $OVERLAY_ROOTFS/usr/

# 使用 '--remove-destination' 可正确覆盖
# '$OVERLAY_ROOTFS' 中可能已存在的软链接。
cp -r --remove-destination $DEST_DIR/usr/* \
  $OVERLAY_ROOTFS/usr/

echo "bundle '$BUNDLE_NAME' 已安装完成。"

cd $SRC_DIR
