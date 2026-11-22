#!/bin/sh
# 运行环境: 本脚本在 FasterEdgeOS 目标机上由 BusyBox ash(/bin/sh) 执行,
# 不是 POSIX 参考 shell。下列 read 用法依赖 BusyBox ash 的扩展:
#   read -t N      带超时读键(用于"等待 5 秒或任意按键")
#   read -n1 -s    无回显读单字符
# 它们是刻意保留的运行期行为(去掉会改变启动交互体验); shellcheck 按 POSIX
# sh 判定 SC3045 / SC3061 在此不适用, 故只在保留的那几行加带理由的 disable,
# 不在文件头整体关闭规则。彩色输出统一用 POSIX 的 printf '%b\n', 不依赖 echo -e。
# shellcheck shell=sh

# FasterEdgeOS 系统初始化序列：
#
# /init
#  |
#  +--(1) /etc/01_prepare.sh
#  |
#  +--(2) /etc/02_overlay.sh (本文件)
#          |
#          +-- /etc/03_init.sh
#               |
#               +-- /sbin/init
#                    |
#                    +--(1) /etc/04_bootscript.sh
#                    |       |
#                    |       +-- /etc/autorun/* (所有脚本)
#                    |
#                    +--(2) /bin/sh (Alt + F1, 主控制台)
#                    |
#                    +--(2) /bin/sh (Alt + F2)
#                    |
#                    +--(2) /bin/sh (Alt + F3)
#                    |
#                    +--(2) /bin/sh (Alt + F4)

# 在内存中创建新的挂载点。
mount -t tmpfs none /mnt

# 为所有关键文件系统创建目录。
mkdir /mnt/dev
mkdir /mnt/sys
mkdir /mnt/proc
mkdir /mnt/tmp
echo "已为核心文件系统创建目录。"

# 把根目录内容复制到新挂载点。
printf '%b\n' "正在把根文件系统复制到 \\e[94m/mnt\\e[0m。"
for dir in */ ; do
  case $dir in
    dev/)
      # 跳过
      ;;
    proc/)
      # 跳过
      ;;
    sys/)
      # 跳过
      ;;
    mnt/)
      # 跳过
      ;;
    tmp/)
      # 跳过
      ;;
    *)
      cp -a $dir /mnt
      ;;
  esac
done

DEFAULT_OVERLAY_DIR="/tmp/fasteredgeos/overlay"
DEFAULT_UPPER_DIR="/tmp/fasteredgeos/rootfs"
DEFAULT_WORK_DIR="/tmp/fasteredgeos/work"

echo "正在搜索包含 overlay 内容的设备。"
for DEVICE in /dev/* ; do
  DEV=$(echo "${DEVICE##*/}")
  SYSDEV=$(echo "/sys/class/block/$DEV")

  case $DEV in
    *loop*) continue ;;
  esac

  if [ ! -d "$SYSDEV" ] ; then
    continue
  fi

  mkdir -p /tmp/mnt/device
  DEVICE_MNT=/tmp/mnt/device

  OVERLAY_DIR=""
  OVERLAY_MNT=""
  UPPER_DIR=""
  WORK_DIR=""

  mount $DEVICE $DEVICE_MNT 2>/dev/null
  if [ -d "$DEVICE_MNT/fasteredgeos/rootfs" ] && [ -d "$DEVICE_MNT/fasteredgeos/work" ] ; then
    # 文件夹模式
    printf '%b\n' "  在设备 \\e[31m$DEVICE\\e[0m 上找到 \\e[94m/fasteredgeos\\e[0m 目录。"
    touch $DEVICE_MNT/fasteredgeos/rootfs/fasteredgeos.pid 2>/dev/null
    if [ -f $DEVICE_MNT/fasteredgeos/rootfs/fasteredgeos.pid ] ; then
      # 读/写模式
      printf '%b\n' "  设备 \\e[31m$DEVICE\\e[0m 以读/写模式挂载。"

      rm -f $DEVICE_MNT/fasteredgeos/rootfs/fasteredgeos.pid

      OVERLAY_DIR=$DEFAULT_OVERLAY_DIR
      OVERLAY_MNT=$DEVICE_MNT
      UPPER_DIR=$DEVICE_MNT/fasteredgeos/rootfs
      WORK_DIR=$DEVICE_MNT/fasteredgeos/work
    else
      # 只读模式
      printf '%b\n' "  设备 \\e[31m$DEVICE\\e[0m 以只读模式挂载。"

      OVERLAY_DIR=$DEVICE_MNT/fasteredgeos/rootfs
      OVERLAY_MNT=$DEVICE_MNT
      UPPER_DIR=$DEFAULT_UPPER_DIR
      WORK_DIR=$DEFAULT_WORK_DIR
    fi
  elif [ -f $DEVICE_MNT/fasteredgeos.img ] ; then
    # 镜像模式
    printf '%b\n' "  在设备 \\e[31m$DEVICE\\e[0m 上找到 \\e[94m/fasteredgeos.img\\e[0m 镜像。"

    mkdir -p /tmp/mnt/image
    IMAGE_MNT=/tmp/mnt/image

    LOOP_DEVICE=$(losetup -f)
    losetup $LOOP_DEVICE $DEVICE_MNT/fasteredgeos.img

    mount $LOOP_DEVICE $IMAGE_MNT
    if [ -d "$IMAGE_MNT/rootfs" ] && [ -d "$IMAGE_MNT/work" ] ; then
      touch $IMAGE_MNT/rootfs/fasteredgeos.pid 2>/dev/null
      if [ -f $IMAGE_MNT/rootfs/fasteredgeos.pid ] ; then
        # 读/写模式
        printf '%b\n' "  镜像 \\e[94m$DEVICE/fasteredgeos.img\\e[0m 以读/写模式挂载。"

        rm -f $IMAGE_MNT/rootfs/fasteredgeos.pid

        OVERLAY_DIR=$DEFAULT_OVERLAY_DIR
        OVERLAY_MNT=$IMAGE_MNT
        UPPER_DIR=$IMAGE_MNT/rootfs
        WORK_DIR=$IMAGE_MNT/work
      else
        # 只读模式
        printf '%b\n' "  镜像 \\e[94m$DEVICE/fasteredgeos.img\\e[0m 以只读模式挂载。"

        OVERLAY_DIR=$IMAGE_MNT/rootfs
        OVERLAY_MNT=$IMAGE_MNT
        UPPER_DIR=$DEFAULT_UPPER_DIR
        WORK_DIR=$DEFAULT_WORK_DIR
      fi
    else
      umount $IMAGE_MNT
      rm -rf "${IMAGE_MNT:?}"
    fi
  fi

  if [ "$OVERLAY_DIR" != "" ] && [ "$UPPER_DIR" != "" ] && [ "$WORK_DIR" != "" ] ; then
    mkdir -p $OVERLAY_DIR
    mkdir -p $UPPER_DIR
    mkdir -p $WORK_DIR

    mount -t overlay -o lowerdir=$OVERLAY_DIR:/mnt,upperdir=$UPPER_DIR,workdir=$WORK_DIR none /mnt 2>/dev/null

    OUT=$?
    if [ ! "$OUT" = "0" ] ; then
      printf '%b\n' "  \\e[31m挂载失败（可能是在 vfat 上）。\\e[0m"

      umount $OVERLAY_MNT 2>/dev/null
      rmdir $OVERLAY_MNT 2>/dev/null

      rmdir $DEFAULT_OVERLAY_DIR 2>/dev/null
      rmdir $DEFAULT_UPPER_DIR 2>/dev/null
      rmdir $DEFAULT_WORK_DIR 2>/dev/null
    else
      # 全部完成。
      printf '%b\n' "  设备 \\e[31m$DEVICE\\e[0m 上的 overlay 数据已合并。"
      break
    fi
  else
    printf '%b\n' "  设备 \\e[31m$DEVICE\\e[0m 没有合适的 overlay 结构。"
  fi

  umount $DEVICE_MNT 2>/dev/null
  rm -rf "${DEVICE_MNT:?}" 2>/dev/null
done

# 把关键文件系统移到新挂载点。
mount --move /dev /mnt/dev
mount --move /sys /mnt/sys
mount --move /proc /mnt/proc
mount --move /tmp /mnt/tmp
printf '%b\n' "挂载点 \\e[94m/dev\\e[0m、\\e[94m/sys\\e[0m、\\e[94m/tmp\\e[0m 和 \\e[94m/proc\\e[0m 已移动到 \\e[94m/mnt\\e[0m。"

# 新挂载点成为文件系统根目录。所有原始根目录会随命令执行自动删除。
# 随后调用 '/sbin/init'，它成为新的 PID 1 父进程。
echo "正在从 initramfs 根区域切换到 overlayfs 根区域。"
# switch_root 成功即不再返回; 失败时下面的报错与等待按键仍需执行。
# shellcheck disable=SC2093
exec switch_root /mnt /etc/03_init.sh

echo "(/etc/02_overlay.sh) - 存在严重错误。"

# 等待按键。
# BusyBox ash 支持 -t / -n1 / -s; 目标机固定 BusyBox, 保留交互行为。
# shellcheck disable=SC3045,SC3061
read -n1 -s
