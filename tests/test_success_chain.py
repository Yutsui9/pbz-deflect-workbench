from pathlib import Path
import sys
from lupa import LuaRuntime
root = Path(__file__).resolve().parents[1]
scripts = root / 'mod/Scripts'
lua = LuaRuntime(unpack_returned_tuples=True)
for file in scripts.glob('*.lua'):
    lua.execute('assert(loadfile(...))', str(file))
lua.globals().scripts = str(scripts).replace('\\', '/') + '/'
lua.execute(r'''
local chain=assert(loadfile(scripts..'success_chain.lua'))()
local c={SuccessChainEnabled=true,SuccessChainTimeout=6,SuccessChainMaxStacks=3,SuccessChainRefundStep=.02,SuccessChainPoiseStep=.02}
local s=chain.new()
for i=1,8 do
    local n,r,p=chain.success(s,i,i,c)
    assert(n==math.min(i-1,3) and math.abs(r-n*.02)<1e-8 and r==p)
end
chain.success(s,8,8,c);assert(s.count==8) -- one step per press
chain.miss(s,7);assert(s.count==8) -- old delayed miss cannot break newer success
chain.miss(s,9);assert(s.count==0)
assert(chain.success(s,10,10,c)==0)
chain.expire(s,17,c);assert(s.count==0)
chain.success(s,11,20,c);chain.expire(s,1,c);assert(s.count==0)
c.SuccessChainEnabled=false;assert(chain.success(s,12,2,c)==0)

local function obj(id)
    return {IsValid=function() return true end,GetAddress=function() return id end,GetFullName=function() return 'LiveActor'..id end}
end
local player,enemy=obj(1),obj(2)
player.Shachi=0;player.Shachi_Max=100;player.Health=100
enemy.Shachi=1000;enemy.Shachi_Max=1000;enemy.Health=100
local pc=obj(3);pc.Pawn=player
local passive=obj(4)
passive.GetAvatarActorFromActorInfo=function() return player end
local resets=0;passive['Reset Perfect Window Punishment']=function() resets=resets+1 end
local lib={GetCharacterAttributeValue=function(_,actor,attr) return actor[attr.name] end,
    ModifyCharacterAttributeValue=function(_,actor,attr,op,amount) assert(op==0);actor[attr.name]=actor[attr.name]+amount end}
local asc={IsValid=function() return true end,GetAllAttributes=function(_,out)
    for _,n in ipairs({'Shachi','Shachi_Max','Health'}) do
        local name=n;out[#out+1]={get=function() return {name=name,AttributeName={ToString=function() return name end}} end}
    end
end}
function StaticFindObject(path)
    if path:find('BPL_DeflectUtils',1,true) then return obj(5) end
    if path:find('AbilitySystemBlueprintLibrary',1,true) then return {GetAbilitySystemComponent=function() return asc end} end
    return lib
end
function FindAllOf() return {passive} end
local hook
function RegisterHook(_,fn) hook=fn;return 1,2 end
package.preload.UEHelpers=function() return {GetPlayerController=function() return pc end} end
local R=assert(loadfile(scripts..'success_rewards.lua'))()
c.SuccessChainEnabled=true;c.Debug=false;c.WindowSeconds=.25;c.PerfectParryRefundPercent=.1;c.PerfectParryPoisePercent=.15
local function arm(t) passive['Perfect Window']=t+.25;R.arm(player,c,t);R.tick(t,c) end
local function hit(t,tag,handle)
    local e={DefenderAvatar=player,SourceAvatar=enemy,DeflectResult={TagName={ToString=function() return tag or 'Deflect.Result.Perfect' end}},HitGameTime=t,IsHit=false}
    hook(nil,nil,{get=function() return handle or t end},{get=function() return e end})
end
arm(1);hit(1.1);R.tick(1.1,c);assert(player.Shachi==10 and enemy.Shachi==850 and resets==1)
assert(passive['Perfect Window']==1.25) -- successful hit preserves the remaining window
arm(2);hit(2.1);R.tick(2.1,c);assert(player.Shachi==22 and enemy.Shachi==680 and resets==2)
hit(2.1);R.tick(2.11,c);assert(player.Shachi==22 and resets==2)
hit(2.15,nil,99);R.tick(2.15,c);assert(player.Shachi==34 and resets==3) -- distinct hit, same chain step
arm(3);hit(3.1,'Deflect.Result.Normal');R.tick(3.1,c);assert(player.Shachi==34 and resets==3)
arm(4);hit(4.1);R.tick(4.1,c);assert(player.Shachi==44)
arm(5);R.tick(5.5,c);arm(6);hit(6.1);R.tick(6.1,c);assert(player.Shachi==54)
arm(13);hit(13.1);R.tick(13.1,c);assert(player.Shachi==64)
player.Shachi=99;enemy.Shachi=1;arm(14);hit(14.1);R.tick(14.1,c);assert(player.Shachi==100 and enemy.Shachi==0)
player.Health=0;R.tick(14.2,c);player.Health=100;player.Shachi=0
arm(15);hit(15.1);R.tick(15.1,c);assert(player.Shachi==10)
R.clear();player.Shachi=0;hit(15.1,nil,123);R.tick(15.2,c);assert(player.Shachi==0)
print('PASS: restored remaining window, multiple distinct hits, per-press chain counting, duplicate events, timeout, misses, death, clear, attribute caps.')
''')
