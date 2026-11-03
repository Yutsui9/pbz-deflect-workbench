param([int]$Seconds=20)
$ErrorActionPreference='Stop'
if($Seconds -lt 1 -or $Seconds -gt 120){throw 'Duration must be 1..120 seconds'}
$root=$PSScriptRoot
$ff=Join-Path $root '../VideoIntro/.python/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
$game=@(Get-Process PBZ -ErrorAction SilentlyContinue | Where-Object {$_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -like 'Phantom Blade Zero*'})
if($game.Count -ne 1){throw 'Expected one running Phantom Blade Zero window'}
$out=Join-Path $root ('captures/'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory $out -Force | Out-Null
$video=Join-Path $out 'warning.mp4'
& $ff -hide_banner -loglevel warning -f gdigrab -framerate 60 -draw_mouse 0 -i ('title='+$game[0].MainWindowTitle) -t $Seconds -an -c:v libx264 -preset ultrafast -crf 18 -pix_fmt yuv420p $video
if($LASTEXITCODE){throw 'Window recording failed; no render verdict available'}
python (Join-Path $root 'analyze-warning-video.py') $video --seconds $Seconds --out (Join-Path $out 'analysis')
if($LASTEXITCODE){throw 'Analysis failed'}
Write-Output ('Captured and measured: '+$out)
