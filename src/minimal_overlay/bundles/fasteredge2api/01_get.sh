#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# 获取 FasterEdge2Api 源码, 固定到已由 CI 端到端验证的 commit(防供应链漂移)。
# 离线/内网构建: 设环境变量 FE2A_SOURCE_DIR 指向本地 FasterEdge2Api 仓(须含 go.mod)。
set -e

. ../../common.sh

# 固定的 FasterEdge2Api commit: 随上游修复演进手动更新(当前为 v1.0.20261022 线,
# 对齐 go.mod 的 go 1.26.0 与 Docker golang:1.26 构建镜像)。
FE2A_COMMIT=${FE2A_COMMIT:-461d997532f2aeabfed4b8ad9400cf58af87ec9f}
DEST_DIR=$OVERLAY_SOURCE_DIR/FasterEdge2Api
REPO_URL=https://github.com/FasterEdge/FasterEdge2Api.git

mkdir -p $OVERLAY_SOURCE_DIR

if [ -n "${FE2A_SOURCE_DIR:-}" ] && [ -f "$FE2A_SOURCE_DIR/go.mod" ] ; then
  echo "使用本地 FasterEdge2Api 源码: $FE2A_SOURCE_DIR"
  LOCAL_COMMIT=$(git -C "$FE2A_SOURCE_DIR" rev-parse HEAD 2>/dev/null || echo unknown)
  if [ "$LOCAL_COMMIT" != "$FE2A_COMMIT" ] && git -C "$FE2A_SOURCE_DIR" cat-file -e "$FE2A_COMMIT" 2>/dev/null ; then
    git -C "$FE2A_SOURCE_DIR" checkout -q --detach "$FE2A_COMMIT"
    LOCAL_COMMIT=$FE2A_COMMIT
  fi
  [ "$LOCAL_COMMIT" = "$FE2A_COMMIT" ] || echo "警告: 本地源码 commit($LOCAL_COMMIT) 与固定 commit($FE2A_COMMIT) 不同, 按本地 HEAD 构建"
  rm -rf "${DEST_DIR:?}"
  cp -r "$FE2A_SOURCE_DIR" "$DEST_DIR"
  rm -rf "$DEST_DIR/.git"
  echo "FasterEdge2Api 本地源码就绪"
else
  if [ -d "$DEST_DIR/.git" ] ; then
    echo "FasterEdge2Api 源码已存在, 更新到固定 commit。"
    cd "$DEST_DIR"
    git fetch --depth 1 origin "$FE2A_COMMIT" || git fetch origin "$FE2A_COMMIT"
    git checkout -q --detach "$FE2A_COMMIT"
    cd $SRC_DIR
  else
    echo "正在克隆 FasterEdge2Api ($FE2A_COMMIT)。"
    git clone "$REPO_URL" "$DEST_DIR"
    cd "$DEST_DIR"
    git checkout -q --detach "$FE2A_COMMIT"
    cd $SRC_DIR
  fi
  [ -f "$DEST_DIR/go.mod" ] || { echo "错误: 源码目录缺少 go.mod"; exit 1; }
  [ "$(git -C "$DEST_DIR" rev-parse HEAD)" = "$FE2A_COMMIT" ] || { echo "错误: commit 校验失败"; exit 1; }
  echo "FasterEdge2Api 源码就绪: $FE2A_COMMIT"
fi

# cmd/fasteredge2api 是可运行入口; go.mod 依赖已发布的 github.com/FasterEdge/FasterEdge
# v1.0.20261022(经 goproxy 解析, go.sum 已随源码提交), 无 replace。
[ -f "$DEST_DIR/cmd/fasteredge2api/main.go" ] || { echo "错误: 源码缺少 cmd/fasteredge2api/main.go"; exit 1; }
