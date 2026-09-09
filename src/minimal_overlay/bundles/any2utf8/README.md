# any2utf8 —— 文本/文件转 UTF-8 工具(FasterEdge 系统初始工具)

系统自带的本机文本/文件编码转换器。与系统 `iconv` 的关键差异:

- **内置编码, 不依赖系统编码集**: GBK / GB18030 / Big5 / Shift_JIS / EUC-JP /
  EUC-KR / UTF-16(LE/BE) / Windows-1252 / ISO-8859-* / KOI8-R 等常见编码由
  Go 纯实现提供(`golang.org/x/text`)。系统没有 `iconv`、没有对应 `locale`、
  也没安装编码集时, 工具照常转换——**"本地没有 UTF-8 编码集"不再是障碍**。
- **自动探测源编码**: 未指定 `-from` 时按
  `BOM → 合法 UTF-8 → 系统默认编码(LANG/LC_ALL/LC_CTYPE) → GBK 启发` 的顺序判定;
  判定依赖系统默认编码时会输出警告提示。
- **未知编码名**给出 `--list` 内置清单; 若确需系统级编码集,
  会提示安装 `locales` 并 `locale-gen`(仅系统其它工具需要的场景)。

## 用法

```
any2utf8 [选项] [文件...]      # 转换文件, 缺省读标准输入
any2utf8 --list                # 列出内置编码
any2utf8 --sys-encoding        # 输出系统默认编码检测结果
any2utf8 --detect [文件...]    # 仅探测源编码, 不转换
```

| 选项 | 含义 |
| --- | --- |
| `-from 编码` | 源编码(默认 auto: BOM → UTF-8 校验 → 系统默认 → GBK 启发) |
| `-to 编码` | 目标编码(默认 `utf-8`; 如 `-to gbk` 可反向) |
| `-output 文件` | 输出文件(默认 stdout; 与 `-inplace` 互斥) |
| `-inplace` | 原地转换, 原子替换原文件(保留原权限) |
| `-strict` | 严格模式: 出现替换字符/非法序列即失败(exit 1) |
| `-list` / `-detect` / `-sys-encoding` | 信息类子命令 |

> 约束: 标准输入有 1GiB 上限(超限明确报错, 不静默截断); `-output` 仅限单文件
> (多文件输出请用重定向或 `-inplace`)。

## 示例

```sh
any2utf8 -from GBK report.txt > report.utf8.txt   # GBK → UTF-8
any2utf8 -inplace -from GB18030 old.txt           # 原地转 UTF-8
cat log.txt | any2utf8 --detect                   # 探测标准输入编码
any2utf8 -from auto *.txt                         # 多文件自动探测转换(输出到 stdout)
any2utf8 -from GBK -to gbk -output back.txt a.txt # 通用双向转换
```

## 系统默认编码检测

工具按 `LC_ALL → LC_CTYPE → LANG` 顺序读取, 取 locale 名 `.` 后的 charset 段
(如 `zh_CN.GBK` → GBK, `en_US.UTF-8` → UTF-8), 并映射常见
`GB2312 → GBK`、`CP936 → GBK`、`CP950 → Big5`、`CP932 → Shift_JIS` 等别名。
`any2utf8 --sys-encoding` 可单独查看。

## 缺编码集场景的处理

1. **转换层面(本工具)**: 全部内置, 无系统依赖——系统缺编码集不影响转换。
2. **源编码判定失败**: 自动回退 `UTF-8` 并打警告; 可用 `-strict`
   让"解码出现替换字符/非法序列"直接失败, 防止静默乱码。
3. **系统其它工具需要编码集时**: 提示安装 `locales` 并 `locale-gen`
   (Debian/Ubuntu 系: `apt install locales && locale-gen zh_CN.GBK` 等)。

## 构建

随 `OVERLAY_BUNDLES` 启用(bundle 目录加入列表, 如
`OVERLAY_BUNDLES="dhcp,fasteredgeos,any2utf8"`)。需要宿主机 Go 1.25+
(CI 经 `actions/setup-go` 提供)。离线升级可设 `ANY2UTF8_SOURCE_DIR`
指向本地新版源码目录(须含 `main.go` / `go.mod` / `go.sum`)。