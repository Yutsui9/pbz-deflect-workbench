param([string]$GameRoot)
. (Join-Path $PSScriptRoot 'Common.ps1')
$game=Get-GameRoot $GameRoot
Assert-Closed $game
$work=In-Root $game '_ModWork\WarningColorsNativeInstall'
$manifest=Join-Path $work 'install-state.json'
if(!(Test-Path -LiteralPath $manifest)){throw '没有独立换色安装记录。手动安装者请移出 PBZWarningColors 文件夹，再重启游戏。'}
$state=Get-Content $manifest -Raw | ConvertFrom-Json
$archive=Join-Path $work ('Uninstalled\'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-ffff'))
New-Item -ItemType Directory $archive -Force | Out-Null
foreach($entry in $state.files){
 if($entry.path -notmatch '^ProjectPBZ\\Content\\Paks\\~mods\\PBZWarningColors\\PBZWarningColors_P\.(pak|utoc|ucas)$'){throw '安装记录包含非换色文件。'}
 $target=In-Root $game $entry.path
 if(Test-Path -LiteralPath $target){Move-Item -LiteralPath $target -Destination (Join-Path $archive ([IO.Path]::GetFileName($target)))}
 if($entry.backup){$original=In-Root $work $entry.backup;Copy-Item -LiteralPath $original -Destination $target}
}
Move-Item -LiteralPath $manifest -Destination (Join-Path $archive 'install-state.json')
Write-Output '独立换色已卸载；安装前的同名资源（如有）已恢复。卸势调校与 UE4SS 不受影响。重启游戏生效。'
