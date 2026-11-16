param(
  [Parameter(Mandatory = $true)][Alias('Input')][string]$Source,
  [Parameter(Mandatory = $true)][string]$Name,
  [string]$OutDir = "$PSScriptRoot\out",
  [string]$Bucket = "masareen-landing",
  [switch]$SkipUpload
)

$ErrorActionPreference = "Stop"
Set-Location -LiteralPath $PSScriptRoot

if (-not (Test-Path -LiteralPath $Source)) { throw "Input not found: $Source" }
if ($Name -notmatch '^[a-z0-9][a-z0-9-]{1,60}$') {
  throw "Name must be lowercase letters, numbers and dashes (2-61 chars)."
}

$root = Join-Path $OutDir $Name
foreach ($variant in @("1080p", "720p", "480p")) {
  New-Item -ItemType Directory -Force -Path (Join-Path $root $variant) | Out-Null
}

$filter = @"
[0:v]split=3[v1][v2][v3];
[v1]scale=1920:-2:flags=lanczos,setsar=1[v1out];
[v2]scale=1280:-2:flags=lanczos,setsar=1[v2out];
[v3]scale=854:-2:flags=lanczos,setsar=1[v3out];
[0:a]asplit=3[a1][a2][a3]
"@

$segment = Join-Path $root "%v\seg_%03d.ts"
$playlist = Join-Path $root "%v\index.m3u8"

Write-Host "Transcoding with NVENC -> $root" -ForegroundColor Cyan
$log = Join-Path $root "transcode.log"
$nativeErrorAction = $ErrorActionPreference
$ErrorActionPreference = "Continue"
ffmpeg -y -i $Source -filter_complex $filter 2> $log `
  -map "[v1out]" -map "[a1]" -c:v:0 h264_nvenc -preset p4 -tune hq -rc vbr -cq 21 `
  -b:v:0 6000k -maxrate:v:0 7500k -bufsize:v:0 12000k -g 120 -keyint_min 120 `
  -map "[v2out]" -map "[a2]" -c:v:1 h264_nvenc -preset p4 -tune hq -rc vbr -cq 23 `
  -b:v:1 3000k -maxrate:v:1 3750k -bufsize:v:1 6000k -g 120 -keyint_min 120 `
  -map "[v3out]" -map "[a3]" -c:v:2 h264_nvenc -preset p4 -tune hq -rc vbr -cq 26 `
  -b:v:2 1200k -maxrate:v:2 1500k -bufsize:v:2 2400k -g 120 -keyint_min 120 `
  -c:a aac -b:a 128k -ac 2 -ar 48000 `
  -f hls -hls_time 4 -hls_playlist_type vod -hls_flags independent_segments `
  -master_pl_name master.m3u8 `
  -var_stream_map "v:0,a:0,name:1080p v:1,a:1,name:720p v:2,a:2,name:480p" `
  -hls_segment_filename $segment $playlist
$transcodeExit = $LASTEXITCODE
$ErrorActionPreference = $nativeErrorAction

if ($transcodeExit -ne 0) {
  Get-Content $log -Tail 25
  throw "ffmpeg failed with exit code $transcodeExit"
}

if (-not $SkipUpload) {
  Write-Host "Uploading to R2 bucket $Bucket..." -ForegroundColor Cyan
  $prefix = "media/hls/$Name"
  Get-ChildItem -Recurse -File -LiteralPath $root | ForEach-Object {
    $relative = $_.FullName.Substring($root.Length + 1).Replace("\", "/")
    $key = "$prefix/$relative"
    $type = switch ($_.Extension) {
      ".m3u8" { "application/vnd.apple.mpegurl" }
      ".ts" { "video/mp2t" }
      ".m4s" { "video/iso.segment" }
      ".mp4" { "video/mp4" }
      default { "application/octet-stream" }
    }
    Write-Host "  $key"
    npx wrangler r2 object put "$Bucket/$key" --file $_.FullName --content-type $type --remote
    if ($LASTEXITCODE -ne 0) { throw "Upload failed for $key" }
  }
}

Write-Host ""
Write-Host "VOD master playlist:" -ForegroundColor Green
Write-Host "https://masareen.com/media/hls/$Name/master.m3u8" -ForegroundColor Green
