import { createWriteStream, promises as fs } from 'node:fs';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { spawn } from 'node:child_process';
import path from 'node:path';

const API = (process.env.MASAREEN_API || 'https://masareen.com').replace(/\/+$/, '');
const SECRET = process.env.INGEST_SECRET || '';
const FFMPEG = process.env.FFMPEG || 'ffmpeg';
const FFPROBE = process.env.FFPROBE || 'ffprobe';
const POLL_MS = Math.max(3000, Number(process.env.POLL_MS || 15000));
const WORK_DIR = path.resolve(process.env.WORK_DIR || '.work');
const KEEP_WORK = process.env.KEEP_WORK === '1';
const MAX_ATTEMPTS = Math.max(1, Number(process.env.MAX_ATTEMPTS || 3));
const ONCE = process.argv.includes('--once');
const MIME = {
  '.m3u8': 'application/vnd.apple.mpegurl',
  '.ts': 'video/mp2t',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
};

if (!SECRET) {
  console.error('INGEST_SECRET is required.');
  process.exit(1);
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const log = (...args) => console.log(new Date().toISOString(), ...args);

async function api(pathname, options = {}) {
  const res = await fetch(API + pathname, {
    ...options,
    headers: {
      'x-ingest-secret': SECRET,
      ...(options.body ? { 'content-type': 'application/json' } : {}),
      ...(options.headers || {}),
    },
  });
  const text = await res.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = { message: text };
  }
  if (!res.ok) {
    throw new Error(data?.message || data?.error || `HTTP ${res.status}`);
  }
  return data;
}

function run(command, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (chunk) => {
      stdout += chunk.toString();
      if (stdout.length > 8000) stdout = stdout.slice(-8000);
    });
    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
      if (stderr.length > 8000) stderr = stderr.slice(-8000);
    });
    child.on('error', reject);
    child.on('close', (code) => {
      if (code === 0) resolve(stdout.trim());
      else reject(new Error(`${path.basename(command)} exited ${code}: ${stderr.trim().slice(-1200)}`));
    });
  });
}

async function download(url, destination) {
  const res = await fetch(url);
  if (!res.ok || !res.body) throw new Error(`Could not download original video (HTTP ${res.status})`);
  await pipeline(Readable.fromWeb(res.body), createWriteStream(destination));
}

async function probeDuration(file) {
  try {
    const value = await run(FFPROBE, [
      '-v', 'error',
      '-show_entries', 'format=duration',
      '-of', 'default=noprint_wrappers=1:nokey=1',
      file,
    ]);
    const duration = Number.parseFloat(value);
    return Number.isFinite(duration) && duration > 0 ? Math.round(duration) : null;
  } catch {
    return null;
  }
}

async function transcode(input, outDir, duration) {
  await fs.mkdir(outDir, { recursive: true });
  await run(FFMPEG, [
    '-hide_banner', '-loglevel', 'error', '-y',
    '-i', input,
    '-vf', 'scale=-2:720',
    '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '23',
    '-profile:v', 'main', '-pix_fmt', 'yuv420p',
    '-c:a', 'aac', '-b:a', '96k', '-ac', '2', '-ar', '48000',
    '-hls_time', '6', '-hls_playlist_type', 'vod',
    '-hls_segment_filename', path.join(outDir, 'seg_%05d.ts'),
    path.join(outDir, 'index.m3u8'),
  ]);

  const poster = path.join(outDir, 'poster.jpg');
  const seek = duration && duration > 1 ? '1' : '0';
  await run(FFMPEG, [
    '-hide_banner', '-loglevel', 'error', '-y',
    '-ss', seek, '-i', input, '-frames:v', '1', '-q:v', '2', poster,
  ]);
  await fs.access(poster);
}

async function uploadObject(jobId, relativePath, file) {
  const key = `media/hls/${jobId}/${relativePath}`;
  const body = await fs.readFile(file);
  const contentType = MIME[path.extname(file).toLowerCase()] || 'application/octet-stream';
  const res = await fetch(`${API}/api/v1/internal/hls/upload?key=${encodeURIComponent(key)}`, {
    method: 'POST',
    headers: { 'x-ingest-secret': SECRET, 'content-type': contentType },
    body,
  });
  const text = await res.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = { message: text };
  }
  if (!res.ok) throw new Error(data?.message || `Upload failed (HTTP ${res.status})`);
  return data.url;
}

async function updateJob(id, body) {
  return api(`/api/v1/internal/video-jobs/${encodeURIComponent(id)}`, {
    method: 'POST',
    body: JSON.stringify(body),
  });
}

async function processJob(job) {
  const work = path.join(WORK_DIR, job.id);
  const input = path.join(work, 'source');
  const outDir = path.join(work, 'hls');
  try {
    await fs.rm(work, { recursive: true, force: true });
    await fs.mkdir(work, { recursive: true });
    log('processing', job.id);
    await updateJob(job.id, { status: 'processing' });

    await download(job.original_url, input);
    const duration = await probeDuration(input);
    await transcode(input, outDir, duration);

    const names = (await fs.readdir(outDir)).sort();
    const segments = names.filter((name) => name.endsWith('.ts'));
    if (!segments.length || !names.includes('index.m3u8')) throw new Error('ffmpeg produced no HLS playlist');

    for (const name of segments) {
      await uploadObject(job.id, name, path.join(outDir, name));
    }
    const hlsUrl = await uploadObject(job.id, 'index.m3u8', path.join(outDir, 'index.m3u8'));
    const posterUrl = await uploadObject(job.id, 'poster.jpg', path.join(outDir, 'poster.jpg'));

    await updateJob(job.id, {
      status: 'ready',
      hls_url: hlsUrl,
      poster_url: posterUrl,
      duration_seconds: duration,
    });
    log('ready', job.id, hlsUrl);
  } catch (error) {
    const attempts = Number(job.attempts || 0) + 1;
    const status = attempts >= MAX_ATTEMPTS ? 'error' : 'queued';
    log('failed', job.id, status, error.message);
    try {
      await updateJob(job.id, { status, error: error.message.slice(0, 400) });
    } catch (updateError) {
      log('could not update failed job', job.id, updateError.message);
    }
  } finally {
    if (!KEEP_WORK) {
      await fs.rm(work, { recursive: true, force: true }).catch(() => {});
    }
  }
}

async function tick() {
  const jobs = await api('/api/v1/internal/video-jobs?status=queued&limit=1');
  for (const job of Array.isArray(jobs) ? jobs : []) {
    await processJob(job);
  }
  return Array.isArray(jobs) ? jobs.length : 0;
}

let stopping = false;
process.on('SIGINT', () => {
  stopping = true;
  log('stopping after the current job');
});
process.on('SIGTERM', () => {
  stopping = true;
  log('stopping after the current job');
});

if (ONCE) {
  await tick();
} else {
  log(`watching ${API} every ${POLL_MS}ms`);
  while (!stopping) {
    try {
      await tick();
    } catch (error) {
      log('poll failed', error.message);
    }
    await sleep(POLL_MS);
  }
}
