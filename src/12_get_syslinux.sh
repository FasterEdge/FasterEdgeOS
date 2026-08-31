#!/bin/sh

set -e

# 加载公共属性与函数。
. ./common.sh

download() {
  # 从 '.config' 读取 'SYSLINUX_SOURCE_URL' 属性。
  DOWNLOAD_URL=`read_property SYSLINUX_SOURCE_URL`

  # 取最后一个 '/' 之后的部分作为归档文件名。
  ARCHIVE_FILE=${DOWNLOAD_URL##*/}

  # 把 Syslinux 源码归档下载到 'source' 目录。
  download_source $DOWNLOAD_URL $SOURCE_DIR/$ARCHIVE_FILE

  # 把 Syslinux 源码解压到 'work/syslinux' 目录。
  extract_source $SOURCE_DIR/$ARCHIVE_FILE syslinux
}

echo "*** 获取 SYSLINUX 开始 ***"

# 从 '.config' 读取 'FIRMWARE_TYPE' 属性。
FIRMWARE_TYPE=`read_property FIRMWARE_TYPE`
echo "固件类型为 '$FIRMWARE_TYPE'。"

case $FIRMWARE_TYPE in
  bios)
    download
    ;;

  both)
    download
    ;;

  uefi)
    download
    ;;

  *)
    echo "无法识别的固件类型 '$FIRMWARE_TYPE'，构建中止。"
    ;;

esac

# 返回 FasterEdgeOS 主源码目录。
cd $SRC_DIR

echo "*** 获取 SYSLINUX 结束 ***"
