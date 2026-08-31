#!/bin/sh

set -e

. ../../common.sh

cd $WORK_DIR/overlay/$BUNDLE_NAME

# 切换到 gcc 源码目录（由 ls 找到），例如 'gcc-11.1.0'。
cd $(ls -d gcc-*)

if [ -f Makefile ] ; then
  echo "正在准备 '$BUNDLE_NAME' 的工作目录，这可能需要一些时间。"
  make -j $NUM_JOBS clean || true
else
  echo "已跳过 '$BUNDLE_NAME' 的清理阶段。"
fi

rm -rf $DEST_DIR

echo "正在配置 '$BUNDLE_NAME'。"
CFLAGS="$CFLAGS" ./configure \
  --prefix=/usr \
  --enable-languages=c \
  --disable-multilib \
  --disable-static \
  --disable-libquadmath \
  --enable-shared

echo "正在编译 '$BUNDLE_NAME'。"
make -j $NUM_JOBS all-gcc
make -j $NUM_JOBS all-target-libgcc

echo "正在安装 '$BUNDLE_NAME'。"
make -j $NUM_JOBS install-target-libgcc DESTDIR=$DEST_DIR

mkdir -p $OVERLAY_ROOTFS/lib
# 使用 '--remove-destination' 可正确覆盖
# '$OVERLAY_ROOTFS' 中可能已存在的软链接。
cp -r --remove-destination $DEST_DIR/usr/lib64/libgcc_s.so* \
  $OVERLAY_ROOTFS/lib/

echo "bundle '$BUNDLE_NAME' 已安装完成。"

cd $SRC_DIR
