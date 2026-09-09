#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# 编译 any2utf8 静态二进制(免 CGO)。
# 需要宿主机 Go 1.25+ 工具链: CI 使用 actions/setup-go 提供; 本地构建请先安装 Go。
# 依赖 golang.org/x/text(纯 Go 编码实现), go.sum 已随源码预填
# (哈希经 proxy.golang.org 实测); GOFLAGS=-mod=mod 允许有网络时自动补录。
set -e

. ../../common.sh

SRC=$OVERLAY_SOURCE_DIR/any2utf8
OUT_DIR=$OVERLAY_WORK_DIR/$BUNDLE_NAME

[ -d "$SRC" ] || { echo "错误: 缺少 any2utf8 源码(先执行 01_get.sh)"; exit 1; }
command -v go >/dev/null 2>&1 || { echo "错误: 需要宿主机 Go 工具链(Go 1.25+)"; exit 1; }

rm -rf "${OVERLAY_WORK_DIR:?}/$BUNDLE_NAME"
mkdir -p "$OUT_DIR"

echo "正在编译 any2utf8 (CGO_ENABLED=0)..."
cd "$SRC"
CGO_ENABLED=0 GOPROXY=${GOPROXY:-https://goproxy.cn,direct} GOFLAGS=-mod=mod \
  go build -trimpath -ldflags="-s -w" -o "$OUT_DIR/any2utf8" .
cd $SRC_DIR

[ -x "$OUT_DIR/any2utf8" ] || { echo "错误: 编译产物缺失"; exit 1; }
echo "any2utf8 编译完成: $OUT_DIR/any2utf8"
