param([Parameter(Mandatory=$true)][string]$PackageRoot)
$ErrorActionPreference='Stop'
$area=Join-Path (Split-Path $PSScriptRoot) ('.test-work\launcher-'+[Guid]::NewGuid().ToString('N'))
$game=Join-Path $area '中文 测试 PBZ'
New-Item -ItemType Directory -Path (Join-Path $game 'platform\steam\ue4ss') -Force | Out-Null
foreach($file in @('platform\steam\PBZ.exe','platform\steam\dwmapi.dll','platform\steam\ue4ss\UE4SS.dll')) {[IO.File]::WriteAllText((Join-Path $game $file),'fixture; never executable')}
$launch=Join-Path $PackageRoot 'deploy\Launch.ps1'
function Check([bool]$condition,[string]$label) {if(!$condition){throw ('FAIL: '+$label)}}
$good=Join-Path $area 'success.log'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $launch -Action Install -GameRoot $game -NonInteractive -LogPath $good | Out-Null
Check ($LASTEXITCODE -eq 0) 'launcher reports successful installation'
Check ([IO.File]::ReadAllText($good).Contains('安装成功')) 'success log persists'
$bad=Join-Path $area 'failure.log'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $launch -Action Install -GameRoot (Join-Path $area 'not-a-game') -NonInteractive -LogPath $bad | Out-Null
Check ($LASTEXITCODE -eq 1) 'launcher returns failure exit code'
Check ([IO.File]::ReadAllText($bad).Contains('不是有效的 PBZ')) 'failure log identifies wrong directory'
$incomplete=Join-Path $area 'incomplete\deploy'
New-Item -ItemType Directory -Path $incomplete -Force | Out-Null
Copy-Item -LiteralPath $launch -Destination $incomplete
$missing=Join-Path $area 'missing-files.log'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $incomplete 'Launch.ps1') -Action Install -GameRoot $game -NonInteractive -LogPath $missing | Out-Null
Check ($LASTEXITCODE -eq 1) 'incomplete package rejected'
Check ([IO.File]::ReadAllText($missing).Contains('安装包不完整')) 'incomplete package explains release download'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $launch -Action Uninstall -GameRoot $game -NonInteractive -LogPath (Join-Path $area 'uninstall.log') | Out-Null
Check ($LASTEXITCODE -eq 0) 'launcher uninstall works'
Check (!(Test-Path -LiteralPath (Join-Path $game '卸势调校台.exe'))) 'launcher uninstalled owned files'
Write-Output 'PASS: launcher success/failure exit codes, persistent logs, Chinese paths, incomplete package diagnostics and uninstall.'
