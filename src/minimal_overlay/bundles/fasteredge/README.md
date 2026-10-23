# fasteredge -- FasterEdge 节点运行时(FasterEdge 系统初始工具)

FasterEdge 软件组合的核心框架。本 bundle 将 FasterEdge 的最小可运行演示编译为
常驻节点运行时, 交由根管理器 DontCrack-Manager 监管, 使无进程管理器的 Live
系统也能以受控方式运行 FasterEdge 框架骨架。

- 框架骨架演示: examples/demo 演示 Atom 启动、组件挂载、NetMap 注册对等节点、
  OneKey 签发/校验令牌、TimeAbility 记录系统时间、ConfigFileAbility 持久化配置、
  ShAbility 白名单执行 printf, 约 100ms 后优雅退出(exit 0)。
- 一次性转常驻: demo 自身运行完即退出; 本 bundle 附带常驻包装器
  /usr/bin/fasteredge-node, 周期性(默认 300s, 由 FE_NODE_INTERVAL 控制)拉起
  demo, 使 fasteredge 服务对根管理器表现为持续存活的常驻进程。
- 离线/无网络: demo 运行不发起任何网络连接(时间同步仅记录本地时钟), 适合边缘
  离线场景。

## 安装产物

| 路径 | 说明 |
| --- | --- |
| /usr/bin/fasteredge-demo | FasterEdge 最小演示二进制(一次性, exit 0) |
| /usr/bin/fasteredge-node | 常驻包装器(循环拉起 demo, 供根管理器监管) |
| /etc/fasteredgeos/manager.yaml | 追加 fasteredge 服务 stanza(幂等) |
| /var/log/fasteredgeos/fasteredge/ | 服务日志目录 |

## 根管理器接线

03_install.sh 幂等地向 /etc/fasteredgeos/manager.yaml 追加:

```yaml
  - name: fasteredge
    path: /usr/bin/fasteredge-node
    start_now: true
    port: 11882          # 每实例唯一
    restart: always
    backoff: 3s
    backoff_max: 60s
    file_log: true
    log_path: /var/log/fasteredgeos/fasteredge/
```

查询根管理器聚合状态(含 fasteredge 子进程):

```
wget -q -O - http://127.0.0.1:11884/healthz    # 全部服务健康才返回 ok
wget -q -O - http://127.0.0.1:11884/status
```

## 构建

随 OVERLAY_BUNDLES 启用(bundle 目录加入列表, 如
OVERLAY_BUNDLES="dhcp,fasteredgeos,fasteredge")。需要宿主机 Go 1.25+
(CI 经 actions/setup-go 提供; examples/demo 为独立 module, 依赖 beevik/ntp、
x/net、x/sys, 经 goproxy 解析)。源码固定到已由 CI 验证的 commit(默认
212b9b9..., 对应 v1.0.20261022 线); 离线升级可设 FE_SOURCE_DIR 指向本地
FasterEdge 仓(须含 go.mod), 或以 FE_COMMIT 覆盖固定 commit。
