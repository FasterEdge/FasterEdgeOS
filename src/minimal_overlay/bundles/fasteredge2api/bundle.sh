#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# fasteredge2api bundle: 系统初始工具 —— FasterEdge 集群拓扑与管理操作 HTTP API。
# fasteredge2api 作为常驻 HTTP 服务运行(FasterEdge 软件组合的 API 网关),
# 由根管理器 DontCrack-Manager 监管; 健康探针直连其 /healthz 端点。
# 服务 stanza 由 03_install.sh 幂等追加。

set -e

. ../../common.sh

./01_get.sh
./02_build.sh
./03_install.sh

cd $SRC_DIR
