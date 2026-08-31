#!/bin/sh

set -e

# 在当前脚本中加载公共属性和函数。
. ./common.sh

echo "*** 打包 ROOTFS 开始 ***"

echo "正在打包 initramfs，这可能需要一些时间。"

# 如果旧的 'initramfs' 归档已存在，则将其移除。
rm -f $WORK_DIR/rootfs.cpio.xz

cd $ROOTFS

# 将当前的 'initramfs' 文件夹结构打包到 'cpio.xz' 归档中。
find . | cpio -R root:root -H newc -o | xz -9 --check=crc32 > $WORK_DIR/rootfs.cpio.xz

echo "initramfs 打包已完成。"

cd $SRC_DIR

echo "*** 打包 ROOTFS 结束 ***"
