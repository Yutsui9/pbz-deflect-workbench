-- A short visual-only slice of this weapon's real entry animation.
-- Its StanceShake timeline contains only JumpTimeline, so cannot animate a tap.
local M={}
local cacheDir=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
local cache=assert(loadfile(cacheDir.."object_cache.lua"))()
local pending,playing,sources={},{},{}
local reported=false
local function valid(o) return o and o:IsValid() end
local function same(a,b) return valid(a) and valid(b) and a:GetAddress()==b:GetAddress() end
local function role(t,name) return valid(t) and t:GetFullName():match("[^%.%s:]+$")==name end
local function idle(a)
    if not valid(a) or not a.bIsActive or a["In Deflect"] or a["In Deflect Start"] or a["In Impact"] then return false end
    local t=a:GetPlayTimelineTask()
    return valid(t) and (role(t.Timeline,"StanceLoop") or role(t.Timeline,"StanceShake"))
end
local function stop(s)
    if valid(s.anim) and valid(s.montage) then s.anim:Montage_Stop(.05,s.montage) end
end
local function source(a)
    local key=a:GetAddress()
    if sources[key] and valid(sources[key].ability) and valid(sources[key].asset) then return sources[key] end
    local found
    local function actions(list)
        list:ForEach(function(_,r)
            local action=r:get().Action
            if found or not valid(action) or not action:GetFullName():find("LGAAction_PlayMontage",1,true) then return end
            local montage=action.MontageToPlay
            if not valid(montage) then return end
            montage.SlotAnimTracks:ForEach(function(_,v)
                local track=v:get()
                if track.SlotName:ToString()~="UpperBody" then return end
                track.AnimTrack.AnimSegments:ForEach(function(_,s)
                    local seg=s:get()
                    if not found and valid(seg.AnimReference) and seg.AnimEndTime>seg.AnimStartTime then
                        found={ability=a,asset=seg.AnimReference,slot=FName(track.SlotName:ToString()),start=seg.AnimStartTime+(seg.AnimEndTime-seg.AnimStartTime)*.35}
                    end
                end)
            end)
        end)
    end
    if valid(a.StanceEnter) then
        actions(a.StanceEnter.Actions)
        a.StanceEnter.RoleLayers:ForEach(function(_,r) actions(r:get().Actions) end)
    end
    sources[key]=found;return found
end
local function play(key,job,a,now)
    local clip=source(a)
    if not clip or not valid(job.avatar.Mesh) then return end
    local anim=job.avatar.Mesh:GetAnimInstance()
    if not valid(anim) then return end
    if playing[key] then stop(playing[key]);playing[key]=nil end
    local montage=anim:PlaySlotAnimationAsDynamicMontage(clip.asset,clip.slot,.025,.05,1.75,1,-1,clip.start)
    assert(valid(montage),"upper-body tap montage was not created")
    playing[key]={anim=anim,montage=montage,ability=a,start=now,expires=now+.16}
    if job.debug or not reported then
        print("[YanyunGuard] Tap upper-body montage="..montage:GetFullName().." playing="..tostring(anim:Montage_IsPlaying(montage)).." source="..clip.asset:GetFullName().."\n")
        reported=true
    end
end
function M.request(avatar,c,now)
    if c.ParryTapShake==false then return end
    pending[avatar:GetAddress()]={avatar=avatar,start=now,expires=now+.18,debug=c.Debug}
    M.tick(now)
end
function M.tick(now)
    cache.tick(now)
    for key,s in pairs(playing) do
        if now>=s.expires or now<s.start or not idle(s.ability) then stop(s);playing[key]=nil end
    end
    for key,s in pairs(sources) do if not valid(s.ability) or not valid(s.asset) then sources[key]=nil end end
    if next(pending)==nil then return end
    for key,job in pairs(pending) do
        if not valid(job.avatar) or now>job.expires or now<job.start then pending[key]=nil
        else
            for _,a in ipairs(cache.get("BP_StanceAction_Base_Player_C")) do
                if not a:GetFullName():find("Default__",1,true) and a.bIsActive and same(a:GetAvatarActorFromActorInfo(),job.avatar) then
                    if idle(a) then pending[key]=nil;play(key,job,a,now);break end
                    local t=a:GetPlayTimelineTask()
                    if a["In Deflect"] or a["In Deflect Start"] or a["In Impact"] or (valid(t) and not role(t.Timeline,"StanceEnter")) then pending[key]=nil;break end
                end
            end
        end
    end
end
function M.clear()
    for _,s in pairs(playing) do pcall(stop,s) end
    pending={};playing={};sources={}
end
return M
