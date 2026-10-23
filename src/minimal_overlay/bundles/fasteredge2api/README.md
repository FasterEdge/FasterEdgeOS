# fasteredge2api -- FasterEdge 集群 HTTP API 服务(FasterEdge 系统初始工具)

FasterEdge 软件组合的 API 网关: 以常驻 HTTP 服务暴露 FasterEdge 集群拓扑与管理
操作(节点信息、对等节点、角色、云/边能力与指标、令牌签发等)。本 bundle 将其编译
为 /usr/bin/fasteredge2api, 交由根管理器 DontCrack-Manager 监管, 并以健康探针
直连其 /healthz 端点。

- 常驻服务: serve 子命令启动后长期运行(不会自行退出), 由根管理器保持 StateRunning。
- 明文本机监听: 未配 TLS 时在 127.0.0.1:8080 提供明文 HTTP(仅本机); 对外暴露
  必须配置 --tls-cert/--tls-key 或置于可信 TLS 反代之后。
- 未认证健康端点: GET /healthz 无需令牌, 返回 {"ok":true,"time":...}, 供探针与
  编排使用; 其余 /api/v1/* 需 Bearer 令牌。
- 离线引导: token 子命令离线签发首个 admin 令牌(仅允许 subject=admin), 节点令牌
  经认证后的 HTTP API 签发。

## 安装产物

| 路径 | 说明 |
| --- | --- |
| /usr/bin/fasteredge2api | FasterEdge 集群 HTTP API 服务二进制(常驻) |
| /etc/fasteredgeos/manager.yaml | 追加 fasteredge2api 服务 stanza(含探针, 幂等) |
| /var/lib/fasteredgeos/ | 运行数据目录(keyring 快照, 引擎启动时自动创建) |
| /var/log/fasteredgeos/fasteredge2api/ | 服务日志目录 |

## 根管理器接线

03_install.sh 幂等地向 /etc/fasteredgeos/manager.yaml 追加:

```yaml
  - name: fasteredge2api
    path: /usr/bin/fasteredge2api
    args: "serve --listen 127.0.0.1:8080 --node-name edge-1 --role edge --keyring /var/lib/fasteredgeos/keyring.json"
    start_now: true
    port: 11885                              # 每实例唯一
    probe_cmd: "wget -q -O /dev/null http://127.0.0.1:8080/healthz"
    probe_interval: 5
    probe_timeout: 3
    probe_failure_limit: 3
    restart: always
    backoff: 3s
    backoff_max: 60s
    file_log: true
    log_path: /var/log/fasteredgeos/fasteredge2api/
```

## 用法

服务由根管理器按上方配置自动拉起。手动操作:

```
fasteredge2api version                                                # 打印版本
fasteredge2api token --subject admin --ttl 24h \
  --keyring /var/lib/fasteredgeos/keyring.json                       # 离线引导 admin 令牌
wget -q -O - http://127.0.0.1:8080/healthz                            # 健康检查
wget -q -O - --header="Authorization: Bearer <token>" \
  http://127.0.0.1:8080/api/v1/info                                   # 认证 API 示例
```

注意: keyring 由排他文件锁保护, 同一时刻仅允许一个 serve/token 进程持有; 签发
引导令牌前请先确认 serve 未在运行(或改用认证后的 HTTP API)。

## 构建

随 OVERLAY_BUNDLES 启用(bundle 目录加入列表, 如
OVERLAY_BUNDLES="dhcp,fasteredgeos,fasteredge2api")。需要宿主机 Go 1.25+
(CI 经 actions/setup-go 提供; go.mod 依赖已发布的 github.com/FasterEdge/FasterEdge
v1.0.20261022 与 golang.org/x/sys, 经 goproxy 解析)。源码固定到已由 CI 验证的
commit(默认 461d997..., 对应 v1.0.20261022 线); 离线升级可设 FE2A_SOURCE_DIR
指向本地 FasterEdge2Api 仓(须含 go.mod), 或以 FE2A_COMMIT 覆盖固定 commit。
