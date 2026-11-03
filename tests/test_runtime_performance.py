from pathlib import Path
from lupa import LuaRuntime
root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().root = str(root / 'mod/Scripts') + '/'
lua.execute(r"""
local realLoad=loadfile
local config=assert(realLoad(root..'config.lua'))()
local now,pressed,held=0,{},{}
local scans,names,plays=0,0,0
function FName(s) names=names+1;return s end
local function obj(id)
 return {IsValid=function(self) return not self.dead end,GetAddress=function() return id end,GetFullName=function() return 'Live'..id end}
end
local pawn,pc,passive,stance=obj(1),obj(2),obj(3),obj(4)
pc.Pawn=pawn
pc.WasInputKeyJustPressed=function(_,k) return pressed[k.KeyName] or false end
pc.IsInputKeyDown=function(_,k) return held[k.KeyName] or false end
local helpers={GetPlayerController=function() return pc end,
 GetKismetSystemLibrary=function() return {GetGameTimeInSeconds=function() return now end} end,
 GetGameplayStatics=function() return {IsGamePaused=function() return false end} end}
package.preload.UEHelpers=function() return helpers end
local asc={GetAllAttributes=function(_,out)
 for _,name in ipairs({'Shachi','Shachi_Max'}) do
  out[#out+1]={get=function() return {AttributeName=name} end}
 end
end}
passive.GetAbilitySystemComponentFromActorInfo=function() return asc end
passive.GetAvatarActorFromActorInfo=function() return pawn end
stance.GetAvatarActorFromActorInfo=function() return pawn end
stance.UseStrongDeflectAnim=false
passive['Anger Cost Data']={CostOfTime_6_1918214C431B290CEA5A4A9CAEAA8C4A=1,CostOfTimeStartDelay_10_D32DE2BC437394BD04342497EDBEB139=0}
passive['Normal Window']=0;passive['Perfect Window']=0;passive['Current Perfect Window Counter']=0
passive['On Stance Key Down']=function(self) self['Stance Key Down']=true end
passive['On Stance Key Release']=function(self) self['Stance Key Down']=false end
passive['Give Perfect Window']=function(self) self['Normal Window']=now+8/30;self['Perfect Window']=now+8/30 end
function FindAllOf(class)
 if class=='BP_StanceAction_Base_Player_C' then scans=scans+1;return {stance} end
 if class=='BP_PlayerDeflectPassive_C' then return {passive} end
 return {}
end
local lib={GetCharacterAttributeValue=function() return 100 end,ModifyCharacterAttributeValue=function() end}
function StaticFindObject(path) if path:find('AttributeUtils',1,true) then return lib end end
function ExecuteInGameThread(f) f() end
function LoopInGameThreadWithDelay(_,f) frame=f end
function loadfile(path)
 if path:find('config.lua',1,true) then return function() return config end end
 if path:find('parry_fx.lua',1,true) then return function() return {tick=function() end,clear=function() end,play=function() plays=plays+1 end} end end
 if path:find('warning_colors.lua',1,true) then return function() return {tick=function() end,clear=function() end} end end
 if path:find('panel_bridge.lua',1,true) then return function() return {start=function(api) bridge=api end} end end
 return realLoad(path)
end
local keys=assert(loadfile(root..'input_keys.lua'))()
for _,key in ipairs({'RightMouseButton','MiddleMouseButton','LeftMouseButton','G','Q','LeftShift','LeftControl','SpaceBar','Tab','F1','F12'}) do assert(keys.make(key).KeyName==key) end
assert(keys.make('XButton1').KeyName=='ThumbMouseButton')
assert(keys.make('XButton2').KeyName=='ThumbMouseButton2')
assert(not pcall(keys.make,'F5') and not pcall(keys.make,'Bogus'))
local m=assert(loadfile(root..'combat.lua'))();m.start();frame()
local beforeNames=names
for i=1,600 do now=i/60;frame() end
assert(scans<=11,'per-frame global stance scan regression: '..scans)
assert(names==beforeNames,'input FNames should be reused')
-- The running loop must use the new keys for BOTH actions after APPLY.
config.ParryKey='XButton1';config.GuardKey='XButton2';m.reload()
now=11;pressed={ThumbMouseButton=true};frame()
assert(plays==1 and passive['Stance Key Down'] and stance.UseStrongDeflectAnim)
pressed={};now=12;held={ThumbMouseButton2=true};frame();assert(passive['Stance Key Down'])
held={};now=12.1;frame();assert(not passive['Stance Key Down'] and not stance.UseStrongDeflectAnim)
config.ParryKey='Q';config.GuardKey='LeftControl';m.reload()
now=13;pressed={Q=true};frame();assert(plays==2)
pressed={};now=14;held={LeftControl=true};frame();assert(passive['Stance Key Down'])
held={};now=14.1;frame();assert(not passive['Stance Key Down'])
config.GuardKey='Bogus';assert(not pcall(m.reload));config.GuardKey='LeftControl'
now=15;pressed={Q=true};frame();assert(plays==3,'invalid config must retain previous input')
pressed={};m.disable();assert(not passive['Stance Key Down'])
-- Shared cache is reused across module loads and recovers on object/world changes.
local cache=assert(loadfile(root..'object_cache.lua'))()
assert(cache==assert(loadfile(root..'object_cache.lua'))())
cache.clear();cache.tick(20);local n=scans
cache.get('BP_StanceAction_Base_Player_C');cache.get('BP_StanceAction_Base_Player_C');assert(scans==n+1)
stance.dead=true;assert(#cache.get('BP_StanceAction_Base_Player_C')==0)
stance=obj(5);cache.tick(21);assert(cache.get('BP_StanceAction_Base_Player_C')[1]==stance)
cache.tick(0);cache.get('BP_StanceAction_Base_Player_C');assert(scans==n+3)
print('PASS: 600 frames <=11 stance searches; shared cache expiry/death/world reset; zero per-frame input FNames; side buttons and keyboard APPLY/rollback; guard release and animation restore')
""")
