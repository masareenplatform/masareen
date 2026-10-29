#!/usr/bin/env node
/**
 * Trigger, poll, and download the MASAREEN iOS IPA build on Codemagic.
 *
 * Usage:
 *   node tools/codemagic-ios-build.mjs [--trigger] [--status <buildId>] [--wait] [--download <outPath>]
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');

const DEFAULT_APP_ID = process.env.CODEMAGIC_APP_ID || '6ae3cdfaeba8ddc288cff2a0';
const DEFAULT_WORKFLOW_ID = process.env.CODEMAGIC_WORKFLOW_ID || 'ios-ipa';
const DEFAULT_BRANCH = process.env.CODEMAGIC_BRANCH || 'main';

function getApiKey() {
  if (process.env.CODEMAGIC_API_KEY) return process.env.CODEMAGIC_API_KEY.trim();
  const keyFile = path.join(ROOT, 'codemagic_api.txt');
  if (fs.existsSync(keyFile)) return fs.readFileSync(keyFile, 'utf8').trim();
  throw new Error('CODEMAGIC_API_KEY env var or codemagic_api.txt not found.');
}

async function cmFetch(endpoint, opts = {}) {
  const apiKey = getApiKey();
  const res = await fetch(`https://api.codemagic.io${endpoint}`, {
    ...opts,
    headers: {
      'x-auth-token': apiKey,
      'content-type': 'application/json',
      ...(opts.headers || {}),
    },
  });
  const text = await res.text();
  let data;
  try {
    data = JSON.parse(text);
  } catch {
    data = { raw: text };
  }
  if (!res.ok) {
    throw new Error(`Codemagic API ${endpoint} failed (${res.status}): ${text}`);
  }
  return data;
}

export async function triggerIosBuild({
  appId = DEFAULT_APP_ID,
  workflowId = DEFAULT_WORKFLOW_ID,
  branch = DEFAULT_BRANCH,
  apiBaseUrl = process.env.API_BASE_URL || 'https://masareen.com',
} = {}) {
  const body = {
    appId,
    workflowId,
    branch,
    environment: {
      variables: {
        API_BASE_URL: apiBaseUrl,
      },
    },
  };
  return await cmFetch('/builds', {
    method: 'POST',
    body: JSON.stringify(body),
  });
}

export async function getBuildStatus(buildId) {
  return await cmFetch(`/builds/${buildId}`);
}

export async function waitForBuild(buildId, { pollMs = 15000, timeoutMs = 45 * 60 * 1000 } = {}) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const info = await getBuildStatus(buildId);
    const build = info.build || info;
    const status = build.status;
    console.log(`[Codemagic] Build ${buildId} status: ${status}`);
    if (['finished', 'failed', 'canceled', 'timeout'].includes(status)) {
      return build;
    }
    await new Promise((r) => setTimeout(r, pollMs));
  }
  throw new Error(`Timed out waiting for Codemagic build ${buildId}`);
}

export async function downloadIpaArtifact(build, outPath) {
  const artefacts = build.artefacts || [];
  const ipa = artefacts.find((a) => a.name?.endsWith('.ipa') || a.type === 'ipa');
  if (!ipa || !ipa.url) {
    throw new Error('No .ipa artifact found on build: ' + JSON.stringify(artefacts));
  }
  const apiKey = getApiKey();
  const res = await fetch(ipa.url, { headers: { 'x-auth-token': apiKey } });
  if (!res.ok) throw new Error(`Failed to download IPA (${res.status})`);
  const buf = Buffer.from(await res.arrayBuffer());
  fs.writeFileSync(outPath, buf);
  console.log(`[Codemagic] Downloaded IPA (${buf.length} bytes) -> ${outPath}`);
  return outPath;
}

if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url))) {
  const args = process.argv.slice(2);
  const statusIdx = args.indexOf('--status');
  const waitFlag = args.includes('--wait');
  const triggerFlag = args.includes('--trigger') || statusIdx === -1;
  const dlIdx = args.indexOf('--download');
  const outPath = dlIdx !== -1 ? args[dlIdx + 1] : path.join(ROOT, 'masareen-unsigned.ipa');

  let buildId = statusIdx !== -1 ? args[statusIdx + 1] : null;
  if (triggerFlag && !buildId) {
    const triggered = await triggerIosBuild();
    buildId = triggered.buildId;
    console.log(`[Codemagic] Triggered iOS build: ${buildId}`);
  }
  if (buildId && !waitFlag && !triggerFlag) {
    const info = await getBuildStatus(buildId);
    console.log(JSON.stringify(info.build || info, null, 2));
  } else if (buildId && waitFlag) {
    const build = await waitForBuild(buildId);
    if (build.status !== 'finished') {
      console.error(`[Codemagic] Build ended with status: ${build.status}`);
      process.exit(1);
    }
    if (dlIdx !== -1) {
      await downloadIpaArtifact(build, outPath);
    }
  }
}
