#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# 安装 DontCrack-Manager 到 overlay rootfs:
#   /usr/bin/dontcrack-manager            根管理器二进制
#   /etc/fasteredgeos/manager.yaml        根管理器配置
#   /etc/autorun/20_dontcrack-manager.sh  开机自动启动(系统初始工具, 最先启动)
#   /usr/bin/fasteredgeos-demo            演示子进程
#   /var/lib/fasteredgeos/  /var/log/fasteredgeos/  运行数据与日志目录
set -e

. ../../common.sh

BIN=$OVERLAY_WORK_DIR/$BUNDLE_NAME/dontcrack-manager

[ -x "$BIN" ] || { echo "错误: 缺少编译产物(先执行 02_build.sh)"; exit 1; }

mkdir -p $OVERLAY_ROOTFS/usr/bin
mkdir -p $OVERLAY_ROOTFS/etc/fasteredgeos
mkdir -p $OVERLAY_ROOTFS/etc/autorun
mkdir -p $OVERLAY_ROOTFS/var/lib/fasteredgeos
mkdir -p $OVERLAY_ROOTFS/var/log/fasteredgeos
mkdir -p $OVERLAY_ROOTFS/var/run

install -m755 "$BIN" $OVERLAY_ROOTFS/usr/bin/dontcrack-manager
install -m755 "$OVERLAY_WORK_DIR/$BUNDLE_NAME/dontcrack" $OVERLAY_ROOTFS/usr/bin/dontcrack
install -m644 "$SRC_DIR/manager.yaml" $OVERLAY_ROOTFS/etc/fasteredgeos/manager.yaml
install -m755 "$SRC_DIR/20_dontcrack-manager.sh" $OVERLAY_ROOTFS/etc/autorun/20_dontcrack-manager.sh
install -m755 "$SRC_DIR/fasteredgeos-demo" $OVERLAY_ROOTFS/usr/bin/fasteredgeos-demo

echo "fasteredgeos bundle (DontCrack-Manager 系统初始工具) 已安装。"