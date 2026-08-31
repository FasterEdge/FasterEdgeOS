#!/bin/sh

# 不带参数运行此脚本时，将用 QEMU 启动生成的 ISO 镜像。
# 传入 '-hdd' 或 '-h' 时，会挂载虚拟硬盘 'hdd.img'。
# 注意该虚拟硬盘需要提前创建，可使用脚本 'generate_hdd.sh' 生成硬盘镜像。
# 有了硬盘镜像后，可将其作为 overlay 设备使用并持久化所有修改。
# 更多关于 overlay 支持的信息请参考 '.config' 文件。
#
# 若出现内核崩溃并提示 "No working init found"，可尝试把内存从 128M 增加到 256M。
#
# 按 'Ctrl + A' 再按 'C' 可在客户机系统控制台与 QEMU monitor 之间切换。
# 按 'Ctrl + A' 再按 'X' 可终止 QEMU 实例。
#
# 在 nographic 模式下，qemu 会禁用虚拟控制台。要获得系统控制台，
# 可以使用虚拟串口。在此模式下，虚拟串口默认重定向到宿主机 stdio。
# 在内核命令行传入 "console=ttySn"（PC）或 "console=ttyAMAn"（ARM），
# 其中 n 为 0、1、...。

cat << CEOF

  'Ctrl + A' 再按 'C' 可在客户机系统控制台与 QEMU monitor 之间切换。
  'Ctrl + A' 再按 'X' 可终止 QEMU 实例。

  在启动菜单中输入 'console'，即可在 QEMU 控制台模式下运行 FasterEdgeOS。

CEOF

if [ "`uname -m`" = "x86_64" ] ; then
  ARCH="x86_64"
else
  ARCH="i386"
fi

cmd="qemu-system-$ARCH -m 128M -cdrom fasteredgeos.iso -boot d -nographic"

if [ "$1" = "-hdd" -o "$1" = "-h" ] ; then
  echo "正在启动 QEMU（挂载 ISO 镜像与硬盘）。"
  echo 'console' | $cmd -hda hdd.img
else
  echo "正在启动 QEMU（挂载 ISO 镜像）。"
  echo 'console' | $cmd
fi
