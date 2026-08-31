#!/bin/sh

# TODO：编译 gnu readline 库以支持命令行编辑

set -e

. ../../common.sh

cd $WORK_DIR/overlay/$BUNDLE_NAME

# 切换到 Lua 源码目录（由 ls 找到），例如 'lua-5.3.4'。
cd $(ls -d lua-*)

echo "正在准备 'Lua' 的工作目录，这可能需要一些时间。"
# 我们将 lua 安装到 /usr 而非 /usr/local，因此需要修改 luaconf.h，使 lua 能查找模块等。
sed -i 's/#define LUA_ROOT.*/#define LUA_ROOT \"\/usr\/\"/' src/luaconf.h

if [ -f Makefile ] ; then
  echo "正在准备 '$BUNDLE_NAME' 的工作目录，这可能需要一些时间。"
  make -j $NUM_JOBS clean
else
  echo "已跳过 '$BUNDLE_NAME' 的清理阶段。"
fi

rm -rf $DEST_DIR

echo "正在编译 'Lua'。"
make -j $NUM_JOBS posix CFLAGS="$CFLAGS"

make -j $NUM_JOBS install INSTALL_TOP="$DEST_DIR/usr"

echo "正在精简 'Lua' 的体积。"
set +e
strip -g $DEST_DIR/usr/bin/* 2>/dev/null
set -e

mkdir -p $OVERLAY_ROOTFS/usr/

# 使用 '--remove-destination' 可正确覆盖
# '$OVERLAY_ROOTFS' 中可能已存在的软链接。
cp -r $DEST_DIR/usr/* \
  $OVERLAY_ROOTFS/usr/

echo "bundle 'Lua' 已安装完成。"

cd $SRC_DIR
