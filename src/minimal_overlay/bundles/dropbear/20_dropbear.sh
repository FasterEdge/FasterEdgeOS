#!/bin/sh

# 首启时生成主机密钥(若缺失): 构建期不再固化 host key, 避免所有预构建
# 镜像共享同一密钥(SSH MITM 风险); 每实例独立生成。
for key_type in rsa ecdsa; do
  key_file="/etc/dropbear/dropbear_${key_type}_host_key"
  if [ ! -f "$key_file" ]; then
    dropbearkey -t "$key_type" -f "$key_file"
  fi
done

dropbear

cat << CEOF
[1m  Dropbear SSH 服务器已启动。[0m
CEOF
