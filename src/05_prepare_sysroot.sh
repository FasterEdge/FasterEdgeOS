#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

set -e

# 在当前脚本中加载公共属性和函数。
. ./common.sh

echo "*** 准备 SYSROOT 开始 ***"

echo "正在清理现有的 sysroot，这可能需要一些时间。"
rm -rf $SYSROOT
mkdir -p $SYSROOT

echo "正在准备 glibc，这可能需要一些时间。"

# 1) 将 glibc 中的所有内容复制到新的 sysroot 区域。
cp -r $GLIBC_INSTALLED/* $SYSROOT

# 2) 将所有内核头文件复制到 sysroot 文件夹。
cp -r $KERNEL_INSTALLED/include $SYSROOT

# 3) 针对缺失 '/work/sysroot/usr' 文件夹的临时解决方案。我们链接
#    现有的库和内核头文件。没有这个方案，Busybox 的编译过程会失败。
#    正确的做法是在 glibc 构建过程中使用 '--prefix=/usr'，
#    但那样我们就得处理其他问题。
#    目前这个方案是最简单直接的解决方案。
mkdir -p $SYSROOT/usr
ln -s ../include $SYSROOT/usr/include
ln -s ../lib $SYSROOT/usr/lib

cd $SRC_DIR

echo "*** 准备 SYSROOT 结束 ***"
