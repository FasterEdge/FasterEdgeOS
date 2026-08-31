#!/bin/sh

set -e

# 在当前脚本中加载公共属性和函数。
. ./common.sh

echo "*** 构建 BUSYBOX 开始 ***"

# 移除旧的 Busybox 安装目录。
echo "正在移除旧的 Busybox 构建产物，这可能需要一些时间。"
rm -rf $BUSYBOX_INSTALLED

# 切换到 ls 找到的源码目录，例如 'busybox-1.24.2'。
cd `ls -d $WORK_DIR/busybox/busybox-*`

# 移除之前生成的构建产物。
echo "正在准备 Busybox 工作区，这可能需要一些时间。"
make distclean -j $NUM_JOBS

# 从 '.config' 读取 'USE_PREDEFINED_BUSYBOX_CONFIG' 属性
USE_PREDEFINED_BUSYBOX_CONFIG=`read_property USE_PREDEFINED_BUSYBOX_CONFIG`

if [ "$USE_PREDEFINED_BUSYBOX_CONFIG" = "true" -a ! -f $SRC_DIR/minimal_config/busybox.config ] ; then
  echo "配置文件 $SRC_DIR/minimal_config/busybox.config 不存在。"
  USE_PREDEFINED_BUSYBOX_CONFIG="false"
fi

if [ "$USE_PREDEFINED_BUSYBOX_CONFIG" = "true" ] ; then
  # 使用 Busybox 的预定义配置文件。
  echo "正在使用配置文件 $SRC_DIR/minimal_config/busybox.config"
  cp -f $SRC_DIR/minimal_config/busybox.config .config
else
  # 创建默认配置文件。
  echo "正在生成默认 Busybox 配置。"
  make defconfig -j $NUM_JOBS
fi

# 现在让 Busybox 使用 sysroot 区域。
sed -i "s|.*CONFIG_SYSROOT.*|CONFIG_SYSROOT=\"$SYSROOT\"|" .config

# 配置编译器标志，并显式将 Busybox 与 sysroot 中的 GLIBC 链接。
sed -i "s|.*CONFIG_EXTRA_CFLAGS.*|CONFIG_EXTRA_CFLAGS=\"$CFLAGS -L$SYSROOT/lib\"|" .config

# 以“并行任务数 = 处理器数量”的优化方式编译 busybox。
echo "正在构建 Busybox。"
make \
  busybox -j $NUM_JOBS

# 为 busybox 创建符号链接，使用 'busybox.links' 文件来完成。
echo "正在生成基于 Busybox 的 initramfs 区域。"
make \
  CONFIG_PREFIX="$BUSYBOX_INSTALLED" \
  install -j $NUM_JOBS

cd $SRC_DIR

echo "*** 构建 BUSYBOX 结束 ***"
