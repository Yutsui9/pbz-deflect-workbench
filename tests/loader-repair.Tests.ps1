param([Parameter(Mandatory=$true)][string]$PackageRoot,[string]$UE4SSArchive)
$ErrorActionPreference='Stop'
$area=Join-Path (Split-Path $PSScriptRoot) ('.test-work\helper-repair-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $area 'platform\steam\ue4ss') -Force | Out-Null
foreach($rel in @('platform\steam\PBZ.exe','platform\steam\dwmapi.dll','platform\steam\ue4ss\UE4SS.dll','platform\steam\ue4ss\UE4SS-settings.ini')) {[IO.File]::WriteAllText((Join-Path $area $rel),'sentinel; never executable')}
$helper=Join-Path $area 'platform\steam\ue4ss\Mods\shared\UEHelpers\UEHelpers.lua'
New-Item -ItemType Directory -Path (Split-Path $helper) -Force | Out-Null
[IO.File]::WriteAllText($helper,'') # Empty helper must also be treated as missing.
$install=Join-Path $PackageRoot 'deploy\Install.ps1'
$rejected=$false
try {& $install -GameRoot $area} catch {$rejected=$_.Exception.Message.Contains('UEHelpers')}
if(!$rejected){throw 'Missing helper was not detected before mod installation.'}
if(Test-Path -LiteralPath (Join-Path $area '卸势调校台.exe')){throw 'Mod was installed with missing helper.'}
if($UE4SSArchive) {
    & $install -GameRoot $area -InstallUE4SS -UE4SSArchive $UE4SSArchive
    if(!(Test-Path -LiteralPath $helper) -or (Get-Item -LiteralPath $helper).Length -eq 0){throw 'Helper repair failed.'}
    foreach($rel in @('platform\steam\dwmapi.dll','platform\steam\ue4ss\UE4SS.dll','platform\steam\ue4ss\UE4SS-settings.ini')) {
        if([IO.File]::ReadAllText((Join-Path $area $rel)) -ne 'sentinel; never executable'){throw 'Existing loader file was changed.'}
    }
    $hash=(Get-FileHash -LiteralPath $helper -Algorithm SHA256).Hash
    & $install -GameRoot $area
    if((Get-FileHash -LiteralPath $helper -Algorithm SHA256).Hash -ne $hash){throw 'Existing helper was overwritten.'}
    Write-Output 'PASS: verified archive repairs missing helper; DLLs/settings preserved; existing helper retained.'
} else {Write-Output 'PASS: missing or empty UEHelpers detected before installing mod.'}
