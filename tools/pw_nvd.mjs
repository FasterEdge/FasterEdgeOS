#!/usr/bin/env node
/* NVD CVE 查询工具（Playwright 驱动，输出精简 CVE 清单）。
 * 用法: node pw_nvd.mjs <cpeName> [maxResults]
 * 示例: node pw_nvd.mjs "cpe:2.3:a:busybox:busybox:1.34.1" 30
 * 输出: CVE id | 严重度 | 摘要(前160字符)
 * 环境变量: 同 pw_tool.mjs —— PW_MODULE / PW_EXE(必填)
 */
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const PW_MODULE = process.env.PW_MODULE;
const chromium = await import(PW_MODULE || require.resolve('playwright')).then(m => m.chromium);

const EXE = process.env.PW_EXE;
if (!EXE) {
  console.error('缺少环境变量 PW_EXE: 请设置浏览器可执行文件路径');
  process.exit(2);
}

const cpe = process.argv[2];
const max = parseInt(process.argv[3] || '30', 10);
if (!cpe) {
  console.error('用法: node pw_nvd.mjs <cpeName> [maxResults]');
  process.exit(2);
}

const url = `https://services.nvd.nist.gov/rest/json/cves/2.0?cpeName=${encodeURIComponent(cpe)}&resultsPerPage=${max}`;

const browser = await chromium.launch({ headless: true, executablePath: EXE });
try {
  const page = await browser.newPage();
  console.log(`## CPE: ${cpe}`);
  await page.goto(url, { timeout: 60000, waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(1500);
  const body = await page.evaluate(() => document.body.innerText);
  const start = body.indexOf('{');
  const json = JSON.parse(body.slice(start));
  const vulns = json.vulnerabilities || [];
  console.log(`(共 ${json.totalResults ?? '?'} 条记录，列出前 ${vulns.length})`);
  for (const v of vulns) {
    const c = v.cve;
    const sev = c.metrics?.cvssMetricV31?.[0]?.cvssData?.baseSeverity
      || c.metrics?.cvssMetricV2?.[0]?.baseSeverity
      || 'N/A';
    const desc = c.descriptions?.find(d => d.lang === 'en')?.value || '';
    console.log(`- ${c.id} [${sev}] ${desc.slice(0, 160)}`);
  }
} finally {
  await browser.close();
}