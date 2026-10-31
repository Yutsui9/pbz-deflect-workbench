param([Parameter(Mandatory=$true)][string]$PackageRoot)
$ErrorActionPreference='Stop'
. (Join-Path $PackageRoot 'deploy\SteamPaths.ps1')
$area=Join-Path (Split-Path $PSScriptRoot) ('.test-work\steam-'+[Guid]::NewGuid().ToString('N'))
$steam=Join-Path $area 'Steam'
$extra=Join-Path $area '中文 游戏库'
New-Item -ItemType Directory -Path (Join-Path $steam 'steamapps'),(Join-Path $extra 'steamapps\common\Renamed PBZ\platform\steam') -Force | Out-Null
$game=Join-Path $extra 'steamapps\common\Renamed PBZ'
[IO.File]::WriteAllText((Join-Path $game 'platform\steam\PBZ.exe'),'fixture; never executed')
[IO.File]::WriteAllText((Join-Path $extra 'steamapps\appmanifest_123.acf'),'"AppState" { "installdir" "Renamed PBZ" }')
function Check([bool]$ok,[string]$label) {if(!$ok){throw ('FAIL: '+$label)}}
function LibraryList([string]$text) {[IO.File]::WriteAllText((Join-Path $steam 'steamapps\libraryfolders.vdf'),$text)}
$escaped=$extra.Replace('\','\\')
LibraryList ("`"libraryfolders`"`n{`n`"1`"`n{`n`"path`" `""+$escaped+"`"`n}`n}")
$found=@(Find-PBZSteamGameRoot -SteamRoots @($steam,$steam.ToUpperInvariant()))
Check ($found.Count -eq 1 -and $found[0] -eq $game) 'modern multi-library manifest, Unicode path and deduplication'
LibraryList ("`"libraryfolders`"`n{`n`"1`" `""+$escaped+"`"`n}")
Check (@(Find-PBZSteamGameRoot -SteamRoots @($steam)).Count -eq 1) 'legacy library list'
LibraryList 'malformed or stale list'
Check (@(Find-PBZSteamGameRoot -SteamRoots @($steam)).Count -eq 0) 'missing executable never accepted'
$second=Join-Path $steam 'steamapps\common\PBZ'
New-Item -ItemType Directory -Path (Join-Path $second 'platform\steam') -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $second 'platform\steam\PBZ.exe'),'fixture; never executed')
LibraryList ("`"path`" `""+$escaped+"`"")
Check (@(Find-PBZSteamGameRoot -SteamRoots @($steam)).Count -eq 2) 'multiple game copies preserved for manual choice'
Check (@(Find-PBZSteamGameRoot -SteamRoots @()).Count -eq 0) 'explicit empty discovery roots'
[IO.File]::WriteAllText((Join-Path $steam 'steamapps\appmanifest_999.acf'),'"installdir" "..\\..\\outside"')
Check (@(Find-PBZSteamGameRoot -SteamRoots @($steam)).Count -eq 2) 'manifest path escape ignored'
Write-Output 'PASS: Steam modern/legacy libraries, manifest folder names, Unicode, duplicates, missing files, multiple copies and invalid paths.'
