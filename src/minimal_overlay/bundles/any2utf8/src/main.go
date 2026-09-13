// Any2UTF8 —— FasterEdge 系统初始工具: 文本/文件 → UTF-8 转换。
//
// 与系统 iconv 的差异:
//   * 常见编码(GBK/GB18030/Big5/Shift_JIS/EUC-JP/EUC-KR/UTF-16/Windows-1252 等)
//     由 Go 内置实现(golang.org/x/text), 不依赖系统安装的编码集
//     (无 iconv/locale 支持时也可用; 系统缺编码集不再需要安装)。
//   * 自动探测源编码: 无 -from 时按
//       BOM → 合法 UTF-8 → 系统默认编码(LANG/LC_ALL/LC_CTYPE) → GBK 启发 的顺序判定。
//   * 未知编码给出 --list 提示与系统级安装建议(可选的系统 locales 场景)。
//
// 兼容 GNU iconv 常用用法子集: -f/-t/-o/-l 等。

package main

import (
	"bufio"
	"bytes"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"unicode/utf8"

	"golang.org/x/text/encoding"
	"golang.org/x/text/encoding/ianaindex"
	"golang.org/x/text/encoding/unicode"
	"golang.org/x/text/transform"
)

const progName = "any2utf8"

// version 与 FasterEdge 版本链一致的语义化版本。
const version = "1.0.20260913"

// nameAliases 常用名别名 → IANA 注册名(大小写不敏感)。
var nameAliases = map[string]string{
	"utf8":           "UTF-8",
	"gbk":            "GBK",
	"utf-8":          "UTF-8",
	"unicode":        "UTF-8",
	"gb2312":         "GBK",
	"gb-2312":        "GBK",
	"gb_2312":        "GBK",
	"chinese":        "GBK",
	"cp936":          "GBK",
	"ms936":          "GBK",
	"gb18030":        "GB18030",
	"cp54936":        "GB18030",
	"big5":           "Big5",
	"big-5":          "Big5",
	"big5-hkscs":     "Big5",
	"cp950":          "Big5",
	"shift-jis":      "Shift_JIS",
	"shift_jis":      "Shift_JIS",
	"shiftjis":       "Shift_JIS",
	"sjis":           "Shift_JIS",
	"cp932":          "Shift_JIS",
	"ms932":          "Shift_JIS",
	"euc-jp":         "EUC-JP",
	"eucjp":          "EUC-JP",
	"euc-kr":         "EUC-KR",
	"euckr":          "EUC-KR",
	"ksc5601":        "EUC-KR",
	"ks_c_5601-1987": "EUC-KR",
	"cp949":          "EUC-KR",
	"ms949":          "EUC-KR",
	"windows-1252":   "Windows-1252",
	"cp1252":         "Windows-1252",
	"latin1":         "ISO-8859-1",
	"iso-8859-1":     "ISO-8859-1",
	"latin2":         "ISO-8859-2",
	"iso-8859-2":     "ISO-8859-2",
	"koi8-r":         "KOI8-R",
}

// resolveEncoding 解析编码名 → encoding.Encoding。name 为空/"auto" 返回 nil(自动探测)。
func resolveEncoding(name string) (encoding.Encoding, string, error) {
	n := strings.ToLower(strings.TrimSpace(name))
	switch n {
	case "", "auto":
		return nil, "auto", nil
	case "utf-16", "utf16":
		return unicode.UTF16(unicode.LittleEndian, unicode.UseBOM), "UTF-16", nil
	case "utf-16le", "utf16le", "utf-16-le":
		return unicode.UTF16(unicode.LittleEndian, unicode.UseBOM), "UTF-16LE", nil
	case "utf-16be", "utf16be", "utf-16-be":
		return unicode.UTF16(unicode.BigEndian, unicode.UseBOM), "UTF-16BE", nil
	}
	canon := n
	display := n
	if a, ok := nameAliases[n]; ok {
		canon = strings.ToLower(a)
		display = a
	}
	// IANA 索引(含 GBK/GB18030/Big5/Shift_JIS/EUC-JP/EUC-KR/Windows-1252 等,
	// 全部纯 Go 实现, 无需系统 iconv)。
	for _, idx := range []*ianaindex.Index{ianaindex.IANA, ianaindex.MIME} {
		if e, err := idx.Encoding(canon); err == nil && e != nil {
			return e, display, nil
		}
	}
	if e, err := ianaindex.IANA.Encoding(n); err == nil && e != nil {
		return e, display, nil
	}
	if e, err := ianaindex.MIME.Encoding(n); err == nil && e != nil {
		return e, display, nil
	}
	return nil, "", fmt.Errorf(
		"未知编码 %q: 可用 %s --list 查看内置编码; 若确需系统编码集, 可安装 locales 并 locale-gen(或升级 iconv 支持)",
		name, progName)
}

// resolveTargetEncoding 解析目标编码。UTF-16LE/BE 编码时不写 BOM(与 GNU iconv 一致);
// 解码侧仍由 resolveEncoding 负责剥离输入 BOM。
func resolveTargetEncoding(name string) (encoding.Encoding, string, error) {
	n := strings.ToLower(strings.TrimSpace(name))
	switch n {
	case "utf-16le", "utf16le", "utf-16-le":
		return unicode.UTF16(unicode.LittleEndian, unicode.IgnoreBOM), "UTF-16LE", nil
	case "utf-16be", "utf16be", "utf-16-be":
		return unicode.UTF16(unicode.BigEndian, unicode.IgnoreBOM), "UTF-16BE", nil
	}
	return resolveEncoding(name)
}

// localeRe 匹配 "zh_CN.GBK" / "en_US.UTF-8" 等 locale 名尾部的 charset 段。
var localeRe = regexp.MustCompile(`\.([A-Za-z0-9_@.-]+)\s*$`)

// systemCharset 从环境变量推断系统默认字符集(找不到返回 "")。
func systemCharset() string {
	for _, k := range []string{"LC_ALL", "LC_CTYPE", "LANG"} {
		v := os.Getenv(k)
		if v == "" {
			continue
		}
		// 可能含 ":"(如 LANG=zh_CN.GBK:en_US.UTF-8)——取第一段。
		first := strings.SplitN(v, ":", 2)[0]
		m := localeRe.FindStringSubmatch(strings.TrimSpace(first))
		if m == nil {
			continue
		}
		cs := strings.ToUpper(m[1])
		switch cs {
		case "UTF8", "UTF-8":
			return "UTF-8"
		case "GBK", "GB2312", "CP936", "MS936":
			return "GBK"
		case "GB18030":
			return "GB18030"
		case "BIG5", "CP950":
			return "Big5"
		case "SHIFT_JIS", "SJIS", "CP932", "MS932":
			return "Shift_JIS"
		case "EUC-JP", "EUCJP":
			return "EUC-JP"
		case "EUC-KR", "EUCKR", "CP949", "MS949":
			return "EUC-KR"
		case "WINDOWS-1252", "CP1252":
			return "Windows-1252"
		case "ISO-8859-1", "LATIN1":
			return "ISO-8859-1"
		case "KOI8-R":
			return "KOI8-R"
		default:
			// 未识别: 交给 resolveEncoding 尝试(如 UTF-16 变体等)。
			return m[1]
		}
	}
	return ""
}

// sniffEncoding 基于字节内容启发式判定编码(确定性优先)。
// 注意: UTF-16 判定须在 utf8.Valid 之前 —— ASCII 主导的 UTF-16LE 文本
// (如 'A\x00B\x00') 本身是合法 UTF-8, 若先做 UTF-8 校验会误判。
func sniffEncoding(data []byte) string {
	switch {
	case bytes.HasPrefix(data, []byte{0xEF, 0xBB, 0xBF}):
		return "UTF-8"
	case bytes.HasPrefix(data, []byte{0xFF, 0xFE}):
		return "UTF-16LE"
	case bytes.HasPrefix(data, []byte{0xFE, 0xFF}):
		return "UTF-16BE"
	case looksLikeUTF16LE(data):
		return "UTF-16LE"
	case utf8.Valid(data):
		return "UTF-8"
	case looksLikeGBK(data):
		return "GBK"
	}
	return ""
}

// looksLikeUTF16LE 识别无 BOM 的 UTF-16LE 文本(ASCII 主导):
// 偶数索引字节(每对的低字节之后)大量为 0 且占比 ≥90% 时判定。
// 中文等非 ASCII 主导的 UTF-16 不含此特征, 不会误判。
func looksLikeUTF16LE(data []byte) bool {
	if len(data) < 4 {
		return false
	}
	pairs := len(data) / 2
	if pairs < 2 {
		return false
	}
	zeros := 0
	for i := 1; i < len(data); i += 2 {
		if data[i] == 0 {
			zeros++
		}
	}
	return zeros*100 >= pairs*90
}

// looksLikeGBK 粗略统计: 大部分非 ASCII 字节构成 GBK 双字节
// (首字节 0x81-0xFE, 次字节 0x40-0xFE 且非 0x7F)。
func looksLikeGBK(data []byte) bool {
	nonASCII, validPairs := 0, 0
	for i := 0; i < len(data); i++ {
		b := data[i]
		if b < 0x80 {
			continue
		}
		nonASCII++
		if b >= 0x81 && b <= 0xFE && i+1 < len(data) {
			c := data[i+1]
			if c >= 0x40 && c <= 0xFE && c != 0x7F {
				validPairs++
				i++ // 消耗双字节
			}
		}
	}
	return nonASCII > 0 && validPairs*100 >= nonASCII*80
}

// detectSourceEncoding 综合 -from flag 与内容确定源编码。
// 返回 (编码, 显示名, 错误); 编码为 nil 表示按 UTF-8 原样处理。
func detectSourceEncoding(fromFlag string, data []byte) (encoding.Encoding, string, error) {
	if fromFlag != "" && fromFlag != "auto" {
		return resolveEncoding(fromFlag)
	}
	if s := sniffEncoding(data); s != "" {
		e, name, err := resolveEncoding(s)
		if err == nil {
			return e, name, nil
		}
	}
	if s := systemCharset(); s != "" {
		e, name, err := resolveEncoding(s)
		if err == nil && e != nil {
			fmt.Fprintf(os.Stderr, "%s: 警告: 未检测到内容编码, 按系统默认编码 %s 转换(可用 -from 显式指定)\n", progName, name)
			return e, name, nil
		}
	}
	fmt.Fprintln(os.Stderr, progName+": 警告: 未检测到源编码, 按 UTF-8 处理(可用 -from 指定)")
	return nil, "UTF-8", nil
}

// listEncodings 输出内置编码说明。
func listEncodings(w io.Writer) {
	names := make([]string, 0, len(nameAliases)+3)
	seen := map[string]bool{}
	for _, v := range nameAliases {
		if !seen[v] {
			seen[v] = true
			names = append(names, v)
		}
	}
	names = append(names, "UTF-16", "UTF-16LE", "UTF-16BE")
	sort.Strings(names)
	fmt.Fprintf(w, "内置常用编码(%d 个, 全部纯 Go 实现, 不依赖系统 iconv):\n", len(names))
	for _, n := range names {
		fmt.Fprintf(w, "  %s\n", n)
	}
	fmt.Fprintln(w, "另支持 IANA/MIME 注册的全部编码(经 golang.org/x/text)。")
	fmt.Fprintln(w, "用法示例: any2utf8 -from GBK 文件.txt > out.txt")
}

// convertReader 将 r 按 enc 解码后写入 w(流式)。
// x/text 解码器对非法字节序列返回错误(不静默替换), 转换失败即退出(fail-closed)。
func convertReader(r io.Reader, w io.Writer, enc encoding.Encoding) error {
	if enc == nil {
		_, err := io.Copy(w, r)
		return err
	}
	tr := transform.NewReader(r, enc.NewDecoder())
	_, err := io.Copy(w, tr)
	return err
}

// convertStrict 解码后统计 U+FFFD 替换符, >0 则失败(fail-closed)。
func convertStrict(data []byte, enc encoding.Encoding) ([]byte, error) {
	if enc == nil {
		if !utf8.Valid(data) {
			return nil, fmt.Errorf("strict: 输入含非法 UTF-8 字节序列")
		}
		return data, nil
	}
	out, err := io.ReadAll(transform.NewReader(bytes.NewReader(data), enc.NewDecoder()))
	if err != nil {
		return nil, err
	}
	if bytes.Contains(out, []byte{0xEF, 0xBF, 0xBD}) {
		return nil, fmt.Errorf("strict: 解码后出现替换字符(U+FFFD), 源编码判定可能错误(试试 -from 显式指定)")
	}
	return out, nil
}

// encodeTo 把 UTF-8 数据编码为目标编码(供 -to 使用)。
func encodeTo(data []byte, enc encoding.Encoding) ([]byte, error) {
	if enc == nil {
		return data, nil
	}
	return io.ReadAll(transform.NewReader(bytes.NewReader(data), enc.NewEncoder()))
}

// writeOutput 原子写文件: 临时文件 + rename(失败时保留原文件)。
// 权限: 目标已存在则保留其权限; 新建文件为 0644。
func writeOutput(path string, data []byte) error {
	dir := filepath.Dir(path)
	tmp, err := os.CreateTemp(dir, ".any2utf8-*.tmp")
	if err != nil {
		return fmt.Errorf("创建临时文件失败: %w", err)
	}
	tmpName := tmp.Name()
	cleanup := func() { _ = os.Remove(tmpName) }
	if fi, statErr := os.Stat(path); statErr == nil {
		_ = os.Chmod(tmpName, fi.Mode().Perm())
	} else {
		_ = os.Chmod(tmpName, 0o644)
	}
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		cleanup()
		return fmt.Errorf("写入失败: %w", err)
	}
	if err := tmp.Close(); err != nil {
		cleanup()
		return fmt.Errorf("关闭临时文件失败: %w", err)
	}
	if err := os.Rename(tmpName, path); err != nil {
		cleanup()
		return fmt.Errorf("替换目标失败: %w", err)
	}
	return nil
}

func printUsage(w io.Writer) {
	fmt.Fprintf(w, `%s —— 文本/文件转 UTF-8 工具(FasterEdge 系统初始工具)

用法:
  %s [选项] [文件...]          转换文件(缺省读标准输入)
  %s --list                   列出内置编码
  %s --sys-encoding           输出系统默认编码检测结果
  %s --detect [文件...]       仅探测源编码并输出(不转换)

选项:
  -from 编码      源编码(默认 auto: BOM → UTF-8 校验 → 系统默认 → GBK 启发)
  -to 编码        目标编码(默认 utf-8; 如 -to gbk 可反向转换)
  -output 文件    输出文件(默认 stdout; 与 -inplace 互斥)
  -inplace        原地转换(覆盖原文件; 需要文件参数)
  -strict         严格模式: 出现替换字符/非法序列即失败(exit 1)
  -version        打印版本
  -list           列出内置编码
  -detect         探测源编码并输出, 不转换
  -sys-encoding   输出系统默认编码检测结果
  -h, -help       显示本帮助

示例:
  any2utf8 -from GBK report.txt > report.utf8.txt      # GBK → UTF-8
  any2utf8 -inplace -from GB18030 old.txt              # 原地转 UTF-8
  cat log.txt | any2utf8 --detect                      # 探测标准输入编码
  any2utf8 -from GBK -to gbk -output back.txt a.txt    # 通用双向转换

说明:
  * 内置编码不依赖系统 iconv/编码集安装; 系统缺编码集时无需安装即可转换。
  * 未知编码名会给出 --list 提示; 若需系统级 locales 可安装并 locale-gen。
`, progName, progName, progName, progName, progName)
}

func main() {
	fs := flag.NewFlagSet(progName, flag.ContinueOnError)
	fs.Usage = func() { printUsage(fs.Output()) }
	fromFlag := fs.String("from", "", "源编码(默认 auto)")
	toFlag := fs.String("to", "utf-8", "目标编码(默认 utf-8)")
	outFlag := fs.String("output", "", "输出文件(默认 stdout)")
	inplace := fs.Bool("inplace", false, "原地转换")
	list := fs.Bool("list", false, "列出内置编码")
	detect := fs.Bool("detect", false, "仅探测源编码")
	sysEnc := fs.Bool("sys-encoding", false, "输出系统默认编码")
	strict := fs.Bool("strict", false, "严格模式")
	ver := fs.Bool("version", false, "打印版本")

	if err := fs.Parse(os.Args[1:]); err != nil {
		if errors.Is(err, flag.ErrHelp) {
			os.Exit(0) // -h/-help 已打印帮助, 正常退出
		}
		os.Exit(2)
	}

	switch {
	case *ver:
		fmt.Fprintln(os.Stdout, version)
		return
	case *list:
		listEncodings(os.Stdout)
		return
	case *sysEnc:
		cs := systemCharset()
		if cs == "" {
			fmt.Fprintln(os.Stdout, "未检测到系统默认编码(LC_ALL/LC_CTYPE/LANG 均未设置或无法解析)")
		} else {
			fmt.Fprintf(os.Stdout, "系统默认编码: %s\n", cs)
		}
		return
	}

	// 目标编码解析(-to)。
	var toEnc encoding.Encoding
	if *toFlag != "" && *toFlag != "auto" {
		e, _, err := resolveTargetEncoding(*toFlag)
		if err != nil {
			fmt.Fprintf(os.Stderr, "%s: %v\n", progName, err)
			os.Exit(2)
		}
		toEnc = e
	}

	if *outFlag != "" && *inplace {
		fmt.Fprintln(os.Stderr, progName+": -output 与 -inplace 互斥")
		os.Exit(2)
	}
	if *inplace && fs.NArg() == 0 {
		fmt.Fprintln(os.Stderr, progName+": -inplace 需要至少一个文件参数")
		os.Exit(2)
	}
	if *outFlag != "" && fs.NArg() > 1 {
		fmt.Fprintln(os.Stderr, progName+": 多文件时不能使用 -output(请用重定向或 -inplace)")
		os.Exit(2)
	}

	files := fs.Args()
	if len(files) == 0 {
		files = []string{"-"} // stdin
	}

	// 多文件逐个处理; 任一失败即停止(fail-closed)。
	for _, path := range files {
		var data []byte
		var err error
		if path == "-" {
			data, err = io.ReadAll(io.LimitReader(os.Stdin, 1<<30+1)) // 1GiB+1 上限, 超限可检出
			if err != nil {
				fmt.Fprintf(os.Stderr, "%s: 读取标准输入失败: %v\n", progName, err)
				os.Exit(1)
			}
			if len(data) > 1<<30 {
				fmt.Fprintln(os.Stderr, progName+": 标准输入超过 1GiB 上限, 拒绝处理")
				os.Exit(1)
			}
		} else {
			data, err = os.ReadFile(path)
			if err != nil {
				fmt.Fprintf(os.Stderr, "%s: %v\n", progName, err)
				os.Exit(1)
			}
		}

		srcEnc, srcName, err := detectSourceEncoding(*fromFlag, data)
		if err != nil {
			fmt.Fprintf(os.Stderr, "%s: %v\n", progName, err)
			os.Exit(1)
		}

		if *detect {
			if path == "-" {
				fmt.Fprintf(os.Stdout, "stdin: %s\n", srcName)
			} else {
				fmt.Fprintf(os.Stdout, "%s: %s\n", path, srcName)
			}
			continue
		}

		// 转换主体。
		var out []byte
		if *strict {
			utf8out, err := convertStrict(data, srcEnc)
			if err != nil {
				fmt.Fprintf(os.Stderr, "%s: %s: %v\n", progName, path, err)
				os.Exit(1)
			}
			out, err = encodeTo(utf8out, toEnc)
			if err != nil {
				fmt.Fprintf(os.Stderr, "%s: %s: 目标编码失败: %v\n", progName, path, err)
				os.Exit(1)
			}
		} else {
			var buf bytes.Buffer
			bw := bufio.NewWriter(&buf)
			if err := convertReader(bytes.NewReader(data), bw, srcEnc); err != nil {
				fmt.Fprintf(os.Stderr, "%s: %s: 转换失败: %v\n", progName, path, err)
				os.Exit(1)
			}
			if err := bw.Flush(); err != nil {
				fmt.Fprintf(os.Stderr, "%s: %s: 转换失败: %v\n", progName, path, err)
				os.Exit(1)
			}
			out, err = encodeTo(buf.Bytes(), toEnc)
			if err != nil {
				fmt.Fprintf(os.Stderr, "%s: %s: 目标编码失败: %v\n", progName, path, err)
				os.Exit(1)
			}
		}

		// 输出。
		switch {
		case *inplace:
			if err := writeOutput(path, out); err != nil {
				fmt.Fprintf(os.Stderr, "%s: %s: %v\n", progName, path, err)
				os.Exit(1)
			}
		case *outFlag != "":
			if len(files) > 1 {
				fmt.Fprintf(os.Stderr, "%s: 多文件时不能使用 -output(请用重定向或 -inplace)\n", progName)
				os.Exit(2)
			}
			if err := writeOutput(*outFlag, out); err != nil {
				fmt.Fprintf(os.Stderr, "%s: %v\n", progName, err)
				os.Exit(1)
			}
		default:
			if _, err := os.Stdout.Write(out); err != nil {
				fmt.Fprintf(os.Stderr, "%s: 写标准输出失败: %v\n", progName, err)
				os.Exit(1)
			}
		}
	}
}
