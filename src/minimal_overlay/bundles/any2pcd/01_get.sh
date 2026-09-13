#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# 准备 any2pcd 源码到 overlay 构建区。
# 源码随 bundle 入库(本目录 src/), 无网络依赖;
# 离线/内网升级: 设环境变量 ANY2PCD_SOURCE_DIR 指向本地新版源码目录
# (须含 main.go / go.mod), 优先使用本地源码。
set -e

. ../../common.sh

DEST=$OVERLAY_SOURCE_DIR/any2pcd
# 脚本自身所在目录(独立于 $SRC_DIR 语义, 兼容 common.sh 环境)。
BUNDLE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ -n "${ANY2PCD_SOURCE_DIR:-}" ] && [ -f "$ANY2PCD_SOURCE_DIR/main.go" ] ; then
  echo "使用本地 any2pcd 源码: $ANY2PCD_SOURCE_DIR"
  rm -rf "${DEST:?}"
  cp -r "$ANY2PCD_SOURCE_DIR" "$DEST"
  rm -rf "$DEST/.git"
  [ -f "$DEST/go.mod" ] || { echo "错误: 本地源码缺少 go.mod"; exit 1; }
  echo "any2pcd 本地源码就绪"
else
  rm -rf "${DEST:?}"
  cp -r "$BUNDLE_DIR/src" "$DEST"
  [ -f "$DEST/main.go" ] || { echo "错误: 包内源码缺少 main.go"; exit 1; }
  [ -f "$DEST/go.mod" ] || { echo "错误: 包内源码缺少 go.mod"; exit 1; }
  echo "any2pcd 包内源码就绪(无网络依赖)"
fi
