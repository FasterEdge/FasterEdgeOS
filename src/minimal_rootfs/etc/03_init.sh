#!/bin/sh

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
read -t 5 -n1 -s key

if [ "$key" = "" ] ; then
  # 使用基于 '/etc/inittab' 配置的默认初始化逻辑。
  echo -e "正在以 \\e[32m/sbin/init\\e[0m 作为 PID 1 执行。"
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
read -n1 -s