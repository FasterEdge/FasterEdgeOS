// FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge
//
// any2pcd —— 文本/二进制点云转 PCD 工具(Go, 零第三方依赖)。
//
// 与系统/第三方点云工具的关键差异:
//   - 保持时序: 转换过程严格按输入点的原始顺序写出, 不做任何排序/去重/重排;
//     bin 中的时间戳字段(如第 4 列 timestamp)可经 -fields 映射到 PCD 字段保留。
//   - UTF-8 无 BOM: 输出文件为 UTF-8(无 BOM)编码; PCD 内容为 ASCII 子集,
//     不依赖系统 locale, 任何环境解码一致。
//   - 输入自动探测: 按扩展名与内容识别 bin(float32 序列)/ text / csv / PCD
//     (ASCII 或 binary), 无需手动指定。
package main

import (
	"bufio"
	"bytes"
	"encoding/binary"
	"errors"
	"flag"
	"fmt"
	"io"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

// progName 与 any2utf8 风格一致的进程名。
const progName = "any2pcd"

// 默认最大字段数(bin 自动探测上限)。
const maxFields = 16

// fieldNameRe 校验 PCD 字段名: 仅 ASCII 字母/数字/下划线, 首字符字母或下划线。
var fieldNameRe = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*$`)

// version 与 FasterEdge 版本链一致的语义化版本。
const version = "1.0.20260913"

// Field 描述输出 PCD 的一个字段。
type Field struct {
	Name string
	// Size 为字节宽度(当前仅支持 4 字节 float32)。
	Size int
	// Type 为 PCD TYPE 字符('F')。
	Type byte
}

func (f Field) String() string { return f.Name }

// options 汇总命令行选项。
type options struct {
	from     string // auto | bin | text | csv | pcd
	fields   string // 逗号分隔字段名(空 = 按输入探测的默认命名)
	binary   bool   // 输出 binary PCD(DATA binary)
	output   string // 单输入时的输出文件(缺省 stdout)
	outdir   string // 多输入时的输出目录(缺省当前目录)
	strict   bool   // 严格模式: NaN/Inf/坏行即失败
	skipBad  bool   // 跳过坏行(仅 text/csv)
	showVer  bool   // 打印版本
	noHeader bool   // 保留内部标志位(未来扩展), 当前无效果
}

// parseFields 把 "x,y,z" 解析为字段名切片并逐个校验。
func parseFields(s string) ([]string, error) {
	if s == "" {
		return nil, nil
	}
	parts := strings.Split(s, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p == "" {
			return nil, fmt.Errorf("字段名不能为空(格式: x,y,z)")
		}
		if !fieldNameRe.MatchString(p) {
			return nil, fmt.Errorf("非法字段名 %q: 仅允许 ASCII 字母/数字/下划线", p)
		}
		out = append(out, p)
	}
	return out, nil
}

// defaultFieldNames 按列数给出默认字段名。
//
//	3 列 -> x y z; 4 列 -> x y z intensity; 6 列 -> x y z r g b;
//	7 列 -> x y z intensity r g b; 其余 -> x y z feature0..featureN。
func defaultFieldNames(n int) []string {
	if n < 1 {
		return nil
	}
	if n < 3 {
		names := make([]string, n)
		for i := range names {
			names[i] = fmt.Sprintf("feature%d", i)
		}
		return names
	}
	switch n {
	case 3:
		return []string{"x", "y", "z"}
	case 4:
		return []string{"x", "y", "z", "intensity"}
	case 6:
		return []string{"x", "y", "z", "r", "g", "b"}
	case 7:
		return []string{"x", "y", "z", "intensity", "r", "g", "b"}
	}
	names := make([]string, 0, n)
	names = append(names, "x", "y", "z")
	for i := 3; i < n; i++ {
		names = append(names, fmt.Sprintf("feature%d", i-3))
	}
	return names
}

// makeFields 构造 Field 切片(当前统一 float32)。
func makeFields(names []string) []Field {
	fs := make([]Field, len(names))
	for i, n := range names {
		fs[i] = Field{Name: n, Size: 4, Type: 'F'}
	}
	return fs
}

// points 为内存中的点集(每点 float64 行)。
type points struct {
	fields []Field
	rows   [][]float64
}

func (p *points) count() int { return len(p.rows) }

// ---------------------------------------------------------------------------
// 输入解析
// ---------------------------------------------------------------------------

// detectFrom 按扩展名与首字节探测输入格式。
func detectFrom(name string, head []byte) string {
	ext := strings.ToLower(filepath.Ext(name))
	switch ext {
	case ".bin":
		return "bin"
	case ".csv":
		return "csv"
	case ".pcd":
		return "pcd"
	}
	if len(head) > 0 {
		first := head
		if len(first) > 64 {
			first = first[:64]
		}
		low := strings.ToLower(string(first))
		if strings.Contains(low, "# .pcd") || strings.HasPrefix(low, "version 0.") {
			return "pcd"
		}
	}
	return "text"
}

// readBin 解析二进制点云(每点 n×float32, little-endian)。
func readBin(data []byte, n int) ([][]float64, error) {
	per := n * 4
	if per == 0 || len(data)%per != 0 {
		return nil, fmt.Errorf("bin 数据大小 %d 不能被每点 %d 字节整除", len(data), per)
	}
	count := len(data) / per
	rows := make([][]float64, 0, count)
	buf := make([]byte, 4)
	for i := 0; i < count; i++ {
		row := make([]float64, n)
		for j := 0; j < n; j++ {
			copy(buf, data[(i*n+j)*4:])
			v := math.Float32frombits(binary.LittleEndian.Uint32(buf))
			row[j] = float64(v)
		}
		rows = append(rows, row)
	}
	return rows, nil
}

// splitLine 按分隔符切分一行(空格/Tab/逗号)。
func splitLine(line string, sep byte) []string {
	if sep == ',' {
		return strings.Split(line, ",")
	}
	return strings.FieldsFunc(line, func(r rune) bool {
		return r == ' ' || r == '\t' || r == '\r'
	})
}

// parseRow 把一行转为 float64 切片。
func parseRow(parts []string) ([]float64, error) {
	row := make([]float64, len(parts))
	for i, s := range parts {
		v, err := strconv.ParseFloat(strings.TrimSpace(s), 32)
		if err != nil {
			return nil, fmt.Errorf("列 %d 的值 %q 不是数字: %v", i+1, s, err)
		}
		row[i] = v
	}
	return row, nil
}

// readText 解析逐行文本点云(text/csv)。
func readText(data []byte, sep byte, skipBad bool) ([][]float64, error) {
	sc := bufio.NewScanner(bytes.NewReader(data))
	sc.Buffer(make([]byte, 64*1024), 16*1024*1024)
	var rows [][]float64
	nCols := -1
	lineNo := 0
	for sc.Scan() {
		lineNo++
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := splitLine(line, sep)
		if len(parts) == 0 {
			continue
		}
		row, err := parseRow(parts)
		if err != nil {
			if skipBad {
				continue
			}
			return nil, fmt.Errorf("第 %d 行: %v", lineNo, err)
		}
		if nCols == -1 {
			nCols = len(row)
		} else if len(row) != nCols {
			if skipBad {
				continue
			}
			return nil, fmt.Errorf("第 %d 行列数 %d 与首行列数 %d 不一致", lineNo, len(row), nCols)
		}
		rows = append(rows, row)
	}
	if err := sc.Err(); err != nil {
		return nil, err
	}
	return rows, nil
}

// parsePCDHeader 解析 PCD 头部, 返回字段名/点数/数据模式/body 偏移。
func parsePCDHeader(data []byte) (names []string, sizes []int, types []byte, count int, binaryMode bool, bodyStart int, err error) {
	sc := bufio.NewScanner(bytes.NewReader(data))
	sc.Buffer(make([]byte, 64*1024), 16*1024*1024)
	var fieldsLine, sizeLine, typeLine string
	lineNo := 0
	for sc.Scan() {
		lineNo++
		line := strings.TrimSpace(sc.Text())
		if line == "" {
			continue
		}
		if strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.Fields(line)
		if len(parts) == 0 {
			continue
		}
		key := parts[0]
		rest := parts[1:]
		switch key {
		case "VERSION":
			// 忽略版本差异, 只要以 VERSION 开头即视为 PCD。
		case "FIELDS":
			fieldsLine = strings.Join(rest, " ")
			names = rest
		case "SIZE":
			sizeLine = strings.Join(rest, " ")
			for _, s := range rest {
				v, e := strconv.Atoi(s)
				if e != nil {
					return nil, nil, nil, 0, false, 0, fmt.Errorf("PCD SIZE %q 非法", s)
				}
				sizes = append(sizes, v)
			}
		case "TYPE":
			typeLine = strings.Join(rest, " ")
			types = append(types, []byte(strings.Join(rest, ""))...)
		case "COUNT":
			// 仅支持每字段 COUNT=1; 其余拒绝(保持简单)。
			for _, s := range rest {
				if s != "1" {
					return nil, nil, nil, 0, false, 0, fmt.Errorf("不支持 COUNT=%s(仅支持每字段 1)", s)
				}
			}
		case "POINTS":
			if len(rest) == 0 {
				return nil, nil, nil, 0, false, 0, errors.New("PCD POINTS 行缺少数值")
			}
			v, e := strconv.Atoi(rest[0])
			if e != nil || v < 0 {
				return nil, nil, nil, 0, false, 0, fmt.Errorf("POINTS %q 非法", rest[0])
			}
			count = v
		case "DATA":
			mode := "ascii"
			if len(rest) > 0 {
				mode = strings.ToLower(rest[0])
			}
			binaryMode = mode == "binary"
			if mode != "ascii" && mode != "binary" {
				return nil, nil, nil, 0, false, 0, fmt.Errorf("不支持 DATA 模式 %q", mode)
			}
			bodyStart = headerEndOffset(data, lineNo)
			if bodyStart < 0 {
				return nil, nil, nil, 0, false, 0, errors.New("PCD 头解析失败")
			}
			return names, sizes, types, count, binaryMode, bodyStart, nil
		default:
			// WIDTH/HEIGHT/VIEWPOINT 等忽略。
		}
	}
	_ = fieldsLine
	_ = sizeLine
	_ = typeLine
	return nil, nil, nil, 0, false, 0, errors.New("未找到 DATA 行, 不是有效 PCD")
}

// headerEndOffset 计算 DATA 行结束后的字节偏移(即 body 起点)。
func headerEndOffset(data []byte, dataLine int) int {
	offset := 0
	line := 0
	for _, b := range data {
		offset++
		if b == '\n' {
			line++
			if line == dataLine {
				return offset
			}
		}
	}
	return -1
}

// readPCD 解析 PCD 输入(ASCII 或 binary), 保持原字段与顺序。
func readPCD(data []byte) (names []string, rows [][]float64, err error) {
	names, sizes, types, count, binaryMode, bodyStart, err := parsePCDHeader(data)
	if err != nil {
		return nil, nil, err
	}
	n := len(names)
	if n == 0 {
		return nil, nil, errors.New("PCD FIELDS 为空")
	}
	if len(sizes) != n || len(types) != n {
		return nil, nil, fmt.Errorf("PCD 头不一致: FIELDS %d 个, SIZE %d 个, TYPE %d 个", n, len(sizes), len(types))
	}
	for i := range sizes {
		if sizes[i] != 4 {
			return nil, nil, fmt.Errorf("不支持字段 %q 的 SIZE=%d(仅支持 4 字节)", names[i], sizes[i])
		}
		if types[i] != 'F' && types[i] != 'U' && types[i] != 'I' {
			return nil, nil, fmt.Errorf("不支持字段 %q 的 TYPE=%c", names[i], types[i])
		}
	}
	body := data[bodyStart:]
	if binaryMode {
		per := n * 4
		if per == 0 || len(body) < per*count {
			return nil, nil, fmt.Errorf("PCD binary body 大小不足: 需要 %d 字节, 实得 %d", per*count, len(body))
		}
		buf := make([]byte, 4)
		for i := 0; i < count; i++ {
			row := make([]float64, n)
			for j := 0; j < n; j++ {
				copy(buf, body[(i*n+j)*4:])
				raw := binary.LittleEndian.Uint32(buf)
				if types[j] == 'F' {
					row[j] = float64(math.Float32frombits(raw))
				} else if types[j] == 'U' {
					row[j] = float64(raw)
				} else {
					row[j] = float64(int32(raw))
				}
			}
			rows = append(rows, row)
		}
		return names, rows, nil
	}
	// ASCII 模式: 逐行解析, 行数应与 POINTS 一致。
	sc := bufio.NewScanner(bytes.NewReader(body))
	sc.Buffer(make([]byte, 64*1024), 16*1024*1024)
	lineNo := 0
	for sc.Scan() {
		lineNo++
		line := strings.TrimSpace(sc.Text())
		if line == "" {
			continue
		}
		parts := strings.Fields(line)
		if len(parts) != n {
			return nil, nil, fmt.Errorf("PCD 第 %d 行列数 %d 与 FIELDS 数 %d 不一致", lineNo, len(parts), n)
		}
		row := make([]float64, n)
		for i, s := range parts {
			v, e := strconv.ParseFloat(s, 32)
			if e != nil {
				return nil, nil, fmt.Errorf("PCD 第 %d 行第 %d 列 %q 非法: %v", lineNo, i+1, s, e)
			}
			row[i] = v
		}
		rows = append(rows, row)
	}
	if err := sc.Err(); err != nil {
		return nil, nil, err
	}
	if len(rows) != count {
		return nil, nil, fmt.Errorf("PCD POINTS=%d 与数据行数 %d 不一致", count, len(rows))
	}
	return names, rows, nil
}

// loadPoints 按指定格式加载点集。
func loadPoints(from string, data []byte, name string, opts *options) (*points, error) {
	var rows [][]float64
	var names []string
	var err error
	switch from {
	case "bin":
		nFields := 0
		if opts.fields != "" {
			names, err = parseFields(opts.fields)
			if err != nil {
				return nil, err
			}
			nFields = len(names)
		} else {
			// 自动探测: 从 3 开始找第一个能整除的字段数。
			for n := 3; n <= maxFields; n++ {
				if len(data)%(n*4) == 0 {
					nFields = n
					names = defaultFieldNames(n)
					break
				}
			}
			if nFields == 0 {
				return nil, fmt.Errorf("bin 数据大小 %d 无法匹配 3..%d 个 float32 字段", len(data), maxFields)
			}
		}
		if len(data)%(nFields*4) != 0 {
			return nil, fmt.Errorf("bin 数据大小 %d 不能被 %d 字段 × 4 字节整除", len(data), nFields)
		}
		rows, err = readBin(data, nFields)
		if err != nil {
			return nil, err
		}
	case "text", "csv":
		sep := byte(' ')
		if from == "csv" {
			sep = ','
		}
		rows, err = readText(data, sep, opts.skipBad)
		if err != nil {
			return nil, err
		}
		if len(rows) == 0 {
			return nil, errors.New("未解析到任何点(空输入?)")
		}
		n := len(rows[0])
		if opts.fields != "" {
			names, err = parseFields(opts.fields)
			if err != nil {
				return nil, err
			}
			if len(names) != n {
				return nil, fmt.Errorf("-fields 指定 %d 个字段, 但输入每行 %d 列", len(names), n)
			}
		} else {
			names = defaultFieldNames(n)
		}
	case "pcd":
		names, rows, err = readPCD(data)
		if err != nil {
			return nil, err
		}
	default:
		return nil, fmt.Errorf("未知格式 %q(可选 auto/bin/text/csv/pcd)", from)
	}
	if len(names) == 0 {
		return nil, errors.New("未解析到字段名")
	}
	if opts.strict {
		for ri, row := range rows {
			for ci, v := range row {
				if math.IsNaN(v) || math.IsInf(v, 0) {
					return nil, fmt.Errorf("严格模式: 第 %d 点第 %d 列为 NaN/Inf", ri+1, ci+1)
				}
			}
		}
	}
	return &points{fields: makeFields(names), rows: rows}, nil
}

// ---------------------------------------------------------------------------
// 输出
// ---------------------------------------------------------------------------

// writeHeader 写出 PCD 头部。
func writeHeader(w io.Writer, fs []Field, count int, binaryMode bool) error {
	names := make([]string, len(fs))
	sizes := make([]string, len(fs))
	types := make([]string, len(fs))
	for i, f := range fs {
		names[i] = f.Name
		sizes[i] = strconv.Itoa(f.Size)
		types[i] = string([]byte{f.Type})
	}
	lines := []string{
		"# .PCD v0.7 - Point Cloud Data file format",
		"VERSION 0.7",
		"FIELDS " + strings.Join(names, " "),
		"SIZE " + strings.Join(sizes, " "),
		"TYPE " + strings.Join(types, " "),
		"COUNT " + strings.TrimSpace(strings.Repeat("1 ", len(fs))),
		fmt.Sprintf("WIDTH %d", count),
		"HEIGHT 1",
		"VIEWPOINT 0 0 0 1 0 0 0",
		fmt.Sprintf("POINTS %d", count),
	}
	if binaryMode {
		lines = append(lines, "DATA binary")
	} else {
		lines = append(lines, "DATA ascii")
	}
	out := strings.Join(lines, "\n") + "\n"
	_, err := io.WriteString(w, out)
	return err
}

// formatFloat 输出 float32 的最短无损表示(UTF-8/ASCII 兼容)。
func formatFloat(v float64) string {
	return strconv.FormatFloat(v, 'g', -1, 32)
}

// writeASCII 逐点写 ASCII 行(保持输入时序)。
func writeASCII(w io.Writer, fs []Field, rows [][]float64) error {
	for _, row := range rows {
		parts := make([]string, len(row))
		for i, v := range row {
			parts[i] = formatFloat(v)
		}
		if _, err := io.WriteString(w, strings.Join(parts, " ")+"\n"); err != nil {
			return err
		}
	}
	return nil
}

// writeBinary 逐点写二进制 body(little-endian float32, 保持输入时序)。
func writeBinary(w io.Writer, fs []Field, rows [][]float64) error {
	buf := make([]byte, 4)
	for _, row := range rows {
		for _, v := range row {
			binary.LittleEndian.PutUint32(buf, math.Float32bits(float32(v)))
			if _, err := w.Write(buf); err != nil {
				return err
			}
		}
	}
	return nil
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

func usage(fs *flag.FlagSet) {
	out := fs.Output()
	fmt.Fprintf(out, "%s —— 文本/二进制点云转 PCD 工具(FasterEdge)\n\n", progName)
	fmt.Fprintf(out, "用法:\n  %s [选项] [文件...]      # 转换文件, 缺省读标准输入\n", progName)
	fmt.Fprintf(out, "  cat x.bin | %s -from bin    # 从标准输入读取\n", progName)
	fmt.Fprintf(out, "\n选项:\n")
	fs.PrintDefaults()
	fmt.Fprintf(out, `
输入格式(-from auto 按扩展名/内容自动探测):
  bin   每点 N×float32(little-endian), 自动探测字段数(3..16); 常见 KITTI 为 4 字段
        (x y z intensity)。带时间戳的雷达 bin 用 -fields "x,y,z,timestamp" 映射。
  text  逐行空格/Tab 分隔数字(3/4/6/7 列自动命名, 其余 feature0..)
  csv   逗号分隔(同 text)
  pcd   已是 PCD 的文件(ASCII 或 binary, 仅支持 4 字节数值字段)——可做格式重编码

要点:
  - 保持时序: 严格按输入顺序写出点, 不排序/去重/重排
  - UTF-8 无 BOM: 输出为 UTF-8(无 BOM); PCD 内容为 ASCII 子集, 不依赖 locale
`)
}

func run(args []string, stdout, stderr io.Writer) int {
	fs := flag.NewFlagSet(progName, flag.ContinueOnError)
	fs.SetOutput(stderr)
	var opts options
	fs.StringVar(&opts.from, "from", "auto", "输入格式: auto|bin|text|csv|pcd")
	fs.StringVar(&opts.fields, "fields", "", "字段名(逗号分隔, 如 x,y,z,intensity 或 x,y,z,timestamp)")
	fs.BoolVar(&opts.binary, "binary", false, "输出二进制 PCD(DATA binary)")
	fs.StringVar(&opts.output, "output", "", "输出文件(仅单输入; 缺省标准输出)")
	fs.StringVar(&opts.outdir, "outdir", ".", "多输入时的输出目录")
	fs.BoolVar(&opts.strict, "strict", false, "严格模式: NaN/Inf/坏行/列数不一致即失败")
	fs.BoolVar(&opts.skipBad, "skip-bad", false, "跳过坏行(仅 text/csv, 默认失败)")
	fs.BoolVar(&opts.showVer, "version", false, "打印版本")
	fs.Usage = func() { usage(fs) }

	if err := fs.Parse(args); err != nil {
		return 2
	}
	if opts.showVer {
		fmt.Fprintln(stdout, version)
		return 0
	}
	inputs := fs.Args()
	if len(inputs) > 1 && opts.output != "" {
		fmt.Fprintln(stderr, "错误: 多输入时不能用 -output, 请用 -outdir")
		return 2
	}
	from := opts.from // auto 由 convert 内 detectFrom 按扩展名/内容决定(stdin 亦按内容探测)

	convert := func(name string, data []byte, toStdout bool) error {
		f := from
		if f == "auto" {
			f = detectFrom(name, data)
		}
		pt, err := loadPoints(f, data, name, &opts)
		if err != nil {
			return err
		}
		var buf bytes.Buffer
		if err := writeHeader(&buf, pt.fields, pt.count(), opts.binary); err != nil {
			return err
		}
		if opts.binary {
			if err := writeBinary(&buf, pt.fields, pt.rows); err != nil {
				return err
			}
		} else {
			if err := writeASCII(&buf, pt.fields, pt.rows); err != nil {
				return err
			}
		}
		if toStdout {
			_, err = stdout.Write(buf.Bytes())
			return err
		}
		outPath := opts.output
		if outPath == "" {
			base := strings.TrimSuffix(filepath.Base(name), filepath.Ext(name))
			if base == "" {
				base = "output"
			}
			outPath = filepath.Join(opts.outdir, base+".pcd")
		}
		if dir := filepath.Dir(outPath); dir != "." {
			if err := os.MkdirAll(dir, 0o755); err != nil {
				return err
			}
		}
		return os.WriteFile(outPath, buf.Bytes(), 0o644)
	}

	// 输出目标: 无输入 -> stdout; 单输入且未给 -output -> stdout;
	// 单输入给 -output -> 写文件; 多输入 -> -outdir 派生文件名。
	toStdout := len(inputs) == 0 || (opts.output == "" && len(inputs) == 1)
	if len(inputs) == 0 {
		data, err := io.ReadAll(stdinReader())
		if err != nil {
			fmt.Fprintf(stderr, "错误: 读取标准输入失败: %v\n", err)
			return 1
		}
		if err := convert("<stdin>", data, true); err != nil {
			fmt.Fprintf(stderr, "错误: %v\n", err)
			return 1
		}
		return 0
	}
	failed := false
	for _, in := range inputs {
		data, err := os.ReadFile(in)
		if err != nil {
			fmt.Fprintf(stderr, "错误: %s: %v\n", in, err)
			failed = true
			continue
		}
		if err := convert(in, data, toStdout); err != nil {
			fmt.Fprintf(stderr, "错误: %s: %v\n", in, err)
			failed = true
			continue
		}
		if !toStdout {
			base := strings.TrimSuffix(filepath.Base(in), filepath.Ext(in))
			if base == "" {
				base = "output"
			}
			fmt.Fprintf(stderr, "已转换: %s -> %s\n", in, filepath.Join(opts.outdir, base+".pcd"))
		}
	}
	if failed {
		return 1
	}
	return 0
}

var stdinReader = func() io.Reader { return os.Stdin }

func main() {
	os.Exit(run(os.Args[1:], os.Stdout, os.Stderr))
}
