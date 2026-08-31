#!/bin/sh

set -e

. ../../common.sh

cd $WORK_DIR/overlay/$BUNDLE_NAME

# 切换到 util-linux 源码目录（由 ls 找到），例如 'util-linux-2.34'。
cd $(ls -d util-linux-*)

if [ -f Makefile ] ; then
  echo "正在准备 '$BUNDLE_NAME' 的工作目录，这可能需要一些时间。"
  make -j $NUM_JOBS clean
else
  echo "已跳过 '$BUNDLE_NAME' 的清理阶段。"
fi

rm -rf $DEST_DIR
mkdir -p $DEST_DIR/usr/share/doc/util-linux
mkdir -p $DEST_DIR/bin

echo "正在配置 '$BUNDLE_NAME'。"
CFLAGS="$CFLAGS" ./configure \
  ADJTIME_PATH=/var/lib/hwclock/adjtime   \
  --prefix=$DEST_DIR \
  --docdir=$DEST_DIR/usr/share/doc/util-linux \
  --disable-chfn-chsh  \
  --disable-login      \
  --disable-nologin    \
  --disable-su         \
  --disable-setpriv    \
  --disable-runuser    \
  --disable-pylibmount \
  --disable-static     \
  --disable-makeinstall-chown \
  --without-python     \
  --without-systemd    \
  --without-systemdsystemunitdir

echo "正在编译 '$BUNDLE_NAME'。"
make -j $NUM_JOBS

echo "正在安装 '$BUNDLE_NAME'。"
make -j $NUM_JOBS install

echo "正在精简 '$BUNDLE_NAME' 的体积。"
reduce_size $DEST_DIR/bin

install_to_overlay bin

echo "bundle '$BUNDLE_NAME' 已安装完成。"

cd $SRC_DIR

