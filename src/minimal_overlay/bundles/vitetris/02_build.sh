#!/bin/sh

set -e

. ../../common.sh

cd $WORK_DIR/overlay/$BUNDLE_NAME/vitetris-master

echo "正在准备 '$BUNDLE_NAME' 的工作目录，这可能需要一些时间。"
make -j $NUM_JOBS clean

rm -rf $DEST_DIR

echo "正在配置 '$BUNDLE_NAME'。"
CFLAGS="$CFLAGS" ./configure \
  --prefix=$WORK_DIR/overlay/$BUNDLE_NAME/vitetris-master \
  2player=no \
  joystick=no \
  network=no \
  curses=no \
  allegro=no \
  xlib=no \
  term_resizing=no \
  menu=no \
  blockstyles=no \
  pctimer=no

echo "正在编译 '$BUNDLE_NAME'。"
make -j $NUM_JOBS

echo "正在安装 '$BUNDLE_NAME'。"
mkdir $DEST_DIR
cp tetris $DEST_DIR

echo "正在精简 '$BUNDLE_NAME' 的体积。"
set +e
strip -g $DEST_DIR/*
set -e

mkdir -p "$OVERLAY_ROOTFS/bin"
cp -r $DEST_DIR/tetris $OVERLAY_ROOTFS/bin/tetris

echo "bundle '$BUNDLE_NAME' 已安装完成。"

cd $SRC_DIR

