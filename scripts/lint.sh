#!/bin/sh
# FasterEdgeOS 仓库静态检查入口（跨平台：Windows Git Bash / Linux）。
#
# 覆盖：
#   1) shell 静态检查 —— 有 shellcheck 用 shellcheck；没有则退化为 bash -n + sh -n 语法检查
#   2) shell 语法检查（bash -n / sh -n）—— 始终执行，即使 shellcheck 可用
#   3) tools/*.mjs 语法检查 —— node --check
#   4) yaml/json 解析校验 —— 交给 scripts/lint_marshal.mjs
#
# 用法：
#   scripts/lint.sh            # 全量检查，任一项失败退出码非 0
#   scripts/lint.sh --quick    # 只跑 shell 语法 + yaml/json（跳过 shellcheck 与 mjs）
#
# 环境变量：
#   SHELLCHECK       指定 shellcheck 可执行文件（默认在 PATH 中查找）
#   LINT_STRICT=1    把 info/style 级别的 shellcheck 提示也升级为失败（默认只拦 error/warning）
#   LINT_SKIP=1      只执行 shell 语法 + yaml/json 校验（跳过 shellcheck 与 mjs）
#
# 说明：shellcheck 在 Windows 上没有官方二进制发行版；本脚本用
# `shellcheck -S error -S warning` 作为默认门槛，CI(ubuntu) 上额外装
# `shellcheck` apt 包即可获得更强检查（见 .github/workflows/check.yml）。

set -e

REPO_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$REPO_ROOT"

FAILED=0
STRICT=${LINT_STRICT:-0}

log() { printf '%s\n' "$*"; }
err() { printf '%s\n' "$*" >&2; }

for arg in "$@" ; do
  case "$arg" in
    --quick) LINT_SKIP=1 ;;
    -h|--help) sed -n '2,22p' "$0" ; exit 0 ;;
    *) err "未知参数: $arg（可用: --quick）" >&2 ; exit 2 ;;
  esac
done

# 按 git 跟踪列表取 shell 脚本，避免把 work/、source/ 等未跟踪产物算进来。
# scripts/ 也纳入范围（门禁脚本自身出错时同样要被拦住）；用 sort -u 去重，
# 避免 scripts/lint.sh 已入库后重复检查。
# 无 git 时退化为按路径排除的 find。
# 覆盖 *.sh 之外的无扩展名 shell 脚本：按首行 shebang 判定（覆盖 src/minimal_rootfs/init
# 等目标机启动脚本），这类文件不带 .sh 后缀，只按扩展名收集会整个漏掉。
list_shell_scripts() {
  if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 ; then
    git -C "$REPO_ROOT" ls-files -z '*.sh' \
      | tr '\0' '\n' \
      | grep -v '^src/source/' \
      | grep -v '^src/work/'
  else
    find scripts .github src -type f -name '*.sh' 2>/dev/null \
      | grep -v '/work/' | grep -v '/source/'
  fi
  find scripts -type f -name '*.sh' 2>/dev/null
}

# 无扩展名 shell 脚本：src/minimal_rootfs/init、bundle 的 05_rc.dhcp /
# fasteredge-node 等都不带 .sh 后缀，只按扩展名收集会整个漏掉，
# 这里按首行 shebang 判定（排除二进制与文档）。
list_shebangs() {
  git -C "$REPO_ROOT" ls-files -z 2>/dev/null \
    | tr '\0' '\n' \
    | grep -v '\.sh$' \
    | while IFS= read -r f ; do
        case "$f" in
          */.git/*|src/source/*|src/work/*|dist/*) continue ;;
        esac
        [ -f "$REPO_ROOT/$f" ] || continue
        if head -n 1 "$REPO_ROOT/$f" 2>/dev/null | grep -qE '^#!.*(bash|sh)$' ; then
          printf '%s\n' "$f"
        fi
      done
}

# 探测顺序：SHELLCHECK 环境变量 -> PATH -> 常见安装位置。
find_shellcheck() {
  if [ -n "${SHELLCHECK:-}" ] && command -v "$SHELLCHECK" >/dev/null 2>&1 ; then
    printf '%s\n' "$SHELLCHECK"
    return 0
  fi
  if command -v shellcheck >/dev/null 2>&1 ; then
    command -v shellcheck
    return 0
  fi
  for cand in /usr/bin/shellcheck /usr/local/bin/shellcheck \
              /opt/homebrew/bin/shellcheck ; do
    if [ -x "$cand" ] ; then
      printf '%s\n' "$cand"
      return 0
    fi
  done
  # Windows: pip 的 shellcheck-py 会装到 Scripts/ 下（shellcheck.exe）。
  for cand in "$HOME/AppData/Roaming/Python"/*/Scripts/shellcheck.exe \
              "$LOCALAPPDATA/Programs/Python"/*/Scripts/shellcheck.exe ; do
    if [ -x "$cand" ] ; then
      printf '%s\n' "$cand"
      return 0
    fi
  done
  return 1
}

SCRIPTS=$(
  {
    list_shell_scripts
    list_shebangs
    [ -f "$REPO_ROOT/scripts/lint.sh" ] && printf 'scripts/lint.sh\n'
    :
  } | grep . | sort -u
)
if [ -z "$SCRIPTS" ] ; then
  err "未找到任何 shell 脚本，检查仓库是否完整。"
  exit 1
fi
SCRIPT_COUNT=$(printf '%s\n' "$SCRIPTS" | grep -c . || true)
log "== shell 脚本数量: $SCRIPT_COUNT"

# ---------------------------------------------------------------- 1) bash -n
log "== bash -n 语法检查"
BASH_FAIL=0
for f in $SCRIPTS ; do
  if ! bash -n "$f" ; then
    err "bash -n 失败: $f"
    BASH_FAIL=1
  fi
done
if [ "$BASH_FAIL" -ne 0 ] ; then FAILED=1 ; fi

# ---------------------------------------------------------------- 2) sh -n
log "== sh -n 语法检查"
SH_FAIL=0
for f in $SCRIPTS ; do
  if ! sh -n "$f" ; then
    err "sh -n 失败: $f"
    SH_FAIL=1
  fi
done
if [ "$SH_FAIL" -ne 0 ] ; then FAILED=1 ; fi

# ------------------------------------------------------------ 3) shellcheck
if [ "${LINT_SKIP:-0}" != "1" ] ; then
  SC=$(find_shellcheck || true)
  if [ -n "$SC" ] ; then
    log "== shellcheck ($SC)"
    if [ "$STRICT" = "1" ] ; then
      SC_OPTS="-S style"
    else
      SC_OPTS="-S error -S warning"
    fi
    # -x 跟随 source 的公共脚本；-s sh 按 POSIX sh 判定（仓库脚本以 #!/bin/sh 为主）。
    # 逐个文件调用 shellcheck，避免命令行过长（Windows CreateProcess 限制）。
    SC_FAIL=0
    for f in $SCRIPTS ; do
      if ! "$SC" $SC_OPTS -x -s sh "$f" ; then
        SC_FAIL=1
      fi
    done
    if [ "$SC_FAIL" -ne 0 ] ; then
      err "shellcheck 报告了 error/warning 级别问题。"
      FAILED=1
    fi
  else
    log "== shellcheck 未安装，已退化为 bash -n + sh -n 语法检查（本机未安装 shellcheck）"
  fi

  # ---------------------------------------------------------- 4) mjs 语法
  log "== node --check tools/*.mjs"
  MJS_FAIL=0
  for f in tools/*.mjs ; do
    [ -f "$f" ] || continue
    if ! node --check "$f" ; then
      err "node --check 失败: $f"
      MJS_FAIL=1
    fi
  done
  if [ "$MJS_FAIL" -ne 0 ] ; then FAILED=1 ; fi
fi

# --------------------------------------------------- 5) yaml/json 解析校验
log "== yaml/json 解析校验"
if ! node scripts/lint_marshal.mjs ; then
  err "yaml/json 解析校验失败。"
  FAILED=1
fi

if [ "$FAILED" -ne 0 ] ; then
  err "静态检查未通过。"
  exit 1
fi
log "静态检查全部通过。"
