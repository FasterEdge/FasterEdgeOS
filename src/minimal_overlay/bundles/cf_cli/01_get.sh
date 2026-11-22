#!/bin/sh

set -e

. ../../common.sh

# 读取公共配置属性。
DOWNLOAD_URL=`read_property CLOUD_FOUNDRY_CLI_URL`
download_source $DOWNLOAD_URL $OVERLAY_SOURCE_DIR/cf-cli.tgz

# 删除先前准备好的 cloud foundry cli 目录。
echo "正在清理 Cloud Foundry CLI 的工作目录，这可能需要一些时间。"
rm -rf "${WORK_DIR:?}/overlay/${BUNDLE_NAME:?}"
mkdir $WORK_DIR/overlay/$BUNDLE_NAME

# 复制 cf-cli.tgz 到目录 'work/overlay/cf_cli'。
cp $OVERLAY_SOURCE_DIR/cf-cli.tgz $WORK_DIR/overlay/$BUNDLE_NAME

cd $SRC_DIR
