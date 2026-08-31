#!/bin/sh

set -e

# 在当前脚本中加载公共属性和函数。
. ./common.sh

echo "*** 构建内核开始 ***"

# 切换到 ls 找到的内核源码目录，例如 'linux-4.4.6'。
cd `ls -d $WORK_DIR/kernel/linux-*`

# 清理内核源码，包括配置文件。
echo "正在准备内核工作区。"
make mrproper -j $NUM_JOBS

# 从 '.config' 读取 'USE_PREDEFINED_KERNEL_CONFIG' 属性
USE_PREDEFINED_KERNEL_CONFIG=`read_property USE_PREDEFINED_KERNEL_CONFIG`
BUILD_KERNEL_MODULES=`read_property BUILD_KERNEL_MODULES`

if [ "$USE_PREDEFINED_KERNEL_CONFIG" = "true" -a ! -f $SRC_DIR/minimal_config/kernel.config ] ; then
  echo "配置文件 '$SRC_DIR/minimal_config/kernel.config' 不存在。"
  USE_PREDEFINED_KERNEL_CONFIG=false
fi

if [ "$USE_PREDEFINED_KERNEL_CONFIG" = "true" ] ; then
  # 使用内核的预定义配置文件。
  echo "正在使用配置文件 '$SRC_DIR/minimal_config/kernel.config'。"
  cp -f $SRC_DIR/minimal_config/kernel.config .config
else
  # 为内核创建默认配置文件。
  make defconfig -j $NUM_JOBS
  echo "已生成默认内核配置。"

  # 设置 FasterEdgeOS 默认主机名。
  sed -i "s/.*CONFIG_DEFAULT_HOSTNAME.*/CONFIG_DEFAULT_HOSTNAME=\"fasteredgeos\"/" .config

  # OVERLAYFS - 开始 - 大多数功能已被禁用（你并不真正需要它们）

  # 启用 overlay 支持，例如合并只读（ro）和可写（rw）目录（3.18+）。
  sed -i "s/.*CONFIG_OVERLAY_FS.*/CONFIG_OVERLAY_FS=y/" .config

  # 默认开启 redirect dir 功能（4.10+）。
  echo "# CONFIG_OVERLAY_FS_REDIRECT_DIR is not set" >> .config

  # 默认开启 inodes 索引功能（4.13+）。
  echo "# CONFIG_OVERLAY_FS_INDEX is not set" >> .config

  # 即使重定向已关闭，也始终跟随重定向（4.15+）。
  echo "CONFIG_OVERLAY_FS_REDIRECT_ALWAYS_FOLLOW=y" >> .config

  # 默认开启 NFS 导出功能（4.16+）。
  echo "# CONFIG_OVERLAY_FS_NFS_EXPORT is not set" >> .config

  # 自动启用 inode 编号映射（4.17+）。
  echo "# CONFIG_OVERLAY_FS_XINO_AUTO is not set" >> .config

  # 默认开启仅元数据复制（metadata only copy up）功能（4.19+）。
  echo "# CONFIG_OVERLAY_FS_METACOPY is not set" >> .config

  # OVERLAYFS - 结束

  # 步骤 1 - 禁用所有已启用的内核压缩选项（应该只有一个）。
  sed -i "s/.*\\(CONFIG_KERNEL_.*\\)=y/\\#\\ \\1 is not set/" .config

  # 步骤 2 - 启用 'xz' 压缩选项。
  sed -i "s/.*CONFIG_KERNEL_XZ.*/CONFIG_KERNEL_XZ=y/" .config

  # 启用 VESA 帧缓冲以支持图形显示。
  sed -i "s/.*CONFIG_FB_VESA.*/CONFIG_FB_VESA=y/" .config

  # 从 '.config' 读取 'USE_BOOT_LOGO' 属性
  USE_BOOT_LOGO=`read_property USE_BOOT_LOGO`

  if [ "$USE_BOOT_LOGO" = "true" ] ; then
    sed -i "s/.*CONFIG_LOGO_LINUX_CLUT224.*/CONFIG_LOGO_LINUX_CLUT224=y/" .config
    echo "已启用开机徽标。"
  else
    sed -i "s/.*CONFIG_LOGO_LINUX_CLUT224.*/\\# CONFIG_LOGO_LINUX_CLUT224 is not set/" .config
    echo "已禁用开机徽标。"
  fi

  # 禁用内核中的调试符号，=> 更小的内核二进制文件。
  sed -i "s/^CONFIG_DEBUG_KERNEL.*/\\# CONFIG_DEBUG_KERNEL is not set/" .config

  # 启用 EFI stub
  sed -i "s/.*CONFIG_EFI_STUB.*/CONFIG_EFI_STUB=y/" .config

  # 请求固件在重启后清除 RAM 中的内容（4.14+）。
  echo "CONFIG_RESET_ATTACK_MITIGATION=y" >> .config

  # 禁用 Apple Properties（对 Mac 有用，但一般情况下没有用处）
  echo "CONFIG_APPLE_PROPERTIES=n" >> .config

  # 检查是否在构建 64 位内核。
  if [ "`grep "CONFIG_X86_64=y" .config`" = "CONFIG_X86_64=y" ] ; then
    # 构建 64 位内核时启用混合（mixed）EFI 模式。
    echo "CONFIG_EFI_MIXED=y" >> .config
  fi
fi

# 以“并行任务数 = 处理器数量”的优化方式编译内核。
# 关于不同内核的详细说明：
# http://unix.stackexchange.com/questions/5518/what-is-the-difference-between-the-following-kernel-makefile-terms-vmlinux-vmlinux
echo "正在构建内核。"
make \
  CFLAGS="$CFLAGS" \
  bzImage -j $NUM_JOBS

if [ "$BUILD_KERNEL_MODULES" = "true" ] ; then
  echo "正在构建内核模块。"
  make \
    CFLAGS="$CFLAGS" \
    modules -j $NUM_JOBS
fi

# 准备内核安装区域。
echo "正在移除旧的内核构建产物，这可能需要一些时间。"
rm -rf $KERNEL_INSTALLED
mkdir $KERNEL_INSTALLED

echo "正在安装内核。"
# 安装内核文件。
cp arch/x86/boot/bzImage \
  $KERNEL_INSTALLED/kernel

if [ "$BUILD_KERNEL_MODULES" = "true" ] ; then
  make INSTALL_MOD_PATH=$KERNEL_INSTALLED \
    modules_install -j $NUM_JOBS
fi

# 安装内核头文件，稍后构建和配置 GNU C 库（glibc）时会用到。
echo "正在生成内核头文件。"
make \
  INSTALL_HDR_PATH=$KERNEL_INSTALLED \
  headers_install -j $NUM_JOBS

cd $SRC_DIR

echo "*** 构建内核结束 ***"
