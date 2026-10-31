-- Brief local lighting isolated to the blade, plus a quiet native tap sound.
local M={}
local modulePath=debug.getinfo(1,"S").source:gsub("^@","")
local moduleDir=assert(modulePath:match("^(.*[/\\])"))
local rewards=assert(loadfile(moduleDir.."success_rewards.lua"))()
local tapMotion=assert(loadfile(moduleDir.."tap_motion.lua"))()
local moduleConfig=assert(loadfile(moduleDir.."config.lua"))()
local warningFX=assert(loadfile(moduleDir.."warning_colors.lua"))()
local live={}
local raiseJobs={}
local function valid(o) return o and o:IsValid() end
local function accelerateRaise(job)
    for _,ability in ipairs(FindAllOf("BP_StanceAction_Base_Player_C") or {}) do
        if not ability:GetFullName():find("Default__",1,true) then
            local owner=ability:GetAvatarActorFromActorInfo()
            if valid(owner) and owner:GetAddress()==job.avatar:GetAddress() then
                local task=ability:GetPlayTimelineTask()
                if valid(task) and valid(task.Timeline) then
                    local timeline=task.Timeline
                    local enter,exit=ability.StanceEnter,ability.StanceExit
                    local speed,label
                    if valid(enter) and timeline:GetAddress()==enter:GetAddress() then speed=job.speed;label="raise"
                    elseif valid(exit) and timeline:GetAddress()==exit:GetAddress() then speed=job.lower;label="lower" end
                    local key=tostring(task:GetAddress())..":"..timeline:GetAddress()
                    if speed and not job.tasks[key] then
                        task:SetSectionPlayRate(speed,0,timeline.SequenceLength,true)
                        job.tasks[key]={task=task,ability=ability,timeline=timeline,length=timeline.SequenceLength}
                        if job.debug then print("[YanyunGuard] Stance "..label.." speed="..speed.." native duration="..timeline.SequenceLength.." at="..task.CurrentTime.."\n") end
                    end
                end
            end
        end
    end
end
local function weaponMesh(avatar)
    local wc=avatar["Character Weapons Component"]
    if not valid(wc) then return end
    local mesh
    wc.RuntimeWeaponData:ForEach(function(k,v)
        local tag=k:get()
        if tag.TagName:ToString()~="Weapon.Slot.Main" then return end
        local current=wc:GetCurrentWeaponIndex(tag,false)
        v:get().Weapons:ForEach(function(i,r)
            if i~=current+1 then return end
            r:get().WeaponActors:ForEach(function(_,w)
                if mesh then return end
                local actor=w:get()
                if not valid(actor) then return end
                local candidate=actor:GetComponentByClass(StaticFindObject("/Script/Engine.MeshComponent"))
                if valid(candidate) then mesh=candidate end
            end)
        end)
    end)
    return mesh
end
local function restore(s)
    if valid(s.audio) then s.audio:Stop() end -- Wwise owns this auto-destroy component
    if valid(s.light) then s.light:SetIntensity(0);s.light:K2_DestroyComponent(s.light:GetOwner()) end
    if valid(s.mesh) then s.mesh:SetLightingChannels(s.ch0,s.ch1,s.ch2) end
end
local function playSound(avatar,s,c)
    if c.ParryTapSound==false then return end
    local event=StaticFindObject("/Game/Wwise/Events/SFX/Combat/Special/Hero_Special/Hun/Common/Puppet_Block_Sword/SFX_Combat_Deflect_BluntVessel_BladeDefault_VeryLight_Perfect.SFX_Combat_Deflect_BluntVessel_BladeDefault_VeryLight_Perfect")
    assert(valid(event),"quiet metal event is not loaded")
    if valid(s.audio) then s.audio:Stop() end
    local pos=s.mesh:GetSocketLocation(FName("DeflectMiddle"))
    s.audio=StaticFindObject("/Script/AkAudio.Default__AkGameplayStatics"):SpawnAkComponentAtLocation(
        avatar,event,{X=pos.X,Y=pos.Y,Z=pos.Z},{Pitch=0,Yaw=0,Roll=0},true,true)
    assert(valid(s.audio),"cannot spawn tap audio")
    local volume=c.ParryTapSoundVolume or 0.18
    assert(volume>=0 and volume<=1,"ParryTapSoundVolume must be 0..1")
    s.audio:SetOutputBusVolume(volume)
    s.audio:SetEarlyReflectionsVolume(0)
    if c.Debug then print("[YanyunGuard] Tap sound spawned volume="..volume.."\n") end
end
local function move(s)
    local socket=FName("DeflectMiddle")
    if not s.mesh:DoesSocketExist(socket) then socket=FName("MeshMiddle") end
    if not s.mesh:DoesSocketExist(socket) then return end
    local p=s.mesh:GetSocketLocation(socket)
    local pc=require("UEHelpers").GetPlayerController()
    local view=pc.PlayerCameraManager:GetCameraLocation()
    local x,y,z=view.X-p.X,view.Y-p.Y,view.Z-p.Z
    local length=math.max(math.sqrt(x*x+y*y+z*z),1)
    s.light:K2_SetWorldLocation({X=p.X+x/length*18,Y=p.Y+y/length*18,Z=p.Z+z/length*18},false,{},true)
end
function M.play(avatar,c,now)
    local speed=c.ParryRaiseSpeed or 1.75
    assert(speed>=1 and speed<=2.5,"ParryRaiseSpeed must be 1..2.5")
    moduleConfig=c
    rewards.arm(avatar,c,now)
    local motionOK,motionError=pcall(tapMotion.request,avatar,c,now)
    if not motionOK then print("[YanyunGuard] Tap shake skipped: "..tostring(motionError).."\n") end
    local job=raiseJobs[avatar:GetAddress()] or {avatar=avatar,tasks={}}
    job.speed=speed;job.lower=c.ParryLowerSpeed or 1.60;job.expires=now+1.5;job.debug=c.Debug
    assert(job.lower>=1 and job.lower<=2.5,"ParryLowerSpeed must be 1..2.5")
    raiseJobs[avatar:GetAddress()]=job
    local raiseOK,raiseError=pcall(accelerateRaise,job)
    if not raiseOK then print("[YanyunGuard] Raise speed skipped: "..tostring(raiseError).."\n") end
    if not c.ParryTapFX then return end
    local mesh=weaponMesh(avatar)
    if not mesh then return false,"no equipped blade mesh" end
    local key=mesh:GetAddress()
    local s=live[key]
    if not s then
        local transform={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
        local light=avatar:AddComponentByClass(StaticFindObject("/Script/Engine.PointLightComponent"),true,transform,false)
        if not valid(light) then return false,"cannot create blade glint light" end
        local channels=mesh.LightingChannels
        s={mesh=mesh,light=light,ch0=channels.bChannel0,ch1=channels.bChannel1,ch2=channels.bChannel2}
        live[key]=s
        light:SetMobility(2)
        light:SetCastShadows(false)
        light:SetIndirectLightingIntensity(0)
        light:SetAffectGlobalIllumination(false)
        light:SetUseInverseSquaredFalloff(false)
        light:SetIntensityUnits(0)
        light:SetAttenuationRadius(45)
        light:SetLightFalloffExponent(2)
        light:SetSourceRadius(6)
        light:SetSourceLength(20)
        light:SetSpecularScale(1)
        light:SetLightColor({R=0.86,G=0.93,B=1,A=1},false)
        light:SetLightingChannels(false,true,false)
        mesh:SetLightingChannels(s.ch0,true,s.ch2)
    end
    local duration=c.BladeFlashDuration or 0.09
    local interval=math.max(c.BladeFlashMinInterval or 0.18,duration+0.06)
    assert(duration>=0.04 and duration<=0.4,"BladeFlashDuration must be 0.04..0.4")
    s.expires=now+math.max(0.55,interval)
    if not s.nextFlash or now>=s.nextFlash then
        s.start=now;s.flashEnd=now+duration;s.nextFlash=now+interval;s.peak=(c.BladeFlashStrength or 0.16)*2500
        move(s)
        s.light:SetIntensity(s.peak)
        if c.Debug then print("[YanyunGuard] Blade flash start="..now.." end="..s.flashEnd.." next="..s.nextFlash.."\n") end
    end
    local soundOK,soundError=pcall(playSound,avatar,s,c)
    if not soundOK then print("[YanyunGuard] Tap sound skipped: "..tostring(soundError).."\n") end
    if c.Debug then print("[YanyunGuard] Blade glint light "..mesh:GetFullName().." intensity="..s.peak.."\n") end
    return true
end
function M.tick(now)
    warningFX.tick(moduleConfig,now)
    local motionOK,motionError=pcall(tapMotion.tick,now)
    if not motionOK then tapMotion.clear();print("[YanyunGuard] Tap shake skipped: "..tostring(motionError).."\n") end
    local rewardOK,rewardError=pcall(rewards.tick,now,moduleConfig)
    if not rewardOK then print("[YanyunGuard] Success rewards skipped: "..tostring(rewardError).."\n") end
    for key,job in pairs(raiseJobs) do
        if not valid(job.avatar) or now>=job.expires then raiseJobs[key]=nil
        else
            local ok,err=pcall(accelerateRaise,job)
            if not ok then raiseJobs[key]=nil;print("[YanyunGuard] Raise speed skipped: "..tostring(err).."\n") end
        end
    end
    for key,s in pairs(live) do
        if not valid(s.mesh) or not valid(s.light) or now>=s.expires then
            pcall(restore,s);live[key]=nil
        else
            local ok,err=pcall(function()
                move(s)
                local t=math.min(1,math.max(0,(now-s.start)/(s.flashEnd-s.start)))
                s.light:SetIntensity(s.peak*(1-t)*(1-t))
            end)
            if not ok then
                pcall(restore,s);live[key]=nil
                print("[YanyunGuard] Blade glint stopped: "..tostring(err).."\n")
            end
        end
    end
end
function M.clear()
    warningFX.clear()
    tapMotion.clear()
    rewards.clear()
    for _,job in pairs(raiseJobs) do
        for _,t in pairs(job.tasks) do
            if valid(t.task) and valid(t.ability) then pcall(function()
                local current=t.ability:GetPlayTimelineTask()
                if valid(current) and current:GetAddress()==t.task:GetAddress() and valid(current.Timeline) and current.Timeline:GetAddress()==t.timeline:GetAddress() and current.CurrentTime<t.length-0.001 then
                    current:SetSectionPlayRate(1,0,t.length,true)
                end
            end) end
        end
    end
    raiseJobs={}
    for _,s in pairs(live) do pcall(restore,s) end
    live={}
end
return M
