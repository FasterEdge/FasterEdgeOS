#!/bin/sh

# 每个 overlay bundle 都可以提供一个 'autorun' 脚本，系统启动时由 FasterEdgeOS
# 执行。该文件必须放在 '/etc/autorun' 目录下，命名格式为 'XX_something.sh'，
# 其中 XX 是 00 到 99 的数字，决定脚本的执行顺序，例如 '00_something.sh'
# 最先执行，'99_something.sh' 最后执行。

cat << CEOF
[31m  [fasteredgeos_hello][0m [1m输入 'hello' 并按回车。[0m
CEOF
