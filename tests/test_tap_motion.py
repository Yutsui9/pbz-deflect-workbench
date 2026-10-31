from pathlib import Path
import sys
from lupa import LuaRuntime
scripts=Path(__file__).resolve().parents[1]/'mod/Scripts'
lua=LuaRuntime(unpack_returned_tuples=True)
lua.globals().scripts=str(scripts).replace(chr(92),'/')+'/'
for file in scripts.glob('*.lua'):
    lua.execute('assert(loadfile(...))',str(file))
lua.execute(r'''
local function obj(id,name) return {IsValid=function() return true end,GetAddress=function() return id end,GetFullName=function() return name or 'Object.Other'..id end} end
local function array(items) return {ForEach=function(_,fn) for i,x in ipairs(items) do fn(i,{get=function() return x end}) end end} end
function FName(x) return x end
local player,other=obj(1),obj(2)
local a=obj(3,'LiveAbility');a.bIsActive=true
local function timeline(id,name) return obj(id,'LGATimeline /Game/Map.Actor.Ability.'..name) end
local loop,entry,exit=timeline(4,'StanceLoop'),timeline(5,'StanceEnter'),timeline(6,'StanceExit')
local task=obj(7);task.Timeline=loop
local asset=obj(8,'AnimSequence NativeEntry');local montage=obj(9,'AnimMontage NativeEntry')
local slot={ToString=function() return 'UpperBody' end}
montage.SlotAnimTracks=array({{SlotName=slot,AnimTrack={AnimSegments=array({{AnimReference=asset,AnimStartTime=0,AnimEndTime=1}})}}})
local action=obj(10,'LGAAction_PlayMontage Original');action.MontageToPlay=montage
entry.Actions=array({{Action=action}});entry.RoleLayers=array({})
a.StanceEnter=entry;a.GetPlayTimelineTask=function() return task end
a.GetAvatarActorFromActorInfo=function() return player end
local count,stops=0,0
local anim=obj(11)
anim.PlaySlotAnimationAsDynamicMontage=function(_,clip,s,bi,bo,rate,loops,trigger,start)
    assert(clip==asset and s=='UpperBody' and rate==1.75 and loops==1 and start==.35)
    count=count+1;return obj(100+count,'AnimMontage Tap'..count)
end
anim.Montage_Stop=function(_,blend,m) assert(m:GetAddress()>100 and blend==.05);stops=stops+1 end
anim.Montage_IsPlaying=function() return true end
player.Mesh=obj(12);player.Mesh.GetAnimInstance=function() return anim end
function FindAllOf() return {a} end
local M=assert(loadfile(scripts..'tap_motion.lua'))()
local c={Debug=false,ParryTapShake=true}
M.request(player,c,1);assert(count==1)
M.request(player,c,1.1);assert(count==2 and stops==1)
M.tick(1.3);assert(stops==2)
for _,flag in ipairs({'In Deflect','In Deflect Start','In Impact'}) do
    a[flag]=true;M.request(player,c,2);assert(count==2);a[flag]=false
end
M.request(player,c,3);assert(count==3);a['In Impact']=true;M.tick(3.01);assert(stops==3);a['In Impact']=false
 task.Timeline=entry;M.request(player,c,4);assert(count==3);task.Timeline=loop;M.tick(4.1);assert(count==4)
M.clear();assert(stops==4)
task.Timeline=entry;M.request(player,c,5);task.Timeline=loop;M.tick(5.2);assert(count==4)
task.Timeline=exit;M.request(player,c,6);task.Timeline=loop;M.tick(6.1);assert(count==4)
a.bIsActive=false;M.request(player,c,7);M.clear();assert(count==4);a.bIsActive=true
c.ParryTapShake=false;M.request(player,c,8);assert(count==4);c.ParryTapShake=true
M.request(other,c,9);assert(count==4);M.clear()
M.request(player,c,10);assert(count==5);M.clear();assert(stops==5)
print('PASS: syntax; native UpperBody entry clip; isolated dynamic montage; per-press restart; timed fade; impact cancellation; protected combat/exit; initial raise wait; expiration; inactive/foreign ability; disable and clear.')
''')
