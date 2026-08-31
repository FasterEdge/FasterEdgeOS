#!/bin/sh

# 此脚本适用于使用提升权限执行过 FasterEdgeOS 构建流程的情况。
# 它会递归地把所有文件的属主恢复为原始用户。

set -e

echo "*** 清理开始 ***"

if [ "$(id -u)" = "0" ] ; then
  echo "正在把所有受影响文件的属主恢复为原始用户，可能需要一些时间。"

  # 查找原始用户。注意结果不一定总是正确。
  ORIG_USER=`who | head -n 1 | awk '{print \$1}'`
  echo "原始用户为 '$ORIG_USER'。"

  # 把所有受影响文件的属主恢复为原始属主。
  chown -R $ORIG_USER:$ORIG_USER *
else
  echo "无需执行清理。"
fi

echo "*** 清理结束 ***"
