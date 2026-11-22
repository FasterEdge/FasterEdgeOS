#!/bin/sh

# 可复现构建与供应链 sidecar 的自检脚本。
#
# 这个脚本不需要真的编译内核/glibc(那是 ~1 小时的构建), 只做静态可验证的
# 部分:
#
#   1) 所有 *.sh 通过 'bash -n' 语法检查;
#   2) common.sh 导出的 SOURCE_DATE_EPOCH / TAR_REPRODUCIBLE / 固定 UUID 取值
#      正确, 并且确实 export 给了子进程(打包工具在子进程里读它们);
#   3) tar 打包选项确实能让同一目录两次打包得到同一份归档(字节级);
#   4) gzip -n 确实不写入时间戳;
#   5) 每个 download_source 调用点的落点都有对应的 .sha256 sidecar, 即供应链
#      覆盖率 100%(fail-closed 才成立);
#   6) 每个 sidecar 自洽: 内嵌文件名与文件名一致, 哈希是 64 位十六进制;
#   7) KERNEL_ARCH 参数化: 各架构的内核产物路径与 make 目标符合 Linux 内核
#      的 arch/<arch>/boot/<image> 约定。
#
# 用法:
#   ./test_reproducible.sh
#
# 退出码 0 表示全部通过, 非 0 表示有检查项失败。
#
# 覆盖不到的(需要真实构建, 见 README "可复现构建" 一节的降级声明):
#   * ISO/EXT2/FAT 镜像的端到端字节一致(需要 xorriso/mke2fs/mkfs.vfat/loop);
#   * arm64/arm 的 ISO 引导链(只产内核与 initramfs);
#   * overlay=sparse 分支(需要 root + loop 设备)。

set -e

SRC_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH='' cd -- "$SRC_DIR/.." && pwd)
FAILED=0

pass() { echo "  [PASS] $1" ; }
fail() { echo "  [FAIL] $1" ; FAILED=$((FAILED + 1)) ; }

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

echo "=============================================="
echo " FasterEdgeOS 可复现构建与供应链自检"
echo "=============================================="

# ---------------------------------------------------------------------------
echo
echo "[1] bash -n 语法检查"
# ---------------------------------------------------------------------------
find "$REPO_ROOT" -name '*.sh' -type f \
  -not -path '*/work/*' -not -path '*/source/*' -not -path '*/.git/*' \
  | LC_ALL=C sort > "$T/shell_scripts.txt"
while IFS= read -r f ; do
  if ! bash -n "$f" 2>/dev/null ; then
    fail "bash -n ${f#"$REPO_ROOT"/}"
    bash -n "$f" || true
  fi
done < "$T/shell_scripts.txt"
[ "$FAILED" = "0" ] && pass "所有 *.sh 语法正确($(wc -l < "$T/shell_scripts.txt") 个文件)"

# ---------------------------------------------------------------------------
echo
echo "[2] SOURCE_DATE_EPOCH / TAR_REPRODUCIBLE / 固定 UUID"
# ---------------------------------------------------------------------------
# 回读变量的方式是 exec env: 输出的就是进程环境, 因此只有真正 export 出去
# 的变量才会出现, 打包工具 (tar/gzip/xz/cpio/mkfs/xorriso) 看到的正是这份环境。
# 注意不要写成 `SOURCE_DATE_EPOCH=1700000000 . ./common.sh`: 前缀赋值对内建
# 命令 `.` 只在命令执行期间生效, bash 会在 source 返回后还原, 而 POSIX sh /
# dash 会保留, 于是同一份脚本在两种 shell 下结论相反。这里显式赋值后由
# common.sh 自己 export, 与 shell 实现无关。
ENVDUMP=$(cd "$SRC_DIR" \
  && sh -c 'unset SOURCE_DATE_EPOCH
             SOURCE_DATE_EPOCH=1700000000
             . ./common.sh >/dev/null 2>&1 || exit 1
             exec env')
SDE=$(printf '%s\n' "$ENVDUMP" | sed -n 's/^SOURCE_DATE_EPOCH=//p')
TAROPT=$(printf '%s\n' "$ENVDUMP" | sed -n 's/^TAR_REPRODUCIBLE=//p')
BS=$(printf '%s\n' "$ENVDUMP" | sed -n 's/^KBUILD_BUILD_TIMESTAMP=//p')
TZVAL=$(printf '%s\n' "$ENVDUMP" | sed -n 's/^TZ=//p')
UUID=$(printf '%s\n' "$ENVDUMP" | sed -n 's/^FEOS_OVERLAY_FS_UUID=//p')
FATID=$(printf '%s\n' "$ENVDUMP" | sed -n 's/^FEOS_UEFI_FAT_VOLUME_ID=//p')

[ "$SDE" = "1700000000" ] || fail "SOURCE_DATE_EPOCH 未透传到子进程(得到 '$SDE')"
[ "$BS" = "@1700000000" ] || fail "KBUILD_BUILD_TIMESTAMP 未设置(得到 '$BS')"
[ "$TZVAL" = "UTC" ] || fail "TZ 未固定为 UTC(得到 '$TZVAL')"
case "$UUID" in
  ????????-????-????-????-????????????) ;;
  *) fail "FEOS_OVERLAY_FS_UUID 不是固定 UUID(得到 '$UUID')" ;;
esac
case "$FATID" in
  ????????) ;;
  *) fail "FEOS_UEFI_FAT_VOLUME_ID 不是 8 位十六进制(得到 '$FATID')" ;;
esac

for opt in '--sort=name' '--mtime=@1700000000' '--owner=0' '--group=0' '--numeric-owner' ; do
  case "$TAROPT" in
    *"$opt"*) ;;
    *) fail "TAR_REPRODUCIBLE 缺少 $opt" ;;
  esac
done
[ "$FAILED" = "0" ] && pass "SOURCE_DATE_EPOCH/TAR_REPRODUCIBLE/KBUILD_BUILD_TIMESTAMP/UUID 正确且已 export"

# ---------------------------------------------------------------------------
echo
echo "[3] tar 打包两次字节一致(真实执行)"
# ---------------------------------------------------------------------------
mkdir -p "$T/tree/a" "$T/tree/b"
printf 'first\n'  > "$T/tree/a/1.txt"
printf 'second\n' > "$T/tree/b/2.txt"
printf 'third\n'  > "$T/tree/3.txt"
# 故意设置互不相同的 mtime, 验证 --mtime 覆盖了它们。
touch -d '2020-01-01T00:00:00Z' "$T/tree/a/1.txt"
touch -d '2021-06-15T12:00:00Z' "$T/tree/b/2.txt"
touch -d '2022-11-30T23:59:59Z' "$T/tree/3.txt"

# TAR_REPRODUCIBLE 必须按空白拆成多个参数, 这里显式拆到位置参数上。
# shellcheck disable=SC2086
set -- $TAROPT
( cd "$T/tree" && tar "$@" -cf "$T/one.tar" . )
sleep 2
touch "$T/tree/a/1.txt" "$T/tree/b/2.txt" "$T/tree/3.txt"
( cd "$T/tree" && tar "$@" -cf "$T/two.tar" . )

if cmp -s "$T/one.tar" "$T/two.tar" ; then
  pass "两次 tar 打包字节一致(即使源文件 mtime 被改动)"
else
  fail "两次 tar 打包结果不同"
  cmp "$T/one.tar" "$T/two.tar" || true
fi

# 归档内不应出现非 0 的 uid/gid。
if tar -tvf "$T/one.tar" | grep -qvE '^(d|-)[rwxsStT-]{9} +0/0 ' ; then
  fail "归档内存在非 0/0 属主或权限异常的成员"
  tar -tvf "$T/one.tar" || true
else
  pass "归档内所有成员属主均为 0/0"
fi

# ---------------------------------------------------------------------------
echo
echo "[4] gzip -n 不写入时间戳/文件名"
# ---------------------------------------------------------------------------
printf 'hello fasteredgeos\n' > "$T/plain.txt"
gzip -n -9 < "$T/plain.txt" > "$T/one.gz"
sleep 2
gzip -n -9 < "$T/plain.txt" > "$T/two.gz"
if cmp -s "$T/one.gz" "$T/two.gz" ; then
  pass "两次 gzip -n 压缩字节一致"
else
  fail "两次 gzip -n 压缩结果不同"
fi
# gzip 头部第 5..8 字节是 MTIME, 必须为 0。
MTIME=$(od -An -tu4 -j4 -N4 "$T/one.gz" | tr -d ' ')
[ "$MTIME" = "0" ] || fail "gzip 头部 MTIME 非 0(得到 $MTIME)"
[ "$FAILED" = "0" ] && pass "gzip 头部 MTIME=0(未写入时间戳)"

# xz 同理: .xz 容器本身不写时间戳, 但多线程分块会改变输出, 因此 10_pack_rootfs.sh
# 与 mll_source/bundle.sh 都显式固定 --threads=1。这里验证固定线程数后输出稳定。
if command -v xz >/dev/null 2>&1 ; then
  xz -9 --check=crc32 --threads=1 < "$T/one.tar" > "$T/one.xz"
  sleep 2
  xz -9 --check=crc32 --threads=1 < "$T/one.tar" > "$T/two.xz"
  if cmp -s "$T/one.xz" "$T/two.xz" ; then
    pass "两次 xz --threads=1 压缩字节一致(cpio/xz 打包路径)"
  else
    fail "两次 xz --threads=1 压缩结果不同"
  fi
else
  echo "  [SKIP] 本机没有 xz, 跳过 xz 稳定性检查"
fi

# ---------------------------------------------------------------------------
echo
echo "[5] 供应链 sidecar 覆盖率(fail-closed 前提)"
# ---------------------------------------------------------------------------
# 从 '.config' 读取属性(取最后一次出现的行, 与 read_property 的语义一致)。
config_get() {
  _cfg=$1
  _prop=$2
  [ -f "$_cfg" ] || return 0
  grep -i "^${_prop}=" "$_cfg" 2>/dev/null | tail -n 1 | cut -f2- -d'=' \
    | sed 's/[[:space:]]*$//'
}

# 解析一个 01_get.sh / 主链脚本里 download_source 的落点文件名。
# 只支持本仓库实际使用的写法:
#   download_source <url> $OVERLAY_SOURCE_DIR/<字面量>
#   download_source <url> $OVERLAY_SOURCE_DIR/$ARCHIVE_FILE  (ARCHIVE_FILE=${DOWNLOAD_URL##*/})
#   download_source <url> $SOURCE_DIR/$ARCHIVE_FILE
# <字面量> 形式(gf_cli/bosh_cli/static_get)直接取字面量; 变量形式回溯到
# ${<var>##*/} 再回溯到 read_property <PROP>, 最后从 .config 取 URL 末段。
resolve_targets() {
  _script=$1
  _bdir=$(dirname "$_script")
  grep -E '^[[:space:]]*download_source[[:space:]]' "$_script" 2>/dev/null \
    | grep -v '^[[:space:]]*#' | while IFS= read -r _line ; do
    # 下面 case 模式里的单引号是故意的: 要匹配的是源码中的字面量
    # '$OVERLAY_SOURCE_DIR/' / '$SOURCE_DIR/' 文本, 而不是本脚本自己的变量。
    # shellcheck disable=SC2016
    case "$_line" in
      *'$OVERLAY_SOURCE_DIR/'*) _where=overlay ; _tail=${_line#*\$OVERLAY_SOURCE_DIR/} ;;
      *'$SOURCE_DIR/'*)         _where=main    ; _tail=${_line#*\$SOURCE_DIR/} ;;
      *) continue ;;
    esac
    _target=${_tail%%[[:space:]]*}
    _target=${_target%%\"*}
    case "$_target" in
      '$'*)
        _var=${_target#\$}
        _var=${_var#\{}
        _var=${_var%%\}*}
        _assign=$(grep -E "^[[:space:]]*(export[[:space:]]+)?${_var}=" "$_script" 2>/dev/null | tail -n 1)
        [ -n "$_assign" ] || continue
        _value=${_assign#*=}
        # 只认 ${OTHER##*/} 这一种"取 URL 末段"的写法。
        _srcvar=$(printf '%s\n' "$_value" \
          | sed -n 's/^[$][{]\([A-Za-z0-9_]*\)##[*][/][}]$/\1/p')
        [ -n "$_srcvar" ] || continue
        _prop=$(grep -E "^[[:space:]]*(export[[:space:]]+)?${_srcvar}=" "$_script" 2>/dev/null \
          | tail -n 1 | cut -d= -f2- \
          | sed -n 's/.*read_property[[:space:]]*\([^`)]*\).*/\1/p' \
          | sed 's/[[:space:]]*$//')
        [ -n "$_prop" ] || continue
        # 展开属性名里的 ${...}(adopt_openjdk 的 ADOPT_OPENJDK_${JVM_ENGINE}_URL)。
        while printf '%s\n' "$_prop" | grep -q '[$]{' ; do
          _n=$(printf '%s\n' "$_prop" | sed -n 's/.*[$]{\([A-Za-z0-9_]*\)}.*/\1/p')
          [ -n "$_n" ] || break
          _v=$(config_get "$_bdir/.config" "$_n")
          [ -n "$_v" ] || _v=$(config_get "$SRC_DIR/.config" "$_n")
          [ -n "$_v" ] || break
          _prop=$(printf '%s\n' "$_prop" | sed "s/[$]{${_n}}/${_v}/")
        done
        _url=$(config_get "$_bdir/.config" "$_prop")
        [ -n "$_url" ] || _url=$(config_get "$SRC_DIR/.config" "$_prop")
        [ -n "$_url" ] || continue
        _name=${_url##*/}
        ;;
      *) _name=$_target ;;
    esac
    [ -n "$_name" ] || continue
    printf '%s %s\n' "$_where" "$_name"
  done
}

: > "$T/targets.txt"
for _s in "$SRC_DIR"/[0-9][0-9]_*.sh "$SRC_DIR"/minimal_overlay/bundles/*/01_get.sh ; do
  [ -f "$_s" ] || continue
  resolve_targets "$_s" >> "$T/targets.txt"
done
# adopt_openjdk 的 JVM_ENGINE 可切换, 两种引擎的归档都必须有 sidecar。
for _eng in HOTSPOT OPENJ9 ; do
  _url=$(config_get "$SRC_DIR/minimal_overlay/bundles/adopt_openjdk/.config" \
    "ADOPT_OPENJDK_${_eng}_URL")
  [ -n "$_url" ] && printf 'overlay %s\n' "${_url##*/}" >> "$T/targets.txt"
done
LC_ALL=C sort -u "$T/targets.txt" > "$T/targets_sorted.txt"

CHECKED=0
while read -r _where _name ; do
  case "$_where" in
    overlay) side="$SRC_DIR/source/overlay/$_name.sha256" ; ;;
    main)    side="$SRC_DIR/source/$_name.sha256" ; ;;
    *) continue ;;
  esac
  CHECKED=$((CHECKED + 1))
  if [ -f "$side" ] ; then
    pass "sidecar 存在: ${side#"$SRC_DIR"/}"
  else
    fail "sidecar 缺失: ${side#"$SRC_DIR"/}(download_source 落点 '$_name')"
  fi
done < "$T/targets_sorted.txt"
[ "$CHECKED" -gt 0 ] || fail "未解析出任何 download_source 落点, 覆盖率检查本身失效"
echo "  [INFO] 已解析 download_source 落点 $CHECKED 个"

# 反向检查: 'source/overlay' 下不应有无人引用的 sidecar(拼错的文件名会让
# fail-closed 校验在真实构建时才炸)。仅提示, 不计入失败。
# 落点名里含 '+' 等正则元字符(openjdk-11+28), 因此用 -F -x 做字面量整行匹配。
for side in "$SRC_DIR"/source/overlay/*.sha256 ; do
  [ -f "$side" ] || continue
  name=$(basename "$side" .sha256)
  grep -qFx "overlay $name" "$T/targets_sorted.txt" \
    || echo "  [INFO] sidecar 未被任何 download_source 引用: source/overlay/${name}.sha256"
done

# ---------------------------------------------------------------------------
echo
echo "[6] sidecar 自洽(文件名与哈希格式)"
# ---------------------------------------------------------------------------
BAD=0
for side in "$SRC_DIR"/source/*.sha256 "$SRC_DIR"/source/overlay/*.sha256 ; do
  [ -f "$side" ] || continue
  want=$(basename "$side" .sha256)
  got=$(awk 'NR==1 { print $2 }' "$side")
  hash=$(awk 'NR==1 { print $1 }' "$side")
  if [ "$got" != "$want" ] ; then
    fail "${side#"$SRC_DIR"/}: 内嵌文件名 '$got' 与文件名 '$want' 不一致"
    BAD=$((BAD + 1))
    continue
  fi
  case "$hash" in
    *[!0-9A-Fa-f]*) fail "${side#"$SRC_DIR"/}: 哈希含非十六进制字符" ; BAD=$((BAD + 1)) ; continue ;;
  esac
  if [ "${#hash}" -ne 64 ] ; then
    fail "${side#"$SRC_DIR"/}: 哈希长度不是 64(得到 ${#hash})"
    BAD=$((BAD + 1))
  fi
done
[ "$BAD" = "0" ] && pass "所有 sidecar 内嵌文件名与哈希格式正确"

# ---------------------------------------------------------------------------
echo
echo "[7] KERNEL_ARCH 参数化"
# ---------------------------------------------------------------------------
# 从 02_build_kernel.sh 的 case 分支里提取架构 -> 产物路径的映射, 逐个核对
# Linux 内核的 arch/<arch>/boot/<image> 约定。
KSH="$SRC_DIR/02_build_kernel.sh"
for arch in x86 arm64 arm ; do
  if grep -q "^  $arch)" "$KSH" ; then
    case "$arch" in
      x86)   expect=arch/x86/boot/bzImage ; image=bzImage ;;
      arm64) expect=arch/arm64/boot/Image ; image=Image ;;
      arm)   expect=arch/arm/boot/zImage ; image=zImage ;;
    esac
    if grep -A4 "^  $arch)" "$KSH" | grep -q "KERNEL_IMAGE_PATH=$expect" ; then
      pass "$arch -> $expect"
    else
      fail "$arch 的 KERNEL_IMAGE_PATH 不是 $expect"
      grep -A4 "^  $arch)" "$KSH" || true
    fi
    if grep -A4 "^  $arch)" "$KSH" | grep -q "KERNEL_IMAGE_TARGET=$image" ; then
      pass "$arch -> make $image"
    else
      fail "$arch 的 KERNEL_IMAGE_TARGET 不是 $image"
    fi
  else
    fail "$arch 分支缺失(02_build_kernel.sh)"
  fi
done

# 内核与 logo 打包都不应再出现硬编码的 arch/x86 产物路径。
# 注释行(patch 说明里会引用旧写法)先剔除, 否则会误报。
BEFORE_ARCH=$FAILED
for f in "$KSH" "$SRC_DIR/minimal_overlay/bundles/mll_logo/bundle.sh" ; do
  [ -f "$f" ] || continue
  sed -E 's/(^|[[:space:]])#.*$//' "$f" > "$T/no_comment.sh"
  if grep -nE '(^|[[:space:]])cp[[:space:]]+arch/x86/boot/bzImage' "$T/no_comment.sh" >/dev/null 2>&1 ; then
    fail "仍存在硬编码的 cp arch/x86/boot/bzImage: ${f#"$SRC_DIR"/}"
    grep -nE 'cp[[:space:]]+arch/x86/boot/bzImage' "$T/no_comment.sh" || true
  fi
  if grep -nE 'make[[:space:]]+(bzImage|Image|zImage)([[:space:]]|$)' "$T/no_comment.sh" >/dev/null 2>&1 ; then
    fail "仍存在不带 ARCH= 的内核 make 调用: ${f#"$SRC_DIR"/}"
    grep -nE 'make[[:space:]]+(bzImage|Image|zImage)([[:space:]]|$)' "$T/no_comment.sh" || true
  fi
  # defconfig 也必须带 ARCH=, 否则在 x86 主机上交叉构建 arm64 会静默生成 x86 配置。
  if grep -nE 'make .*defconfig' "$T/no_comment.sh" | grep -v 'KERNEL_MAKE_ARGS' >/dev/null 2>&1 ; then
    fail "make defconfig 未带 ARCH=: ${f#"$SRC_DIR"/}"
    grep -nE 'make .*defconfig' "$T/no_comment.sh" || true
  fi
done
[ "$FAILED" = "$BEFORE_ARCH" ] && pass "内核 make 调用均带 ARCH=/CROSS_COMPILE, 产物路径无硬编码"

# ---------------------------------------------------------------------------
echo
echo "=============================================="
if [ "$FAILED" = "0" ] ; then
  echo " 全部通过。"
  echo "=============================================="
  exit 0
else
  echo " 失败项: $FAILED"
  echo "=============================================="
  exit 1
fi
