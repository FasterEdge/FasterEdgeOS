#!/bin/sh

set -e

. ../../common.sh

cd $WORK_DIR/overlay/$BUNDLE_NAME

# 切换到 vim 源码目录（由 ls 找到），例如 'vim-8.0.1298'。
cd $(ls -d vim-*)

if [ -f Makefile ] ; then
  echo "正在准备 '$BUNDLE_NAME' 的工作目录，这可能需要一些时间。"
  make -j $NUM_JOBS clean
else
  echo "已跳过 '$BUNDLE_NAME' 的清理阶段。"
fi

rm -rf $DEST_DIR

echo "正在设置 'vimrc' 的位置。"
echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h

echo "正在配置 '$BUNDLE_NAME'。"
CFLAGS="$CFLAGS" ./configure \
  --prefix=/usr \
  --enable-gui=no \
  --without-x \
  --with-tlib=ncurses \
  --disable-xsmp \
  --disable-gpm \
  --disable-selinux \
  --disable-canberra \
  --disable-acl

export CONF_OPT_GUI='--enable-gui=no'
export CONF_OPT_PERL='--enable-perlinterp'
export CONF_OPT_PYTHON='--enable-pythoninterp'
export CONF_OPT_TCL='--enable-tclinterp'
export CONF_OPT_RUBY='--enable-rubyinterp'
export CONF_OPT_LUA='--enable-luainterp'
export CONF_OPT_X='--without-x'
export CONF_OPT_CSCOPE='--enable-cscope'
export CONF_OPT_MULTIBYTE='--enable-multibyte'
export CONF_OPT_FEAT='--with-features=huge'

echo "正在编译 '$BUNDLE_NAME'。"
make -j $NUM_JOBS

echo "正在安装 '$BUNDLE_NAME'。"
make -j $NUM_JOBS install DESTDIR=$DEST_DIR

echo "正在生成 '$BUNDLE_NAME'。"
mkdir -p $DEST_DIR/etc
cat > $DEST_DIR/etc/vimrc << "EOF"
" Begin /etc/vimrc

set nocompatible
set backspace=2
set mouse=r
syntax on
set background=dark

" End /etc/vimrc
EOF

echo "正在将 'vim' 软链接到 'vi'。"
ln -sv vim $DEST_DIR/usr/bin/vi
mkdir -p $DEST_DIR/bin
ln -sv vim $DEST_DIR/bin/vi

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
