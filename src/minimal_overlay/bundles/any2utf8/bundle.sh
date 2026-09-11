#!/bin/sh
# FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge

# any2utf8 bundle: 系统初始工具 —— 文本/文件转 UTF-8 转换器。
# 内置常见编码(GBK/GB18030/Big5/Shift_JIS/EUC-JP/EUC-KR/UTF-16/Windows-1252 等,
# 经 golang.org/x/text 纯 Go 实现), 不依赖系统 iconv 与编码集安装;
# 自动探测系统默认编码(LANG/LC_ALL/LC_CTYPE + 内容启发式)与命令行指定编码集。

set -e

. ../../common.sh

./01_get.sh
./02_build.sh
./03_install.sh

cd $SRC_DIR
