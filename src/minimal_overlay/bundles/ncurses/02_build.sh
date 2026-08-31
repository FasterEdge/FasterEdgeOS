#!/bin/sh

set -e

. ../../common.sh

cd $WORK_DIR/overlay/$BUNDLE_NAME

# 切换到 ncurses 源码目录（由 ls 找到），例如 'ncurses-6.0'。
cd $(ls -d ncurses-*)

if [ -f Makefile ] ; then
  echo "正在准备 '$BUNDLE_NAME' 的工作目录，这可能需要一些时间。"
  make -j $NUM_JOBS clean
else
  echo "已跳过 '$BUNDLE_NAME' 的清理阶段。"
fi

rm -rf $DEST_DIR

# 移除静态库
sed -i '/LIBTOOL_INSTALL/d' c++/Makefile.in
# http://www.linuxfromscratch.org/lfs/view/development/chapter06/ncurses.html

echo "正在配置 '$BUNDLE_NAME'。"
CFLAGS="$CFLAGS" ./configure \
    --prefix=/usr \
    --with-termlib \
    --with-terminfo-dirs=/lib/terminfo \
    --with-default-terminfo-dirs=/lib/terminfo \
    --without-normal \
    --without-debug \
    --without-ada \
    --without-cxx-binding \
    --with-abi-version=6 \
    --enable-widec \
    --enable-pc-files \
    --with-shared \
    CPPFLAGS=-I$PWD/ncurses/widechar \
    LDFLAGS=-L$PWD/lib \
    CPPFLAGS="-P"

# 大部分配置开关取自 AwlsomeAlex
# https://github.com/AwlsomeAlex/AwlsomeLinux/blob/59d59730703b058081a2371076a807590cacb31e/src/overlay_ncurses.sh

# CPPFLAGS 修复了 Ubuntu 16.04 上的一个 bug
# https://trac.sagemath.org/ticket/19762

echo "正在编译 '$BUNDLE_NAME'。"
make -j $NUM_JOBS

echo "正在安装 '$BUNDLE_NAME'。"
make -j $NUM_JOBS install DESTDIR=$DEST_DIR

# 为宽字符库创建符号链接
cd $DEST_DIR/usr/lib
ln -s libncursesw.so.5 libncurses.so.5
ln -s libncurses.so.5 libncurses.so
ln -s libtinfow.so.5 libtinfo.so.5
ln -s libtinfo.so.5 libtinfo.so

echo "正在精简 '$BUNDLE_NAME' 的体积。"
set +e
strip -g $DEST_DIR/usr/bin/*
set -e

# 使用 '--remove-destination' 可正确覆盖
# '$OVERLAY_ROOTFS' 中可能已存在的软链接。
cp -r --remove-destination $DEST_DIR/usr/* \
  $OVERLAY_ROOTFS

echo "bundle '$BUNDLE_NAME' 已安装完成。"

cd $SRC_DIR
