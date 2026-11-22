#!/usr/bin/env node
/* FasterEdgeOS 仓库 yaml/json 解析校验。
 *
 * 设计取舍：
 *   - 不引入 js-yaml / yaml 等 npm 依赖（仓库没有 package.json，也没有
 *     lockfile，凭空加依赖会让 CI 多一步 npm install，且离线环境装不上）。
 *   - 这里做的是「可解析性 + 少量结构性断言」，不是完整 schema 校验：
 *     目标是拦住提交时打错字、缩进错、缺引号这类硬错误。
 *   - YAML 解析交给外部解析器：按 python3(PyYAML) -> ruby(Psych) 的顺序探测，
 *     任一可用即可；都不可用时明确报错并计入失败（不静默跳过）。
 *     缺失时安装任一即可：pip install pyyaml ／ apt install python3-yaml。
 */
import { execFileSync } from 'node:child_process';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/[\\/]$/, '');
const SKIP_DIRS = new Set(['.git', 'node_modules', 'work', 'source', 'dist']);

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    if (SKIP_DIRS.has(name)) continue;
    const full = join(dir, name);
    if (statSync(full).isDirectory()) walk(full, out);
    else out.push(full);
  }
  return out;
}

/* YAML -> JS 值。python3 与 ruby 的失败原因要区分开：
 * 「解析器不存在」应继续尝试下一个；「YAML 本身有语法错」应立即返回错误。 */
function parseYamlData(content) {
  try {
    const out = execFileSync(
      'python3',
      ['-c', 'import sys,yaml,json; print(json.dumps(yaml.safe_load(sys.stdin.read())))'],
      { input: content, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] },
    );
    return { ok: true, via: 'python3:PyYAML', data: JSON.parse(out) };
  } catch (e) {
    const msg = String(e.stderr || e.message || '').trim();
    if (!/No module named|not found|ENOENT/.test(msg)) {
      return { ok: false, via: 'python3:PyYAML', err: msg };
    }
  }

  try {
    const out = execFileSync(
      'ruby',
      ['-ryaml', '-rjson', '-e', 'puts JSON.generate(YAML.safe_load(STDIN.read, permitted_classes: [], aliases: true))'],
      { input: content, encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] },
    );
    return { ok: true, via: 'ruby:Psych', data: JSON.parse(out) };
  } catch (e) {
    const msg = String(e.stderr || e.message || '').trim();
    return { ok: false, via: 'ruby:Psych', err: msg };
  }
}

function fail(rel, msg) {
  process.stderr.write(`  [FAIL] ${rel}: ${msg}\n`);
  return false;
}

function checkYaml(rel, content) {
  const r = parseYamlData(content);
  if (!r.ok) {
    const detail = (r.err || '').split('\n').slice(0, 6).join('\n    ');
    return fail(rel, `YAML 解析失败 (${r.via})\n    ${detail}`);
  }
  return true;
}

function checkJson(rel, content) {
  try {
    JSON.parse(content);
    return true;
  } catch (e) {
    return fail(rel, `JSON 解析失败: ${e.message}`);
  }
}

/* 根管理器配置追加结构断言：manager.yaml 是 FasterEdgeOS 运行期的关键输入，
 * 缺顶层字段或端口冲突会让 DontCrack-Manager 起不来，值得单独拦一道。
 * 只做「键存在 + 类型正确 + 端口唯一」这类可静态判定的断言，不重复实现 schema。 */
function checkManagerYaml(rel, content) {
  const r = parseYamlData(content);
  if (!r.ok) return true; // 解析层已报错，不重复
  const data = r.data;
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    return fail(rel, '顶层不是 mapping');
  }

  const problems = [];
  if (typeof data.log_level !== 'string' || !data.log_level) {
    problems.push('log_level 缺失或不是字符串');
  }
  if (typeof data.shutdown_grace !== 'string' || !/^\d+[smh]$/.test(data.shutdown_grace)) {
    problems.push('shutdown_grace 缺失或不是 "10s" 形式的时长');
  }
  if (data.listen !== undefined && typeof data.listen !== 'string') {
    problems.push('listen 存在但不是字符串');
  }

  if (!Array.isArray(data.services)) {
    problems.push('services 缺失或不是列表');
  } else {
    const ports = new Map();
    data.services.forEach((s, i) => {
      if (!s || typeof s !== 'object' || Array.isArray(s)) {
        problems.push(`services[${i}] 不是 mapping`);
        return;
      }
      if (typeof s.name !== 'string' || !s.name) problems.push(`services[${i}].name 缺失`);
      if (typeof s.path !== 'string' || !s.path) problems.push(`services[${i}].path 缺失`);
      if (s.port !== undefined) {
        if (!Number.isInteger(s.port)) problems.push(`services[${i}].port 不是整数`);
        else if (ports.has(s.port)) {
          problems.push(`services[${i}].port 与 services[${ports.get(s.port)}].port 重复(${s.port})`);
        } else ports.set(s.port, i);
      }
      for (const k of ['backoff', 'backoff_max']) {
        if (s[k] !== undefined && !/^\d+[smh]$/.test(String(s[k]))) {
          problems.push(`services[${i}].${k} 不是 "3s" 形式的时长`);
        }
      }
    });
  }

  if (problems.length) {
    process.stderr.write(`  [FAIL] ${rel}:\n`);
    for (const p of problems) process.stderr.write(`    - ${p}\n`);
    return false;
  }
  return true;
}

const files = walk(ROOT);
let checked = 0;
let failed = 0;
for (const f of files) {
  const rel = relative(ROOT, f).split(sep).join('/');
  if (/\.ya?ml$/i.test(rel)) {
    checked++;
    const content = readFileSync(f, 'utf8');
    if (!checkYaml(rel, content)) failed++;
    else if (rel.endsWith('bundles/fasteredgeos/manager.yaml')) {
      if (!checkManagerYaml(rel, content)) failed++;
    }
  } else if (/\.json$/i.test(rel)) {
    checked++;
    if (!checkJson(rel, readFileSync(f, 'utf8'))) failed++;
  }
}

if (checked === 0) {
  process.stderr.write('  [FAIL] 未找到任何 yaml/json 文件，校验范围可能配置有误\n');
  process.exit(1);
}
process.stdout.write(`  yaml/json 文件数: ${checked}，失败: ${failed}\n`);
process.exit(failed ? 1 : 0);
