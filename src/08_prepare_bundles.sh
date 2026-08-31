#!/bin/sh

set -e

# 在当前脚本中加载公共属性和函数。
. ./common.sh

echo "*** 准备 OVERLAY 开始 ***"

echo "正在准备 overlay 工作区。"
rm -rf $WORK_DIR/overlay*

# 从 '.config' 读取 'OVERLAY_BUNDLES' 属性
OVERLAY_BUNDLES=`read_property OVERLAY_BUNDLES`

if [ ! "$OVERLAY_BUNDLES" = "" ] ; then
  echo "正在生成额外的 overlay 软件包，这可能需要一些时间。"
  cd $SRC_DIR/minimal_overlay
  ./overlay_build.sh
  cd $SRC_DIR
else
  echo "已跳过附加 overlay 软件包的生成。"
fi

echo "*** 准备 OVERLAY 结束 ***"
