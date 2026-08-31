#!/bin/sh

set -e

SRC_DIR=$(pwd)

echo "正在清理 overlay 工作区，这可能需要一些时间。"
rm -rf ../work/overlay
rm -rf ../work/overlay_rootfs

# -p 可避免目录已存在时报错。
mkdir -p ../work/overlay
mkdir -p ../work/overlay_rootfs
mkdir -p ../source/overlay

echo "已准备好继续处理 overlay 软件。"

cd $SRC_DIR
