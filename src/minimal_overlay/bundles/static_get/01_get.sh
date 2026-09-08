#!/bin/sh
# ─────────────────────────────────────────────────────────────
# FasterEdge 开源项目
# Github: https://github.com/FasterEdge
# Gitee:  https://gitee.com/FasterEdge
# ─────────────────────────────────────────────────────────────

set -e

. ../../common.sh

# 读取公共配置属性。
DOWNLOAD_URL=`read_property STATIC_GET_URL`
download_source $DOWNLOAD_URL $OVERLAY_SOURCE_DIR/static-get.sh

# 删除之前准备好的 static-get 文件夹。
echo "正在移除 static-get 工作区，这可能需要一些时间。"
rm -rf "${WORK_DIR:?}/overlay/${BUNDLE_NAME:?}"
mkdir $WORK_DIR/overlay/$BUNDLE_NAME

# 将 static-get 复制到文件夹 'work/overlay/static_get'。
cp $OVERLAY_SOURCE_DIR/static-get.sh $WORK_DIR/overlay/$BUNDLE_NAME

cd $SRC_DIR
