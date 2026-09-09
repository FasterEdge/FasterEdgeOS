#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# 获取 DontCrack-Manager 源码, 固定到已由 CI 端到端验证的 commit(防供应链漂移)。
# 离线/内网构建: 设环境变量 DCM_SOURCE_DIR 指向本地 DontCrack-Manager 仓。
set -e

. ../../common.sh

# 固定的 DontCrack-Manager commit: 由 CI 端到端验证的版本(随上游修复演进手动更新)。
# 当前 e137ed2: 在 c9b7928 全部深检修复基础上, 补 log_path 默认值双仓契约
# (applyDefaults + buildArgs logPathVal 回落 ./logs/proc_manager/, 与 DontCrack
#  -log-path 默认一致, 避免空值覆盖致 file_log 落盘位置偏离; CI run success)。
DCM_COMMIT=${DCM_COMMIT:-e137ed29a5fc0f96d77b907915474a085bbcd4ec}
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

# --- DontCrack 单体(被 DCM 监管的实例, 每个管一个子进程) ---
# demo 服务由 DCM 在 $PATH 中查找 'dontcrack' 并拉起; 镜像必须提供该单体。
# (CI 实测缺单体时 demo 永远启动失败, healthz 恒 503, Test Docker 必然失败;
#  本地 WSL 完整链验证: 补上单体后 healthz=ok)
DC4M_COMMIT=${DC4M_COMMIT:-990ba43007ab24c03d2f1249caf9c13ba4ddc3dc}
SINGLE_SRC=$OVERLAY_SOURCE_DIR/DontCrack4ManyLinux
SINGLE_REPO=https://github.com/FasterEdge/DontCrack4ManyLinux.git

if [ -n "${DC4M_SOURCE_DIR:-}" ] && [ -f "$DC4M_SOURCE_DIR/go.mod" ] ; then
  echo "使用本地 DontCrack4ManyLinux 源码: $DC4M_SOURCE_DIR"
  LOCAL_COMMIT=$(git -C "$DC4M_SOURCE_DIR" rev-parse HEAD 2>/dev/null || echo unknown)
  if [ "$LOCAL_COMMIT" != "$DC4M_COMMIT" ] && git -C "$DC4M_SOURCE_DIR" cat-file -e "$DC4M_COMMIT" 2>/dev/null ; then
    git -C "$DC4M_SOURCE_DIR" checkout -q --detach "$DC4M_COMMIT"
    LOCAL_COMMIT=$DC4M_COMMIT
  fi
  [ "$LOCAL_COMMIT" = "$DC4M_COMMIT" ] || echo "警告: 本地单体源码 commit($LOCAL_COMMIT) 与固定 commit($DC4M_COMMIT) 不同, 按本地 HEAD 构建"
  rm -rf "${SINGLE_SRC:?}"
  cp -r "$DC4M_SOURCE_DIR" "$SINGLE_SRC"
  rm -rf "$SINGLE_SRC/.git"
  echo "DontCrack 单体本地源码就绪"
else
  if [ -d "$SINGLE_SRC/.git" ] ; then
    echo "DontCrack 单体源码已存在, 更新到固定 commit。"
    cd "$SINGLE_SRC"
    git fetch --depth 1 origin "$DC4M_COMMIT" || git fetch origin "$DC4M_COMMIT"
    git checkout -q --detach "$DC4M_COMMIT"
    cd $SRC_DIR
  else
    echo "正在克隆 DontCrack4ManyLinux ($DC4M_COMMIT)。"
    git clone "$SINGLE_REPO" "$SINGLE_SRC"
    cd "$SINGLE_SRC"
    git checkout -q --detach "$DC4M_COMMIT"
    cd $SRC_DIR
  fi
  [ -f "$SINGLE_SRC/go.mod" ] || { echo "错误: 单体源码目录缺少 go.mod"; exit 1; }
  [ "$(git -C "$SINGLE_SRC" rev-parse HEAD)" = "$DC4M_COMMIT" ] || { echo "错误: 单体 commit 校验失败"; exit 1; }
  echo "DontCrack 单体源码就绪: $DC4M_COMMIT"
fi