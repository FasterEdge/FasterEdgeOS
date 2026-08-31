#!/bin/sh

set -e

. ../../common.sh

echo "正在准备 FasterEdgeOS 工具文件夹，这可能需要一些时间。"
rm -rf $WORK_DIR/overlay/$BUNDLE_NAME
mkdir -p $WORK_DIR/overlay/$BUNDLE_NAME/sbin

echo "FasterEdgeOS 工具文件夹已准备就绪。"

cd $SRC_DIR