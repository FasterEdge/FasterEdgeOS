#!/bin/sh

set -e

. ../../common.sh

# 读取公共配置属性。
DOWNLOAD_URL=`read_property PYTHON_SOURCE_URL`
USE_LOCAL_SOURCE=`read_property USE_LOCAL_SOURCE`

INSTALL_PIP=`read_property INSTALL_PIP`
PIP_DOWNLOAD_URL=`read_property PIP_SOURCE_URL`
USE_LOCAL_PIP_SOURCE=`read_property USE_LOCAL_SOURCE`

# 取最后一个 '/' 之后的所有字符。
ARCHIVE_FILE=${DOWNLOAD_URL##*/}
PIP_FILE=${PIP_DOWNLOAD_URL##*/}

if [ "$USE_LOCAL_SOURCE" = "true" -a ! -f $MAIN_SRC_DIR/source/overlay/$ARCHIVE_FILE  ] ; then
  echo "源码包 $MAIN_SRC_DIR/source/overlay/$ARCHIVE_FILE 缺失，将进行下载。"
  USE_LOCAL_SOURCE="false"
fi

if [ "$INSTALL_PIP" = "true" ] ; then
  if [ "$USE_LOCAL_PIP_SOURCE" = "true" -a ! -f $MAIN_SRC_DIR/source/overlay/$PIP_FILE  ] ; then
    echo "pip 安装程序 $MAIN_SRC_DIR/source/overlay/$PIP_FILE 缺失，将进行下载。"
    USE_LOCAL_PIP_SOURCE="false"
  fi
fi

cd $MAIN_SRC_DIR/source/overlay

if [ ! "$USE_LOCAL_SOURCE" = "true" ] ; then
  # 正在下载 python 源码包文件。'-c' 选项允许断点续传下载。
  echo "正在从 $DOWNLOAD_URL 下载 PYTHON 源码包"
  wget -c $DOWNLOAD_URL
else
  echo "使用本地 PYTHON 源码包 $MAIN_SRC_DIR/source/overlay/$ARCHIVE_FILE"
fi

if [ "$INSTALL_PIP" = "true" ] ; then
  if [ ! "$USE_LOCAL_PIP_SOURCE" = "true" ] ; then
    # 正在下载 pip 源码包文件。'-c' 选项允许断点续传下载。
    echo "正在从 $PIP_DOWNLOAD_URL 下载 PIP 源码包"
    wget -c $PIP_DOWNLOAD_URL
  else
    echo "使用本地 PIP 源码包 $MAIN_SRC_DIR/source/overlay/$PIP_FILE"
  fi
fi

# 删除先前解压出的 python 目录。
echo "正在清理 PYTHON 的工作目录，这可能需要一些时间。"
rm -rf $WORK_DIR/overlay/$BUNDLE_NAME
mkdir $WORK_DIR/overlay/$BUNDLE_NAME

# 解压 python 到目录 'work/overlay/python'。
# 完整路径形如 'work/overlay/python/Python-3.8.0'。
tar -xvf $ARCHIVE_FILE -C $WORK_DIR/overlay/$BUNDLE_NAME

if [ "$INSTALL_PIP" = "true" ] ; then
  # 复制 pip 安装脚本
  cp $PIP_FILE $WORK_DIR/overlay/$BUNDLE_NAME/get-pip.py
fi

cd $SRC_DIR
