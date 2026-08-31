#!/bin/sh

set -e

. ../../common.sh

cd $WORK_DIR/overlay/$BUNDLE_NAME

# 切换到 kbd 源码目录（由 ls 找到），例如 'kbd-2.04'。
cd $(ls -d kbd-*)

# 重命名同名键盘映射 开始

mv data/keymaps/i386/qwertz/cz.map \
  data/keymaps/i386/qwertz/cz-qwertz.map

mv data/keymaps/i386/olpc/es.map \
  data/keymaps/i386/olpc/es-olpc.map

mv data/keymaps/i386/olpc/pt.map \
  data/keymaps/i386/olpc/pt-olpc.map

mv data/keymaps/i386/fgGIod/trf.map \
  data/keymaps/i386/fgGIod/trf-fgGIod.map

mv data/keymaps/i386/colemak/en-latin9.map \
  data/keymaps/i386/colemak/colemak.map

# 重命名同名键盘映射 结束


if [ -f Makefile ] ; then
  echo "正在准备 '$BUNDLE_NAME' 的工作目录，这可能需要一些时间。"
  make -j $NUM_JOBS clean
else
  echo "已跳过 '$BUNDLE_NAME' 的清理阶段。"
fi

rm -rf $DEST_DIR

echo "正在配置 '$BUNDLE_NAME'。"
CFLAGS="$CFLAGS" ./configure \
  --prefix=/usr \
  --disable-vlock
# vlock 需要 PAM

echo "正在编译 '$BUNDLE_NAME'。"
make -j $NUM_JOBS

echo "正在安装 '$BUNDLE_NAME'。"
make -j $NUM_JOBS install DESTDIR="$DEST_DIR"

echo "正在精简 '$BUNDLE_NAME' 的体积。"
set +e
strip -g \
  $DEST_DIR/usr/bin/* \
  $DEST_DIR/usr/sbin/* \
  $DEST_DIR/lib/*
set -e

mkdir -p $OVERLAY_ROOTFS/usr
mkdir -p $OVERLAY_ROOTFS/etc/autorun

# 使用 '--remove-destination' 可正确覆盖
# '$OVERLAY_ROOTFS' 中可能已存在的软链接。
cp -r --remove-destination "$DEST_DIR/usr/bin" "$DEST_DIR/usr/share" \
  "$OVERLAY_ROOTFS/usr/"
cp -r --remove-destination "$SRC_DIR/90_kbd.sh" \
  "$OVERLAY_ROOTFS/etc/autorun"

echo "bundle '$BUNDLE_NAME' 已安装完成。"

cd $SRC_DIR
