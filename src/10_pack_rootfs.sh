#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

set -e

# 在当前脚本中加载公共属性和函数。
. ./common.sh

echo "*** 打包 ROOTFS 开始 ***"

echo "正在打包 initramfs，这可能需要一些时间。"

# 如果旧的 'initramfs' 归档已存在，则将其移除。
rm -f "$WORK_DIR/rootfs.cpio.xz"

cd "$ROOTFS"

# 可复现打包:
#   * 'find' 输出按 'LC_ALL=C sort' 固定顺序(避免目录项顺序随文件系统 inode 变化);
#   * 'cpio -R root:root' 固定属主, '-0' 保证含空格/换行的文件名不被拆分;
#   * xz 的 .xz 容器不写时间戳, 但多线程分块会改变输出, 因此显式 --threads=1,
#     --check=crc32 固定校验类型。
find . -print0 | LC_ALL=C sort -z | cpio -R root:root -0 -H newc -o \
  | xz -9 --check=crc32 --threads=1 > "$WORK_DIR/rootfs.cpio.xz"

echo "initramfs 打包已完成。"

cd "$SRC_DIR"

echo "*** 打包 ROOTFS 结束 ***"
