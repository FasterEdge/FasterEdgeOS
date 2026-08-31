#!/bin/sh

set -e

mkdir -p minimal_overlay/rootfs/etc/autorun
cat << CEOF > minimal_overlay/rootfs/etc/autorun/99_autoshutdown.sh
#!/bin/sh

# 此脚本自动关闭系统。
sleep 10 && poweroff &

echo "  FasterEdgeOS 将在 10 秒后关闭。"

CEOF
chmod +x minimal_overlay/rootfs/etc/autorun/99_autoshutdown.sh

cat <<CEOF > minimal_boot/bios/boot/syslinux/syslinux.cfg
SERIAL 0
DEFAULT operatingsystem
LABEL operatingsystem
    LINUX /boot/kernel.xz
    APPEND console=tty0 console=ttyS0
    INITRD /boot/rootfs.xz

CEOF

./repackage.sh
qemu-system-x86_64 -m 256M -cdrom fasteredgeos.iso -boot d -localtime -nographic &

sleep 5
if [ "`ps -ef | grep -i [q]emu-system`" = "" ] ; then
  echo "`date` | !!! 失败 !!! FasterEdgeOS 未在 QEMU 中运行。"
  exit 1
else
  echo "`date` | FasterEdgeOS 正在 QEMU 中运行，等待自动关机。"
fi

RETRY=10
while [ ! "$RETRY" = "0" ] ; do
  echo "`date` | 倒计时：$RETRY"
  if [ "`ps -ef | grep -i [q]emu-system`" = "" ] ; then
    break
  fi
  sleep 30
  RETRY=$(($RETRY - 1))
done

if [ "`ps -ef | grep -i [q]emu-system`" = "" ] ; then
  echo "`date` | FasterEdgeOS 未在 QEMU 中运行。"
else
  echo "`date` | !!! 失败 !!! FasterEdgeOS 仍在 QEMU 中运行。"
  exit 1
fi

cat << CEOF

  ##################################################################
  #                                                                #
  #  QEMU 测试通过。请手动清理受影响的 FasterEdgeOS 产物。         #
  #                                                                #
  ##################################################################

CEOF

echo "`date` | *** FasterEdgeOS QEMU 测试 - 结束 ***"

set +e
