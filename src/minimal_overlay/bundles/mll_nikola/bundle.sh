#!/bin/sh

set -e

. ../../common.sh

mkdir -p $DEST_DIR/etc/autorun
cp $SRC_DIR/99_nikola.sh $DEST_DIR/etc/autorun
chmod +x $DEST_DIR/etc/autorun/99_nikola.sh

install_to_overlay

# 最后输出 bundle 已安装完成的信息，并返回
# overlay 源码目录。
echo "bundle '$BUNDLE_NAME' 已安装完成。"

cd $SRC_DIR

