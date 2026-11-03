$ErrorActionPreference='Stop'
function Get-GameRoot([string]$Path) {
    if (!$Path) {
        . (Join-Path $PSScriptRoot 'SteamPaths.ps1')
        $found=@(Find-PBZSteamGameRoot)
        if($found.Count -eq 1){$Path=$found[0];Write-Host ('已从 Steam 自动识别游戏目录：'+$Path)}
        else {$Path=Read-Host '输入 Steam 游戏目录（包含 platform 和 ProjectPBZ 的 PBZ 文件夹）'}
    }
    $root=[IO.Path]::GetFullPath($Path.Trim('"')).TrimEnd('\')
    if (!(Test-Path -LiteralPath (Join-Path $root 'platform\steam\PBZ.exe'))) {throw '不是有效的 PBZ 游戏根目录：找不到 platform\steam\PBZ.exe。'}
    return $root
}
function In-Root([string]$Root,[string]$Relative) {
    if ([IO.Path]::IsPathRooted($Relative)) {throw 'Expected relative path.'}
    $path=[IO.Path]::GetFullPath((Join-Path $Root $Relative))
    if (!$path.StartsWith($Root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) {throw 'Path leaves game directory.'}
    return $path
}
function Assert-Closed([string]$Root) {
    foreach($p in @(Get-Process -Name PBZ,'卸势调校台','燕云式招架配置' -ErrorAction SilentlyContinue)) {
        try {$path=$p.Path} catch {throw '请先关闭游戏和配置面板。'}
        if ($path -and $path.StartsWith($Root+'\',[StringComparison]::OrdinalIgnoreCase)) {throw '请先关闭该游戏目录下的游戏和配置面板。'}
    }
}
function Write-Utf8([string]$Path,[string]$Content) {
    New-Item -ItemType Directory -Path (Split-Path $Path) -Force | Out-Null
    [IO.File]::WriteAllText($Path,$Content,(New-Object Text.UTF8Encoding($false)))
}
