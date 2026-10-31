param([Parameter(Mandatory=$true)][string]$PackageRoot)
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot
$area=Join-Path $repo ('.test-work\'+[Guid]::NewGuid().ToString('N'))
$game=Join-Path $area 'Fake PBZ'
foreach($dir in @('platform\steam\ue4ss','ProjectPBZ\Saved\SaveGames')) {New-Item -ItemType Directory -Path (Join-Path $game $dir) -Force | Out-Null}
foreach($file in @('platform\steam\PBZ.exe','platform\steam\dwmapi.dll','platform\steam\ue4ss\UE4SS.dll')) {[IO.File]::WriteAllText((Join-Path $game $file),'fixture, never executable')}
[IO.File]::WriteAllText((Join-Path $game 'ProjectPBZ\Saved\SaveGames\test.sav'),'original-save-fixture')
function Check([bool]$ok,[string]$label) {if(!$ok){throw ('FAIL: '+$label)}}
$install=Join-Path $PackageRoot 'deploy\Install.ps1'
$uninstall=Join-Path $PackageRoot 'deploy\Uninstall.ps1'
& $install -GameRoot $game
$mod=Join-Path $game 'platform\steam\ue4ss\Mods\PBZYanyunGuard'
$cfg=Join-Path $mod 'Scripts\config.lua'
Check (Test-Path -LiteralPath (Join-Path $game '卸势调校台.exe')) 'panel installed'
Check (Test-Path -LiteralPath (Join-Path $mod 'enabled.txt')) 'mod enabled'
Check (@(Get-ChildItem -LiteralPath (Join-Path $game '_ModWork\DeflectWorkbench\SaveBackups') -Filter test.sav -Recurse).Count -eq 1) 'save backup made'
$custom=[IO.File]::ReadAllText($cfg) -replace 'ParryKey = "RightMouseButton"','ParryKey = "H"'
[IO.File]::WriteAllText($cfg,$custom)
& $install -GameRoot $game
Check ([IO.File]::ReadAllText($cfg) -eq $custom) 'upgrade preserves tuning'
& $uninstall -GameRoot $game
Check (!(Test-Path -LiteralPath (Join-Path $mod 'enabled.txt'))) 'uninstall removes enable marker'
Check (!(Test-Path -LiteralPath (Join-Path $game '卸势调校台.exe'))) 'uninstall archives executable'
Check (Test-Path -LiteralPath (Join-Path $game 'platform\steam\ue4ss\UE4SS.dll')) 'loader retained'
Check ([IO.File]::ReadAllText((Join-Path $game 'ProjectPBZ\Saved\SaveGames\test.sav')) -eq 'original-save-fixture') 'active save unchanged'
# Existing manually installed version must be restored, including its config.
New-Item -ItemType Directory -Path (Join-Path $mod 'Scripts') -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $mod 'Scripts\combat.lua'),'old-combat-fixture')
[IO.File]::WriteAllText($cfg,$custom)
& $install -GameRoot $game
& $uninstall -GameRoot $game
Check ([IO.File]::ReadAllText((Join-Path $mod 'Scripts\combat.lua')) -eq 'old-combat-fixture') 'prior mod restored'
Check ([IO.File]::ReadAllText($cfg) -eq $custom) 'prior config preserved'
. (Join-Path $PackageRoot 'deploy\Common.ps1')
$rejected=$false
try {$null=In-Root $game '..\outside.txt'} catch {$rejected=$true}
Check $rejected 'path traversal rejected'
Write-Output 'PASS: first install, upgrade, save backup, preserved tuning, uninstall archive, prior version restore, loader retention, path validation.'
