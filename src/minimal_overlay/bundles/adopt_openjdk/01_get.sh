#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

set -e

. ../../common.sh

# 读取配置属性。
JVM_ENGINE=`read_property JVM_ENGINE`
DOWNLOAD_URL=`read_property ADOPT_OPENJDK_${JVM_ENGINE}_URL`

# 取最后一个 '/' 之后的所有字符。
ARCHIVE_FILE=${DOWNLOAD_URL##*/}

download_source $DOWNLOAD_URL $OVERLAY_SOURCE_DIR/$ARCHIVE_FILE

extract_source $OVERLAY_SOURCE_DIR/$ARCHIVE_FILE $BUNDLE_NAME

cd $SRC_DIR

