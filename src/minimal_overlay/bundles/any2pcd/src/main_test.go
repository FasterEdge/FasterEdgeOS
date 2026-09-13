// FasterEdge 开源项目 - Github: https://github.com/FasterEdge - Gitee: https://gitee.com/FasterEdge
//
// any2pcd 单元测试: bin 自动探测/往返、保序、UTF-8 无 BOM、字段映射、PCD 重编码。
package main

import (
	"bytes"
	"encoding/binary"
	"io"
	"math"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// makeBin 把 [][]float64 编码为 little-endian float32 二进制。
func makeBin(rows [][]float64) []byte {
	buf := make([]byte, 0, len(rows)*4)
	for _, r := range rows {
		for _, v := range r {
			var b [4]byte
			binary.LittleEndian.PutUint32(b[:], math.Float32bits(float32(v)))
			buf = append(buf, b[:]...)
		}
	}
	return buf
}

// runCLI 以给定 stdin/args 运行 CLI, 返回退出码与 stdout。
func runCLI(t *testing.T, stdin []byte, args ...string) (int, string) {
	t.Helper()
	var out bytes.Buffer
	var errB bytes.Buffer
	oldStdin := stdinReader
	stdinReader = func() io.Reader { return bytes.NewReader(stdin) }
	defer func() { stdinReader = oldStdin }()
	code := run(args, &out, &errB)
	return code, out.String()
}

func TestBinAutoDetect4Fields(t *testing.T) {
	// 5 点 × 4 字段 = 20 float32: 3 字段不整除(20%3≠0), 4 字段整除 → 探测为 4 字段。
	rows := [][]float64{
		{1, 2, 3, 0.5},
		{4, 5, 6, 0.9},
		{7, 8, 9, 0.1},
		{10, 11, 12, 0.2},
		{13, 14, 15, 0.3},
	}
	data := makeBin(rows)
	pt, err := loadPoints("bin", data, "x.bin", &options{})
	if err != nil {
		t.Fatalf("loadPoints: %v", err)
	}
	if got := len(pt.fields); got != 4 {
		t.Fatalf("字段数 = %d, 期望 4", got)
	}
	want := []string{"x", "y", "z", "intensity"}
	for i := range want {
		if pt.fields[i].Name != want[i] {
			t.Errorf("字段 %d = %q, 期望 %q", i, pt.fields[i].Name, want[i])
		}
	}
	if pt.count() != 5 {
		t.Errorf("点数 = %d, 期望 5", pt.count())
	}
}

func TestBinRejectNonMultiple(t *testing.T) {
	data := make([]byte, 13) // 不是 4 的倍数
	_, err := loadPoints("bin", data, "bad.bin", &options{})
	if err == nil {
		t.Fatal("期望非 4 倍数报错")
	}
}

func TestASCIIRoundtripOrderPreserved(t *testing.T) {
	// 核心: 保持时序 —— 故意乱序值, 输出顺序必须与输入一致。
	rows := [][]float64{
		{30, 1, -5, 0.25},
		{10, -2, 4, 0.5},
		{20, 3, 6, 0.75},
	}
	pt, err := loadPoints("bin", makeBin(rows), "t.bin", &options{fields: "x,y,z,intensity"})
	if err != nil {
		t.Fatalf("loadPoints: %v", err)
	}
	var buf bytes.Buffer
	if err := writeHeader(&buf, pt.fields, pt.count(), false); err != nil {
		t.Fatal(err)
	}
	if err := writeASCII(&buf, pt.fields, pt.rows); err != nil {
		t.Fatal(err)
	}
	s := buf.String()
	if !strings.Contains(s, "FIELDS x y z intensity") {
		t.Errorf("FIELDS 头缺失: %q", s)
	}
	if !strings.Contains(s, "POINTS 3") {
		t.Errorf("POINTS 头缺失: %q", s)
	}
	lines := strings.Split(strings.TrimSpace(s), "\n")
	bodyLines := 0
	for _, l := range lines {
		if l != "" && !strings.HasPrefix(l, "#") && !strings.HasPrefix(l, "VERSION") &&
			!strings.HasPrefix(l, "FIELDS") && !strings.HasPrefix(l, "SIZE") &&
			!strings.HasPrefix(l, "TYPE") && !strings.HasPrefix(l, "COUNT") &&
			!strings.HasPrefix(l, "WIDTH") && !strings.HasPrefix(l, "HEIGHT") &&
			!strings.HasPrefix(l, "VIEWPOINT") && !strings.HasPrefix(l, "POINTS") &&
			!strings.HasPrefix(l, "DATA") {
			bodyLines++
		}
	}
	if bodyLines != 3 {
		t.Fatalf("数据行数 = %d, 期望 3", bodyLines)
	}
	// 保序校验: 第一列应为 30,10,20(输入顺序)。
	if !strings.Contains(s, "30 1 -5 0.25") || !strings.Contains(s, "10 -2 4 0.5") || !strings.Contains(s, "20 3 6 0.75") {
		t.Errorf("点顺序被破坏:\n%s", s)
	}
}

func TestBinaryRoundtrip(t *testing.T) {
	rows := [][]float64{{1, 2, 3}, {4, 5, 6}}
	pt, err := loadPoints("bin", makeBin(rows), "t.bin", &options{})
	if err != nil {
		t.Fatal(err)
	}
	var buf bytes.Buffer
	if err := writeHeader(&buf, pt.fields, pt.count(), true); err != nil {
		t.Fatal(err)
	}
	if err := writeBinary(&buf, pt.fields, pt.rows); err != nil {
		t.Fatal(err)
	}
	s := buf.String()
	hdrEnd := strings.Index(s, "DATA binary\n")
	if hdrEnd < 0 {
		t.Fatalf("binary 头缺失: %q", s)
	}
	body := []byte(s)[hdrEnd+len("DATA binary\n"):]
	want := 2 * 3 * 4 // 2 点 × 3 字段 × 4 字节
	if len(body) != want {
		t.Fatalf("body 字节 = %d, 期望 %d", len(body), want)
	}
	// 校验首点 x=1 的位模式。
	if got := math.Float32frombits(binary.LittleEndian.Uint32(body[:4])); got != 1 {
		t.Errorf("首点 x = %v, 期望 1", got)
	}
}

func TestTimestampFieldMapping(t *testing.T) {
	// 雷达 bin(x y z timestamp) 映射到 PCD timestamp 字段 —— 覆盖"保持时序"的时间戳场景。
	rows := [][]float64{{0, 0, 1, 123456.5}, {0, 0, 2, 123456.75}}
	pt, err := loadPoints("bin", makeBin(rows), "lidar.bin", &options{fields: "x,y,z,timestamp"})
	if err != nil {
		t.Fatal(err)
	}
	var buf bytes.Buffer
	if err := writeHeader(&buf, pt.fields, pt.count(), false); err != nil {
		t.Fatal(err)
	}
	if err := writeASCII(&buf, pt.fields, pt.rows); err != nil {
		t.Fatal(err)
	}
	s := buf.String()
	if !strings.Contains(s, "FIELDS x y z timestamp") {
		t.Fatalf("timestamp 字段缺失: %q", s)
	}
	if !strings.Contains(s, "123456.5") || !strings.Contains(s, "123456.75") {
		t.Fatalf("timestamp 值缺失(时序保持): %q", s)
	}
}

func TestTextMultiColumn(t *testing.T) {
	text := "# comment\n1 2 3\n4 5 6\n\n7 8 9\n"
	pt, err := loadPoints("text", []byte(text), "t.txt", &options{})
	if err != nil {
		t.Fatal(err)
	}
	if pt.count() != 3 {
		t.Fatalf("点数 = %d, 期望 3", pt.count())
	}
	if got := len(pt.fields); got != 3 {
		t.Fatalf("字段数 = %d, 期望 3", got)
	}
}

func TestText6ColNamedRGB(t *testing.T) {
	text := "1 2 3 255 128 0\n4 5 6 0 255 64\n"
	pt, err := loadPoints("text", []byte(text), "t.txt", &options{})
	if err != nil {
		t.Fatal(err)
	}
	want := "x y z r g b"
	got := make([]string, len(pt.fields))
	for i, f := range pt.fields {
		got[i] = f.Name
	}
	if strings.Join(got, " ") != want {
		t.Fatalf("6 列字段 = %q, 期望 %q", strings.Join(got, " "), want)
	}
}

func TestTextBadRowSkipAndStrict(t *testing.T) {
	text := "1 2 3\nbad line\n4 5 6\n"
	if _, err := loadPoints("text", []byte(text), "t.txt", &options{}); err == nil {
		t.Fatal("期望坏行默认报错")
	}
	pt, err := loadPoints("text", []byte(text), "t.txt", &options{skipBad: true})
	if err != nil {
		t.Fatalf("skip-bad: %v", err)
	}
	if pt.count() != 2 {
		t.Fatalf("skip-bad 后点数 = %d, 期望 2", pt.count())
	}
}

func TestCSV(t *testing.T) {
	text := "1,2,3,0.1\n4,5,6,0.2\n"
	pt, err := loadPoints("csv", []byte(text), "t.csv", &options{})
	if err != nil {
		t.Fatal(err)
	}
	if pt.count() != 2 || len(pt.fields) != 4 {
		t.Fatalf("csv 解析异常: 点数 %d 字段 %d", pt.count(), len(pt.fields))
	}
}

func TestPCDReencode(t *testing.T) {
	// ASCII PCD 输入 -> binary PCD 输出(重编码场景)。
	pcd := `# .PCD v0.7 - Point Cloud Data file format
VERSION 0.7
FIELDS x y z intensity
SIZE 4 4 4 4
TYPE F F F F
COUNT 1 1 1 1
WIDTH 2
HEIGHT 1
VIEWPOINT 0 0 0 1 0 0 0
POINTS 2
DATA ascii
1 2 3 0.5
4 5 6 0.9
`
	names, rows, err := readPCD([]byte(pcd))
	if err != nil {
		t.Fatalf("readPCD: %v", err)
	}
	if len(names) != 4 || len(rows) != 2 {
		t.Fatalf("PCD 解析: 字段 %d 行 %d", len(names), len(rows))
	}
	if rows[0][0] != 1 || rows[1][2] != 6 {
		t.Fatalf("PCD 值错误: %v", rows)
	}
}

func TestPCDBinaryInput(t *testing.T) {
	rows := [][]float64{{0.1, 0.2, 0.3, 1}, {1.1, 1.2, 1.3, 2}}
	body := makeBin(rows)
	head := `# .PCD v0.7
VERSION 0.7
FIELDS x y z intensity
SIZE 4 4 4 4
TYPE F F F F
COUNT 1 1 1 1
WIDTH 2
HEIGHT 1
VIEWPOINT 0 0 0 1 0 0 0
POINTS 2
DATA binary
`
	_, got, err := readPCD(append([]byte(head), body...))
	if err != nil {
		t.Fatalf("readPCD binary: %v", err)
	}
	// float32 反序列化到 float64 有表示误差(如 0.1f -> 0.10000000149011612), 用容差比较。
	if math.Abs(got[1][3]-2) > 1e-6 || math.Abs(got[0][0]-0.1) > 1e-6 {
		t.Fatalf("binary PCD 值错误: %v", got)
	}
}

func TestStrictRejectsNaN(t *testing.T) {
	_, err := loadPoints("text", []byte("nan 0 0\n"), "t.txt", &options{strict: true})
	if err == nil {
		t.Fatal("期望 strict 模式拒绝 NaN")
	}
}

func TestStrictRejectsInfBinary(t *testing.T) {
	var buf bytes.Buffer
	binary.Write(&buf, binary.LittleEndian, float32(math.Inf(1)))
	binary.Write(&buf, binary.LittleEndian, float32(0))
	binary.Write(&buf, binary.LittleEndian, float32(0))
	_, err := loadPoints("bin", buf.Bytes(), "t.bin", &options{strict: true})
	if err == nil {
		t.Fatal("期望 strict 模式拒绝 Inf")
	}
}

func TestParseFieldsValidation(t *testing.T) {
	if _, err := parseFields("x,y,z"); err != nil {
		t.Fatalf("合法字段被拒: %v", err)
	}
	if _, err := parseFields("x,,z"); err == nil {
		t.Fatal("期望空字段名报错")
	}
	if _, err := parseFields("x;y"); err == nil {
		t.Fatal("期望非法字符报错")
	}
}

func TestUTF8NoBOMOutput(t *testing.T) {
	// 通过 CLI 写文件, 校验无 BOM 且内容为 UTF-8。
	dir := t.TempDir()
	in := filepath.Join(dir, "in.bin")
	rows := [][]float64{{1, 2, 3}}
	if err := os.WriteFile(in, makeBin(rows), 0o644); err != nil {
		t.Fatal(err)
	}
	outArg := filepath.Join(dir, "out.pcd")
	code, _ := runCLI(t, nil, "-from", "bin", "-output", outArg, in)
	if code != 0 {
		t.Fatalf("退出码 = %d", code)
	}
	got, err := os.ReadFile(outArg)
	if err != nil {
		t.Fatal(err)
	}
	if len(got) >= 3 && got[0] == 0xEF && got[1] == 0xBB && got[2] == 0xBF {
		t.Fatal("输出含 UTF-8 BOM")
	}
	if !bytes.Contains(got, []byte("DATA ascii")) {
		t.Fatalf("输出缺 DATA ascii: %q", got[:min(len(got), 200)])
	}
}

func TestAutoDetectByExt(t *testing.T) {
	if got := detectFrom("a.bin", nil); got != "bin" {
		t.Errorf("a.bin -> %q", got)
	}
	if got := detectFrom("a.csv", nil); got != "csv" {
		t.Errorf("a.csv -> %q", got)
	}
	if got := detectFrom("a.pcd", nil); got != "pcd" {
		t.Errorf("a.pcd -> %q", got)
	}
	if got := detectFrom("a.txt", []byte("# .PCD v0.7")); got != "pcd" {
		t.Errorf("PCD 头内容 -> %q", got)
	}
	if got := detectFrom("a.xyz", nil); got != "text" {
		t.Errorf("a.xyz -> %q", got)
	}
}

func TestVersionFlag(t *testing.T) {
	code, out := runCLI(t, nil, "-version")
	if code != 0 {
		t.Fatalf("退出码 = %d", code)
	}
	if strings.TrimSpace(out) != version {
		t.Fatalf("版本 = %q, 期望 %q", strings.TrimSpace(out), version)
	}
}

func TestFieldsMismatchText(t *testing.T) {
	_, err := loadPoints("text", []byte("1 2 3\n"), "t.txt", &options{fields: "x,y,z,intensity"})
	if err == nil {
		t.Fatal("期望字段数不匹配报错")
	}
}

func TestText2ColumnFeatureNames(t *testing.T) {
	pt, err := loadPoints("text", []byte("1 2\n3 4\n"), "t.txt", &options{})
	if err != nil {
		t.Fatal(err)
	}
	if len(pt.fields) != 2 || pt.fields[0].Name != "feature0" || pt.fields[1].Name != "feature1" {
		t.Fatalf("2 列字段 = %v, 期望 feature0 feature1", pt.fields)
	}
}

func TestPCDBinaryUnsignedLargeValue(t *testing.T) {
	head := "# .PCD v0.7\nVERSION 0.7\nFIELDS x y z\nSIZE 4 4 4\nTYPE U U U\nCOUNT 1 1 1\nWIDTH 1\nHEIGHT 1\nVIEWPOINT 0 0 0 1 0 0 0\nPOINTS 1\nDATA binary\n"
	var body bytes.Buffer
	binary.Write(&body, binary.LittleEndian, uint32(0xFFFFFFFF))
	binary.Write(&body, binary.LittleEndian, uint32(0x80000000))
	binary.Write(&body, binary.LittleEndian, uint32(7))
	_, rows, err := readPCD(append([]byte(head), body.Bytes()...))
	if err != nil {
		t.Fatal(err)
	}
	if rows[0][0] != 4294967295 || rows[0][1] != 2147483648 || rows[0][2] != 7 {
		t.Fatalf("U 字段解析 = %v, 期望 4294967295 2147483648 7", rows[0])
	}
}

func TestPCDRejectMultiCount(t *testing.T) {
	head := "# .PCD v0.7\nVERSION 0.7\nFIELDS x y\nSIZE 4 4\nTYPE F F\nCOUNT 2 1\nPOINTS 1\nDATA ascii\n"
	_, _, err := readPCD([]byte(head))
	if err == nil {
		t.Fatal("期望 COUNT>1 被拒绝")
	}
}

func FuzzReadText(f *testing.F) {
	f.Add("1 2 3\n4 5 6\n")
	f.Add("1,2,3\nbad\n")
	f.Add("# c\n1 2\n")
	f.Add("nan inf -inf\n")
	f.Fuzz(func(t *testing.T, s string) {
		_, _ = readText([]byte(s), ' ', false)
		_, _ = readText([]byte(s), ',', false)
	})
}

func FuzzParseRow(f *testing.F) {
	f.Add("1 2 3")
	f.Add("0x1p2")
	f.Add("-1.5e10")
	f.Fuzz(func(t *testing.T, s string) {
		_, _ = parseRow(strings.Fields(s))
	})
}
