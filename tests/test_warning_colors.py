from pathlib import Path
from lupa import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.globals().module_path=str(Path(__file__).resolve().parents[1]/'mod/Scripts/warning_colors.lua')
lua.execute(r'''
function FName(s) return {ToString=function() return s end} end
function FText(s) return {ToString=function() return s end} end
local function array(values)
 return {ForEach=function(_,fn) for i,v in ipairs(values) do fn(i,{get=function() return values[i] end,set=function(_,x) values[i]=x end}) end end}
end
local function curve(id,name,data)
 return {IsValid=function() return true end,GetAddress=function() return id end,GetFullName=function() return name end,bUseLUT=true,ShaderLUT=array(data)}
end
local r={1,.02,.01,.7,1,1,1,.8,0,0,0,0}
local b={.1,.3,2,.6}
local other={.1,.3,2,.6}
local prefix='NiagaraDataInterfaceColorCurve /PBZVFXPack/VFX/BattleFX/Common/'
local curves={curve(1,prefix..'NS_AttackAlert_Red_001.NS_AttackAlert_Red_001:Emitter.Curve',r),curve(2,prefix..'NS_AttackAlert_Blue_002.NS_AttackAlert_Blue_002:Emitter.Curve',b),curve(3,prefix..'NS_AttackAlertHun_White_301.Other:Curve',other)}
local native='尽可能完美格挡<Tutorial_Body_Blue>蓝光技能</>，或完美闪避<Tutorial_Body_Red>红光技能</>，才有取胜之机！'
local current=FText(native)
local widget={IsValid=function() return true end,GetAddress=function() return 4 end,GetFullName=function() return 'PBZCommonLocRichText Tutorial' end,GetText=function() return current end,SetText=function(_,t) current=t end}
local edge={R=25,G=0,B=0,A=1}
local body={R=.5,G=.01,B=.01,A=.37}
local uv={R=1,G=0,B=0,A=0}
local neutral={R=.8,G=.8,B=.8,A=.372}
local function name(s) return {ToString=function() return s end} end
local meshParams={{MaterialParameterName=name('EdgeColor'),Value=edge},{MaterialParameterName=name('Main_Color_1'),Value=body},{MaterialParameterName=name('MaskChannel'),Value=uv},{MaterialParameterName=name('Main_Color_0'),Value=neutral}}
local renderer={IsValid=function() return true end,GetAddress=function() return 5 end,GetFullName=function() return 'NiagaraMeshRendererProperties /PBZVFXPack/VFX/BattleFX/Hun/NS_AttackAlertHun_Red_001.NS_AttackAlertHun_Red_001:Emitter.Renderer' end,MaterialParameters={VectorParameters=array(meshParams)},Material='native texture',ColorBinding={RootName=name('Color'),ParamMapVariable={Name=name('Particles.Color')},DataSetName=name('Color'),bBindingExistsOnSource=true}}
local parent={IsValid=function() return true end,GetAddress=function() return 100 end,GetFullName=function() return 'Native_Glow_Texture' end,K2_GetVectorParameterValue=function() return {R=.5,G=.5,B=.5,A=.5} end}
local function sprite(id,sim)
 return {IsValid=function() return true end,GetAddress=function() return id end,GetFullName=function() return 'NiagaraSpriteRendererProperties /PBZVFXPack/VFX/BattleFX/Hun/NS_AttackAlertHun_Red_001.NS_AttackAlertHun_Red_001:Emitter'..id..'.Renderer' end,GetOuter=function() return {VersionData=array({{SimTarget=sim}})} end,Material=parent,MaterialParameters={VectorParameters=array({})},ColorBinding={RootName=name('Color'),ParamMapVariable={Name=name('Particles.Color')},DataSetName=name('Color'),bBindingExistsOnSource=true}}
end
local gpu,cpu=sprite(6,1),sprite(7,0)
local smoke=sprite(8,1)
smoke.Material={IsValid=function() return true end,GetAddress=function() return 102 end,GetFullName=function() return 'Native_Smoke_Texture' end,K2_GetVectorParameterValue=parent.K2_GetVectorParameterValue}
local smokeParent=smoke.Material
local smokeTint={R=.8,G=.8,B=.8,A=.372}
smoke.MaterialParameters.VectorParameters=array({{MaterialParameterName=name('Main_Color_1'),Value=smokeTint}})
package.preload.UEHelpers=function() return {GetPlayerController=function() return {} end} end
local nextId=200
local textHook
local hookRegistrations=0
local spriteObjects={gpu,cpu,smoke}
local assetVersion=0
local scans=0
function RegisterHook(_,pre,post) hookRegistrations=hookRegistrations+1;textHook=post;return 1,2 end
function StaticFindObject(path)
 if path=='/Script/UMG.RichTextBlock:SetText' then return {IsValid=function() return true end} end
 if path:find('/PBZVFXPack/',1,true) then
  if assetVersion>0 then return {IsValid=function() return true end,GetAddress=function() return assetVersion end} end
  return nil
 end
 return {CreateDynamicMaterialInstance=function()
  nextId=nextId+1;local id=nextId
  return {params={},scalars={},SetScalarParameterValue=function(self,key,v) self.scalars[key:ToString()]=v end,IsValid=function() return true end,GetAddress=function() return id end,SetVectorParameterValue=function(self,key,v) self.params[key:ToString()]=v end}
 end}
end
function FindAllOf(c) scans=scans+1;if c=='NiagaraSpriteRendererProperties' then return spriteObjects elseif c=='NiagaraMeshRendererProperties' then return {renderer} elseif c=='NiagaraDataInterfaceColorCurve' then return curves elseif c=='PBZCommonLocRichText' then return {widget} end end
local m=assert(loadfile(module_path))()
local function settle(t) for i=0,14 do local before=scans;m.tick({WarningColorsEnabled=true},t+i*.02);assert(scans-before<=1,'at most one class discovery per frame') end end
settle(0)
assert(r[1]==1 and r[2]==.78 and r[3]==.025 and r[4]==.7)
assert(b[1]==2 and b[2]==.05 and b[3]==.02 and b[4]==.6)
assert(gpu.Material~=parent and math.abs(gpu.Material.params.Main_Color_1.R-1.17)<1e-8 and gpu.Material.params.Main_Color_1.A==.375,'GPU gold uses original texture parent with reduced opacity')
assert(gpu.Material.scalars.Tex_Color_Pow==1.2,'glow texture contrast tightened without increasing peak brightness')
assert(cpu.Material~=parent and cpu.ColorBinding.DataSetName:ToString()=='PBZWarningGoldGlow','CPU outer glow red multiplier covered')
assert(math.abs(smokeTint.R-.45)<1e-8 and math.abs(smokeTint.G-.28)<1e-8 and math.abs(smokeTint.A-.1674)<1e-8,'outer smoke gold and translucent')
assert(math.abs(edge.R-10)<1e-8 and math.abs(edge.G-8.8)<1e-8 and math.abs(edge.B-5.5)<1e-8 and edge.A==1,'gold ring HDR intensity reduced without hue/alpha change')
assert(math.abs(body.R-.4592)<1e-8 and body.A==.37,'layered body retains source alpha')
assert(uv.R==1 and uv.G==0 and neutral.R==.8 and neutral.G==.8,'UV masks and neutral smoke untouched')
assert(renderer.Material=='native texture' and renderer.ColorBinding.DataSetName:ToString()=='PBZWarningGoldCore','native shader retained; only primary gold quad bypasses red tint')
assert(r[5]==1 and r[6]==1 and r[7]==1 and r[8]==.8,'white flash and alpha preserved')
assert(other[1]==.1 and other[2]==.3,'unrelated systems untouched')
assert(current:ToString():find('<Tutorial_Body_Red>红光技能</>',1,true))
assert(current:ToString():find('<Tutorial_Body_Yellow>黄光技能</>',1,true))
local baselineScans,baselineMaterials=scans,nextId
for i=1,600 do m.tick({WarningColorsEnabled=true},.2+i/60) end
assert(scans==baselineScans and nextId==baselineMaterials,'steady state performs zero global searches and creates zero extra materials')
current=FText(native)
textHook({get=function() return widget end})
m.tick({WarningColorsEnabled=true},10.21)
assert(current:ToString():find('<Tutorial_Body_Yellow>黄光技能</>',1,true),'late tutorial SetText event patched')
assert(scans==baselineScans,'tutorial events do not trigger a global search')
assetVersion=1
settle(11)
assert(scans==baselineScans+5,'newly loaded target assets trigger one discovery pass')

m.clear()
assert(smoke.Material==smokeParent and smokeTint.R==.8 and smokeTint.A==.372,'smoke material/tint/alpha restored')
assert(gpu.Material==parent and gpu.ColorBinding.DataSetName:ToString()=='Color','GPU material and colour binding restored')
assert(renderer.ColorBinding.DataSetName:ToString()=='Color' and renderer.ColorBinding.bBindingExistsOnSource,'original core binding restored')
assert(edge.G==0 and edge.B==0 and body.R==.5 and body.G==.01 and body.A==.37,'exact renderer parameter restoration')
assert(r[2]==.02 and r[3]==.01 and b[1]==.1 and b[3]==2,'exact curve restoration')
assert(current:ToString()==native,'original rich text restored')
settle(12)
current=FText('another tutorial')
m.tick({WarningColorsEnabled=false},13)
assert(current:ToString()=='another tutorial','reused widget is not overwritten on disable')
settle(14)
m.clear();m.clear()
assert(b[1]==.1,'repeated restore is idempotent')
local m2=assert(loadfile(module_path))()
for i=0,14 do m2.tick({WarningColorsEnabled=true},16+i*.02) end
assert(hookRegistrations==1,'reload does not register duplicate text listeners')
current=FText(native)
textHook({get=function() return widget end})
m2.tick({WarningColorsEnabled=true},16.3)
assert(current:ToString():find('<Tutorial_Body_Yellow>黄光技能</>',1,true),'existing listener routes to newly loaded module')
local unrelatedReads=0
for i=1,200 do
 local id=1000+i
 spriteObjects[#spriteObjects+1]={IsValid=function() return true end,GetAddress=function() return id end,GetFullName=function() unrelatedReads=unrelatedReads+1;return 'NiagaraSpriteRendererProperties Unrelated'..id end}
end
assetVersion=2
for i=1,60 do
 local beforeScans,beforeReads=scans,unrelatedReads
 m2.tick({WarningColorsEnabled=true},16.3+i*.02)
 assert(scans-beforeScans<=1 and unrelatedReads-beforeReads<=32,'large discoveries respect per-frame class/object budget')
end
assert(unrelatedReads==200,'large discovery visits each unrelated object once')
m2.clear()

''')
print('PASS: zero steady-state global scans/material allocations, incremental discovery, late text events, asset refresh, exact alert scope, requested hues, glow parent/opacity and rollback, CPU outer glow coverage, HDR gold edge, layered body, exact renderer restoration, alpha/white flashes, rich-text styles, repeat apply, full restore, reused widget, repeated disable.')
