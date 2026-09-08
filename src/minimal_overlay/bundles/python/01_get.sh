#!/bin/sh

set -e

. ../../common.sh

# 读取公共配置属性。
DOWNLOAD_URL=`read_property PYTHON_SOURCE_URL`

INSTALL_PIP=`read_property INSTALL_PIP`
PIP_DOWNLOAD_URL=`read_property PIP_SOURCE_URL`

# 取最后一个 '/' 之后的所有字符。
ARCHIVE_FILE=${DOWNLOAD_URL##*/}
PIP_FILE=${PIP_DOWNLOAD_URL##*/}

# 经公共 download_source 下载(重试 + sidecar 校验加固, 与主链一致)。
download_source $DOWNLOAD_URL $OVERLAY_SOURCE_DIR/$ARCHIVE_FILE

if [ "$INSTALL_PIP" = "true" ] ; then
  download_source $PIP_DOWNLOAD_URL $OVERLAY_SOURCE_DIR/$PIP_FILE
fi

# 删除先前解压出的 python 目录。
echo "正在清理 PYTHON 的工作目录，这可能需要一些时间。"
rm -rf "${WORK_DIR:?}/overlay/${BUNDLE_NAME:?}"
mkdir $WORK_DIR/overlay/$BUNDLE_NAME

# 解压 python 到目录 'work/overlay/python'。
# 完整路径形如 'work/overlay/python/Python-3.8.0'。
extract_source $OVERLAY_SOURCE_DIR/$ARCHIVE_FILE $BUNDLE_NAME

if [ "$INSTALL_PIP" = "true" ] ; then
  # 复制 pip 安装脚本
  cp $OVERLAY_SOURCE_DIR/$PIP_FILE $WORK_DIR/overlay/$BUNDLE_NAME/get-pip.py
fi

cd $SRC_DIR
