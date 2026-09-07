#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# fasteredgeos bundle: 系统初始工具 —— DontCrack-Manager 多进程根管理器。
# 单体的 DontCrack 一次只能管理一个进程; DontCrack-Manager 同时监管多个
# DontCrack 实例(各自管理一个子进程), 作为无进程管理器环境(本 Live 系统)
# 的系统多进程根管理器。开机经 /etc/autorun/20_dontcrack-manager.sh 第一个启动。

set -e

. ../../common.sh

./01_get.sh
./02_build.sh
./03_install.sh

cd $SRC_DIR