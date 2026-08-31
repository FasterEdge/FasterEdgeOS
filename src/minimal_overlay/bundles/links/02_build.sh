#!/bin/sh

set -e

. ../../common.sh

cd $WORK_DIR/overlay/$BUNDLE_NAME

# 切换到 Links 源码目录（由 ls 找到），例如 'links-2.12'。
cd $(ls -d links-*)

if [ -f Makefile ] ; then
  echo "正在准备 'Links' 的工作目录，这可能需要一些时间。"
  make -j $NUM_JOBS clean
else
  echo "已跳过 'Links' 的清理阶段。"
fi

rm -rf $DEST_DIR

echo "正在配置 'Links'。"
CFLAGS="$CFLAGS" ./configure \
  --prefix=/usr \
  --disable-graphics \
  --disable-utf8 \
  --without-ipv6 \
  --without-ssl \
  --without-zlib \
  --without-x

echo "正在编译 'Links'。"
make -j $NUM_JOBS

echo "正在安装 'Links'。"
make -j $NUM_JOBS install DESTDIR=$DEST_DIR

echo "正在精简 'Links' 的体积。"
set +e
strip -g $DEST_DIR/usr/bin/*
set -e

mkdir -p "$OVERLAY_ROOTFS/usr/bin"

# 使用 '--remove-destination' 可正确覆盖
# '$OVERLAY_ROOTFS' 中可能已存在的软链接。
cp -r --remove-destination $DEST_DIR/usr/bin/* \
  $OVERLAY_ROOTFS/usr/bin/

echo "bundle 'Links' 已安装完成。"

cd $SRC_DIR
