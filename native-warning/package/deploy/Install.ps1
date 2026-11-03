param([string]$GameRoot)
. (Join-Path $PSScriptRoot 'Common.ps1')
$game=Get-GameRoot $GameRoot
Assert-Closed $game
$combat=In-Root $game 'platform\steam\ue4ss\Mods\PBZYanyunGuard\Scripts\combat.lua'
if((Test-Path -LiteralPath $combat) -and (Get-Content -LiteralPath $combat -Raw).Contains('local warningFX=')) {
 throw '检测到旧合并版卸势模组。请先安装卸势调校台 v0.3.0 或更新版，再安装独立换色包，避免重复修改颜色。'
}
$relative='ProjectPBZ\Content\Paks\~mods\PBZWarningColors'
$source=Join-Path (Split-Path $PSScriptRoot) $relative
$hashes=Get-Content (Join-Path (Split-Path $PSScriptRoot) 'SHA256.json') -Raw | ConvertFrom-Json
foreach($ext in @('pak','utoc','ucas')) {
 $name='PBZWarningColors_P.'+$ext
 if(!(Test-Path -LiteralPath (Join-Path $source $name)) -or (Get-FileHash -LiteralPath (Join-Path $source $name)).Hash -ne $hashes.$name){throw ('安装包损坏：'+$name)}
}
$work=In-Root $game '_ModWork\WarningColorsNativeInstall'
$manifest=Join-Path $work 'install-state.json'
if(Test-Path -LiteralPath $manifest){$state=Get-Content $manifest -Raw | ConvertFrom-Json}else{$state=[PSCustomObject]@{version=1;files=@()}}
$stamp=[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-ffff')
foreach($ext in @('pak','utoc','ucas')) {
 $name='PBZWarningColors_P.'+$ext;$rel=$relative+'\'+$name;$target=In-Root $game $rel
 if(!($state.files | Where-Object path -eq $rel)) {
  $backup=''
  if(Test-Path -LiteralPath $target){$backup='Original\'+$stamp+'\'+$name;$saved=In-Root $work $backup;New-Item -ItemType Directory (Split-Path $saved) -Force | Out-Null;Copy-Item -LiteralPath $target -Destination $saved}
  $state.files+= [PSCustomObject]@{path=$rel;backup=$backup}
  Write-Utf8 $manifest ($state | ConvertTo-Json -Depth 5)
 }
 New-Item -ItemType Directory (Split-Path $target) -Force | Out-Null
 Copy-Item -LiteralPath (Join-Path $source $name) -Destination $target -Force
}
Write-Output '独立预警换色已安装：卸势红光、闪避金黄光。重启游戏生效；不需要 UE4SS。'
