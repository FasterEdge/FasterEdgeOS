#!/bin/sh

set -e

. ../../common.sh

# 读取公共配置属性。
DOWNLOAD_URL=`read_property DROPBEAR_SOURCE_URL`

# 取最后一个 '/' 之后的所有字符。
ARCHIVE_FILE=${DOWNLOAD_URL##*/}

# 经公共 download_source 下载（与核心utils/adopt_openjdk 同款加固：
# 5 次 shell 重试 + source/overlay 下 .sha256 强制校验 fail-closed）。
# 注：此前此处为裸 wget（无重试/无校验），与主链供应链加固不一致，
# 已对齐 911 轮修复语义。
download_source $DOWNLOAD_URL $OVERLAY_SOURCE_DIR/$ARCHIVE_FILE

extract_source $OVERLAY_SOURCE_DIR/$ARCHIVE_FILE $BUNDLE_NAME

cd $SRC_DIR
