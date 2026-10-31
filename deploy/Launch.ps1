param(
    [ValidateSet('Install','Uninstall')][string]$Action='Install',
    [string]$GameRoot,
    [switch]$NonInteractive,
    [string]$LogPath
)
$ErrorActionPreference='Stop'
$result=1
$transcribing=$false
try {
    if (!$LogPath) {
        $logDir=Join-Path $env:TEMP 'PBZDeflectWorkbench'
        $LogPath=Join-Path $logDir ('setup-'+[DateTime]::Now.ToString('yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,6)+'.log')
    }
    New-Item -ItemType Directory -Path (Split-Path $LogPath) -Force | Out-Null
    Start-Transcript -LiteralPath $LogPath -Force | Out-Null
    $transcribing=$true
    Write-Host '影之刃零 · 卸势调校台'
    Write-Host ('操作：'+$Action)
    Write-Host ('日志：'+$LogPath)
    $package=Split-Path $PSScriptRoot
    if ($Action -eq 'Install') {
        foreach($file in @('卸势调校台.exe','platform\steam\ue4ss\Mods\PBZYanyunGuard\Scripts\main.lua','platform\steam\ue4ss\Mods\PBZYanyunGuard\Scripts\config.lua')) {
            if (!(Test-Path -LiteralPath (Join-Path $package $file))) {
                throw '安装包不完整或这是 GitHub 源码包。请下载 Releases 中的 windows-x64.zip，先完整解压到普通文件夹，再运行安装.cmd；不要直接在压缩包里双击。'
            }
        }
    }
    if (!$GameRoot) {
        . (Join-Path $PSScriptRoot 'SteamPaths.ps1')
        $detected=@(Find-PBZSteamGameRoot)
        if ($detected.Count -eq 1) {
            $GameRoot=$detected[0]
            Write-Host ('已从 Steam 自动识别游戏目录：'+$GameRoot)
        } elseif ($detected.Count -gt 1) {
            Write-Host 'Steam 中找到多个游戏副本，请手动选择本次要操作的目录。'
            $detected | ForEach-Object {Write-Host ('  '+$_)}
        } else {Write-Host '未在 Steam 游戏库中找到有效游戏目录，请手动选择。'}
    }
    if (!$GameRoot) {
        if ($NonInteractive) {throw '无法自动确定唯一游戏目录，请提供 -GameRoot。'}
        Add-Type -AssemblyName System.Windows.Forms
        $dialog=New-Object System.Windows.Forms.FolderBrowserDialog
        try {
            $dialog.Description='选择 Steam 的 PBZ 游戏根目录，其中应有 platform\steam\PBZ.exe。请先关闭游戏和工作台。'
            $dialog.ShowNewFolderButton=$false
            if ($dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) {throw '你取消了目录选择，未执行安装或卸载。'}
            $GameRoot=$dialog.SelectedPath
        } finally {$dialog.Dispose()}
    }
    Write-Host ('游戏目录：'+$GameRoot)
    if ($Action -eq 'Install') {& (Join-Path $PSScriptRoot 'Install.ps1') -GameRoot $GameRoot -InstallUE4SS | Out-Host}
    else {& (Join-Path $PSScriptRoot 'Uninstall.ps1') -GameRoot $GameRoot | Out-Host}
    $result=0
    $message=if($Action -eq 'Install') {'安装成功。请打开游戏目录下的“卸势调校台.exe”，点击“启用并应用”。'} else {'卸载完成。文件已归档；存档和 UE4SS 保留。'}
    Write-Host $message -ForegroundColor Green
} catch {
    $message='操作未完成：'+$_.Exception.Message
    Write-Host $message -ForegroundColor Red
    Write-Host ($_ | Format-List * -Force | Out-String)
} finally {
    if ($transcribing) {try {Stop-Transcript | Out-Null} catch {}}
}
Write-Host ('日志位置：'+$LogPath)
if (!$NonInteractive) {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $icon=if($result -eq 0){[Windows.Forms.MessageBoxIcon]::Information}else{[Windows.Forms.MessageBoxIcon]::Error}
        [void][Windows.Forms.MessageBox]::Show(($message+"`r`n`r`n日志："+$LogPath),'卸势调校台 · 安装/卸载结果',[Windows.Forms.MessageBoxButtons]::OK,$icon)
    } catch {Write-Host '无法显示结果弹窗，请查看上面的结果与日志。'}
}
exit $result
