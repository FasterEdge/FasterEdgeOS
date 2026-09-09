#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# 安装 any2utf8 到 overlay rootfs:
#   /usr/bin/any2utf8                       转换工具二进制
#   /usr/share/doc/any2utf8/README.md       使用说明
set -e

. ../../common.sh

BIN=$OVERLAY_WORK_DIR/$BUNDLE_NAME/any2utf8
BUNDLE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

[ -x "$BIN" ] || { echo "错误: 缺少编译产物(先执行 02_build.sh)"; exit 1; }

mkdir -p $OVERLAY_ROOTFS/usr/bin
mkdir -p $OVERLAY_ROOTFS/usr/share/doc/any2utf8

install -m755 "$BIN" $OVERLAY_ROOTFS/usr/bin/any2utf8
install -m644 "$BUNDLE_DIR/README.md" $OVERLAY_ROOTFS/usr/share/doc/any2utf8/README.md

echo "any2utf8 bundle (文本/文件转 UTF-8 工具) 已安装。"
