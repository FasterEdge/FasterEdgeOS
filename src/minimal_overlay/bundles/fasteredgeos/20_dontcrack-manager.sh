#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# 系统初始工具: DontCrack-Manager 作为系统多进程根管理器, 开机第一个启动。
# 启动链: BusyBox init -> /etc/04_bootscript.sh -> /etc/autorun/* (按文件名序)
#   -> 本脚本 -> /usr/bin/dontcrack-manager(监管多个 DontCrack 实例)

CFG=/etc/fasteredgeos/manager.yaml
BIN=/usr/bin/dontcrack-manager
LOG=/var/log/fasteredgeos/manager.log

if [ ! -x "$BIN" ] ; then
  echo "dontcrack-manager: 二进制缺失, 跳过启动" >&2
  exit 0
fi
if [ ! -r "$CFG" ] ; then
  echo "dontcrack-manager: 配置 $CFG 不存在, 跳过启动" >&2
  exit 0
fi

echo "启动 DontCrack-Manager (系统多进程根管理器)..."

# setsid: 脱离当前会话, 使根管理器独立于启动脚本运行; & 后台化。
setsid "$BIN" -config "$CFG" >> "$LOG" 2>&1 &
mkdir -p /var/run
echo $! > /var/run/dontcrack-manager.pid

# 查询根管理器状态:
#   wget -q -O - http://127.0.0.1:11884/healthz
#   wget -q -O - http://127.0.0.1:11884/status
# 配置了 password 时: --header="Authorization: Bearer <password>"