#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# 安装 any2pcd 到 overlay rootfs:
#   /usr/bin/any2pcd                  点云转换工具二进制
#   /usr/share/doc/any2pcd/README.md  使用说明
set -e

. ../../common.sh

BIN=$OVERLAY_WORK_DIR/$BUNDLE_NAME/any2pcd
BUNDLE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

[ -x "$BIN" ] || { echo "错误: 缺少编译产物(先执行 02_build.sh)"; exit 1; }

mkdir -p $OVERLAY_ROOTFS/usr/bin
mkdir -p $OVERLAY_ROOTFS/usr/share/doc/any2pcd

install -m755 "$BIN" $OVERLAY_ROOTFS/usr/bin/any2pcd
install -m644 "$BUNDLE_DIR/README.md" $OVERLAY_ROOTFS/usr/share/doc/any2pcd/README.md

echo "any2pcd bundle (文本/二进制点云转 PCD 工具) 已安装。"
