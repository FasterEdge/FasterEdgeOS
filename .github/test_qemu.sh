#!/bin/sh

# 本脚本由 GitHub 工作流调用。

set -e

cd ../src

echo "`date` | *** FasterEdgeOS QEMU 测试 - 开始 ***"

qemu-system-x86_64 -m 256M -cdrom fasteredgeos.iso -boot d -nographic &

sleep 5

if [ "`ps -ef | grep -i [q]emu-system-x86_64`" = "" ] ; then
  echo "`date` | !!! FAILURE !!! FasterEdgeOS 未在 QEMU 中运行。"
  exit 1
else
  echo "`date` | FasterEdgeOS 已在 QEMU 中运行，等待 120 秒自动关机。"
fi

sleep 120

if [ "`ps -ef | grep -i [q]emu-system-x86_64`" = "" ] ; then
  echo "`date` | FasterEdgeOS 已不在 QEMU 中运行。"
else
  echo "`date` | !!! FAILURE !!! FasterEdgeOS 仍在 QEMU 中运行。"
  ps -ef | grep -i [q]emu-system-x86_64
  exit 1
fi

echo "`date` | *** FasterEdgeOS QEMU 测试 - 结束 ***"

cat << CEOF

  #######################
  #                     #
  #  QEMU 测试通过。  #
  #                     #
  #######################

CEOF

set +e

