#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# 本脚本由 GitHub 工作流调用。

set -e

cd ../src

echo "`date` | *** FasterEdgeOS Docker 测试 - 开始 ***"

docker import fasteredgeos_image.tgz fasteredgeos:latest
docker run fasteredgeos /bin/cat /etc/motd

# DontCrack-Manager 根管理器运行验证: 启动管理器并查询健康端点。
DCM_OUT=$(docker run fasteredgeos /bin/sh -c 'setsid /usr/bin/dontcrack-manager -config /etc/fasteredgeos/manager.yaml >/var/log/fasteredgeos/manager.log 2>&1 & sleep 3; wget -q -O - http://127.0.0.1:11884/healthz 2>/dev/null || true')
echo "`date` | DCM healthz: ${DCM_OUT}"
if [ -n "$DCM_OUT" ] ; then
  echo "`date` | DontCrack-Manager 聚合状态端点(11884)响应正常"
else
  echo "`date` | !!! 失败 !!! DontCrack-Manager 未响应 healthz(11884)。"
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

