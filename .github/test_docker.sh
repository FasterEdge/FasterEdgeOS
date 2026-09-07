#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# 本脚本由 GitHub 工作流调用。

set -e

cd ../src

echo "`date` | *** FasterEdgeOS Docker 测试 - 开始 ***"

docker import fasteredgeos_image.tgz fasteredgeos:latest
docker run fasteredgeos /bin/cat /etc/motd

# DontCrack-Manager 根管理器运行验证: 启动管理器并查询健康端点。
# /healthz 语义: 管理器与子进程均健康才返回 200/ok; 否则 503/"process not running"。
# 轮询等待(而非固定 sleep 3): 容器冷启动比固定时长更慢, CI 实测 3s 内
# DCM 未就绪时 wget 无响应(healthz 空)——轮询最多 30s, 避免时序误报。
DCM_OUT=$(docker run fasteredgeos /bin/sh -c '
  setsid /usr/bin/dontcrack-manager -config /etc/fasteredgeos/manager.yaml >/var/log/fasteredgeos/manager.log 2>&1 &
  i=0
  OUT=""
  while [ $i -lt 30 ]; do
    OUT=$(wget -q -O - http://127.0.0.1:11884/healthz 2>/dev/null || true)
    [ -n "$OUT" ] && break
    i=$((i + 1))
    sleep 1
  done
  echo "$OUT"')
if [ -n "$DCM_OUT" ]; then
  echo "`date` | DCM healthz: ${DCM_OUT}"
else
  echo "`date` | DCM healthz: (空响应 - 30s 内未就绪)"
  echo "`date` | --- manager.log (容器内根管理器日志) ---"
  docker run fasteredgeos /bin/sh -c 'cat /var/log/fasteredgeos/manager.log 2>/dev/null || echo "(无 manager.log)"' || true
  echo "`date` | --- 相关文件清单 ---"
  docker run fasteredgeos /bin/sh -c 'ls -la /usr/bin/dontcrack* /usr/bin/fasteredgeos-demo /etc/fasteredgeos/ 2>&1' || true
fi
if echo "$DCM_OUT" | grep -q '^ok$' ; then
  echo "`date` | DontCrack-Manager 健康(healthz=ok, demo 子进程运行中)"
else
  echo "`date` | !!! 失败 !!! DontCrack-Manager 未健康(healthz 期望 'ok', 实际: ${DCM_OUT})"
  exit 1
fi

echo "`date` | *** FasterEdgeOS Docker 测试 - 结束 ***"

cat << CEOF

  #########################
  #                       #
  #  Docker 测试通过。  #
  #                       #
  #########################

CEOF

set +e

