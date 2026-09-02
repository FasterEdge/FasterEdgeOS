#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

set -e

SRC_DIR=$PWD
CONFIG=$SRC_DIR/.config
SOURCE_DIR=$SRC_DIR/source
WORK_DIR=$SRC_DIR/work
KERNEL_INSTALLED=$WORK_DIR/kernel/kernel_installed
GLIBC_OBJECTS=$WORK_DIR/glibc/glibc_objects
GLIBC_INSTALLED=$WORK_DIR/glibc/glibc_installed
BUSYBOX_INSTALLED=$WORK_DIR/busybox/busybox_installed
SYSROOT=$WORK_DIR/sysroot
ROOTFS=$WORK_DIR/rootfs
OVERLAY_ROOTFS=$WORK_DIR/overlay_rootfs
ISOIMAGE=$WORK_DIR/isoimage
ISOIMAGE_OVERLAY=$WORK_DIR/isoimage_overlay

# 该函数从主 '.config' 文件中读取属性。
#
# 使用 () 而不是 {} 作为函数体，是符合 POSIX 规范的执行子 shell
# 的方式，因此函数中的所有变量实际上都会成为局部作用域变量。
# 请注意，大多数 shell 支持 'local' 关键字，但它不符合 POSIX 规范。
read_property() (
  # 我们要查找的属性。
  prop_name=$1

  # 属性的值，初始设置为空字符串。
  prop_value=

  if [ ! "$prop_name" = "" ] ; then
    # 在主 '.config' 文件中搜索。
    prop_value=`grep -i ^${prop_name}= $CONFIG | cut -f2- -d'=' | xargs`
  fi

  echo $prop_value
)

# 从主 '.config' 文件中读取常用属性。
JOB_FACTOR=`read_property JOB_FACTOR`
CFLAGS=`read_property CFLAGS`
NUM_CORES=$(grep ^processor /proc/cpuinfo | wc -l)

# 计算稍后要使用的 'make' 任务数。
NUM_JOBS=$((NUM_CORES * JOB_FACTOR))

download_source() (
  url=$1  # 从此 URL 下载。
  file=$2 # 将资源保存到此文件中。

  local=`read_property USE_LOCAL_SOURCE`

  if [ "$local" = "true" -a ! -f $file  ] ; then
    echo "源文件 '$file' 不存在，将进行下载。"
    local=false
  fi

  if [ ! "$local" = "true" ] ; then
    echo "正在从 '$url' 下载源文件。"
    echo "正在将源文件保存到 '$file'".
    wget -O $file -c $url
  else
    echo "正在使用本地源文件 '$file'。"
  fi
)

extract_source() (
  file=$1
  name=$2

  # 删除之前已解压源码的文件夹。
  echo "正在移除 '$name' 工作区，这可能需要一些时间。"
  rm -rf $WORK_DIR/$name
  mkdir $WORK_DIR/$name

  # 将源码解压到文件夹 'work/$source'。
  tar -xvf $file -C $WORK_DIR/$name
)
