#!/bin/sh

set -e

. ../../common.sh

cd $WORK_DIR/overlay/$BUNDLE_NAME

# 切换到 Python 源码目录（由 ls 找到），例如 'Python-3.7.0'。
cd $(ls -d Python-*)

if [ -f Makefile ] ; then
  echo "正在准备 '$BUNDLE_NAME' 的工作目录，这可能需要一些时间。"
  make -j $NUM_JOBS clean
else
  echo "已跳过 '$BUNDLE_NAME' 的清理阶段。"
fi

rm -rf $DEST_DIR

echo "正在配置 '$BUNDLE_NAME'。"
CFLAGS="$CFLAGS" ./configure \
  --prefix=/usr CXX="/usr/bin/g++" --enable-optimizations

echo "正在编译 '$BUNDLE_NAME'。"
make -j $NUM_JOBS

echo "正在安装 '$BUNDLE_NAME'。"
make -j $NUM_JOBS install DESTDIR=$DEST_DIR

#echo "正在生成 '$BUNDLE_NAME'。"

#echo "正在精简 '$BUNDLE_NAME' 的体积。"
#set +e
#strip -g $DEST_DIR/usr/bin/*
#set -e

cd $SRC_DIR
