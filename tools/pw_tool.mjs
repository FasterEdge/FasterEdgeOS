#!/usr/bin/env node
/* Playwright 网页抓取/搜索工具（Node 版）。
 * 用法:
 *   node pw_tool.mjs search "<查询词>"            — 英文 Bing 搜索
 *   node pw_tool.mjs fetch "<URL>" [maxChars]     — 抓取页面正文纯文本
 * 输出: 纯文本结果到 stdout。
 * 环境变量:
 *   PW_MODULE  Playwright 模块的绝对路径(默认按 npm 全局/本地解析)
 *   PW_EXE     Chromium/Chrome for Testing 可执行文件路径(必填, 未设置则报错)
 */
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const PW_MODULE = process.env.PW_MODULE;
const chromium = await import(PW_MODULE || require.resolve('playwright')).then(m => m.chromium);

const EXE = process.env.PW_EXE;
if (!EXE) {
  console.error('缺少环境变量 PW_EXE: 请设置浏览器可执行文件路径(如 PW_EXE=/usr/bin/chromium 或 playwright 缓存路径)');
  process.exit(2);
}

async function withPage(fn) {
  const browser = await chromium.launch({ headless: true, executablePath: EXE });
  try {
    const page = await browser.newPage({
      userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    });
    return await fn(page);
  } finally {
    await browser.close();
  }
}

async function search(query) {
  const url = 'https://www.bing.com/search?q=' + encodeURIComponent(query) + '&setlang=en&cc=US';
  return withPage(async (page) => {
    console.log(`## 查询: ${query}`);
    await page.goto(url, { timeout: 30000, waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(2500);
    const results = await page.evaluate(() => {
      const items = Array.from(document.querySelectorAll('li.b_algo'));
      return items.slice(0, 12).map((it) => {
        const a = it.querySelector('h2 a');
        const snipEl = it.querySelector('.b_caption p, .b_lineclamp2, .b_snippet');
        return {
          title: a ? a.innerText.trim() : '',
          url: a ? (a.getAttribute('href') || '') : '',
          snippet: snipEl ? snipEl.innerText.trim().slice(0, 500) : '',
        };
      }).filter((r) => r.title || r.url);
    });
    if (!results.length) console.log('(无结果)');
    for (const r of results) console.log(`- ${r.title}\n  URL: ${r.url}\n  ${r.snippet}`);
  });
}

async function fetchPage(url, maxChars) {
  return withPage(async (page) => {
    console.log(`## 抓取: ${url}`);
    await page.goto(url, { timeout: 40000, waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(2000);
    const text = await page.evaluate(() => document.body.innerText);
    const cleaned = text.replace(/\n{3,}/g, '\n\n').trim();
    console.log(cleaned.slice(0, maxChars || 6000));
  });
}

const mode = process.argv[2];
const arg = process.argv[3];
const arg2 = process.argv[4];
if (!mode || !arg) {
  console.error('用法: node pw_tool.mjs search|fetch <查询词|URL> [maxChars]');
  process.exit(2);
}
if (mode === 'search') await search(arg);
else if (mode === 'fetch') await fetchPage(arg, arg2 ? parseInt(arg2, 10) : undefined);
else { console.error('未知模式: ' + mode); process.exit(2); }