#!/bin/sh

# 不带参数运行此脚本时，将用 QEMU 启动生成的 ISO 镜像。
# 传入 '-hdd' 或 '-h' 时，会挂载虚拟硬盘 'hdd.img'。
# 注意该虚拟硬盘需要提前创建，可使用脚本 'generate_hdd.sh' 生成硬盘镜像。
# 有了硬盘镜像后，可将其作为 overlay 设备使用并持久化所有修改。
# 更多关于 overlay 支持的信息请参考 '.config' 文件。
#
# 若出现内核崩溃并提示 "No working init found"，可尝试把内存从 128M 增加到 256M。
#
# 用法:
#   ./qemu-uefi.sh              # 按 KERNEL_ARCH 选择 QEMU 目标(默认 x86_64)
#   ./qemu-uefi.sh -hdd         # 同时挂载虚拟硬盘 'hdd.img'
#
# 架构选择: 优先读 '.config' 的 KERNEL_ARCH(x86 -> x86_64/i386,
# arm64 -> aarch64), 与构建时的目标保持一致。

SRC_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
cd "$SRC_DIR" || exit 1

# 本地文件 'OVMF.fd' 的位置，用作主固件。可在此下载：
#
#   https://sourceforge.net/projects/edk2/files/OVMF/
#
OVMF_LOCATION=~/Downloads/OVMF.fd

KERNEL_ARCH=$(grep -i '^KERNEL_ARCH=' .config | cut -f2- -d'=' | xargs)
[ "$KERNEL_ARCH" = "" ] && KERNEL_ARCH=x86

case "$KERNEL_ARCH" in
  x86)
    if [ "$(uname -m)" = "x86_64" ] ; then
      ARCH="x86_64"
    else
      ARCH="i386"
    fi
    ;;
  arm64)
    ARCH="aarch64"
    ;;
  arm)
    ARCH="arm"
    ;;
  *)
    echo "无法识别的 KERNEL_ARCH='$KERNEL_ARCH'（可选 x86 / arm64 / arm）。" >&2
    exit 1
    ;;
esac

cmd="qemu-system-$ARCH -pflash $OVMF_LOCATION -m 128M -cdrom fasteredgeos.iso -boot d -vga std"

if [ "$1" = "-hdd" ] || [ "$1" = "-h" ] ; then
  echo "正在启动 QEMU（$ARCH，挂载 ISO 镜像与硬盘）。"
  $cmd -hda hdd.img
else
  echo "正在启动 QEMU（$ARCH，挂载 ISO 镜像）。"
  $cmd
fi
