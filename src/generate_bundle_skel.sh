#!/bin/bash
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# 为新的 overlay 软件包生成基本模板

# 重命名软件包和软件包版本变量，然后运行此脚本即可生成新的 overlay 模板

package=test
ver=2.1

packcaps=${package^^}

echo "正在为 '$package' 生成新的 overlay 软件包模板。"

cp -r minimal_overlay/bundles/coreutils minimal_overlay/bundles/$package

sed -i "s/.*Full path.*/# 完整路径将类似 \'work\/overlay\/$package\/$package-$ver\'。" minimal_overlay/bundles/$package/01_get.sh
sed -i "s/.*Extract coreutils.*/# 将 coreutils 解压到文件夹 \'work\/overlay\/$package\'。" minimal_overlay/bundles/$package/01_get.sh
sed -i "s/COREUTILS/$packcaps/g" minimal_overlay/bundles/$package/01_get.sh
sed -i "s/coreutils/$package/g" minimal_overlay/bundles/$package/01_get.sh

sed -i "s/.*source directory which.*/# 切换到 ls 找到的 coreutils 源码目录，例如 \'$package-$ver\'。" minimal_overlay/bundles/$package/02_build.sh
sed -i "s/COREUTILS/$packcaps/g" minimal_overlay/bundles/$package/02_build.sh
sed -i "s/coreutils/$package/g" minimal_overlay/bundles/$package/02_build.sh

echo "已为 $package 创建新的 overlay 软件包。"
echo "请在 .config 中更新源码位置和简要说明。"
echo "请在 README 中更新软件包说明和依赖项。"
