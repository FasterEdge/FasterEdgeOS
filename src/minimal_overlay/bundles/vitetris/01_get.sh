#!/bin/sh

set -e

. ../../common.sh

# 读取公共配置属性。
DOWNLOAD_URL=`read_property VITETRIS_SOURCE_URL`
# 取最后一个 '/' 之后的所有字符。
ARCHIVE_FILE=${DOWNLOAD_URL##*/}

download_source $DOWNLOAD_URL $OVERLAY_SOURCE_DIR/$ARCHIVE_FILE

unzip $OVERLAY_SOURCE_DIR/$ARCHIVE_FILE -d $WORK_DIR/overlay/$BUNDLE_NAME

cd $SRC_DIR

