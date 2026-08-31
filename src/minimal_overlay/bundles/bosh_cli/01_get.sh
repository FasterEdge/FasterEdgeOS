#!/bin/sh

set -e

. ../../common.sh

# 读取公共配置属性。
DOWNLOAD_URL=`read_property BOSH_CLI_URL`
USE_LOCAL_SOURCE=`read_property USE_LOCAL_SOURCE`

if [ "$USE_LOCAL_SOURCE" = "true" -a ! -f $MAIN_SRC_DIR/source/overlay/bosh-cli ] ; then
  echo "脚本 '$MAIN_SRC_DIR/source/overlay/bosh-cli' 缺失，将进行下载。"
  USE_LOCAL_SOURCE="false"
fi

cd $MAIN_SRC_DIR/source/overlay

if [ ! "$USE_LOCAL_SOURCE" = "true" ] ; then
  # 正在下载 BOSH CLI 二进制文件。'-c' 选项允许断点续传下载。
  echo "正在从 $DOWNLOAD_URL 下载 BOSH CLI 二进制文件"
  wget -O bosh-cli -c $DOWNLOAD_URL
else
  echo "使用本地 BOSH CLI 二进制文件 '$MAIN_SRC_DIR/source/overlay/bosh-cli'。"
fi

# 删除先前准备好的 BOSH CLI 目录。
echo "正在清理 BOSH CLI 的工作目录，这可能需要一些时间。"
rm -rf $WORK_DIR/overlay/$BUNDLE_NAME
mkdir $WORK_DIR/overlay/$BUNDLE_NAME

# 复制 bosh-cli 到目录 'work/overlay/bosh_cli'。
cp bosh-cli $WORK_DIR/overlay/$BUNDLE_NAME

cd $SRC_DIR
