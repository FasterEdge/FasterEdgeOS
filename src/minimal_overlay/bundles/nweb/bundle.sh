#!/bin/sh

set -e

. ../../common.sh

echo "正在清理先前的工作目录。"
rm -rf $WORK_DIR/overlay/$BUNDLE_NAME
mkdir -p $WORK_DIR/overlay/$BUNDLE_NAME
cd $WORK_DIR/overlay/$BUNDLE_NAME

# nweb
gcc $CFLAGS $SRC_DIR/nweb23.c -o nweb

echo "'nweb' 已编译完成。"

install -d -m755 "$OVERLAY_ROOTFS/usr"
install -d -m755 "$OVERLAY_ROOTFS/usr/bin"
install -m755 nweb "$OVERLAY_ROOTFS/usr/bin/nweb"
install -d -m755 "$OVERLAY_ROOTFS/srv/www" # 符合 FHS 标准的位置
install -m644 "$SRC_DIR/index.html" "$OVERLAY_ROOTFS/srv/www/index.html"
install -m644 "$SRC_DIR/favicon.ico" "$OVERLAY_ROOTFS/srv/www/favicon.ico"
install -d -m755 "$OVERLAY_ROOTFS/etc"
install -d -m755 "$OVERLAY_ROOTFS/etc/autorun"
install -m755 "$SRC_DIR/90_nweb.sh" "$OVERLAY_ROOTFS/etc/autorun/90_nweb.sh"

echo "bundle 'nweb' 已安装完成。"
echo "它将在开机时自动启动。"
