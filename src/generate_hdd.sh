#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

set -e

# 创建可供 QEMU 使用的 20MB 稀疏文件。

if [ "$1" = "-e" -o "$1" = "--empty" ] ; then
  # 创建新的硬盘镜像文件。
  rm -f hdd.img
  truncate -s 20M hdd.img
  echo "已创建 20MB 大小的硬盘镜像文件 'hdd.img'。"
elif [ "$1" = "-f" -o "$1" = "--folder" ] ; then
  if [ ! "$(id -u)" = "0" ] ; then
    echo "使用 '-f'（或 '--folder'）选项需要 root 权限。"
    exit 1
  fi

  rm -f hdd.img
  truncate -s 20M hdd.img
  echo "已创建 20MB 大小的硬盘镜像文件 'hdd.img'。"

  LOOP_DEVICE=$(losetup -f)
  losetup $LOOP_DEVICE hdd.img
  echo "已将硬盘镜像文件挂载到 loop 设备。"

  mkfs.ext2 $LOOP_DEVICE
  echo "硬盘镜像文件已用 Ext2 文件系统格式化。"

  mkdir folder
  mount hdd.img folder
  echo "已将硬盘镜像文件挂载到临时目录。"

  mkdir -p folder/fasteredgeos/rootfs
  mkdir -p folder/fasteredgeos/work
  echo "overlay 结构已创建。"

  echo "This file is on external hard disk." > folder/fasteredgeos/rootfs/overlay.txt
  echo "已创建示例文本文件。"

  sync
  umount folder
  sync
  rm -rf folder
  echo "已卸载硬盘镜像文件。"

  losetup -d $LOOP_DEVICE
  echo "已将硬盘镜像文件从 loop 设备分离。"

  # 查找原始用户。注意该方法不一定总是正确。
  ORIG_USER=`who | awk '{print \$1}'`
  chown $ORIG_USER hdd.img
  echo "已将硬盘镜像文件的属主还原为原始用户。"
elif [ "$1" = "-s" -o "$1" = "--sparse" ] ; then
  if [ ! "$(id -u)" = "0" ] ; then
    echo "使用 '-s'（或 '--sparse'）选项需要 root 权限。"
    exit 1
  fi

  rm -f hdd.img
  truncate -s 20M hdd.img
  echo "已创建 20MB 大小的硬盘镜像文件 'hdd.img'。"

  LOOP_DEVICE_HDD=$(losetup -f)
  losetup $LOOP_DEVICE_HDD hdd.img
  echo "已将硬盘镜像文件挂载到 loop 设备。"

  mkfs.vfat $LOOP_DEVICE_HDD
  echo "硬盘镜像文件已用 FAT 文件系统格式化。"

  rm -rf sparse
  mkdir sparse
  mount hdd.img sparse
  echo "已将硬盘镜像文件挂载到临时目录。"

  rm -f sparse/fasteredgeos.img
  truncate -s 3M sparse/fasteredgeos.img
  echo "已创建 3MB 大小的 overlay 镜像文件。"

  LOOP_DEVICE_OVL=$(losetup -f)
  losetup $LOOP_DEVICE_OVL sparse/fasteredgeos.img
  echo "已将 overlay 镜像文件挂载到 loop 设备。"

  mkfs.ext2 $LOOP_DEVICE_OVL
  echo "overlay 镜像文件已用 Ext2 文件系统格式化。"

  mkdir ovl
  mount sparse/fasteredgeos.img ovl
  echo "已将 overlay 镜像文件挂载到临时目录。"

  mkdir -p ovl/rootfs
  mkdir -p ovl/work
  echo "overlay 结构已创建。"

  echo "创建示例文本文件。"
  echo "This file is on external hard disk." > ovl/rootfs/overlay.txt

  chown -R root:root ovl
  echo "已将 overlay 内容的属主设置为 root。"

  sync
  umount ovl
  sync
  sleep 1
  rm -rf ovl
  echo "已卸载 overlay 镜像文件。"

  losetup -d $LOOP_DEVICE_OVL
  sleep 1
  echo "overlay 镜像文件已从 loop 设备分离。"

  sync
  umount sparse
  sync
  sleep 1
  rm -rf sparse
  echo "已卸载硬盘镜像文件。"

  losetup -d $LOOP_DEVICE_HDD
  sleep 1
  echo "硬盘镜像文件已从 loop 设备分离。"
  # 查找原始用户。注意该方法不一定总是正确。
  ORIG_USER=`who | awk '{print \$1}'`

  chown $ORIG_USER hdd.img

  echo "已将硬盘镜像文件的属主还原为原始用户。"
elif [ "$1" = "-h" -o "$1" = "--help" ] ; then
  cat << CEOF
  用法: $0 [选项]
  本工具生成 20MB 稀疏文件 'hdd.img'，可作为 QEMU 磁盘镜像使用，
  Live 会话中的全部文件系统变更都会持久化到该镜像中。

  -e, --empty     创建未格式化的空稀疏镜像文件。
  -f, --folder    创建用 Ext2 文件系统格式化、包含兼容 overlay 目录结构的
                  稀疏镜像文件。
  -h, --help      显示本帮助信息。
  -s, --sparse    创建用 FAT 文件系统格式化的稀疏镜像文件，其中包含
                  3MB 大小 'fasteredgeos.img' 稀疏文件（Ext2 格式），该文件
                  存放实际的 overlay 结构。
CEOF

elif [ "$1" = "" ] ; then
  echo "未指定选项。使用 '-h' 或 '--help' 查看帮助。"
else
  echo "无法识别的选项 '$1'。使用 '-h' 或 '--help' 查看帮助。"
fi
