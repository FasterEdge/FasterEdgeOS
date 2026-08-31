#!/bin/sh

set -e

. ../../common.sh

# 读取公共配置属性。
DOWNLOAD_URL=`read_property STATIC_GET_URL`
USE_LOCAL_SOURCE=`read_property USE_LOCAL_SOURCE`

if [ "$USE_LOCAL_SOURCE" = "true" -a ! -f $MAIN_SRC_DIR/source/overlay/static-get.sh  ] ; then
  echo "Shell 脚本 $MAIN_SRC_DIR/source/overlay/static-get.sh 缺失，将进行下载。"
  USE_LOCAL_SOURCE="false"
fi

cd $MAIN_SRC_DIR/source/overlay

if [ ! "$USE_LOCAL_SOURCE" = "true" ] ; then
  # 下载 static-get shell 脚本文件。'-c' 选项允许断点续传下载。
  echo "正在从 $DOWNLOAD_URL 下载 static-get shell 脚本"
  wget -O static-get.sh -c $DOWNLOAD_URL
else
  echo "使用本地 static-get shell 脚本 $MAIN_SRC_DIR/source/overlay/static-get.sh"
fi

# 删除之前准备好的 static-get 文件夹。
echo "正在移除 static-get 工作区，这可能需要一些时间。"
rm -rf $WORK_DIR/overlay/$BUNDLE_NAME
mkdir $WORK_DIR/overlay/$BUNDLE_NAME

# 将 static-get 复制到文件夹 'work/overlay/static_get'。
cp static-get.sh $WORK_DIR/overlay/$BUNDLE_NAME

cd $SRC_DIR