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
#rm -rf "${WORK_DIR:?}"/logo
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

# 解析唯一内核源码目录 (glob 先展开再判定, 避免字面量/多匹配误判)。
set -- $WORK_DIR/kernel/linux-*
if [ "$#" -ne 1 ] || [ ! -f "$1/.config" ] ; then
  echo "内核配置不存在。无法继续。"
  exit 1
fi
KSRC_DIR="$1"

if [ ! -f $WORK_DIR/kernel/kernel_installed/kernel ] ; then
  echo "内核镜像不存在。无法继续。"
  exit 1
fi

# 按 KERNEL_ARCH 参数化(与 02_build_kernel.sh 的架构表保持一致):
#   x86 -> bzImage / arch/x86/boot/bzImage
#   arm64 -> Image / arch/arm64/boot/Image
#   arm -> zImage / arch/arm/boot/zImage
# logo 更换只影响内核镜像内容, 不改变目标架构。
KERNEL_ARCH=`read_property KERNEL_ARCH`
[ "$KERNEL_ARCH" = "" ] && KERNEL_ARCH=x86
# 交叉编译前缀与 02_build_kernel.sh 一致: 仅非空时传给 make。
CROSS_COMPILE=`read_property CROSS_COMPILE`
LOGO_MAKE_ARGS="ARCH=$KERNEL_ARCH"
if [ ! "$CROSS_COMPILE" = "" ] ; then
  LOGO_MAKE_ARGS="$LOGO_MAKE_ARGS CROSS_COMPILE=$CROSS_COMPILE"
fi
case "$KERNEL_ARCH" in
  x86)   LOGO_IMAGE_TARGET=bzImage ; LOGO_IMAGE_PATH=arch/x86/boot/bzImage ;;
  arm64) LOGO_IMAGE_TARGET=Image  ; LOGO_IMAGE_PATH=arch/arm64/boot/Image ;;
  arm)   LOGO_IMAGE_TARGET=zImage ; LOGO_IMAGE_PATH=arch/arm/boot/zImage ;;
  *) echo "错误: 不支持的 KERNEL_ARCH='$KERNEL_ARCH'。" >&2 ; exit 1 ;;
esac

rm -f "$KSRC_DIR/drivers/video/logo/logo_linux_clut224.ppm"
cp $SRC_DIR/mll_logo_ascii_224.ppm "$KSRC_DIR/drivers/video/logo/logo_linux_clut224.ppm"
touch "$KSRC_DIR/drivers/video/logo/logo_linux_clut224.ppm"

cd "$KSRC_DIR"

make $LOGO_MAKE_ARGS $LOGO_IMAGE_TARGET -j 4

cp "$LOGO_IMAGE_PATH" $WORK_DIR/kernel/kernel_installed/kernel

cd $SRC_DIR