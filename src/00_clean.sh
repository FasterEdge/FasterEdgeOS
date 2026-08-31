#!/bin/sh

set -e

# 在当前脚本中加载公共属性和函数。
. ./common.sh

echo "*** 清理开始 ***"

echo "正在清理主工作区，这可能需要一些时间。"
rm -rf $WORK_DIR
mkdir $WORK_DIR
mkdir -p $SOURCE_DIR

echo "*** 清理结束 ***"
