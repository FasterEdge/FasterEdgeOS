#!/bin/sh

set -e

. ../../common.sh

# 取消注释以下内容即可重新生成 FasterEdgeOS 启动 logo。文件 MLL_LOGO
# 必须提前存在，并且提供该文件是您的责任。如果某些命令缺失，
# 您还需要自行配置开发环境。logo 的最大允许尺寸为 80x80。
# 一些有用的资源：
#
# http://www.armadeus.org/wiki/index.php?title=Linux_Boot_Logo
# http://www.articleworld.org/index.php/How_to_change_the_Linux_penguin_boot_logo
#
#MLL_LOGO=/mnt/hgfs/vm_shared/tux3.ppm
#rm -rf $WORK_DIR/logo
#mkdir -p $WORK_DIR/logo
#cp $MLL_LOGO $WORK_DIR/logo/mll_logo.ppm
#ppmquant 224 $WORK_DIR/logo/mll_logo.ppm > $WORK_DIR/logo/mll_logo_224.ppm
#pnmnoraw $WORK_DIR/logo/mll_logo_224.ppm > $SRC_DIR/mll_logo_ascii_224.ppm

# 从 '.config' 中读取 'USE_BOOT_LOGO' 属性
USE_BOOT_LOGO=`read_property USE_BOOT_LOGO`

if [ ! "$USE_BOOT_LOGO" = "true" ] ; then
  echo "启动 logo 已被禁用。无需生成 FasterEdgeOS 启动 logo。"
  exit 0
fi

if [ ! -f $WORK_DIR/kernel/linux-*/.config ] ; then
  echo "内核配置不存在。无法继续。"
  exit 1
fi

if [ ! -f $WORK_DIR/kernel/kernel_installed/kernel ] ; then
  echo "内核镜像不存在。无法继续。"
  exit 1
fi

rm -f `ls -d $WORK_DIR/kernel/linux-*`/drivers/video/logo/logo_linux_clut224.ppm
cp $SRC_DIR/mll_logo_ascii_224.ppm `ls -d $WORK_DIR/kernel/linux-*`/drivers/video/logo/logo_linux_clut224.ppm
touch `ls -d $WORK_DIR/kernel/linux-*`/drivers/video/logo/logo_linux_clut224.ppm

cd `ls -d $WORK_DIR/kernel/linux-*`

make bzImage -j 4

cp arch/x86/boot/bzImage $WORK_DIR/kernel/kernel_installed/kernel

cd $SRC_DIR