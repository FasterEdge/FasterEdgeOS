#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# 安装 FasterEdge2Api 到 overlay rootfs:
#   /usr/bin/fasteredge2api         FasterEdge 集群 HTTP API 服务二进制(常驻)
#   /etc/fasteredgeos/manager.yaml  幂等追加 fasteredge2api 服务 stanza(含健康探针)
#   /var/lib/fasteredgeos/          运行数据目录(keyring 快照, 引擎自动创建)
#   /usr/share/doc/fasteredge2api/README.md  使用说明
set -e

. ../../common.sh

BIN=$OVERLAY_WORK_DIR/$BUNDLE_NAME/fasteredge2api
BUNDLE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CFG=$OVERLAY_ROOTFS/etc/fasteredgeos/manager.yaml

[ -x "$BIN" ] || { echo "错误: 缺少编译产物(先执行 02_build.sh)"; exit 1; }

mkdir -p $OVERLAY_ROOTFS/usr/bin
mkdir -p $OVERLAY_ROOTFS/etc/fasteredgeos
mkdir -p $OVERLAY_ROOTFS/usr/share/doc/fasteredge2api
mkdir -p $OVERLAY_ROOTFS/var/lib/fasteredgeos
mkdir -p $OVERLAY_ROOTFS/var/log/fasteredgeos

install -m755 "$BIN" $OVERLAY_ROOTFS/usr/bin/fasteredge2api
install -m644 "$BUNDLE_DIR/README.md" $OVERLAY_ROOTFS/usr/share/doc/fasteredge2api/README.md

# 将 fasteredge2api 服务 stanza 幂等追加到根管理器配置。
# 依赖 fasteredgeos bundle 先安装 manager.yaml(bundle_deps 保证顺序);
# 若缺失则创建最小合法配置兜底(fail-closed: 至少含 services: 头)。
if [ ! -f "$CFG" ] ; then
  echo "警告: $CFG 不存在, 创建最小根管理器配置(建议同时启用 fasteredgeos bundle)。"
  printf 'log_level: info\nlisten: 127.0.0.1:11884\npassword: ""\nshutdown_grace: 10s\nservices:\n' > "$CFG"
fi
if ! grep -Eq 'name:[[:space:]]*fasteredge2api[[:space:]]*$' "$CFG" ; then
  grep -Eq '^services:' "$CFG" || printf '\nservices:\n' >> "$CFG"
  cat >> "$CFG" << STANZA

  # FasterEdge2Api HTTP 服务(由 fasteredge2api bundle 追加): 常驻 API 网关,
  # 子进程监听 127.0.0.1:8080(未配 TLS 时明文, 仅本机; 对外须配 TLS 或可信反代)。
  # 健康探针直连其 /healthz(未认证, 返回 {"ok":true,...}); 连续失败超限自愈重启。
  - name: fasteredge2api
    path: /usr/bin/fasteredge2api
    args: "serve --listen 127.0.0.1:8080 --node-name edge-1 --role edge --keyring /var/lib/fasteredgeos/keyring.json"
    start_now: true
    port: 11885                 # 每实例唯一
    probe_cmd: "wget -q -O /dev/null http://127.0.0.1:8080/healthz"
    probe_interval: 5
    probe_timeout: 3
    probe_failure_limit: 3
    restart: always
    backoff: 3s
    backoff_max: 60s
    file_log: true
    log_path: /var/log/fasteredgeos/fasteredge2api/
STANZA
  echo "fasteredge2api 服务 stanza 已追加到 $CFG"
else
  echo "fasteredge2api 服务 stanza 已存在, 跳过追加。"
fi

echo "fasteredge2api bundle (FasterEdge 集群 HTTP API 服务) 已安装。"
