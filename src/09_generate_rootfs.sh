#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

set -e

# 在当前脚本中加载公共属性和函数。
. ./common.sh

BUILD_KERNEL_MODULES=`read_property BUILD_KERNEL_MODULES`

echo "*** 生成 ROOTFS 开始 ***"

echo "正在准备 rootfs 工作区，这可能需要一些时间。"
rm -rf $ROOTFS

# 将 Busybox 生成的所有内容复制到 'rootfs' 文件夹。
cp -r $BUSYBOX_INSTALLED $ROOTFS

# 将所有 rootfs 资源复制到 'rootfs' 文件夹。
cp -r $SRC_DIR/minimal_rootfs/* $ROOTFS

# 删除 '.keep' 文件，我们用它们来跟踪原本为空的文件夹。
find $ROOTFS/* -type f -name '.keep' -exec rm {} +

# 移除在 'RAM disk' 模式启动时使用的 'linuxrc'。
rm -f $ROOTFS/linuxrc

# 这是为动态加载器准备的。请注意，名称和位置在 32 位和 64 位
# 机器上各不相同。首先我们检查 Busybox 可执行文件，然后
# 将动态加载器复制到其对应的位置。
BUSYBOX_ARCH=$(file $ROOTFS/bin/busybox | cut -d' ' -f3)
if [ "$BUSYBOX_ARCH" = "64-bit" ] ; then
  mkdir -p $ROOTFS/lib64
  cp $SYSROOT/lib/ld-linux* $ROOTFS/lib64
  echo "动态加载器通过 '/lib64' 访问。"
else
  cp $SYSROOT/lib/ld-linux* $ROOTFS/lib
  echo "动态加载器通过 '/lib' 访问。"
fi

# 将所有必要的 'glibc' 库复制到 '/lib' 开始。

# Busybox 直接依赖这些库。
cp $SYSROOT/lib/libm.so.6 $ROOTFS/lib
cp $SYSROOT/lib/libc.so.6 $ROOTFS/lib
cp $SYSROOT/lib/libresolv.so.2 $ROOTFS/lib

# 将所有必要的 'glibc' 库复制到 '/lib' 结束。

echo "正在缩减库和可执行文件的大小。"
set +e
strip -g \
  $ROOTFS/bin/* \
  $ROOTFS/sbin/* \
  $ROOTFS/lib/* \
  2>/dev/null
set -e

# 从 '.config' 读取 'OVERLAY_LOCATION' 属性
OVERLAY_LOCATION=`read_property OVERLAY_LOCATION`

if [ "$OVERLAY_LOCATION" = "rootfs" ] && \
   [ -d $OVERLAY_ROOTFS ] && \
   [ ! "`ls -A $OVERLAY_ROOTFS`" = "" ] ; then

  echo "正在将 overlay 软件合并到 rootfs 中。"

  # 使用 '--remove-destination'，$OVERLAY_ROOTFS 中所有可能已存在的
  # 软链接都会被正确覆盖。
  cp -r --remove-destination \
    $OVERLAY_ROOTFS/* $ROOTFS
  cp -r --remove-destination \
    $SRC_DIR/minimal_overlay/rootfs/* $ROOTFS

  # 将所有模块复制到 sysroot 文件夹。
  if [ "$BUILD_KERNEL_MODULES" = "true" ] ; then
    echo "正在复制模块，这可能需要一些时间。"
    cp -r --remove-destination $KERNEL_INSTALLED/lib $ROOTFS
  fi
fi

echo "rootfs 区域已生成。"

cd $SRC_DIR

echo "*** 生成 ROOTFS 结束 ***"
