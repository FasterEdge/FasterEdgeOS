#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# 编译 FasterEdge2Api 静态二进制(免 CGO): 可运行入口 cmd/fasteredge2api。
# go.mod 依赖已发布的 github.com/FasterEdge/FasterEdge v1.0.20261022 与
# golang.org/x/sys(经 goproxy 解析; go.sum 已随源码提交)。
# 需要宿主机 Go 1.25+ 工具链: CI 使用 actions/setup-go 提供; 本地构建请先安装 Go。
set -e

. ../../common.sh

SRC=$OVERLAY_SOURCE_DIR/FasterEdge2Api
OUT_DIR=$OVERLAY_WORK_DIR/$BUNDLE_NAME

[ -d "$SRC" ] || { echo "错误: 缺少 FasterEdge2Api 源码(先执行 01_get.sh)"; exit 1; }
command -v go >/dev/null 2>&1 || { echo "错误: 需要宿主机 Go 工具链(Go 1.25+)"; exit 1; }

rm -rf "${OVERLAY_WORK_DIR:?}/$BUNDLE_NAME"
mkdir -p "$OUT_DIR"

echo "正在编译 FasterEdge2Api (cmd/fasteredge2api, CGO_ENABLED=0)..."
cd "$SRC"
CGO_ENABLED=0 GOPROXY=${GOPROXY:-https://goproxy.cn,direct} GOFLAGS=-mod=mod \
  go build -trimpath -ldflags="-s -w" -o "$OUT_DIR/fasteredge2api" ./cmd/fasteredge2api
cd $SRC_DIR

[ -x "$OUT_DIR/fasteredge2api" ] || { echo "错误: 编译产物缺失"; exit 1; }
echo "FasterEdge2Api 编译完成: $OUT_DIR/fasteredge2api"
