#!/bin/sh

set -e

. ../../common.sh


# 解析唯一内核源码目录 (glob 需先展开再判定, 避免 [ -d glob ] 对多匹配/字面量误判)。
set -- $WORK_DIR/kernel/linux-*
if [ "$#" -ne 1 ] || [ ! -d "$1" ] ; then
  echo "内核源码目录缺失，无法继续。"
  exit 1
fi
KSRC_DIR="$1"
echo "内核源码目录存在。"

if [ ! -d "${KERNEL_INSTALLED:?}" ] ; then
  echo "内核尚未构建，无法继续。"
  exit 1
else
  echo "内核已构建。"
fi

rm -rf "${DEST_DIR:?}"

cd "$KSRC_DIR"

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
