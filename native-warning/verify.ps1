$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$dll=Join-Path $root 'tools/uassetapi/lib/net8.0/UAssetAPI.dll'
[Reflection.Assembly]::LoadFrom((Join-Path $root 'tools/zstd/lib/net8.0/ZstdSharp.dll')) | Out-Null
[Reflection.Assembly]::LoadFrom($dll) | Out-Null
$refs=@(Get-ChildItem "$PSHOME/ref/*.dll" | ForEach-Object FullName)+@($dll,(Join-Path $PSHOME "Newtonsoft.Json.dll"))
if(-not ('PatchWarnings' -as [type])) { Add-Type -Path (Join-Path $root 'PatchWarnings.cs') -ReferencedAssemblies $refs -CompilerOptions /nowarn:1701,1702 }
$legacy=Join-Path $root 'legacy'
foreach($file in Get-ChildItem (Join-Path $root 'patched') -Recurse -Filter 'NS_AttackAlert*.uasset') {
 $relative=[IO.Path]::GetRelativePath((Join-Path $root 'patched'),$file.FullName)
 [PatchWarnings]::Verify((Join-Path $legacy $relative),$file.FullName,(Join-Path $root 'tools/ProjectPBZ.usmap'))
 Write-Output ('PASS: visual-only exports; native alpha/white flash preserved: '+$file.Name)
}

if(-not ('GoldMaterials' -as [type])) { Add-Type -Path (Join-Path $root 'GoldMaterials.cs') -ReferencedAssemblies $refs -CompilerOptions /nowarn:1701,1702 }
foreach($file in Get-ChildItem (Join-Path $root 'patched') -Recurse -Filter '*_PBZGold.uasset') {
 $relative=[IO.Path]::GetRelativePath((Join-Path $root 'patched'),$file.FullName).Replace('_PBZGold.uasset','.uasset')
 [GoldMaterials]::Verify((Join-Path (Join-Path $root 'material-original') $relative),$file.FullName,(Join-Path $root 'tools/ProjectPBZ.usmap'))
 Write-Output ('PASS: material parent/textures/non-color parameters preserved: '+$file.Name)
}
