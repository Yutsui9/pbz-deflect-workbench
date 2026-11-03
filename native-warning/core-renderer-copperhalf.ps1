$ErrorActionPreference='Stop'
$root=$PSScriptRoot
[Reflection.Assembly]::LoadFrom((Join-Path $root 'tools/zstd/lib/net8.0/ZstdSharp.dll')) | Out-Null
[Reflection.Assembly]::LoadFrom((Join-Path $root 'tools/uassetapi/lib/net8.0/UAssetAPI.dll')) | Out-Null
$m=[UAssetAPI.Unversioned.Usmap]::new((Join-Path $root 'tools/ProjectPBZ.usmap'))
$input=Join-Path $root 'core-renderer-copperhalf-input'
$baseline=Join-Path $root 'diagnose-restore-core-input'
$files=@(Get-ChildItem $baseline -Recurse -Filter '*.uasset' | Where-Object {$_.BaseName -match '^NS_AttackAlert.*_(Red|Blue)_' -or $_.BaseName.EndsWith('_PBZGold')})
if($files.Count -ne 20){throw 'Expected 20 beta3 assets'}
$count=0
foreach($file in $files){
 $rel=[IO.Path]::GetRelativePath($baseline,$file.FullName);$dst=Join-Path $input $rel
 New-Item -ItemType Directory (Split-Path $dst) -Force | Out-Null
 foreach($ext in @('.uasset','.uexp')){Copy-Item -LiteralPath ([IO.Path]::ChangeExtension($file.FullName,$ext)) -Destination ([IO.Path]::ChangeExtension($dst,$ext)) -Force}
 if($file.BaseName -notmatch '^NS_AttackAlert.*_Red_'){continue}
 $a=[UAssetAPI.UAsset]::new($file.FullName,[UAssetAPI.UnrealTypes.EngineVersion]::VER_UE5_6,$m,[UAssetAPI.CustomSerializationFlags]::None)
 $indices=@()
 for($i=0;$i -lt $a.Exports.Count;$i++){
  $e=$a.Exports[$i]
  if(!$e.ObjectName.ToString().StartsWith('NiagaraSpriteRendererProperties')){continue}
  $mat=$e.Data | Where-Object {$_.Name.ToString() -eq 'Material'}
  if(!$mat -or $mat.Value.Index -ge 0){continue}
  $name=$a.Imports[-$mat.Value.Index-1].ObjectName.ToString()
  if($name -notin @('MI_FX_A1_Glow_001_B_PBZGold','MI_FX_B1_Glow_001_B_PBZGold','MI_FX_B1_Glow_001_Nd_PBZGold')){continue}
  $mp=$e.Data | Where-Object {$_.Name.ToString() -eq 'MaterialParameters'}
  $vectors=$mp.Value | Where-Object {$_.Name.ToString() -eq 'VectorParameters'}
  $changed=0
  foreach($v in $vectors.Value){
   $pn=$v.Value | Where-Object {$_.Name.ToString() -eq 'MaterialParameterName'}
   if($pn.Value.ToString() -notin @('Main_Color_1','Main_Color_2','Color')){continue}
   $pn.Value=[UAssetAPI.UnrealTypes.FName]::FromString($a,$pn.Value.ToString())
   $c=($v.Value | Where-Object {$_.Name.ToString() -eq 'Value'}).Value[0]
   $c.Value=[UAssetAPI.UnrealTypes.FLinearColor]::new(.32,.04,0,$c.Value.A)
   $c.IsZero=$false;$changed++
  }
  if($changed -ne 3){throw 'Expected three existing vectors'}
  $indices+=$i;$count++

 }
 $a.Write($dst)
 $left=[UAssetAPI.UAsset]::new($file.FullName,[UAssetAPI.UnrealTypes.EngineVersion]::VER_UE5_6,$null,[UAssetAPI.CustomSerializationFlags]::None)
 $right=[UAssetAPI.UAsset]::new($dst,[UAssetAPI.UnrealTypes.EngineVersion]::VER_UE5_6,$null,[UAssetAPI.CustomSerializationFlags]::None)
 for($i=0;$i -lt $left.Exports.Count;$i++){
  if($i -notin $indices -and [Convert]::ToBase64String($left.Exports[$i].Data) -ne [Convert]::ToBase64String($right.Exports[$i].Data)){throw 'Non-target export changed'}
 }
 $check=[UAssetAPI.UAsset]::new($dst,[UAssetAPI.UnrealTypes.EngineVersion]::VER_UE5_6,$m,[UAssetAPI.CustomSerializationFlags]::None)
 foreach($i in $indices){
  $mp=$check.Exports[$i].Data | Where-Object {$_.Name.ToString() -eq 'MaterialParameters'}
  $vs=$mp.Value | Where-Object {$_.Name.ToString() -eq 'VectorParameters'}
  foreach($v in $vs.Value){
   $pn=($v.Value | Where-Object {$_.Name.ToString() -eq 'MaterialParameterName'}).Value
   $expected=[UAssetAPI.UnrealTypes.FName]::FromString($check,$pn.ToString())
   if($pn.Value.ToString() -ne $expected.Value.ToString() -or $pn.Number -ne $expected.Number){throw 'FName mismatch'}
   $c=($v.Value | Where-Object {$_.Name.ToString() -eq 'Value'}).Value[0].Value
   if([Math]::Abs($c.R-.32) -gt .00001 -or [Math]::Abs($c.G-.04) -gt .00001 -or [Math]::Abs($c.B-0) -gt .00001 -or $c.A -ne .75){throw 'Color mismatch'}
  }
 }

}
if($count -ne 3){throw ('Expected 3 renderers, got '+$count)}
$out=Join-Path $root 'core-renderer-copperhalf-dist'
New-Item -ItemType Directory $out -Force | Out-Null
& (Join-Path $root 'tools/retoc-verified/retoc.exe') to-zen $input (Join-Path $out 'PBZWarningColors_P.utoc') --version UE5_7
if($LASTEXITCODE){throw 'Pack failed'}
Copy-Item (Join-Path $root '../WarningColorsNativeInstall/before-single-tint-20261103-232216/PBZWarningColors_P.pak') $out -Force
& (Join-Path $root 'tools/retoc-verified/retoc.exe') verify (Join-Path $out 'PBZWarningColors_P.utoc')
if($LASTEXITCODE){throw 'Container check failed'}
'PASS: tints three Glow_001 renderers; parameter identities validated; other exports unchanged'




