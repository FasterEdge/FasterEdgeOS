#!/bin/sh

set -e

# 加载公共属性与函数。
. ./common.sh

echo "*** 生成 OVERLAY 开始 ***"

# 清理旧的 ISO overlay 区域。
echo "正在清理旧 overlay 区域，可能需要一些时间。"
rm -rf $ISOIMAGE_OVERLAY

# 创建新的 ISO overlay 区域。
mkdir -p $ISOIMAGE_OVERLAY
cd $ISOIMAGE_OVERLAY

# 从 '.config' 读取 'OVERLAY_TYPE' 属性。
OVERLAY_TYPE=`read_property OVERLAY_TYPE`

# 从 '.config' 读取 'OVERLAY_LOCATION' 属性。
OVERLAY_LOCATION=`read_property OVERLAY_LOCATION`

BUILD_KERNEL_MODULES=`read_property BUILD_KERNEL_MODULES`

if [ "$OVERLAY_LOCATION" = "iso" ] && \
   [ "$OVERLAY_TYPE" = "sparse" ] && \
   [ -d $OVERLAY_ROOTFS ] && \
   [ ! "`ls -A $OVERLAY_ROOTFS`" = "" ] && \
   [ "$(id -u)" = "0" ] ; then

  # 使用稀疏文件作为存储载体。上面的检查保证整段脚本以 root 权限执行，
  # 否则此分支会被跳过。目录 'minimal_overlay' 下的所有文件与目录会在
  # 启动时与根目录合并。

  echo "正在使用稀疏文件存放 overlay。"

  # 这是我们已经生成好的 Busybox 可执行文件。
  BUSYBOX=$ROOTFS/bin/busybox

  # 创建 3MB 大小的稀疏镜像文件。注意这会增大 ISO 镜像体积。
  $BUSYBOX truncate -s 3M $ISOIMAGE_OVERLAY/fasteredgeos.img

  # 查找可用的 loop 设备。
  LOOP_DEVICE=$($BUSYBOX losetup -f)

  # 把可用 loop 设备与稀疏镜像文件关联。
  $BUSYBOX losetup $LOOP_DEVICE $ISOIMAGE_OVERLAY/fasteredgeos.img

  # 用 Ext2 文件系统格式化稀疏镜像。
  $BUSYBOX mkfs.ext2 $LOOP_DEVICE

  # 把稀疏文件挂载到 'sparse' 目录。
  mkdir $ISOIMAGE_OVERLAY/sparse
  $BUSYBOX mount $ISOIMAGE_OVERLAY/fasteredgeos.img sparse

  # 创建 overlay 目录。
  mkdir -p $ISOIMAGE_OVERLAY/sparse/rootfs
  mkdir -p $ISOIMAGE_OVERLAY/sparse/work

  # 复制 overlay 内容。
  cp -r $OVERLAY_ROOTFS/* \
    $ISOIMAGE_OVERLAY/sparse/rootfs
  cp -r $SRC_DIR/minimal_overlay/rootfs/* \
    $ISOIMAGE_OVERLAY/sparse/rootfs

  # 复制所有内核模块到 sysroot 目录。
  if [ "$BUILD_KERNEL_MODULES" = "true" ] ; then
    echo "正在复制内核模块，可能需要一些时间。"
    cp -r $KERNEL_INSTALLED/lib $ISOIMAGE_OVERLAY/sparse/rootfs
  fi

  # 卸载稀疏文件并删除临时目录。
  sync
  $BUSYBOX umount $ISOIMAGE_OVERLAY/sparse
  sync
  sleep 1
  rm -rf $ISOIMAGE_OVERLAY/sparse

  # 分离 loop 设备。
  $BUSYBOX losetup -d $LOOP_DEVICE
elif [ "$OVERLAY_LOCATION" = "iso" ] && \
     [ "$OVERLAY_TYPE" = "folder" ] && \
     [ -d $OVERLAY_ROOTFS ] && \
     [ ! "`ls -A $OVERLAY_ROOTFS`" = "" ] ; then

  # 使用普通目录结构作为 overlay。目录 'minimal_overlay' 下的所有文件与
  # 目录会在启动时与根目录合并。

  echo "正在使用目录结构存放 overlay。"

  # 创建 overlay 目录。
  mkdir -p $ISOIMAGE_OVERLAY/fasteredgeos/rootfs
  mkdir -p $ISOIMAGE_OVERLAY/fasteredgeos/work

  # 复制 overlay 内容。
  cp -rf $OVERLAY_ROOTFS/* \
    $ISOIMAGE_OVERLAY/fasteredgeos/rootfs
  cp -r $SRC_DIR/minimal_overlay/rootfs/* \
    $ISOIMAGE_OVERLAY/fasteredgeos/rootfs

  # 复制所有内核模块到 sysroot 目录。
  if [ "$BUILD_KERNEL_MODULES" = "true" ] ; then
    echo "正在复制内核模块，可能需要一些时间。"
    cp -r $KERNEL_INSTALLED/lib $ISOIMAGE_OVERLAY/fasteredgeos/rootfs
  fi
else
  echo "ISO 镜像将不包含 overlay 结构。"
fi

cd $SRC_DIR

echo "*** 生成 OVERLAY 结束 ***"