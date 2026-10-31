param([string]$GameRoot)
. (Join-Path $PSScriptRoot 'Common.ps1')
$game=Get-GameRoot $GameRoot
Assert-Closed $game
$work=In-Root $game '_ModWork\DeflectWorkbench'
$manifest=Join-Path $work 'install-state.json'
if (!(Test-Path -LiteralPath $manifest)) {throw '没有本安装器的记录。请勿用卸载脚本删除手动安装版本；先在面板还原原版。'}
$state=Get-Content -LiteralPath $manifest -Raw -Encoding UTF8 | ConvertFrom-Json
$stamp=[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-ffff')
# Validate every source, archive and restore target before moving anything.
foreach($entry in $state.files) {
    $null=In-Root $game $entry.path
    $null=In-Root $work ('Uninstalled\'+$stamp+'\'+$entry.path)
    if($entry.backup) {$original=In-Root $work $entry.backup;if(!(Test-Path -LiteralPath $original)){throw 'Rollback backup missing.'}}
}
foreach($entry in $state.files) {
    $target=In-Root $game $entry.path
    if (Test-Path -LiteralPath $target) {
        $archive=In-Root $work ('Uninstalled\'+$stamp+'\'+$entry.path)
        New-Item -ItemType Directory -Path (Split-Path $archive) -Force | Out-Null
        Move-Item -LiteralPath $target -Destination $archive
    }
    if($entry.backup) {New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null;Copy-Item -LiteralPath (In-Root $work $entry.backup) -Destination $target}
}
Move-Item -LiteralPath $manifest -Destination (Join-Path $work ('uninstalled-state-'+$stamp+'.json'))
Write-Output '工作台与本次安装的模组文件已归档，安装前文件已还原。'
Write-Output '存档、配置备份与 UE4SS 加载器保留；若安装前已有此模组，将恢复该版本。'
