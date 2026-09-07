#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# 编译 DontCrack-Manager 静态二进制(免 CGO)。
# 需要宿主机 Go 1.25+ 工具链: CI 使用 actions/setup-go 提供; 本地构建请先安装 Go。
set -e

. ../../common.sh

SRC_DIR_DCM=$OVERLAY_SOURCE_DIR/DontCrack-Manager
OUT_DIR=$OVERLAY_WORK_DIR/$BUNDLE_NAME

[ -d "$SRC_DIR_DCM" ] || { echo "错误: 缺少 DontCrack-Manager 源码(先执行 01_get.sh)"; exit 1; }
command -v go >/dev/null 2>&1 || { echo "错误: 需要宿主机 Go 工具链"; exit 1; }

rm -rf "${OVERLAY_WORK_DIR:?}/$BUNDLE_NAME"
mkdir -p "$OUT_DIR"

echo "正在编译 DontCrack-Manager (CGO_ENABLED=0)..."
cd "$SRC_DIR_DCM"
CGO_ENABLED=0 GOPROXY=${GOPROXY:-https://goproxy.cn,direct} \
  go build -trimpath -ldflags="-s -w" \
  -o "$OUT_DIR/dontcrack-manager" ./cmd/dontcrack-manager
cd $SRC_DIR

[ -x "$OUT_DIR/dontcrack-manager" ] || { echo "错误: 编译产物缺失"; exit 1; }
echo "DontCrack-Manager 编译完成: $OUT_DIR/dontcrack-manager"