#!/bin/sh

set -e

# 加载公共属性与函数。
. ./common.sh

echo "*** 获取 glibc 开始 ***"

# 从 '.config' 读取 'GLIBC_SOURCE_URL' 属性。
DOWNLOAD_URL=`read_property GLIBC_SOURCE_URL`

# 取最后一个 '/' 之后的部分作为归档文件名。
ARCHIVE_FILE=${DOWNLOAD_URL##*/}

# 把 glibc 源码归档下载到 'source' 目录。
download_source $DOWNLOAD_URL $SOURCE_DIR/$ARCHIVE_FILE

# 把 glibc 源码解压到 'work/glibc' 目录。
extract_source $SOURCE_DIR/$ARCHIVE_FILE glibc

# 返回 FasterEdgeOS 主源码目录。
cd $SRC_DIR

echo "*** 获取 glibc 结束 ***"
