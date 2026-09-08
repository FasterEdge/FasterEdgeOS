#!/bin/sh

set -e

. ../../common.sh

# 读取公共配置属性。
DOWNLOAD_URL=`read_property C2048_SOURCE_URL`
# 取最后一个 '/' 之后的所有字符。
ARCHIVE_FILE=${DOWNLOAD_URL##*/}

download_source $DOWNLOAD_URL $OVERLAY_SOURCE_DIR/$ARCHIVE_FILE

cp $OVERLAY_SOURCE_DIR/$ARCHIVE_FILE $WORK_DIR/overlay/$BUNDLE_NAME

cd $SRC_DIR
