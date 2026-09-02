#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# 本脚本由 GitHub 工作流调用。

set -e

cd ../src

echo "`date` | *** FasterEdgeOS Docker 测试 - 开始 ***"

docker import fasteredgeos_image.tgz fasteredgeos:latest
docker run fasteredgeos /bin/cat /etc/motd

echo "`date` | *** FasterEdgeOS Docker 测试 - 结束 ***"

cat << CEOF

  #########################
  #                       #
  #  Docker 测试通过。  #
  #                       #
  #########################

CEOF

set +e

