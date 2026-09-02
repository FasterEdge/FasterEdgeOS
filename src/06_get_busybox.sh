#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

set -e

# 加载公共属性与函数。
. ./common.sh

echo "*** 获取 BusyBox 开始 ***"

# 从 '.config' 读取 'BUSYBOX_SOURCE_URL' 属性。
DOWNLOAD_URL=`read_property BUSYBOX_SOURCE_URL`

# 取最后一个 '/' 之后的部分作为归档文件名。
ARCHIVE_FILE=${DOWNLOAD_URL##*/}

# 把 BusyBox 源码归档下载到 'source' 目录。
download_source $DOWNLOAD_URL $SOURCE_DIR/$ARCHIVE_FILE

# 把 BusyBox 源码解压到 'work/busybox' 目录。
extract_source $SOURCE_DIR/$ARCHIVE_FILE busybox

# 返回 FasterEdgeOS 主源码目录。
cd $SRC_DIR

echo "*** 获取 BusyBox 结束 ***"
