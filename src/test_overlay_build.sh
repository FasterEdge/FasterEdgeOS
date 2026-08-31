#!/bin/sh

# 此脚本测试每个 overlay 软件包的构建过程。其目的是发现
# 无法正常构建的软件包（错误或过时的构建依赖、失效的下载链接、
# 以及其他简单低级的问题）并采取相应措施。
# 此脚本不测试 overlay 软件包的实际功能。

set -ex

cd minimal_overlay
for bundle in `ls bundles` ; do
  echo "******************************"
  echo "***** $bundle 测试开始 *****"
  echo "******************************"
  ./overlay_clean.sh
  ./overlay_build.sh $bundle
  echo "****************************"
  echo "***** $bundle 测试结束 *****"
  echo "****************************"
done
