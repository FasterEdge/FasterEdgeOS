#!/bin/sh

set -e

. ../../common.sh

# 读取公共配置属性。
DOWNLOAD_URL=`read_property CLOUD_FOUNDRY_CLI_URL`
USE_LOCAL_SOURCE=`read_property USE_LOCAL_SOURCE`

if [ "$USE_LOCAL_SOURCE" = "true" -a ! -f $MAIN_SRC_DIR/source/overlay/cf-cli.tgz ] ; then
  echo "脚本 $MAIN_SRC_DIR/source/overlay/cf-cli.tgz 缺失，将进行下载。"
  USE_LOCAL_SOURCE="false"
fi

cd $MAIN_SRC_DIR/source/overlay

if [ ! "$USE_LOCAL_SOURCE" = "true" ] ; then
  # 正在下载 Cloud Foundry 压缩二进制包。'-c' 选项允许断点续传下载。
  echo "正在从 $DOWNLOAD_URL 下载 Cloud Foundry 压缩二进制包"
  wget -O cf-cli.tgz -c $DOWNLOAD_URL
else
  echo "使用本地 Cloud Foundry 压缩二进制包 $MAIN_SRC_DIR/source/overlay/cf-cli.tgz"
fi

# 删除先前准备好的 cloud foundry cli 目录。
echo "正在清理 Cloud Foundry CLI 的工作目录，这可能需要一些时间。"
rm -rf $WORK_DIR/overlay/$BUNDLE_NAME
mkdir $WORK_DIR/overlay/$BUNDLE_NAME

# 复制 cf-cli.tgz 到目录 'work/overlay/cf_cli'。
cp cf-cli.tgz $WORK_DIR/overlay/$BUNDLE_NAME

cd $SRC_DIR
