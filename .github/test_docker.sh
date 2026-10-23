#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# 本脚本由 GitHub 工作流调用。

set -e

cd ../src

echo "`date` | *** FasterEdgeOS Docker 测试 - 开始 ***"

docker import fasteredgeos_image.tgz fasteredgeos:latest
docker run fasteredgeos /bin/cat /etc/motd

# DontCrack-Manager 根管理器 + FasterEdge 软件组合运行验证。
# /healthz(管理器, 11884): 管理器与所有被监管服务均健康才返回 200/ok, 否则 503。
# /healthz(FasterEdge2Api, 8080): 未认证, 返回 {"ok":true,"time":...}。
# 轮询直到管理器 body == "ok"(而非首个非空响应): 带探针的 fasteredge2api 就绪前,
# 管理器可能先返回 503/not healthy; 若按"首个非空"判定会把未就绪误报为失败。
# 最多轮询 60s: 容器冷启动 + 各服务(含 2Api)就绪比固定时长更慢。
DCM_OUT=$(docker run fasteredgeos /bin/sh -c '
  setsid /usr/bin/dontcrack-manager -config /etc/fasteredgeos/manager.yaml >/var/log/fasteredgeos/manager.log 2>&1 &
  i=0
  MGR=""
  while [ $i -lt 60 ]; do
    MGR=$(wget -q -O - http://127.0.0.1:11884/healthz 2>/dev/null || true)
    [ "$MGR" = "ok" ] && break
    i=$((i + 1))
    sleep 1
  done
  echo "MANAGER=$MGR"
  # 直接探测 fasteredge2api 的 /healthz(独立于管理器, 验证 2Api HTTP 服务本身)。
  j=0
  A2A=""
  while [ $j -lt 30 ]; do
    A2A=$(wget -q -O - http://127.0.0.1:8080/healthz 2>/dev/null || true)
    echo "$A2A" | grep -q "\"ok\":true" && break
    j=$((j + 1))
    sleep 1
  done
  echo "A2A=$A2A"')
MANAGER_BODY=$(echo "$DCM_OUT" | sed -n 's/^MANAGER=//p')
A2A_BODY=$(echo "$DCM_OUT" | sed -n 's/^A2A=//p')
echo "`date` | DontCrack-Manager healthz: ${MANAGER_BODY:-(空)}"
echo "`date` | FasterEdge2Api healthz: ${A2A_BODY:-(空)}"
if [ "$MANAGER_BODY" != "ok" ] ; then
  echo "`date` | !!! 失败 !!! DontCrack-Manager 未健康(healthz 期望 'ok', 实际: ${MANAGER_BODY:-(空)})"
  echo "`date` | --- manager.log (容器内根管理器日志) ---"
  docker run fasteredgeos /bin/sh -c 'cat /var/log/fasteredgeos/manager.log 2>/dev/null || echo "(无 manager.log)"' || true
  echo "`date` | --- 相关文件清单 ---"
  docker run fasteredgeos /bin/sh -c 'ls -la /usr/bin/dontcrack* /usr/bin/fasteredge* /etc/fasteredgeos/ 2>&1' || true
  exit 1
fi
echo "`date` | DontCrack-Manager 健康(healthz=ok, 全部被监管服务运行中)"
if ! echo "$A2A_BODY" | grep -q '"ok":true' ; then
  echo "`date` | !!! 失败 !!! FasterEdge2Api 未健康(/healthz 期望包含 \"ok\":true, 实际: ${A2A_BODY:-(空)})"
  exit 1
fi
echo "`date` | FasterEdge2Api 健康(/healthz ok:true, 集群 API 服务就绪)"

echo "`date` | *** FasterEdgeOS Docker 测试 - 结束 ***"

cat << CEOF

  #########################
  #                       #
  #  Docker 测试通过。  #
  #                       #
  #########################

CEOF

set +e

