#!/bin/sh

set -e

. ../../common.sh

mkdir -p $DEST_DIR/etc
# 不预设空密码 root: 密码字段置 '!' 锁定(fail-closed), 与 dropbear bundle 一致,
# 避免镜像内含空密码账户被无密码本地/远程登录(旧值为 'root::' 空密码)。
echo 'root:!:0:0:Superuser:/:/bin/sh' > $DEST_DIR/etc/passwd

cd $SRC_DIR
