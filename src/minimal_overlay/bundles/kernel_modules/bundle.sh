#!/bin/sh

set -e

. ../../common.sh


if [ ! -d $WORK_DIR/kernel/linux-* ] ; then
  echo "内核源码目录缺失，无法继续。"
  exit 1
else
  echo "内核源码目录存在。"
fi

if [ ! -d $KERNEL_INSTALLED ] ; then
  echo "内核尚未构建，无法继续。"
  exit 1
else
  echo "内核已构建。"
fi

rm -rf $DEST_DIR

cd $WORK_DIR/kernel/linux-*

echo "正在编译内核模块。"
make_target modules

echo "正在安装内核模块。"
make_target \
  INSTALL_MOD_PATH=$DEST_DIR \
  modules_install

echo "正在移除不必要的链接。"
cd $DEST_DIR/lib/modules/*
unlink build
unlink source

echo "正在精简所有生成的内核模块的体积。"
reduce_size $DEST_DIR/lib/modules

mkdir -p $DEST_DIR/etc/autorun
cp $SRC_DIR/10_modules.sh $DEST_DIR/etc/autorun

install_to_overlay

cd $SRC_DIR
