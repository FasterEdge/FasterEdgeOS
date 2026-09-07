#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# 该脚本在系统启动一分钟后自动关机。
sleep 30 && poweroff &

cat << CEOF
[1m  FasterEdgeOS 将在 30 秒后关机。[0m
CEOF

