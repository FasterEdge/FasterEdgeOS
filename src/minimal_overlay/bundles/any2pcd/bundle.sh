#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# any2pcd bundle: 系统初始工具 —— 文本/二进制点云转 PCD 转换器。
# 纯标准库实现(零第三方依赖): 支持 bin/text/csv/pcd 输入, 输出标准 PCD v0.7;
# 自动探测输入格式, 可选 binary 输出/字段映射/严格模式/批量转换。

set -e

. ../../common.sh

./01_get.sh
./02_build.sh
./03_install.sh

cd $SRC_DIR
