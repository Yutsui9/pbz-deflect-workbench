$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$dll=Join-Path $root 'tools/uassetapi/lib/net8.0/UAssetAPI.dll'
[Reflection.Assembly]::LoadFrom((Join-Path $root 'tools/zstd/lib/net8.0/ZstdSharp.dll')) | Out-Null
[Reflection.Assembly]::LoadFrom($dll) | Out-Null
$refs=@(Get-ChildItem "$PSHOME/ref/*.dll" | ForEach-Object FullName)+@($dll,(Join-Path $PSHOME "Newtonsoft.Json.dll"))
Add-Type -Path (Join-Path $root 'PatchWarnings.cs') -ReferencedAssemblies $refs -CompilerOptions /nowarn:1701,1702
Add-Type -Path (Join-Path $root 'GoldMaterials.cs') -ReferencedAssemblies $refs -CompilerOptions /nowarn:1701,1702
$legacy=Join-Path $root 'legacy'
$report=@()
foreach ($file in (Get-ChildItem $legacy -Filter '*.uasset' -Recurse | Where-Object BaseName -Match '_(Red|Blue)_')) {
 $relative=[IO.Path]::GetRelativePath($legacy,$file.FullName)
 $out=Join-Path (Join-Path $root 'patched') $relative
 $report += [PatchWarnings]::Run($file.FullName,$out,(Join-Path $root 'tools/ProjectPBZ.usmap'))
 $original=[IO.Path]::ChangeExtension($file.FullName,'.uexp')
 $baseline=[IO.Path]::ChangeExtension(($out+'.baseline.uasset'),'.uexp')
 if((Get-FileHash $original).Hash -ne (Get-FileHash $baseline).Hash){throw "Untouched round trip differs: $relative"}
 # Baselines live outside the packaged tree.
 $baselineDir=Join-Path $root 'baselines'
 New-Item -ItemType Directory -Path $baselineDir -Force | Out-Null
 foreach($ext in @('.uasset','.uexp')) { $from=[IO.Path]::ChangeExtension(($out+'.baseline.uasset'),$ext);Move-Item -LiteralPath $from -Destination (Join-Path $baselineDir ($file.BaseName+$ext)) -Force }
}
foreach($file in Get-ChildItem (Join-Path $root 'patched') -Recurse -Filter '*_Red_*.uasset') {
 [GoldMaterials]::Run($file.FullName,(Join-Path $root 'material-original'),(Join-Path $root 'patched'),(Join-Path $root 'tools/ProjectPBZ.usmap'))
}
$report | Set-Content (Join-Path $root 'patch-report.txt') -Encoding UTF8
$report
