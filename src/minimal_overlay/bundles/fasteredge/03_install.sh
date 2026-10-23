#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# 安装 FasterEdge 节点运行时到 overlay rootfs:
#   /usr/bin/fasteredge-demo   FasterEdge 框架最小演示二进制(一次性, exit 0)
#   /usr/bin/fasteredge-node   常驻包装器(周期性拉起 demo, 供根管理器监管)
#   /etc/fasteredgeos/manager.yaml  幂等追加 fasteredge 服务 stanza
#   /usr/share/doc/fasteredge/README.md  使用说明
set -e

. ../../common.sh

BIN=$OVERLAY_WORK_DIR/$BUNDLE_NAME/fasteredge-demo
BUNDLE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CFG=$OVERLAY_ROOTFS/etc/fasteredgeos/manager.yaml

[ -x "$BIN" ] || { echo "错误: 缺少编译产物(先执行 02_build.sh)"; exit 1; }

mkdir -p $OVERLAY_ROOTFS/usr/bin
mkdir -p $OVERLAY_ROOTFS/etc/fasteredgeos
mkdir -p $OVERLAY_ROOTFS/usr/share/doc/fasteredge
mkdir -p $OVERLAY_ROOTFS/var/lib/fasteredgeos
mkdir -p $OVERLAY_ROOTFS/var/log/fasteredgeos

install -m755 "$BIN" $OVERLAY_ROOTFS/usr/bin/fasteredge-demo
install -m755 "$BUNDLE_DIR/fasteredge-node" $OVERLAY_ROOTFS/usr/bin/fasteredge-node
install -m644 "$BUNDLE_DIR/README.md" $OVERLAY_ROOTFS/usr/share/doc/fasteredge/README.md

# 将 fasteredge 服务 stanza 幂等追加到根管理器配置。
# 依赖 fasteredgeos bundle 先安装 manager.yaml(bundle_deps 保证顺序);
# 若缺失则创建最小合法配置兜底(fail-closed: 至少含 services: 头)。
if [ ! -f "$CFG" ] ; then
  echo "警告: $CFG 不存在, 创建最小根管理器配置(建议同时启用 fasteredgeos bundle)。"
  printf 'log_level: info\nlisten: 127.0.0.1:11884\npassword: ""\nshutdown_grace: 10s\nservices:\n' > "$CFG"
fi
if ! grep -Eq 'name:[[:space:]]*fasteredge[[:space:]]*$' "$CFG" ; then
  grep -Eq '^services:' "$CFG" || printf '\nservices:\n' >> "$CFG"
  cat >> "$CFG" << STANZA

  # FasterEdge 节点运行时(由 fasteredge bundle 追加): 常驻包装器周期性运行
  # 一次性 FasterEdge demo, 演示框架骨架(Atom/NetMap/OneKey/Time/ConfigFile/Sh)。
  - name: fasteredge
    path: /usr/bin/fasteredge-node
    start_now: true
    port: 11882
    restart: always
    backoff: 3s
    backoff_max: 60s
    file_log: true
    log_path: /var/log/fasteredgeos/fasteredge/
STANZA
  echo "fasteredge 服务 stanza 已追加到 $CFG"
else
  echo "fasteredge 服务 stanza 已存在, 跳过追加。"
fi

echo "fasteredge bundle (FasterEdge 节点运行时) 已安装。"
