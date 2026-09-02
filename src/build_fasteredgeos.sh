#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# FasterEdgeOS 主构建入口。
set -e

for script in $(ls | grep '^[0-9]*_.*.sh'); do
  echo "正在执行构建步骤: $script"
  ./$script
done
