#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# 获取 DontCrack-Manager 源码, 固定到已由 CI 端到端验证的 commit(防供应链漂移)。
# 离线/内网构建: 设环境变量 DCM_SOURCE_DIR 指向本地 DontCrack-Manager 仓。
set -e

. ../../common.sh

# 固定的 DontCrack-Manager commit: 全量 -flag=value 形式 + Setpgid 孤儿清理后的版本。
DCM_COMMIT=${DCM_COMMIT:-0921a75c0a468447ae37a6ec0a5661a2f4f86aac}
DEST_DIR=$OVERLAY_SOURCE_DIR/DontCrack-Manager
REPO_URL=https://github.com/FasterEdge/DontCrack-Manager.git

mkdir -p $OVERLAY_SOURCE_DIR

if [ -n "${DCM_SOURCE_DIR:-}" ] && [ -f "$DCM_SOURCE_DIR/go.mod" ] ; then
  echo "使用本地 DontCrack-Manager 源码: $DCM_SOURCE_DIR"
  LOCAL_COMMIT=$(git -C "$DCM_SOURCE_DIR" rev-parse HEAD 2>/dev/null || echo unknown)
  if [ "$LOCAL_COMMIT" != "$DCM_COMMIT" ] && git -C "$DCM_SOURCE_DIR" cat-file -e "$DCM_COMMIT" 2>/dev/null ; then
    git -C "$DCM_SOURCE_DIR" checkout -q --detach "$DCM_COMMIT"
    LOCAL_COMMIT=$DCM_COMMIT
  fi
  [ "$LOCAL_COMMIT" = "$DCM_COMMIT" ] || echo "警告: 本地源码 commit($LOCAL_COMMIT) 与固定 commit($DCM_COMMIT) 不同, 按本地 HEAD 构建"
  rm -rf "${DEST_DIR:?}"
  cp -r "$DCM_SOURCE_DIR" "$DEST_DIR"
  rm -rf "$DEST_DIR/.git"
  echo "DontCrack-Manager 本地源码就绪"
else
  if [ -d "$DEST_DIR/.git" ] ; then
    echo "DontCrack-Manager 源码已存在, 更新到固定 commit。"
    cd "$DEST_DIR"
    git fetch --depth 1 origin "$DCM_COMMIT" || git fetch origin "$DCM_COMMIT"
    git checkout -q --detach "$DCM_COMMIT"
    cd $SRC_DIR
  else
    echo "正在克隆 DontCrack-Manager ($DCM_COMMIT)。"
    git clone "$REPO_URL" "$DEST_DIR"
    cd "$DEST_DIR"
    git checkout -q --detach "$DCM_COMMIT"
    cd $SRC_DIR
  fi
  [ -f "$DEST_DIR/go.mod" ] || { echo "错误: 源码目录缺少 go.mod"; exit 1; }
  [ "$(git -C "$DEST_DIR" rev-parse HEAD)" = "$DCM_COMMIT" ] || { echo "错误: commit 校验失败"; exit 1; }
  echo "DontCrack-Manager 源码就绪: $DCM_COMMIT"
fi