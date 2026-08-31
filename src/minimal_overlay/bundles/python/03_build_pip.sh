#!/bin/sh

set -e

. ../../common.sh

cd $WORK_DIR/overlay/$BUNDLE_NAME

# 读取公共配置属性。
INSTALL_PIP=`read_property INSTALL_PIP`

if [ "$INSTALL_PIP" = "true" ] ; then
  echo "正在安装 pip"
  $DEST_DIR/usr/bin/python3 get-pip.py
fi

cd $SRC_DIR
