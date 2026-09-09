// Any2UTF8 单元测试: 编码解析 / 启发式探测 / 系统默认编码 / 转换 / 严格模式 / 原子写。

package main

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
)

func TestResolveEncodingAliases(t *testing.T) {
	names := []string{
		"GBK", "gbk", "GB2312", "cp936", "gb18030",
		"Big5", "big5", "cp950",
		"Shift_JIS", "shift-jis", "sjis", "cp932",
		"EUC-JP", "eucjp", "EUC-KR", "euckr",
		"windows-1252", "ISO-8859-1", "KOI8-R",
		"UTF-16", "utf16", "utf-16le", "utf16be",
		"UTF-8", "utf8",
	}
	for _, name := range names {
		e, _, err := resolveEncoding(name)
		if err != nil || e == nil {
			t.Errorf("resolveEncoding(%q) = %v, %v; want non-nil", name, e, err)
		}
	}
}

func TestResolveEncodingUnknown(t *testing.T) {
	if _, _, err := resolveEncoding("not-a-real-codec"); err == nil {
		t.Error("unknown codec should return error")
	}
}

func TestResolveEncodingAuto(t *testing.T) {
	e, name, err := resolveEncoding("auto")
	if err != nil || e != nil || name != "auto" {
		t.Errorf("auto should yield nil enc: got %v %q %v", e, name, err)
	}
}

func TestSniffEncoding(t *testing.T) {
	cases := []struct {
		name string
		data []byte
		want string
	}{
		{"utf8 bom", []byte{0xEF, 0xBB, 0xBF, 'a'}, "UTF-8"},
		{"utf16le bom", []byte{0xFF, 0xFE, 'a', 0}, "UTF-16LE"},
		{"utf16be bom", []byte{0xFE, 0xFF, 0, 'a'}, "UTF-16BE"},
		{"plain utf8", []byte("hello 世界"), "UTF-8"},
		{"utf16le ascii no bom", []byte{'a', 0, 'b', 0, 'c', 0}, "UTF-16LE"},
		{"gbk hanzi", []byte{0xD6, 0xD0, 0xCE, 0xC4}, "GBK"},
		{"empty", nil, "UTF-8"},
	}
	for _, c := range cases {
		if got := sniffEncoding(c.data); got != c.want {
			t.Errorf("sniffEncoding(%s) = %q, want %q", c.name, got, c.want)
		}
	}
}

func TestLooksLikeUTF16LE(t *testing.T) {
	if !looksLikeUTF16LE([]byte{'a', 0, 'b', 0, 'c', 0}) {
		t.Error("ascii utf16le should be true")
	}
	if looksLikeUTF16LE([]byte("plain ascii")) {
		t.Error("plain ascii should be false")
	}
	if looksLikeUTF16LE([]byte{0xD6, 0xD0, 0xCE, 0xC4}) {
		t.Error("gbk hanzi should be false")
	}
	if looksLikeUTF16LE(nil) {
		t.Error("empty should be false")
	}
	if looksLikeUTF16LE([]byte{0x2D, 0x4E, 0x87, 0x65}) { // UTF-16LE 中文(高低字节均非零)
		t.Error("chinese utf16le should be false (no misdetection)")
	}
}

func TestSystemCharset(t *testing.T) {
	t.Setenv("LC_ALL", "")
	t.Setenv("LC_CTYPE", "")
	t.Setenv("LANG", "zh_CN.GBK")
	if got := systemCharset(); got != "GBK" {
		t.Errorf("LANG=zh_CN.GBK => %q, want GBK", got)
	}
	t.Setenv("LANG", "en_US.UTF-8")
	if got := systemCharset(); got != "UTF-8" {
		t.Errorf("LANG=en_US.UTF-8 => %q, want UTF-8", got)
	}
	t.Setenv("LANG", "zh_TW.Big5")
	if got := systemCharset(); got != "Big5" {
		t.Errorf("LANG=zh_TW.Big5 => %q, want Big5", got)
	}
	t.Setenv("LANG", "zh_CN.GBK:en_US.UTF-8")
	if got := systemCharset(); got != "GBK" {
		t.Errorf("LANG=zh_CN.GBK:en_US.UTF-8 => %q, want GBK(取第一段)", got)
	}
	t.Setenv("LANG", "")
	if got := systemCharset(); got != "" {
		t.Errorf("LANG empty => %q, want empty", got)
	}
}

func TestConvertGBK(t *testing.T) {
	enc, _, err := resolveEncoding("GBK")
	if err != nil {
		t.Fatal(err)
	}
	var buf bytes.Buffer
	if err := convertReader(bytes.NewReader([]byte{0xD6, 0xD0, 0xCE, 0xC4}), &buf, enc); err != nil {
		t.Fatalf("convert: %v", err)
	}
	if got := buf.String(); got != "中文" {
		t.Errorf("GBK convert = %q, want 中文", got)
	}
}

func TestConvertUTF16LE(t *testing.T) {
	enc, _, err := resolveEncoding("UTF-16LE")
	if err != nil {
		t.Fatal(err)
	}
	var buf bytes.Buffer
	// "AB" UTF-16LE = 41 00 42 00
	if err := convertReader(bytes.NewReader([]byte{'A', 0, 'B', 0}), &buf, enc); err != nil {
		t.Fatalf("convert: %v", err)
	}
	if got := buf.String(); got != "AB" {
		t.Errorf("UTF-16LE convert = %q, want AB", got)
	}
}

func TestConvertStrict(t *testing.T) {
	enc, _, err := resolveEncoding("GBK")
	if err != nil {
		t.Fatal(err)
	}
	// 合法 GBK 通过。
	if _, err := convertStrict([]byte{0xD6, 0xD0}, enc); err != nil {
		t.Errorf("valid GBK should pass strict: %v", err)
	}
	// 非法 GBK 序列(首字节 0xFE 后随 0x30 < 0x40)应失败。
	if _, err := convertStrict([]byte{0xFE, 0x30}, enc); err == nil {
		t.Error("invalid GBK should fail strict")
	}
	// 合法 UTF-8 原样通过。
	if _, err := convertStrict([]byte("中文"), nil); err != nil {
		t.Errorf("valid UTF-8 should pass strict: %v", err)
	}
}

func TestEncodeToGBK(t *testing.T) {
	enc, _, err := resolveEncoding("GBK")
	if err != nil {
		t.Fatal(err)
	}
	out, err := encodeTo([]byte("中文"), enc)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(out, []byte{0xD6, 0xD0, 0xCE, 0xC4}) {
		t.Errorf("encode = % x, want d6 d0 ce c4", out)
	}
}

func TestWriteOutputNewFilePerms(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "out.txt")
	if err := writeOutput(p, []byte("data")); err != nil {
		t.Fatal(err)
	}
	fi, err := os.Stat(p)
	if err != nil {
		t.Fatal(err)
	}
	if got := fi.Mode().Perm(); got != 0o644 {
		t.Errorf("new file perms = %o, want 644", got)
	}
}

func TestWriteOutputPreservesPerms(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "out.txt")
	if err := os.WriteFile(p, []byte("old"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := writeOutput(p, []byte("new")); err != nil {
		t.Fatal(err)
	}
	fi, err := os.Stat(p)
	if err != nil {
		t.Fatal(err)
	}
	if got := fi.Mode().Perm(); got != 0o600 {
		t.Errorf("preserved perms = %o, want 600", got)
	}
}
