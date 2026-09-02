#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

set -e

# 在当前脚本中加载公共属性和函数。
. ./common.sh

echo "*** 构建 GLIBC 开始 ***"

# 准备工作区，例如 'work/glibc/glibc_objects'。
echo "正在准备 glibc 对象目录，这可能需要一些时间。"
rm -rf $GLIBC_OBJECTS
mkdir $GLIBC_OBJECTS

# 准备安装目录，例如 'work/glibc/glibc_installed'。
echo "正在准备 glibc 安装目录，这可能需要一些时间。"
rm -rf $GLIBC_INSTALLED
mkdir $GLIBC_INSTALLED

# 找到 glibc 源码目录（例如 'glibc-2.23'）并记住它。
GLIBC_SRC=`ls -d $WORK_DIR/glibc/glibc-*`

# 所有 glibc 的工作都在工作区内完成。
cd $GLIBC_OBJECTS

# 'glibc' 被配置为使用根目录（--prefix=），因此所有库都会安装到 '/lib'。
# 请注意，在 64 位机器上，Busybox 将与 '/lib' 中的库链接，而 Linux
# 加载器预期位于 '/lib64'。内核头文件取自我们已准备好的内核头文件区域
# （参见 xx_build_kernel.sh）。为更好地兼容主机系统的构建环境，
# 'gd' 和 'selinux' 软件包被禁用。
echo "正在配置 glibc。"
$GLIBC_SRC/configure \
  --prefix= \
  --with-headers=$KERNEL_INSTALLED/include \
  --without-gd \
  --without-selinux \
  --disable-werror \
  CFLAGS="$CFLAGS"

# 以“并行任务数 = 处理器数量”的优化方式编译 glibc。
echo "正在构建 glibc。"
make -j $NUM_JOBS

# 将 glibc 安装到安装目录，例如 'work/glibc/glibc_installed'。
echo "正在安装 glibc。"
make install \
  DESTDIR=$GLIBC_INSTALLED \
  -j $NUM_JOBS

cd $SRC_DIR

echo "*** 构建 GLIBC 结束 ***"
