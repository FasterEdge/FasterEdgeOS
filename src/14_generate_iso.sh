#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

set -e

# 加载公共属性与函数。
. ./common.sh

# 为 UEFI 系统生成 ISO 镜像。
uefi() {
  cd $ISOIMAGE

  # 生成 'hybrid' 类型 ISO，可直接用于 UEFI 启动或写入 U 盘,
  # 例如 'dd if=fasteredgeos.iso of=/dev/sdb'。
  xorriso -as mkisofs \
    -isohybrid-mbr $WORK_DIR/syslinux/syslinux-*/bios/mbr/isohdpfx.bin \
    -c boot/boot.cat \
    -e boot/uefi.img \
      -no-emul-boot \
      -isohybrid-gpt-basdat \
    -o $SRC_DIR/fasteredgeos.iso \
    $ISOIMAGE
}

# 为 BIOS 系统生成 ISO 镜像。
bios() {
  cd $ISOIMAGE

  # 生成 'hybrid' 类型 ISO，可直接用于 BIOS 启动或写入 U 盘,
  # 例如 'dd if=fasteredgeos.iso of=/dev/sdb'。
  xorriso -as mkisofs \
    -isohybrid-mbr $WORK_DIR/syslinux/syslinux-*/bios/mbr/isohdpfx.bin \
    -c boot/syslinux/boot.cat \
    -b boot/syslinux/isolinux.bin \
      -no-emul-boot \
      -boot-load-size 4 \
      -boot-info-table \
    -o $SRC_DIR/fasteredgeos.iso \
    $ISOIMAGE
}

# 同时生成 BIOS 与 UEFI 兼容的 ISO 镜像。
both() {
  cd $ISOIMAGE

  xorriso -as mkisofs \
    -isohybrid-mbr $WORK_DIR/syslinux/syslinux-*/bios/mbr/isohdpfx.bin \
    -c boot/syslinux/boot.cat \
    -b boot/syslinux/isolinux.bin \
      -no-emul-boot \
      -boot-load-size 4 \
      -boot-info-table \
    -eltorito-alt-boot \
    -e boot/uefi.img \
      -no-emul-boot \
      -isohybrid-gpt-basdat \
    -o $SRC_DIR/fasteredgeos.iso \
  $ISOIMAGE
}

echo "*** 生成 ISO 开始 ***"

if [ ! -d $ISOIMAGE ] ; then
  echo "找不到 ISO 工作目录，无法继续。"
  exit 1
fi

# 从 '.config' 读取 'FIRMWARE_TYPE' 属性。
FIRMWARE_TYPE=`read_property FIRMWARE_TYPE`
echo "固件类型为 '$FIRMWARE_TYPE'。"

case $FIRMWARE_TYPE in
  bios)
    bios
    ;;

  uefi)
    uefi
    ;;

  both)
    both
    ;;

  *)
    echo "无法识别的固件类型 '$FIRMWARE_TYPE'，构建中止。"
    exit 1
    ;;
esac

cd $SRC_DIR

cat << CEOF

  #################################################################
  #                                                               #
  #    已生成 ISO 镜像文件 'fasteredgeos.iso'。                    #
  #                                                               #
  #################################################################

CEOF

echo "*** 生成 ISO 结束 ***"
