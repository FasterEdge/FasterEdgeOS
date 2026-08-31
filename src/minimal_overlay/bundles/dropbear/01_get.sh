#!/bin/sh

set -e

. ../../common.sh

# 读取公共配置属性。
DOWNLOAD_URL=`read_property DROPBEAR_SOURCE_URL`
USE_LOCAL_SOURCE=`read_property USE_LOCAL_SOURCE`

# 取最后一个 '/' 之后的所有字符。
ARCHIVE_FILE=${DOWNLOAD_URL##*/}

if [ "$USE_LOCAL_SOURCE" = "true" -a ! -f $MAIN_SRC_DIR/source/overlay/$ARCHIVE_FILE ] ; then
  echo "源码包 $MAIN_SRC_DIR/source/overlay/$ARCHIVE_FILE 缺失，将进行下载。"
  USE_LOCAL_SOURCE="false"
fi

cd $MAIN_SRC_DIR/source/overlay

if [ ! "$USE_LOCAL_SOURCE" = "true" ] ; then
  # 正在下载 Dropbear 源码包文件。'-c' 选项允许断点续传下载。
  echo "正在从 $DOWNLOAD_URL 下载 Dropbear 源码包"
  wget -c $DOWNLOAD_URL
else
  echo "使用本地 Dropbear 源码包 $MAIN_SRC_DIR/source/overlay/$ARCHIVE_FILE"
fi

# 删除先前解压出的 Dropbear 目录。
echo "正在清理 Dropbear 的工作目录，这可能需要一些时间。"
rm -rf $WORK_DIR/overlay/$BUNDLE_NAME
mkdir $WORK_DIR/overlay/$BUNDLE_NAME

# 解压 Dropbear 到目录 'work/overlay/dropbear'。
# 完整路径形如 'work/overlay/dropbear/dropbear-2016.73'。
tar -xvf $ARCHIVE_FILE -C $WORK_DIR/overlay/$BUNDLE_NAME

cd $SRC_DIR
