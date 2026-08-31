#!/bin/sh

# 一个简单的脚本，用 dd 命令把生成的 ISO 镜像写入 U 盘。

set -e

. ./common.sh

ISO_NAME=$SRC_DIR/fasteredgeos.iso

if ! [ -e $ISO_NAME ]; then
	echo "请先构建 ISO 镜像再运行此脚本！"
	exit 1

elif [ "$#" -ne 1 ]; then
	echo "用法：$0 [设备名]（例如 $0 /dev/sda）"
	exit 1
else
	echo "警告：设备 $1 上的所有数据都将被清除"
	echo "请确认已获知风险"
	sudo dd if=$ISO_NAME of=$1 bs=4M && sync
fi
