#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# 编译 FasterEdge 演示二进制(免 CGO): examples/demo 是独立 module,
# 其 go.mod 以 replace 指回仓根(../..), 依赖 beevik/ntp、x/net、x/sys
# (均已发布, 经 goproxy 解析; go.sum 已随源码提交)。
# 需要宿主机 Go 1.25+ 工具链: CI 使用 actions/setup-go 提供; 本地构建请先安装 Go。
set -e

. ../../common.sh

SRC=$OVERLAY_SOURCE_DIR/FasterEdge
DEMO_DIR=$SRC/examples/demo
OUT_DIR=$OVERLAY_WORK_DIR/$BUNDLE_NAME

[ -d "$DEMO_DIR" ] || { echo "错误: 缺少 FasterEdge 源码(先执行 01_get.sh)"; exit 1; }
command -v go >/dev/null 2>&1 || { echo "错误: 需要宿主机 Go 工具链(Go 1.25+)"; exit 1; }

rm -rf "${OVERLAY_WORK_DIR:?}/$BUNDLE_NAME"
mkdir -p "$OUT_DIR"

echo "正在编译 FasterEdge demo (examples/demo, CGO_ENABLED=0)..."
cd "$DEMO_DIR"
CGO_ENABLED=0 GOPROXY=${GOPROXY:-https://goproxy.cn,direct} GOFLAGS=-mod=mod \
  go build -trimpath -ldflags="-s -w" -o "$OUT_DIR/fasteredge-demo" .
cd $SRC_DIR

[ -x "$OUT_DIR/fasteredge-demo" ] || { echo "错误: 编译产物缺失"; exit 1; }
echo "FasterEdge demo 编译完成: $OUT_DIR/fasteredge-demo"
