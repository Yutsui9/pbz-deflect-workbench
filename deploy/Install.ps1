param([string]$GameRoot,[switch]$InstallUE4SS,[string]$UE4SSArchive)
. (Join-Path $PSScriptRoot 'Common.ps1')
$game=Get-GameRoot $GameRoot
Assert-Closed $game
$package=Split-Path $PSScriptRoot
if (!(Test-Path -LiteralPath (Join-Path $package '卸势调校台.exe'))) {throw '请先运行 build.ps1，或下载并完整解压 Release 安装包。'}
$work=In-Root $game '_ModWork\DeflectWorkbench'
New-Item -ItemType Directory -Path $work -Force | Out-Null
$stamp=[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-ffff')
$loader=In-Root $game 'platform\steam\ue4ss\UE4SS.dll'
$helperCandidates=@('platform\steam\ue4ss\Mods\shared\UEHelpers\UEHelpers.lua','platform\steam\ue4ss\Mods\shared\UEHelpers.lua','platform\steam\ue4ss\UEHelpers.lua')
$helperFound=@($helperCandidates | ForEach-Object {In-Root $game $_} | Where-Object {(Test-Path -LiteralPath $_ -PathType Leaf) -and (Get-Item -LiteralPath $_).Length -gt 0})
$freshLoader=!(Test-Path -LiteralPath $loader)
if ($freshLoader -or $helperFound.Count -eq 0) {
    if (!$InstallUE4SS) {throw '缺少完整 UE4SS 依赖（UE4SS.dll 或 UEHelpers）。请运行新版安装.cmd 自动补齐，或使用 -InstallUE4SS。'}
    $proxy=In-Root $game 'platform\steam\dwmapi.dll'
    if ($freshLoader -and (Test-Path -LiteralPath $proxy)) {throw '已存在 dwmapi.dll，但未找到 UE4SS.dll；为避免覆盖其他加载器，请先处理冲突。'}
    if (!$freshLoader -and !(Test-Path -LiteralPath $proxy)) {throw '已有 UE4SS.dll 但缺少 dwmapi.dll，请先修复加载器。'}
    $url='https://github.com/KintaroModding/ue4ss/releases/download/v3.0.1-1188-gf885e8d2/phantombladezero_ue4ss_v3.0.1-1188-gf885e8d2.zip'
    $archive=$UE4SSArchive
    if (!$archive) {
        $archive=Join-Path $work ('ue4ss-'+$stamp+'.zip')
        [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing
    }
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne '14acc9a34d3b3278860b63513544ac3f6e4759a673e57d6c0b5d3992b2ca5f28') {throw 'UE4SS checksum mismatch; no loader installed.'}
    $extract=Join-Path $work ('loader-'+$stamp)
    Expand-Archive -LiteralPath $archive -DestinationPath $extract
    $candidate=@(Get-ChildItem -LiteralPath $extract -Filter dwmapi.dll -Recurse | Where-Object {Test-Path -LiteralPath (Join-Path $_.DirectoryName 'ue4ss\UE4SS.dll')})
    if ($candidate.Count -ne 1) {throw 'Unexpected UE4SS archive layout.'}
    $helperSource=Join-Path $candidate[0].DirectoryName 'ue4ss\Mods\shared\UEHelpers\UEHelpers.lua'
    if (!(Test-Path -LiteralPath $helperSource)) {throw '验证后的加载器包缺少 UEHelpers，未安装。'}
    if ($freshLoader) {
        $settings=Join-Path $candidate[0].DirectoryName 'ue4ss\UE4SS-settings.ini'
        if (Test-Path -LiteralPath $settings) {
            $text=[IO.File]::ReadAllText($settings) -replace '(?m)^EnableHotReloadSystem\s*=.*$','EnableHotReloadSystem = 0' -replace '(?m)^EnableAutoReloadingLuaMods\s*=.*$','EnableAutoReloadingLuaMods = 0'
            Write-Utf8 $settings $text
        }
        Copy-Item -LiteralPath $candidate[0].FullName -Destination (Split-Path $proxy)
        Copy-Item -LiteralPath (Join-Path $candidate[0].DirectoryName 'ue4ss') -Destination (Split-Path $proxy) -Recurse -Force
    } else {
        $helperTarget=In-Root $game $helperCandidates[0]
        New-Item -ItemType Directory -Path (Split-Path $helperTarget) -Force | Out-Null
        if(Test-Path -LiteralPath $helperTarget) {
            $backup=Join-Path $work ('DependencyBackups\'+$stamp)
            New-Item -ItemType Directory -Path $backup -Force | Out-Null
            Copy-Item -LiteralPath $helperTarget -Destination (Join-Path $backup 'UEHelpers.lua')
        }
        Copy-Item -LiteralPath $helperSource -Destination $helperTarget -Force
        Copy-Item -LiteralPath (Join-Path $candidate[0].DirectoryName 'ue4ss\LICENSE') -Destination (Join-Path (Split-Path $helperTarget) 'LICENSE.ue4ss.txt') -Force
        Write-Output '已补齐 UEHelpers 辅助脚本；已有 UE4SS DLL、设置和其他模组保持不变。'
    }
}
if (!(Test-Path -LiteralPath (In-Root $game 'platform\steam\dwmapi.dll'))) {throw 'UE4SS.dll exists but dwmapi.dll is missing. Repair UE4SS first.'}
# Copy saves only; never change the active save or Steam Cloud preferences.
$saved=In-Root $game 'ProjectPBZ\Saved'
if (Test-Path -LiteralPath $saved) {
    $saveBackup=Join-Path $work ('SaveBackups\'+$stamp+'\Saved')
    New-Item -ItemType Directory -Path (Split-Path $saveBackup) -Force | Out-Null
    Copy-Item -LiteralPath $saved -Destination $saveBackup -Recurse -Force
}
$manifest=Join-Path $work 'install-state.json'
if (Test-Path -LiteralPath $manifest) {$state=Get-Content -LiteralPath $manifest -Raw -Encoding UTF8 | ConvertFrom-Json}
else {$state=[PSCustomObject]@{version=1;files=@()}}
$known=@{}
foreach($entry in $state.files) {$null=In-Root $game $entry.path;if($entry.backup){$null=In-Root $work $entry.backup};$known[$entry.path]=$true}
$relative=@('卸势调校台.exe','_ModWork\YanyunGuard\使用说明.txt','platform\steam\ue4ss\Mods\PBZYanyunGuard\enabled.txt')
$sourceScripts=Join-Path $package 'platform\steam\ue4ss\Mods\PBZYanyunGuard\Scripts'
foreach($file in Get-ChildItem -LiteralPath $sourceScripts -Filter '*.lua') {$relative+=('platform\steam\ue4ss\Mods\PBZYanyunGuard\Scripts\'+$file.Name)}
foreach($rel in $relative) {
    $target=In-Root $game $rel
    if ($rel.EndsWith('\config.lua') -and (Test-Path -LiteralPath $target)) {continue} # Preserve existing tuning.
    if (!$known.ContainsKey($rel)) {
        $backup=''
        if (Test-Path -LiteralPath $target) {
            $backup='OriginalFiles\'+$stamp+'\'+$rel
            $backupFile=In-Root $work $backup
            New-Item -ItemType Directory -Path (Split-Path $backupFile) -Force | Out-Null
            Copy-Item -LiteralPath $target -Destination $backupFile
        }
        $state.files+= [PSCustomObject]@{path=$rel;backup=$backup}
        # Record rollback before mutating each file.
        Write-Utf8 $manifest ($state | ConvertTo-Json -Depth 8)
        $known[$rel]=$true
    }
    New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $package $rel) -Destination $target -Force
}
Write-Output ('安装完成。存档备份/回滚记录：'+$work)
Write-Output ('打开：'+(Join-Path $game '卸势调校台.exe'))
Write-Output '再从 Steam 启动游戏；已存在的配置会保留，选择独立功能开关并点击“应用设置”。'
