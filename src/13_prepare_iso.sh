#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

set -e

# 加载公共属性与函数。
. ./common.sh

init() {
  # 清理旧的 ISO 生成区域。
  echo "正在清理旧的 ISO 工作目录，可能需要一些时间。"
  rm -rf $ISOIMAGE

  echo "正在准备新的 ISO 工作目录。"
  mkdir -p $ISOIMAGE
}

prepare_fasteredgeos_bios() {
  # 这是存放传统 BIOS 启动产物的目录。
  mkdir -p $ISOIMAGE/boot

  # 复制内核。
  cp $KERNEL_INSTALLED/kernel \
    $ISOIMAGE/boot/kernel.xz

  # 复制根文件系统。
  cp $WORK_DIR/rootfs.cpio.xz \
    $ISOIMAGE/boot/rootfs.xz
}

prepare_overlay() {
  # 复制 overlay 内容（如果存在）。
  if [ -d $ISOIMAGE_OVERLAY \
    -a ! "`ls $ISOIMAGE_OVERLAY`" = "" ] ; then

    echo "ISO 镜像将包含 overlay 结构。"
    cp -r $ISOIMAGE_OVERLAY/* $ISOIMAGE
  else
    echo "ISO 镜像将不包含 overlay 结构。"
  fi
}

prepare_boot_bios() {
  # 为传统 BIOS 添加 Syslinux 配置文件以及额外的 UEFI 启动脚本。
  #
  # 现有的 UEFI 启动脚本并不保证可以在所有 UEFI 系统上启动。此脚本仅在
  # 系统进入 UEFI Shell（级别 1 及以上）时被调用。请参考 UEFI Shell
  # 规范 2.2 第 3.1 节。根据系统配置的不同，即使支持 UEFI 也未必会进入
  # UEFI Shell。在这种情况下 FasterEdgeOS 将无法启动，并显示某种 UEFI
  # 错误信息。
  cp -r $SRC_DIR/minimal_boot/bios/* \
    $ISOIMAGE

  # 查找 Syslinux 构建目录。
  WORK_SYSLINUX_DIR=`ls -d $WORK_DIR/syslinux/syslinux-*`

  # 复制预编译文件 'isolinux.bin' 和 'ldlinux.c32'，它们用于传统 BIOS
  # 启动过程中的 Syslinux。
  mkdir -p $ISOIMAGE/boot/syslinux
  cp $WORK_SYSLINUX_DIR/bios/core/isolinux.bin \
    $ISOIMAGE/boot/syslinux
  cp $WORK_SYSLINUX_DIR/bios/com32/elflink/ldlinux/ldlinux.c32 \
    $ISOIMAGE/boot/syslinux
}

# 依据 UEFI 规范 2.7 第 13.3.1.x 与 13.3.2.x 节生成 'El Torito' 启动镜像。
prepare_boot_uefi() {
  # 根据 Busybox 可执行文件判断构建架构。
  BUSYBOX_ARCH=$(file $ROOTFS/bin/busybox | cut -d' ' -f3)

  # 确定合适的 UEFI 配置。默认镜像文件名参见 UEFI 规范 2.7 第 3.5.1.1 节。
  # 注意 x86_64 的 UEFI 镜像文件名中确实包含小写字母 'x'。
  if [ "$BUSYBOX_ARCH" = "64-bit" ] ; then
    FEOS_CONF=x86_64
    LOADER=$WORK_DIR/systemd-boot/systemd-boot*/uefi_root/EFI/BOOT/BOOTx64.EFI
  else
    FEOS_CONF=x86
    LOADER=$WORK_DIR/systemd-boot/systemd-boot*/uefi_root/EFI/BOOT/BOOTIA32.EFI
  fi

  # 计算内核字节数。
  kernel_size=`du -b $KERNEL_INSTALLED/kernel | awk '{print \$1}'`

  # 计算 initramfs 字节数。
  rootfs_size=`du -b $WORK_DIR/rootfs.cpio.xz | awk '{print \$1}'`

  loader_size=`du -b $LOADER | awk '{print \$1}'`

  # EFI 启动镜像比内核大 64KB。
  image_size=$((kernel_size + rootfs_size + loader_size + 65536))

  echo "正在创建 UEFI 启动镜像文件 '$WORK_DIR/uefi.img'。"
  rm -f $WORK_DIR/uefi.img
  truncate -s $image_size $WORK_DIR/uefi.img

  echo "正在把磁盘镜像文件挂载到 loop 设备。"
  LOOP_DEVICE_HDD=$(losetup -f)
  losetup $LOOP_DEVICE_HDD $WORK_DIR/uefi.img

  echo "正在以 FAT 文件系统格式化磁盘镜像。"
  mkfs.vfat $LOOP_DEVICE_HDD

  echo "正在准备 'uefi' 工作目录。"
  rm -rf $WORK_DIR/uefi
  mkdir -p $WORK_DIR/uefi
  mount $WORK_DIR/uefi.img $WORK_DIR/uefi

#  # 添加 UEFI 启动配置文件。
#  cp -r $SRC_DIR/minimal_boot/uefi/* \
#    $ISOIMAGE

  echo "正在准备内核与 rootfs。"
  mkdir -p $WORK_DIR/uefi/fasteredgeos/$FEOS_CONF
  cp $KERNEL_INSTALLED/kernel \
    $WORK_DIR/uefi/fasteredgeos/$FEOS_CONF/kernel.xz
  cp $WORK_DIR/rootfs.cpio.xz \
    $WORK_DIR/uefi/fasteredgeos/$FEOS_CONF/rootfs.xz

  echo "正在准备 'systemd-boot' UEFI 启动加载器。"
  mkdir -p $WORK_DIR/uefi/EFI/BOOT
  cp $LOADER \
    $WORK_DIR/uefi/EFI/BOOT

  echo "正在准备 'systemd-boot' 配置。"
  mkdir -p $WORK_DIR/uefi/loader/entries
  cp $SRC_DIR/minimal_boot/uefi/loader/loader.conf \
    $WORK_DIR/uefi/loader
  cp $SRC_DIR/minimal_boot/uefi/loader/entries/fasteredgeos-${FEOS_CONF}.conf \
    $WORK_DIR/uefi/loader/entries

  echo "正在设置默认 UEFI 启动项。"
  sed -i "s|default.*|default fasteredgeos-$FEOS_CONF|" $WORK_DIR/uefi/loader/loader.conf

  echo "正在卸载 UEFI 启动镜像文件。"
  sync
  umount $WORK_DIR/uefi
  sync
  sleep 1

  # 目录现在已清空（原为 loop 设备的挂载点）。
  rm -rf $WORK_DIR/uefi

  # 确保 UEFI 启动镜像可读。
  chmod ugo+r $WORK_DIR/uefi.img

  mkdir -p $ISOIMAGE/boot
  cp $WORK_DIR/uefi.img \
    $ISOIMAGE/boot
}

check_root() {
  if [ ! "$(id -u)" = "0" ] ; then
    cat << CEOF

  为 UEFI 系统生成 ISO 镜像需要 root 权限，但当前没有相应权限。
  请以 root 权限重新运行此脚本，以生成 UEFI 兼容的 ISO 结构。

CEOF
    exit 1
  fi
}

echo "*** 准备 ISO 开始 ***"

# 从 '.config' 读取 'FIRMWARE_TYPE' 属性。
FIRMWARE_TYPE=`read_property FIRMWARE_TYPE`
echo "固件类型为 '$FIRMWARE_TYPE'。"

case $FIRMWARE_TYPE in
  bios)
    init
    prepare_boot_bios
    prepare_fasteredgeos_bios
    prepare_overlay
    ;;

  uefi)
    check_root
    init
    prepare_boot_uefi
    prepare_overlay
    ;;

  both)
    check_root
    init
    prepare_boot_uefi
    prepare_boot_bios
    prepare_fasteredgeos_bios
    prepare_overlay
    ;;

  *)
    echo "无法识别的固件类型 '$FIRMWARE_TYPE'，构建中止。"
    exit 1
    ;;
esac

echo "*** 准备 ISO 结束 ***"
