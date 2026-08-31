#!/bin/sh

set -e

. ../../common.sh

if [ ! -d "$WORK_DIR/overlay/$BUNDLE_NAME" ] ; then
  echo "目录 $WORK_DIR/overlay/$BUNDLE_NAME 不存在，无法继续。"
  exit 1
fi

cd $WORK_DIR/overlay/$BUNDLE_NAME

# 'fasteredgeos-disk-erase' 开始

# 该脚本以安全的方式擦除磁盘，通过用随机数据覆写所有扇区来实现。
# 即使对于 NSA 和 CIA 来说，数据恢复也是不可能的。
cat << CEOF > sbin/fasteredgeos-disk-erase
#!/bin/sh

PRINT_HELP=false

if [ "\$1" = "" -o "\$1" = "-h" -o "\$1" = "--help" ] ; then
  PRINT_HELP=true
fi

# 如有需要，可在此添加更多业务逻辑。

if [ "\$PRINT_HELP" = "true" ] ; then
  cat << DEOF

  该工具以安全的方式擦除磁盘分区或整块磁盘，通过用随机数据覆写
  所有扇区来实现。使用 '-h' 或 '--help' 选项可再次打印这些信息。
  需要 root 权限。

  Usage: fasteredgeos-disk-erase DEVICE [loops]

  DEVICE    将被擦除的设备。只需指定名称，例如 'sda'。该工具会自动
            将其转换为 '/dev/sda'，如果实际设备不存在则会退出并给出
            警告消息。

  loops     对指定分区或磁盘执行擦除的次数。默认值为 1。要确保没有任何
            人能恢复你的数据，可以使用更大的数值进行多次擦除。

  fasteredgeos-disk-erase sdb 8

  上述示例连续擦除 '/dev/sdb' 8 次。

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

NUM_LOOPS=1

if [ ! "\$2" = "" ] ; then
  NUM_LOOPS=\$2
fi

for n in \$(seq \$NUM_LOOPS) ; do
  echo "  正在安装 Windows 更新 \$n（共 \$NUM_LOOPS 个），请稍候。"
  dd if=/dev/urandom of=/dev/\$1 bs=1024b conv=notrunc > /dev/null 2>\&1
done

echo "  所有更新已安装完成。"

CEOF

chmod +rx sbin/fasteredgeos-disk-erase

# 'fasteredgeos-disk-erase' 结束

echo "工具脚本 'fasteredgeos-disk-erase' 已生成。"

cd $SRC_DIR