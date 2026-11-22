#!/bin/sh
# 运行环境: 本脚本在 FasterEdgeOS 目标机上由 BusyBox ash(/bin/sh) 执行,
# 不是 POSIX 参考 shell。下列 read 用法依赖 BusyBox ash 的扩展:
#   read -t N      带超时读键(用于"等待 5 秒或任意按键")
#   read -n1 -s    无回显读单字符
# 它们是刻意保留的运行期行为(去掉会改变启动交互体验); shellcheck 按 POSIX
# sh 判定 SC3045 / SC3061 在此不适用, 故只在保留的那几行加带理由的 disable,
# 不在文件头整体关闭规则。彩色输出统一用 POSIX 的 printf '%b\n', 不依赖 echo -e。
# shellcheck shell=sh

# 系统初始化序列：
#
# /init
#  |
#  +--(1) /etc/01_prepare.sh
#  |
#  +--(2) /etc/02_overlay.sh
#          |
#          +-- /etc/03_init.sh （本文件）
#               |
#               +-- /sbin/init
#                    |
#                    +--(1) /etc/04_bootscript.sh
#                    |       |
#                    |       +-- /etc/autorun/* （所有脚本）
#                    |
#                    +--(2) /bin/sh （Alt + F1，主控制台）
#                    |
#                    +--(2) /bin/sh （Alt + F2）
#                    |
#                    +--(2) /bin/sh （Alt + F3）
#                    |
#                    +--(2) /bin/sh （Alt + F4）

# 如果你有持久化 overlay 支持，那么你可以编辑此文件，替换系统的默认
# 初始化。例如，你可以使用：
#
# exec setsid cttyhach sh
#
# 这会在 initramfs 区域内给你一个 PID 1 shell。由于这是一个 PID 1
# shell，你仍然可以通过执行以下命令来调用原来的初始化逻辑：
#
# exec /sbin/init

# 在屏幕上打印第一条消息。
cat /etc/msg/03_init_01.txt

# 等待 5 秒或直到按下任意键盘键。
# BusyBox ash 支持 -t / -n1 / -s; 目标机固定 BusyBox, 保留交互行为。
# shellcheck disable=SC3045,SC3061
read -t 5 -n1 -s key

if [ "$key" = "" ] ; then
  # 使用基于 '/etc/inittab' 配置的默认初始化逻辑。
  printf '%b\n' "正在以 \\e[32m/sbin/init\\e[0m 作为 PID 1 执行。"
  exec /sbin/init
else
  # 在屏幕上打印第二条消息。
  cat /etc/msg/03_init_02.txt

  if [ "$PID1_SHELL" = "true" ] ; then
    # 已设置 PID1_SHELL 标志，表示我们有控制终端。
    unset PID1_SHELL
    exec sh
  else
    # 作为 PID 1 的交互式 shell，带有控制 tty。
    exec setsid cttyhack sh
  fi
fi

echo "(/etc/03_init.sh) - 存在严重错误。"

# 等待直到按下任意键。
# BusyBox ash 支持 -t / -n1 / -s; 目标机固定 BusyBox, 保留交互行为。
# shellcheck disable=SC3045,SC3061
read -n1 -s