param(
  [string]$Folder = "$PSScriptRoot\tv",
  [string]$StreamPath = "tv",
  [string]$Password = "masareen-live-2026"
)

# Loops every video in tools\media\tv (mp4/mkv/mov/avi/m4v) into MASAREEN TV.
# Add your own licensed content to that folder; the stream is HLS behind the
# Worker edge cache at /live/tv/index.m3u8.
$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot
New-Item -ItemType Directory -Force -Path $Folder | Out-Null

$files = @(Get-ChildItem -LiteralPath $Folder -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Extension -match '^\.(mp4|mkv|mov|avi|m4v|webm)$' } |
  Sort-Object Name)
if (-not $files.Count) {
  throw "No videos in $Folder. Add licensed video files, then run again."
}

$list = Join-Path $PSScriptRoot "tv-playlist.txt"
$lines = foreach ($file in $files) { "file '$($file.FullName.Replace("'", "'\''"))'" }
[System.IO.File]::WriteAllLines($list, $lines, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Broadcasting $($files.Count) file(s) to $StreamPath" -ForegroundColor Cyan
$ff = Start-Process -FilePath "ffmpeg" -ArgumentList @(
  "-re", "-stream_loop", "-1", "-f", "concat", "-safe", "0", "-i", $list,
  "-vf", "scale='min(1280,iw)':-2",
  "-c:v", "h264_nvenc", "-preset", "p4", "-tune", "hq", "-rc", "vbr",
  "-cq", "23", "-b:v", "2800k", "-maxrate", "3500k", "-bufsize", "5600k", "-g", "120",
  "-c:a", "aac", "-b:a", "128k", "-ar", "48000",
  "-f", "flv", "rtmp://127.0.0.1:1935/live/${StreamPath}?user=masareen&pass=$Password"
) -PassThru -WindowStyle Hidden -RedirectStandardError "ffmpeg-tv.log"
Write-Host "MASAREEN TV is publishing (PID $($ff.Id))." -ForegroundColor Green
Write-Host "Viewer: https://masareen.com/live/$StreamPath/index.m3u8" -ForegroundColor Green
