#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# 获取 FasterEdge 源码, 固定到已由 CI 端到端验证的 commit(防供应链漂移)。
# 离线/内网构建: 设环境变量 FE_SOURCE_DIR 指向本地 FasterEdge 仓(须含 go.mod)。
set -e

. ../../common.sh

# 固定的 FasterEdge commit: 随上游修复演进手动更新(当前为 v1.0.20261022 线,
# 对齐 go.mod 的 go 1.26.0 与 Docker golang:1.26 构建镜像)。
FE_COMMIT=${FE_COMMIT:-212b9b9236be22a87c6c96aae67d4a9481c7eb7f}
DEST_DIR=$OVERLAY_SOURCE_DIR/FasterEdge
REPO_URL=https://github.com/FasterEdge/FasterEdge.git

mkdir -p $OVERLAY_SOURCE_DIR

if [ -n "${FE_SOURCE_DIR:-}" ] && [ -f "$FE_SOURCE_DIR/go.mod" ] ; then
  echo "使用本地 FasterEdge 源码: $FE_SOURCE_DIR"
  LOCAL_COMMIT=$(git -C "$FE_SOURCE_DIR" rev-parse HEAD 2>/dev/null || echo unknown)
  if [ "$LOCAL_COMMIT" != "$FE_COMMIT" ] && git -C "$FE_SOURCE_DIR" cat-file -e "$FE_COMMIT" 2>/dev/null ; then
    git -C "$FE_SOURCE_DIR" checkout -q --detach "$FE_COMMIT"
    LOCAL_COMMIT=$FE_COMMIT
  fi
  [ "$LOCAL_COMMIT" = "$FE_COMMIT" ] || echo "警告: 本地源码 commit($LOCAL_COMMIT) 与固定 commit($FE_COMMIT) 不同, 按本地 HEAD 构建"
  rm -rf "${DEST_DIR:?}"
  cp -r "$FE_SOURCE_DIR" "$DEST_DIR"
  rm -rf "$DEST_DIR/.git"
  echo "FasterEdge 本地源码就绪"
else
  if [ -d "$DEST_DIR/.git" ] ; then
    echo "FasterEdge 源码已存在, 更新到固定 commit。"
    cd "$DEST_DIR"
    git fetch --depth 1 origin "$FE_COMMIT" || git fetch origin "$FE_COMMIT"
    git checkout -q --detach "$FE_COMMIT"
    cd $SRC_DIR
  else
    echo "正在克隆 FasterEdge ($FE_COMMIT)。"
    git clone "$REPO_URL" "$DEST_DIR"
    cd "$DEST_DIR"
    git checkout -q --detach "$FE_COMMIT"
    cd $SRC_DIR
  fi
  [ -f "$DEST_DIR/go.mod" ] || { echo "错误: 源码目录缺少 go.mod"; exit 1; }
  [ "$(git -C "$DEST_DIR" rev-parse HEAD)" = "$FE_COMMIT" ] || { echo "错误: commit 校验失败"; exit 1; }
  echo "FasterEdge 源码就绪: $FE_COMMIT"
fi

# examples/demo 是独立 module(自带 go.mod/go.sum, replace 指回 ../..); 编译前
# 确认其存在, 缺失说明上游结构调整, 提前 fail-closed。
[ -f "$DEST_DIR/examples/demo/go.mod" ] || { echo "错误: 源码缺少 examples/demo/go.mod"; exit 1; }
