#!/bin/sh

# 不带参数运行此脚本时，将用 QEMU 启动生成的 ISO 镜像。
# 传入 '-hdd' 或 '-h' 时，会挂载虚拟硬盘 'hdd.img'。
# 注意该虚拟硬盘需要提前创建，可使用脚本 'generate_hdd.sh' 生成硬盘镜像。
# 有了硬盘镜像后，可将其作为 overlay 设备使用并持久化所有修改。
# 更多关于 overlay 支持的信息请参考 '.config' 文件。
#
# 若出现内核崩溃并提示 "No working init found"，可尝试把内存从 128M 增加到 256M。

# 本地文件 'OVMF.fd' 的位置，用作主固件。可在此下载：
#
#   https://sourceforge.net/projects/edk2/files/OVMF/
#
OVMF_LOCATION=~/Downloads/OVMF.fd

if [ "`uname -m`" = "x86_64" ] ; then
  ARCH="x86_64"
else
  ARCH="i386"
fi

cmd="qemu-system-$ARCH -pflash $OVMF_LOCATION -m 128M -cdrom fasteredgeos.iso -boot d -vga std"

if [ "$1" = "-hdd" -o "$1" = "-h" ] ; then
  echo "正在启动 QEMU（挂载 ISO 镜像与硬盘）。"
  $cmd -hda hdd.img
else
  echo "正在启动 QEMU（挂载 ISO 镜像）。"
  $cmd
fi
