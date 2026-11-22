#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

set -e

# 加载公共属性与函数。
. ./common.sh

# ---------------------------------------------------------------------------
# 可复现 ISO。
#
# xorriso 的 mkisofs 模拟层原生遵循 reproducible-builds.org 规范:
#   只要环境变量 SOURCE_DATE_EPOCH 是一个十进制秒数, 它就会作为默认值驱动
#     * --modification-date  (ISO 卷的创建/修改时间戳, 以及 El Torito 引导
#                             目录时间——这两项默认都会写"当前时间")
#     * --gpt_disk_guid=modification-date  (isohybrid 的 GPT disk GUID 默认
#                             是随机的, 这里改为由该时间戳派生, 从而固定)
#     * --set_all_file_dates=set_to_mtime  (所有文件/目录的 atime/ctime 取各自
#                             mtime, 不再另写构建时钟)
#   (见 xorrisofs(1) 的 ENVIRONMENT VARIABLES 一节)
#
# SOURCE_DATE_EPOCH 由 common.sh 统一计算并 export, 因此本脚本只需保证它在
# 环境中存在即可, 不需要重复传时间戳参数。
#
# 额外显式固定的项:
#   * 输出 ISO 的 sha256 —— 让"两次构建是否一致"在日志里直接可读, 便于论文
#     与 CI 记录。
# ---------------------------------------------------------------------------

echo "ISO 可复现时间戳: SOURCE_DATE_EPOCH=$SOURCE_DATE_EPOCH"

# 为 UEFI 系统生成 ISO 镜像。
uefi() {
  cd "$ISOIMAGE"

  # 生成 'hybrid' 类型 ISO，可直接用于 UEFI 启动或写入 U 盘,
  # 例如 'dd if=fasteredgeos.iso of=/dev/sdb'。
  xorriso -as mkisofs \
    -isohybrid-mbr "$WORK_DIR"/syslinux/syslinux-*/bios/mbr/isohdpfx.bin \
    -c boot/boot.cat \
    -e boot/uefi.img \
      -no-emul-boot \
      -isohybrid-gpt-basdat \
    -o "$SRC_DIR/fasteredgeos.iso" \
    "$ISOIMAGE"
}

# 为 BIOS 系统生成 ISO 镜像。
bios() {
  cd "$ISOIMAGE"

  # 生成 'hybrid' 类型 ISO，可直接用于 BIOS 启动或写入 U 盘,
  # 例如 'dd if=fasteredgeos.iso of=/dev/sdb'。
  xorriso -as mkisofs \
    -isohybrid-mbr "$WORK_DIR"/syslinux/syslinux-*/bios/mbr/isohdpfx.bin \
    -c boot/syslinux/boot.cat \
    -b boot/syslinux/isolinux.bin \
      -no-emul-boot \
      -boot-load-size 4 \
      -boot-info-table \
    -o "$SRC_DIR/fasteredgeos.iso" \
    "$ISOIMAGE"
}

# 同时生成 BIOS 与 UEFI 兼容的 ISO 镜像。
both() {
  cd "$ISOIMAGE"

  xorriso -as mkisofs \
    -isohybrid-mbr "$WORK_DIR"/syslinux/syslinux-*/bios/mbr/isohdpfx.bin \
    -c boot/syslinux/boot.cat \
    -b boot/syslinux/isolinux.bin \
      -no-emul-boot \
      -boot-load-size 4 \
      -boot-info-table \
    -eltorito-alt-boot \
    -e boot/uefi.img \
      -no-emul-boot \
      -isohybrid-gpt-basdat \
    -o "$SRC_DIR/fasteredgeos.iso" \
    "$ISOIMAGE"
}

echo "*** 生成 ISO 开始 ***"

if [ ! -d "$ISOIMAGE" ] ; then
  echo "找不到 ISO 工作目录，无法继续。"
  exit 1
fi

# 从 '.config' 读取 'FIRMWARE_TYPE' 属性。
FIRMWARE_TYPE=$(read_property FIRMWARE_TYPE)
echo "固件类型为 '$FIRMWARE_TYPE'。"

case "$FIRMWARE_TYPE" in
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

cd "$SRC_DIR"

# 输出产物的 sha256, 便于论文/CI 中直接比对两次构建是否字节一致。
echo "正在计算 ISO 的 SHA-256 摘要..."
sha256sum "$SRC_DIR/fasteredgeos.iso"

cat << CEOF

  #################################################################
  #                                                               #
  #    已生成 ISO 镜像文件 'fasteredgeos.iso'。                    #
  #                                                               #
  #################################################################

CEOF

echo "*** 生成 ISO 结束 ***"
