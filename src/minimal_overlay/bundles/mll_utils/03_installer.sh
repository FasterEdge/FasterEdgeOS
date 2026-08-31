#!/bin/sh

set -e

. ../../common.sh

if [ ! -d "$WORK_DIR/overlay/$BUNDLE_NAME" ] ; then
  echo "目录 $WORK_DIR/overlay/$BUNDLE_NAME 不存在，无法继续。"
  exit 1
fi

cd $WORK_DIR/overlay/$BUNDLE_NAME

# 'fasteredgeos-install' 开始

# 该脚本将 FasterEdgeOS 安装到 Ext2 分区。
cat << CEOF > sbin/fasteredgeos-install
#!/bin/sh

CURRENT_DIR=\$(pwd)
PRINT_HELP=false

if [ "\$1" = "" -o "\$1" = "-h" -o "\$1" = "--help" ] ; then
  PRINT_HELP=true
fi

# 如有需要，可在此添加更多业务逻辑。

if [ "\$PRINT_HELP" = "true" ] ; then
  cat << DEOF

  这是 FasterEdgeOS 安装程序。需要 root 权限。

  Usage: fasteredgeos-install DEVICE

  DEVICE    FasterEdgeOS 将被安装到的设备。只需指定名称，例如 'sda'。
            安装程序会自动将其转换为 '/dev/sda'，如果设备不存在，
            则会退出并给出警告消息。

  fasteredgeos-install sdb

  上述示例将 FasterEdgeOS 安装到 '/dev/sdb'。

DEOF

  exit 0
fi

if [ ! "\$(id -u)" = "0" ] ; then
  echo "你需要 root 权限。使用 '-h' 或 '--help' 获取更多信息。"
  exit 1
fi

if [ ! -e /dev/\$1 ] ; then
  echo "设备 '/dev/\$1' 不存在。使用 '-h' 或 '--help' 获取更多信息。"
  exit 1
fi

cat << DEOF

  FasterEdgeOS 将被安装到设备 '/dev/\$1'。该设备将被格式化为 Ext2，
  之前的所有数据都将丢失。按 'Ctrl + C' 退出，或按任意其他键继续。

DEOF

read -n1 -s

umount /dev/\$1 2>/dev/null
sleep 1
mkfs.ext2 /dev/\$1
mkdir /tmp/mnt/inst
mount /dev/\$1 /tmp/mnt/inst
sleep 1
cd /tmp/mnt/device
cp -r kernel.xz rootfs.xz syslinux.cfg src minimal /tmp/mnt/inst 2>/dev/null
cat /opt/syslinux/mbr.bin > /dev/\$1
cd /tmp/mnt/inst
/sbin/extlinux --install .
cd ..
umount /dev/\$1
sleep 1
rmdir /tmp/mnt/inst

cat << DEOF

  安装现已完成。设备 '/dev/\$1' 现在应该可以引导了。请检查上面的输出
  是否有任何错误。你需要移除 ISO 镜像并重新启动系统。希望安装过程
  一切顺利！！！:)

DEOF

cd \$CURRENT_DIR

CEOF

chmod +rx sbin/fasteredgeos-install

# 'fasteredgeos-install' 结束

if [ ! -d "$WORK_DIR/syslinux" ] ; then
echo "安装程序依赖 Syslinux，但缺失该组件，无法继续。"
  exit 1
fi;

cd $WORK_DIR/syslinux
cd $(ls -d syslinux-*)

cp bios/extlinux/extlinux \
  $WORK_DIR/overlay/$BUNDLE_NAME/sbin
mkdir -p $WORK_DIR/overlay/$BUNDLE_NAME/opt/syslinux
cp bios/mbr/mbr.bin \
  $WORK_DIR/overlay/$BUNDLE_NAME/opt/syslinux

# 大妈妈补丁（hack）——需要找到合适的解决方案！！！
# syslinux 和 extlinux 都是 32 位可执行文件，需要 32 位库。
# 可能的解决方案 1 - 按需构建 32 位 GLIBC。
# 可能的解决方案 2 - 放弃 32 位 FasterEdgeOS，提供带 multi-arch 的 64 位版本。
mkdir -p $WORK_DIR/overlay/$BUNDLE_NAME/lib
mkdir -p $WORK_DIR/overlay/$BUNDLE_NAME/usr/lib
cp /lib/ld-linux.so.2 \
  $WORK_DIR/overlay/$BUNDLE_NAME/lib
cp /lib/i386-linux-gnu/libc.so.6 \
  $WORK_DIR/overlay/$BUNDLE_NAME/usr/lib
# 大妈妈补丁 - 结束。

echo "FasterEdgeOS 安装程序已生成。"

cd $SRC_DIR