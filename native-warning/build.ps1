# Developer build: extracted original resources and local tools are required; see README.md.
$ErrorActionPreference='Stop'
& (Join-Path $PSScriptRoot 'patch.ps1')
& (Join-Path $PSScriptRoot 'verify.ps1')
python (Join-Path $PSScriptRoot 'patch_text.py')
if($LASTEXITCODE){throw 'Text patch failed'}
$dist=Join-Path $PSScriptRoot 'dist'
New-Item -ItemType Directory $dist -Force | Out-Null
& (Join-Path $PSScriptRoot 'tools/retoc-verified/retoc.exe') to-zen (Join-Path $PSScriptRoot 'patched') (Join-Path $dist 'PBZWarningColors_P.utoc') --version UE5_7
if($LASTEXITCODE){throw 'IoStore build failed'}
& (Join-Path $PSScriptRoot 'tools/repak/repak.exe') pack --version V11 (Join-Path $PSScriptRoot 'text-patched') (Join-Path $dist 'PBZWarningColors_P.pak')
if($LASTEXITCODE){throw 'PAK build failed'}
& (Join-Path $PSScriptRoot 'tools/retoc-verified/retoc.exe') verify (Join-Path $dist 'PBZWarningColors_P.utoc')
if($LASTEXITCODE){throw 'Container verification failed'}
$target=Join-Path $PSScriptRoot 'package/ProjectPBZ/Content/Paks/~mods/PBZWarningColors'
New-Item -ItemType Directory $target -Force | Out-Null
Copy-Item (Join-Path $dist 'PBZWarningColors_P.*') $target -Force
$hashes=@{}
Get-ChildItem $target -File | ForEach-Object {$hashes[$_.Name]=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()}
$hashes | ConvertTo-Json | Set-Content (Join-Path $PSScriptRoot 'package/SHA256.json') -Encoding UTF8
$artifacts=Join-Path $PSScriptRoot 'artifacts'
New-Item -ItemType Directory $artifacts -Force | Out-Null
$zip=Join-Path $artifacts 'pbz-warning-colors-v1.0.0-beta1-no-ue4ss.zip'
Compress-Archive (Join-Path $PSScriptRoot 'package/*') $zip -Force
((Get-FileHash $zip).Hash.ToLowerInvariant()+'  '+[IO.Path]::GetFileName($zip)) | Set-Content ($zip+'.sha256') -Encoding ASCII
Write-Output $zip
