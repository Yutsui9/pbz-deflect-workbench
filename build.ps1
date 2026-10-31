param([switch]$Test)
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$version=(Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
$out=Join-Path $root 'dist'
New-Item -ItemType Directory -Path $out -Force | Out-Null
$source=Join-Path $root 'src\ControlPanel'
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (!(Test-Path -LiteralPath $compiler)) {throw '.NET Framework 4.x compiler is required on Windows.'}
$exe=Join-Path $out '卸势调校台.exe'
& $compiler /nologo /target:winexe /optimize+ /codepage:65001 ('/win32manifest:'+(Join-Path $source 'app.manifest')) ('/out:'+$exe) /reference:System.Windows.Forms.dll /reference:System.Drawing.dll (Join-Path $source 'ConfigCore.cs') (Join-Path $source 'Panel.cs') (Join-Path $source 'SelfTest.cs')
if ($LASTEXITCODE -ne 0) {throw 'Compilation failed. Close the panel and retry.'}
$scripts=Join-Path $out 'platform\steam\ue4ss\Mods\PBZYanyunGuard\Scripts'
New-Item -ItemType Directory -Path $scripts -Force | Out-Null
Copy-Item (Join-Path $root 'mod\Scripts\*.lua') $scripts -Force
Copy-Item (Join-Path $root 'mod\enabled.txt') (Split-Path $scripts) -Force
$help=Join-Path $out '_ModWork\YanyunGuard'
New-Item -ItemType Directory -Path $help -Force | Out-Null
Copy-Item (Join-Path $root 'docs\使用说明.txt') $help -Force
Copy-Item (Join-Path $root 'deploy') $out -Recurse -Force
foreach($name in @('安装.cmd','卸载.cmd','README.md','LICENSE','VERSION')) {Copy-Item (Join-Path $root $name) $out -Force}
if ($Test) {
    $panelCheck=Start-Process -FilePath $exe -ArgumentList '--self-test' -Wait -PassThru -WindowStyle Hidden
    if ($panelCheck.ExitCode -ne 0) {throw 'Panel self-test failed.'}
    Get-Content -LiteralPath (Join-Path $help 'ControlPanel\self-test.txt')
    & (Join-Path $root 'tests\deploy.Tests.ps1') -PackageRoot $out
    & (Join-Path $root 'tests\launcher.Tests.ps1') -PackageRoot $out
}
$artifacts=Join-Path $root 'artifacts'
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
# Explicit package list: excludes self-test fixtures and any stale build files.
$stage=Join-Path $artifacts ('stage-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stage | Out-Null
foreach($name in @('卸势调校台.exe','platform','deploy','安装.cmd','卸载.cmd','README.md','LICENSE','VERSION')) {Copy-Item (Join-Path $out $name) $stage -Recurse -Force}
$stageHelp=Join-Path $stage '_ModWork\YanyunGuard'
New-Item -ItemType Directory -Path $stageHelp -Force | Out-Null
Copy-Item (Join-Path $help '使用说明.txt') $stageHelp
$zip=Join-Path $artifacts ('pbz-deflect-workbench-v'+$version+'-windows-x64.zip')
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath $zip -Force
Get-FileHash -LiteralPath $zip -Algorithm SHA256 | ForEach-Object {($_.Hash.ToLowerInvariant()+'  '+[IO.Path]::GetFileName($zip)) | Set-Content -LiteralPath ($zip+'.sha256') -Encoding ASCII}
Write-Output ('Release: '+$zip)
