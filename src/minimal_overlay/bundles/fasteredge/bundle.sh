#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# fasteredge bundle: 系统初始工具 —— FasterEdge 节点运行时。
# FasterEdge 是 FasterEdge 软件组合的核心框架库(package FasterEdge); 其最小
# 可运行演示位于 examples/demo(独立 module, 一次性运行后 exit 0)。本 bundle
# 编译该演示为 /usr/bin/fasteredge-demo, 并附带常驻包装器 /usr/bin/fasteredge-node
# (周期性拉起一次性 demo), 使根管理器 DontCrack-Manager 可像监管其它常驻服务
# 一样监管 FasterEdge 节点运行时。服务 stanza 由 03_install.sh 幂等追加。

set -e

. ../../common.sh

./01_get.sh
./02_build.sh
./03_install.sh

cd $SRC_DIR
