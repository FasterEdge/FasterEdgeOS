#!/bin/sh

set -e

. ../../common.sh

if [ ! -d "$WORK_DIR/overlay/$BUNDLE_NAME" ] ; then
  echo "目录 '$WORK_DIR/overlay/$BUNDLE_NAME' 不存在，无法继续。"
  exit 1
fi

# 将所有生成的文件复制到源码 overlay 文件夹。
# 使用 '--remove-destination' 可以正确覆盖 '$OVERLAY_ROOTFS'
# 中可能已存在的软链接。
cp -r $WORK_DIR/overlay/$BUNDLE_NAME/* \
  $OVERLAY_ROOTFS

echo "所有 FasterEdgeOS 工具已安装。"

cd $SRC_DIR