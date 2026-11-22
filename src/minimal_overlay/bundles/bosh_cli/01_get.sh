#!/bin/sh

set -e

. ../../common.sh

# 读取公共配置属性。
DOWNLOAD_URL=`read_property BOSH_CLI_URL`
download_source $DOWNLOAD_URL $OVERLAY_SOURCE_DIR/bosh-cli

# 删除先前准备好的 BOSH CLI 目录。
echo "正在清理 BOSH CLI 的工作目录，这可能需要一些时间。"
rm -rf "${WORK_DIR:?}/overlay/${BUNDLE_NAME:?}"
mkdir $WORK_DIR/overlay/$BUNDLE_NAME

# 复制 bosh-cli 到目录 'work/overlay/bosh_cli'。
cp $OVERLAY_SOURCE_DIR/bosh-cli $WORK_DIR/overlay/$BUNDLE_NAME

cd $SRC_DIR
