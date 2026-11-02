from pathlib import Path
from lupa import LuaRuntime
root=Path(__file__).resolve().parents[1]
for combat in (False, True):
 for colour in (False, True):
  lua=LuaRuntime(unpack_returned_tuples=True)
  lua.globals().root=str(root/'mod/Scripts')+'/'
  lua.globals().combat_on=combat
  lua.globals().colour_on=colour
  lua.execute(r'''local realLoad=loadfile
local config=assert(realLoad(root.."config.lua"))()
config.Enabled=combat_on;config.WarningColorsEnabled=colour_on
local counts={warning=0,fx=0,scan=0,clear=0}
local pc={IsValid=function() return true end,WasInputKeyJustPressed=function() return false end}
package.preload.UEHelpers=function() return {GetPlayerController=function() return pc end,GetKismetSystemLibrary=function() return {GetGameTimeInSeconds=function() return 1 end} end} end
Key={RIGHT_MOUSE_BUTTON=1}
function FName(s) return s end
function FindAllOf() counts.scan=counts.scan+1;return {} end
function StaticFindObject() return nil end
function ExecuteInGameThread(f) f() end
function LoopInGameThreadWithDelay(_,f) frame=f end
function loadfile(path)
 if path:find('config.lua',1,true) then return function() return config end end
 if path:find('parry_fx.lua',1,true) then return function() return {tick=function() counts.fx=counts.fx+1 end,clear=function() end} end end
 if path:find('warning_colors.lua',1,true) then return function() return {tick=function(c) assert(c.WarningColorsEnabled);counts.warning=counts.warning+1 end,clear=function() counts.clear=counts.clear+1 end} end end
 if path:find('panel_bridge.lua',1,true) then return function() return {start=function(api) bridge=api end} end end
 return realLoad(path)
end
local m=assert(loadfile(root..'combat.lua'))();m.start();frame()
assert(bridge.enabled()==combat_on and bridge.warningEnabled()==colour_on)
assert(counts.warning==(colour_on and 1 or 0),'colour follows only its switch')
assert(counts.fx==(combat_on and 1 or 0),'combat feedback follows only its switch')
assert(combat_on or counts.scan==0,'colour-only must not discover combat assets or actors')
config.Enabled=false;config.WarningColorsEnabled=true;m.reload();frame()
assert(not bridge.enabled() and bridge.warningEnabled(),'switch to colour-only')
m.disable();assert(not bridge.enabled() and not bridge.warningEnabled(),'F7 disables both')
local before=counts.warning;frame();assert(counts.warning==before)
m.reload();frame();assert(counts.warning==before+1,'F5 restores saved independent mode')
config.FeatureSwitchVersion=nil;config.Enabled=false;config.WarningColorsEnabled=true;m.reload();frame()
assert(not bridge.warningEnabled(),'legacy disabled remains disabled')
''')
print('PASS: four runtime modes, colour-only skips combat, mode transitions, F7/F5, legacy migration')
