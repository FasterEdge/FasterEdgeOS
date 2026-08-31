#!/bin/sh

set -e

. ../../common.sh

# 从 '.config' 读取 'coreutils' 的下载 URL。
DOWNLOAD_URL=`read_property COREUTILS_SOURCE_URL`

# 取最后一个 '/' 之后的所有字符。
ARCHIVE_FILE=${DOWNLOAD_URL##*/}

# 下载 'coreutils' 源码压缩包到 'source/overlay' 目录。
download_source $DOWNLOAD_URL $OVERLAY_SOURCE_DIR/$ARCHIVE_FILE

# 解压全部 'coreutils' 源码到 'work/overlay/coreutils' 目录。
extract_source $OVERLAY_SOURCE_DIR/$ARCHIVE_FILE coreutils

cd $SRC_DIR
