#!/bin/sh

set -e

. ../../common.sh

cd $WORK_DIR/overlay/$BUNDLE_NAME

# 切换到 screen 源码目录（由 ls 找到），例如 'screen-4.8.0'。
cd $(ls -d screen-*)

if [ -f Makefile ] ; then
  echo "正在准备 '$BUNDLE_NAME' 的工作目录，这可能需要一些时间。"
  make -j $NUM_JOBS clean
else
  echo "已跳过 '$BUNDLE_NAME' 的清理阶段。"
fi

rm -rf $DEST_DIR

echo "正在配置 '$BUNDLE_NAME'。"
CFLAGS="$CFLAGS -I${OVERLAY_ROOTFS}/include" \
LDFLAGS="$LDFLAGS -L${OVERLAY_ROOTFS}/lib -L${OVERLAY_ROOTFS}/usr/lib" \
  ./configure --prefix=/usr

# 移除对 libutempter 的依赖，因为目标系统
# 上不提供该库。
echo "正在修补 '$BUNDLE_NAME' 的配置。"
sed -i 's|-lutempter||g' Makefile
sed -i 's|#define HAVE_UTEMPTER 1||g' config.h

echo "正在编译 '$BUNDLE_NAME'。"
make -j $NUM_JOBS

echo "正在安装 '$BUNDLE_NAME'。"
make -j $NUM_JOBS install DESTDIR=$DEST_DIR

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
