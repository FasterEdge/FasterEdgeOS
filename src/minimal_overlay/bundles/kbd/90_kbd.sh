#!/bin/sh

# 开机时设置的默认键盘布局。
loadkeys us

cat << CEOF
[1m  默认键盘布局为英语（美国）。你可以这样把键盘布局
  改为德语（例如）：

    loadkeys de
    
  你也可以这样恢复为原始的美国键盘布局：
  
    loadkeys us
    
  或者，修改 'kbd' bundle 中的 '90_kbd.sh' 文件，设置
  开机时要使用的键盘布局。[0m
CEOF
