#!/usr/bin/env node
/* NVD CVE 查询工具（Playwright 驱动，输出精简 CVE 清单）。
 * 用法: node pw_nvd.mjs <cpeName> [maxResults]
 * 示例: node pw_nvd.mjs "cpe:2.3:a:busybox:busybox:1.34.1" 30
 * 输出: CVE id | 严重度 | 摘要(前160字符)
 */
import { chromium } from '/Users/tyza66/.hermes/node/lib/node_modules/@playwright/cli/node_modules/playwright/index.mjs';

const EXE = '/Users/tyza66/Library/Caches/ms-playwright/chromium-1234/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing';

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