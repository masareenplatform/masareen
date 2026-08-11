"""Video upload, transcoding, and HLS serving via the Transcoding Farm.

POST /api/v1/videos/upload        – upload video → create transcode job → return job_id + HLS URL
GET  /api/v1/videos/status/{job_id} – poll transcoding status
GET  /api/v1/videos/hls/{job_id}/{path} – serve HLS .m3u8/.ts files
"""
from __future__ import annotations

import os
import shutil
import uuid
import subprocess
import json
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from fastapi.responses import FileResponse
from pydantic import BaseModel

from shared.middleware import TokenPayload, make_auth_dependency

JWT_SECRET = os.getenv("JWT_SECRET", "masaren-alpha-change-me")
JWT_ALGORITHM = "HS256"
auth = make_auth_dependency(JWT_SECRET, JWT_ALGORITHM)

TRANSCODE_API = os.getenv("TRANSCODE_API", "http://100.123.2.61:9100")
HLS_OUTPUT_DIR = "/home/sms/masarenfinal/backend/combined/static/hls"

router = APIRouter(prefix="/videos", tags=["Videos"])

ALLOWED_VIDEO_TYPES = {
    "video/mp4", "video/quicktime", "video/webm",
    "video/x-matroska", "video/avi", "video/x-msvideo",
    "video/MP2T",
}
MAX_VIDEO_SIZE = 500 * 1024 * 1024  # 500 MB


class UploadResponse(BaseModel):
    job_id: str
    hls_url: str
    state: str


class JobStatus(BaseModel):
    job_id: str
    state: str
    progress: int | None = None


class _JobState:
    """In-memory job tracker so /upload can return immediately."""
    _jobs: dict[str, dict] = {}

    @classmethod
    def create(cls, job_id: str, hls_url: str, farm_job_id: str | None = None):
        cls._jobs[job_id] = {
            "state": "transcoding",
            "progress": 0,
            "hls_url": hls_url,
            "farm_job_id": farm_job_id,
        }

    @classmethod
    def get(cls, job_id: str) -> dict | None:
        return cls._jobs.get(job_id)

    @classmethod
    def update(cls, job_id: str, **kw):
        if job_id in cls._jobs:
            cls._jobs[job_id].update(kw)


def _transcode_local(input_path: str, job_id: str):
    """Transcode locally with ffmpeg using the same ABR profiles as the farm."""
    out_dir = os.path.join(HLS_OUTPUT_DIR, job_id)
    os.makedirs(out_dir, exist_ok=True)

    profiles = [
        {"name": "stream_1080p", "w": 1920, "h": 1080, "bitrate": "5000k", "maxrate": "5500k", "bufsize": "10000k"},
        {"name": "stream_720p",  "w": 1280, "h": 720,  "bitrate": "2800k", "maxrate": "3000k", "bufsize": "6000k"},
        {"name": "stream_480p",  "w": 854,  "h": 480,  "bitrate": "1400k", "maxrate": "1500k", "bufsize": "3000k"},
        {"name": "stream_360p",  "w": 640,  "h": 360,  "bitrate": "800k",  "maxrate": "850k",  "bufsize": "1600k"},
        {"name": "stream_240p",  "w": 426,  "h": 240,  "bitrate": "400k",  "maxrate": "450k",  "bufsize": "900k"},
    ]

    cmd = ["ffmpeg", "-y", "-i", input_path]
    master_lines = ["#EXTM3U", "#EXT-X-VERSION:3"]

    for p in profiles:
        cmd.extend([
            "-map", "0:v:0", "-map", "0:a:0?",
            "-c:v", "libx264", "-preset", "fast",
            "-vf", f"scale={p['w']}:{p['h']}:force_original_aspect_ratio=decrease,pad={p['w']}:{p['h']}:(ow-iw)/2:(oh-ih)/2",
            "-b:v", p["bitrate"], "-maxrate", p["maxrate"], "-bufsize", p["bufsize"],
            "-c:a", "aac", "-b:a", "128k", "-ar", "48000",
            "-f", "hls",
            "-hls_time", "6",
            "-hls_list_type", "0",
            "-hls_segment_filename", os.path.join(out_dir, f"{p['name']}/seg_%05d.ts"),
            os.path.join(out_dir, f"{p['name']}/index.m3u8"),
        ])
        master_lines.append(f"#EXT-X-STREAM-INF:BANDWIDTH={int(p['bitrate'].rstrip('k'))*1000},RESOLUTION={p['w']}x{p['h']}")
        master_lines.append(f"{p['name']}/index.m3u8")

    master_path = os.path.join(out_dir, "master.m3u8")

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=1800)
        if result.returncode != 0:
            return False, result.stderr[-500:] if result.stderr else "unknown ffmpeg error"

        with open(master_path, "w") as f:
            f.write("\n".join(master_lines) + "\n")

        return True, None
    except subprocess.TimeoutExpired:
        return False, "ffmpeg timeout (30 min)"
    except Exception as e:
        return False, str(e)


def _do_transcode(job_id: str, input_path: str, filename: str):
    """Background worker: try farm first, fall back to local ffmpeg."""
    import urllib.request
    import urllib.error

    # Try the farm API
    try:
        data = json.dumps({
            "inputPath": input_path,
            "outputDir": f"outputs/{job_id}",
        }).encode()
        req = urllib.request.Request(
            f"{TRANSCODE_API}/api/jobs",
            data=data,
            headers={"Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            job_info = json.loads(resp.read())

        farm_job_id = job_info.get("id")
        _JobState.update(job_id, farm_job_id=farm_job_id)

        # Poll farm
        import time
        for _ in range(600):
            time.sleep(2)
            try:
                with urllib.request.urlopen(f"{TRANSCODE_API}/api/jobs/{farm_job_id}", timeout=10) as resp:
                    info = json.loads(resp.read())
                state = info.get("state", "unknown")
                _JobState.update(job_id, progress=info.get("progress", 0))
                if state == "completed":
                    _JobState.update(job_id, state="completed", progress=100)
                    return
                elif state == "failed":
                    break
            except Exception:
                continue
    except Exception:
        pass

    # Fall back to local ffmpeg
    success, err = _transcode_local(input_path, job_id)
    if success:
        _JobState.update(job_id, state="completed", progress=100)
    else:
        _JobState.update(job_id, state="failed")
        print(f"[video] transcode failed {job_id}: {err}", flush=True)


@router.post("/upload", response_model=UploadResponse, status_code=202)
async def upload_and_transcode(
    file: UploadFile = File(...),
    _token: TokenPayload = Depends(auth),
):
    if file.content_type and file.content_type not in ALLOWED_VIDEO_TYPES:
        raise HTTPException(400, f"Unsupported video type: {file.content_type}")

    # Save to temp
    tmp_dir = Path("/tmp/video_uploads")
    tmp_dir.mkdir(exist_ok=True)
    safe_name = f"{uuid.uuid4().hex}_{file.filename or 'video.mp4'}"
    tmp_path = tmp_dir / safe_name
    with open(tmp_path, "wb") as f:
        shutil.copyfileobj(file.file, f)

    if tmp_path.stat().st_size > MAX_VIDEO_SIZE:
        tmp_path.unlink()
        raise HTTPException(400, "File too large (max 500 MB)")

    job_id = f"job-{uuid.uuid4().hex}"
    hls_url = f"/api/v1/videos/hls/{job_id}/master.m3u8"

    _JobState.create(job_id, hls_url)

    import threading
    threading.Thread(
        target=_do_transcode,
        args=(job_id, str(tmp_path), file.filename or "video.mp4"),
        daemon=True,
    ).start()

    return UploadResponse(job_id=job_id, hls_url=hls_url, state="transcoding")


@router.get("/status/{job_id}", response_model=JobStatus)
async def job_status(job_id: str, _token: TokenPayload = Depends(auth)):
    info = _JobState.get(job_id)
    if not info:
        # Check if HLS output exists on disk (job from another session)
        if os.path.exists(os.path.join(HLS_OUTPUT_DIR, job_id, "master.m3u8")):
            return JobStatus(job_id=job_id, state="completed", progress=100)
        raise HTTPException(404, "Job not found")
    return JobStatus(job_id=job_id, state=info["state"], progress=info["progress"])


@router.get("/hls/{job_id}/{path:path}")
async def serve_hls(job_id: str, path: str):
    file_path = os.path.normpath(os.path.join(HLS_OUTPUT_DIR, job_id, path))
    if not file_path.startswith(HLS_OUTPUT_DIR):
        raise HTTPException(403, "Forbidden")
    if not os.path.isfile(file_path):
        raise HTTPException(404, "File not found")

    if path.endswith(".m3u8"):
        media_type = "application/vnd.apple.mpegurl"
        headers = {"Cache-Control": "public, max-age=60"}
    elif path.endswith(".ts"):
        media_type = "video/mp2t"
        headers = {"Cache-Control": "public, max-age=86400"}
    else:
        media_type = "application/octet-stream"
        headers = {}

    return FileResponse(file_path, media_type=media_type, headers=headers)
