# MASAREEN live + VOD on a Windows PC (RTX 3050)

This folder turns a Windows machine with an NVIDIA RTX 3050 into the
MASAREEN live/VOD origin:

- **mediaMTX** accepts RTMP from OBS and serves HLS.
- **cloudflared** publishes the HLS origin on `media.masareen.com` (or a
  tunnel hostname you choose) without opening router ports.
- **ffmpeg + NVENC** transcodes recorded videos to multi-bitrate HLS for VOD.
- **wrangler** uploads the HLS folders to the `masareen-media` R2 bucket.

## 1. Install once

```powershell
winget install Gyan.FFmpeg
winget install Cloudflare.cloudflared
# Download mediaMTX from https://github.com/bluenviron/mediamtx/releases
# and extract mediamtx.exe into this folder (tools\media).
```

Verify the GPU encoder:

```powershell
ffmpeg -hide_banner -encoders | Select-String nvenc
```

You should see `h264_nvenc` and `hevc_nvenc`.

## 2. Configure

Copy `mediamtx.example.yml` to `mediamtx.yml` and set a strong publish
password. Create the Cloudflare tunnel once:

```powershell
cloudflared tunnel login
cloudflared tunnel create masareen-media
cloudflared tunnel route dns masareen-media media.masareen.com
```

Then copy the tunnel ID into `config.ps1` (or set `$env:MASAREEN_TUNNEL_ID`).

## 3. Go live (one command)

```powershell
.\start-live.ps1 -Watch
```

This starts mediaMTX, the Cloudflare tunnel, and the TV broadcast loop, then keeps checking `https://masareen.com/live/tv/index.m3u8` every 45 seconds and repairs anything that stopped. On macOS/Linux use `./start-live.sh --watch` (with a `mediamtx` binary for that platform and `h264_videotoolbox` available in ffmpeg). The old `live.ps1` remains available for manual OBS streaming.

OBS settings:

- Service: Custom
- Server: `rtmp://127.0.0.1:1935/live`
- Stream key: `masareen` (must match `mediamtx.yml` path)
- Encoder: NVIDIA NVENC H.264, 6000 kbps, keyframe 2s
- Output: 1920x1080, 30/60 fps

Viewer URL (put this in a MASAREEN video/live post):

```text
https://media.masareen.com/live/masareen/index.m3u8
```

The Worker `/api/v1/live/interactions` endpoint already exposes chat and
viewer counters for live posts. mediaMTX serves the HLS; the tunnel keeps the
PC private.

## 4. Publish a recording as VOD

```powershell
.\hls.ps1 -Input .\recording.mp4 -Name climate-forum
```

This produces `out\climate-forum\master.m3u8` plus 1080p/720p/480p variants
using NVENC, then uploads them to R2:

```text
https://masareen.com/media/hls/climate-forum/master.m3u8
```

Paste that master URL into a post as a video (`hls_url`) or use it as the
`video_hls_url` for an existing video job. Android and iOS play HLS natively;
the Flutter video player uses the HLS URL when present and falls back to MP4.

## 5. Podcasts

Podcast episodes use the same audio pipeline: create a post, choose **Voice
note**, and pick the episode audio file. The episode plays inline in the feed
and on the post page. For a series, put the episode number in the post text
and tag the post with the relevant SDG/program.

## Notes

- Keep the PC awake while streaming: `powercfg /change standby-timeout-ac 0`.
- Use a wired connection when possible; the tunnel handles NAT/firewall.
- Never commit `mediamtx.yml`, tunnel credentials or R2 keys.
- RTX 3050 handles one 1080p60 NVENC session comfortably; for two variants
  use 1080p30 + 720p30 or lower the preset to `p4`.
