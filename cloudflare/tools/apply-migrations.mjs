import { readdirSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const local = process.argv.includes('--local');
const dir = fileURLToPath(new URL('../migrations', import.meta.url));
const files = readdirSync(dir).filter((f) => f.endsWith('.sql')).sort();
if (!files.length) {
  console.log('No migrations found.');
  process.exit(0);
}

function runD1Command(extraArgs) {
  const args = ['wrangler', 'd1', 'execute', 'masareen', ...extraArgs];
  if (!local) args.push('--remote');
  return spawnSync('npx', args, { encoding: 'utf8', shell: true });
}

runD1Command(['--command', 'CREATE TABLE IF NOT EXISTS _migrations (name TEXT PRIMARY KEY, applied_at TEXT NOT NULL);']);
const listRes = runD1Command(['--json', '--command', 'SELECT name FROM _migrations;']);
const alreadyApplied = new Set();
if (listRes.status === 0 && listRes.stdout) {
  try {
    const parsed = JSON.parse(listRes.stdout);
    const rows = Array.isArray(parsed) ? (parsed[0]?.results || []) : (parsed?.results || []);
    for (const r of rows) if (r?.name) alreadyApplied.add(String(r.name));
  } catch {}
}

let failed = false;
for (const file of files) {
  if (alreadyApplied.has(file)) {
    console.log(`[skip] ${file} (already recorded in _migrations)`);
    continue;
  }
  console.log(`\n--- applying ${file} ${local ? '(local)' : '(remote)'} ---`);
  const res = runD1Command(['--file', join(dir, file)]);
  const combined = `${res.stdout || ''}\n${res.stderr || ''}`;
  if (res.stdout) process.stdout.write(res.stdout);
  if (res.stderr) process.stderr.write(res.stderr);
  const isBenignDuplicate = /duplicate column name/i.test(combined);
  if (res.status !== 0 && !isBenignDuplicate) {
    console.error(`Migration ${file} failed.`);
    failed = true;
    break;
  }
  const safeName = file.replace(/'/g, "''");
  runD1Command(['--command', `INSERT OR IGNORE INTO _migrations (name, applied_at) VALUES ('${safeName}', datetime('now'));`]);
}
process.exit(failed ? 1 : 0);
