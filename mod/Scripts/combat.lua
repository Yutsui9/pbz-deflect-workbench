local M = {}
local H = require("UEHelpers")
local source = debug.getinfo(1, "S").source:gsub("^@", "")
local dir = source:match("^(.*[/\\])") or ""
local C, enabled, stopped = nil, true, false
local nativeFrames, nativeRate = 8, 30
local snapshots, mappingSnapshots, actors = {}, {}, {}
local context, lastMaintenance, errorShown = nil, -10, false

local function log(s) print("[YanyunGuard] " .. tostring(s) .. "\n") end
local function valid(o) return o and o:IsValid() end
local adjustWindow
local payParryCost, updateParryAnimation
local animationSnapshots={}

local acceptedPresses=0
local tapFX=assert(loadfile(dir.."parry_fx.lua"))()
local fxErrorShown=false
local function keyCode(name)
    local aliases={RightMouseButton="RIGHT_MOUSE_BUTTON",LeftMouseButton="LEFT_MOUSE_BUTTON",MiddleMouseButton="MIDDLE_MOUSE_BUTTON",XButton1="XBUTTON_ONE",XButton2="XBUTTON_TWO",LeftShift="LEFT_SHIFT",LeftControl="LEFT_CONTROL",SpaceBar="SPACE"}
    return Key[aliases[name] or name:upper()]
end
local function bindParry()
    assert(keyCode(C.ParryKey), "Unsupported ParryKey: "..C.ParryKey)
end
local function triggerParry(pc)
    if stopped or not enabled or not valid(pc.Pawn) then return end
    if H.GetGameplayStatics():IsGamePaused(pc) then return end
    for _,s in pairs(actors) do
        local a=s.object
        if valid(a) and valid(a:GetAvatarActorFromActorInfo()) and a:GetAvatarActorFromActorInfo():GetAddress()==pc.Pawn:GetAddress() then
            local now=H.GetKismetSystemLibrary():GetGameTimeInSeconds(a)
            if not payParryCost(a,s) then return end
            updateParryAnimation(a,true)
            a["On Stance Key Down"](a)
            s.ownedStance=true
            a["Give Perfect Window"](a)
            acceptedPresses=acceptedPresses+1
            adjustWindow(a,s,now,true)
            s.pulseUntil=a["Perfect Window"]
            local ok,result,reason=pcall(tapFX.play,pc.Pawn,C,now)
            if not ok or result==false then
                if not fxErrorShown then log("Tap FX skipped: "..tostring(reason or result));fxErrorShown=true end
            elseif result and C.Debug then log("tap feedback started") end
            if C.Debug then log("pulse started, expires="..s.pulseUntil) end
        end
    end
end
local function cfg()
    local c = assert(loadfile(dir .. "config.lua"))()
    if c.Enabled==nil then c.Enabled=true end
    assert(type(c.Enabled)=="boolean","Enabled must be true/false")
    assert(type(c.GuardKey)=="string" and type(c.ParryKey)=="string" and c.GuardKey~=c.ParryKey, "Use two distinct keys")
    assert(c.WindowSeconds>=0.05 and c.WindowSeconds<=0.6, "WindowSeconds must be 0.05..0.6")
    assert(c.SpamRecoverySeconds>=0.1 and c.SpamRecoverySeconds<=2, "Invalid recovery")
    assert(#c.SpamMultipliers==4, "Provide four spam multipliers")
    for _,v in ipairs(c.SpamMultipliers) do assert(v>=0 and v<=1, "Invalid spam multiplier") end
    assert(c.GuardDrainMultiplier>=0 and c.GuardDrainMultiplier<=5, "Invalid guard drain")
    assert(c.GuardDrainStartDelay>=0 and c.GuardDrainStartDelay<=2, "Invalid guard delay")
    assert(c.NormalUltimateMultiplier>=0 and c.NormalUltimateMultiplier<=5, "Invalid normal reward")
    assert(c.PerfectUltimateMultiplier>=0 and c.PerfectUltimateMultiplier<=5, "Invalid perfect reward")
    c.ParryCostPercent=c.ParryCostPercent or 0.04
    if c.StrongParryAnimation==nil then c.StrongParryAnimation=true end
    assert(type(c.ParryCostPercent)=="number" and c.ParryCostPercent>=0 and c.ParryCostPercent<=0.25,"Invalid parry cost percent")
    assert(type(c.StrongParryAnimation)=="boolean","StrongParryAnimation must be true/false")
    if c.ParryTapFX==nil then c.ParryTapFX=true end
    c.ParryTapFXScale=c.ParryTapFXScale or 0.10
    c.ParryTapFXDuration=c.ParryTapFXDuration or 0.10
    assert(type(c.ParryTapFX)=="boolean","ParryTapFX must be true/false")
    assert(type(c.ParryTapFXScale)=="number" and c.ParryTapFXScale>=0.02 and c.ParryTapFXScale<=1,"Invalid tap FX scale")
    assert(type(c.ParryTapFXDuration)=="number" and c.ParryTapFXDuration>=0.04 and c.ParryTapFXDuration<=0.4,"Invalid tap FX duration")
    return c
end
local function attributeName(attr)
    local n=attr.AttributeName
    if type(n)=="string" then return n end
    return n:ToString()
end
local function discoverAttributes(a,s)
    if s.shachi and s.shachiMax then return end
    local asc=a:GetAbilitySystemComponentFromActorInfo()
    local out={}
    asc:GetAllAttributes(out)
    local values=out.OutAttributes or out
    local function visit(attr)
        local n=attributeName(attr)
        if n=="Shachi" then s.shachi=attr end
        if n=="Shachi_Max" then s.shachiMax=attr end
    end
    if type(values)=="table" then for _,attr in ipairs(values) do visit(attr:get()) end
    else values:ForEach(function(_,r) visit(r:get()) end) end
    assert(s.shachi and s.shachiMax,"Cannot resolve native Shachi attributes")
    s.attributeStorage=out
    log("Native Shachi attributes resolved")
end
payParryCost=function(a,s)
    discoverAttributes(a,s)
    local avatar=a:GetAvatarActorFromActorInfo()
    local lib=StaticFindObject("/Script/SGameAttributes.Default__AttributeUtils")
    local current=lib:GetCharacterAttributeValue(avatar,s.shachi)
    local maximum=lib:GetCharacterAttributeValue(avatar,s.shachiMax)
    local cost=maximum*C.ParryCostPercent
    if current+0.0001<cost then log("Parry blocked: insufficient Shachi"); return false end
    if cost>0 then lib:ModifyCharacterAttributeValue(avatar,s.shachi,0,-cost) end
    local after=lib:GetCharacterAttributeValue(avatar,s.shachi)
    if C.Debug then log(string.format("parry cost %.4f: %.4f -> %.4f (max %.4f)",cost,current,after,maximum)) end
    return true
end
updateParryAnimation=function(passive,active)
    local avatar=passive:GetAvatarActorFromActorInfo()
    for _,a in ipairs(FindAllOf("BP_StanceAction_Base_Player_C") or {}) do
        if not a:GetFullName():find("Default__",1,true) then
            local owner=a:GetAvatarActorFromActorInfo()
            if valid(owner) and owner:GetAddress()==avatar:GetAddress() then
                local name=a:GetFullName()
                if not animationSnapshots[name] then
                    animationSnapshots[name]={object=a,original=a.UseStrongDeflectAnim}
                    log("Native strong-deflect animation original="..tostring(a.UseStrongDeflectAnim))
                end
                local original=animationSnapshots[name].original
                a.UseStrongDeflectAnim=(active and C.StrongParryAnimation) or original
            end
        end
    end
end
local scalarFields = {
    "Deflect Perfect Window Frames", "Deflect Perfect Window Frames On Break",
    "Deflect Quickclick Punish Cooldown", "Deflect Ultimate Charge Multiplier Normal",
    "Deflect Ultimate Charge Multiplier Perfect",
}
local function patchAssets()
    for _,o in ipairs(FindAllOf("PDA_GlobalCombatConfig_C") or {}) do
        if not o:GetFullName():find("Default__",1,true) then
            local name=o:GetFullName()
            if not snapshots[name] then
                local s={object=o, values={}, spam={}}
                for _,k in ipairs(scalarFields) do s.values[k]=o[k] end
                o["Deflect Quickclick Punish Multipliers"]:ForEach(function(i,v) s.spam[i]=v:get() end)
                assert(#s.spam==4, "Unexpected native spam array; refusing incompatible build")
                snapshots[name]=s
            end
            local s=snapshots[name]
            s.object=o
            o[scalarFields[1]]=nativeFrames; o[scalarFields[2]]=nativeFrames
            o[scalarFields[3]]=C.SpamRecoverySeconds
            o[scalarFields[4]]=s.values[scalarFields[4]]*C.NormalUltimateMultiplier
            o[scalarFields[5]]=s.values[scalarFields[5]]*C.PerfectUltimateMultiplier
            o["Deflect Quickclick Punish Multipliers"]:ForEach(function(i,v) v:set(C.SpamMultipliers[i]) end)
        end
    end
end
local function patchMappings()
    context=StaticFindObject("/PBZInput/IMC_Deflect.IMC_Deflect")
    if not valid(context) then return end
    local changed=false
    context.DefaultKeyMappings.Mappings:ForEach(function(i,r)
        local m=r:get()
        local action=m.Action:GetFullName()
        local key=m.Key.KeyName:ToString()
        local target=nil
        if not key:find("Gamepad",1,true) then
            if action:find("IA_Deflect.IA_Deflect",1,true) then target="F24" end
            if action:find("IA_Stance.IA_Stance",1,true) then target="F23" end
        end
        if target then
            if not mappingSnapshots[i] then mappingSnapshots[i]={key=key,behavior=m.SettingBehavior} end
            if key~=target or m.SettingBehavior~=2 then
                m.Key.KeyName=FName(target); m.SettingBehavior=2; changed=true
            end
        end
    end)
    if changed then
        StaticFindObject("/Script/EnhancedInput.Default__EnhancedInputLibrary"):RequestRebuildControlMappingsUsingContext(context,true)
        log("Bindings: hold "..C.GuardKey..", tap "..C.ParryKey)
    end
end
local costKey="CostOfTime_6_1918214C431B290CEA5A4A9CAEAA8C4A"
local delayKey="CostOfTimeStartDelay_10_D32DE2BC437394BD04342497EDBEB139"
local function discoverActors()
    for _,a in ipairs(FindAllOf("BP_PlayerDeflectPassive_C") or {}) do
        if not a:GetFullName():find("Default__",1,true) then
            local name=a:GetFullName()
            if not actors[name] then
                local cost=a["Anger Cost Data"]
                actors[name]={object=a, normal=a["Normal Window"], cost=cost[costKey], delay=cost[delayKey]}
                log("Player attached: "..name)
            end
            local s=actors[name]
            discoverAttributes(a,s)
            a["Anger Cost Data"][costKey]=s.cost*C.GuardDrainMultiplier
            a["Anger Cost Data"][delayKey]=C.GuardDrainStartDelay
        end
    end
end
adjustWindow=function(a,s,now,immediate)
    local raw=a["Normal Window"]
    if raw==s.normal then return end
    if raw>now then
        -- The native normal deadline is press time + 8/30, even after spam.
        -- Preserve the press timestamp; do not start a new window on the next render frame.
        local pressTime=immediate and now or (raw-nativeFrames/nativeRate)
        local counter=math.max(0,a["Current Perfect Window Counter"])
        local mult=C.SpamMultipliers[math.min(counter+1,4)]
        local deadline=pressTime+C.WindowSeconds*mult
        a["Perfect Window"]=deadline
        a["Normal Window"]=deadline
        if C.Debug then log(string.format("parry counter=%d duration=%.6f start=%.6f end=%.6f",counter,C.WindowSeconds*mult,pressTime,deadline)) end
    end
    s.normal=a["Normal Window"]
end
local function restore()
    for _,s in pairs(animationSnapshots) do if valid(s.object) then s.object.UseStrongDeflectAnim=s.original end end
    for _,s in pairs(snapshots) do
        if valid(s.object) then
            for k,v in pairs(s.values) do s.object[k]=v; assert(math.abs(s.object[k]-v)<0.00001,"Restore failed: "..k) end
            s.object["Deflect Quickclick Punish Multipliers"]:ForEach(function(i,v) v:set(s.spam[i]) end)
        end
    end
    if valid(context) then
        context.DefaultKeyMappings.Mappings:ForEach(function(i,r)
            local s=mappingSnapshots[i]
            if s then local m=r:get(); m.Key.KeyName=FName(s.key); m.SettingBehavior=s.behavior; assert(m.Key.KeyName:ToString()==s.key,"Mapping restore failed") end
        end)
        StaticFindObject("/Script/EnhancedInput.Default__EnhancedInputLibrary"):RequestRebuildControlMappingsUsingContext(context,true)
    end
    for _,s in pairs(actors) do
        if valid(s.object) then
            s.object["Anger Cost Data"][costKey]=s.cost
            s.object["Anger Cost Data"][delayKey]=s.delay
            s.object["On Stance Key Release"](s.object)
            s.object["Perfect Window"]=0; s.object["Normal Window"]=0; s.normal=0
            s.ownedStance=false; s.pulseUntil=nil
        end
    end
end
function M.status()
    local pc=H.GetPlayerController()
    if valid(pc) and valid(pc.PlayerInput) then
        pc.PlayerInput.EnhancedActionMappings:ForEach(function(_,r)
            local m=r:get(); local n=m.Action:GetFullName()
            if n:find("IA_Stance.IA_Stance",1,true) or n:find("IA_Deflect.IA_Deflect",1,true) then log("native map "..n.." -> "..m.Key.KeyName:ToString()) end
        end)
    end
    log("enabled="..tostring(enabled).." window="..C.WindowSeconds.."s, native rate="..nativeRate..", accepted presses="..acceptedPresses)
    for _,s in pairs(actors) do
        if valid(s.object) then
            local a=s.object; local now=H.GetKismetSystemLibrary():GetGameTimeInSeconds(a)
            if s.shachi and s.shachiMax then
                local lib=StaticFindObject("/Script/SGameAttributes.Default__AttributeUtils")
                log("Shachi="..lib:GetCharacterAttributeValue(a:GetAvatarActorFromActorInfo(),s.shachi).."/"..lib:GetCharacterAttributeValue(a:GetAvatarActorFromActorInfo(),s.shachiMax))
            end
            log("guard="..tostring(a["Stance Key Down"]).." perfect remaining="..(a["Perfect Window"]-now).." drain="..a["Anger Cost Data"][costKey])
        end
    end
end
function M.disable() enabled=false; tapFX.clear(); restore(); log("Vanilla restored; panel enables, F5 reloads saved mode") end
function M.reload()
    local nextFX=assert(loadfile(dir.."parry_fx.lua"))()
    local new=cfg(); assert(keyCode(new.ParryKey), "Unsupported ParryKey: "..new.ParryKey); C=new; enabled=true; lastMaintenance=-10; errorShown=false; fxErrorShown=false
    if not C.ParryTapFX then tapFX.clear() end
    tapFX.clear(); tapFX=nextFX
    if not C.Enabled then M.disable();log("Config loaded: vanilla mode");return end
    bindParry()
    log("Config loaded: "..C.WindowSeconds.." seconds")
end
function M.stop() M.disable(); stopped=true end
function M.start()
    ExecuteInGameThread(function()
    M.reload()
    assert(loadfile(dir.."panel_bridge.lua"))().start({apply=M.reload,restore=M.disable,enabled=function() return enabled end,stopped=function() return stopped end})
    LoopInGameThreadWithDelay(0,function()
        if stopped then return true end

        local ok,err=pcall(function()
            local pc=H.GetPlayerController()
            if not valid(pc) then return end
            if pc:WasInputKeyJustPressed({KeyName=FName("F5")}) then M.reload() end
            if pc:WasInputKeyJustPressed({KeyName=FName("F6")}) then M.status() end
            if pc:WasInputKeyJustPressed({KeyName=FName("F7")}) then M.disable() end
            if not enabled then return end
            if pc:WasInputKeyJustPressed({KeyName=FName(C.ParryKey)}) then triggerParry(pc) end
            local now=H.GetKismetSystemLibrary():GetGameTimeInSeconds(pc)
            tapFX.tick(now)
            if now<lastMaintenance or now-lastMaintenance>=1 then
                patchAssets(); patchMappings(); discoverActors(); lastMaintenance=now
            end
            for name,s in pairs(actors) do
                if valid(s.object) then
                    local a=s.object
                    local ownAvatar=a:GetAvatarActorFromActorInfo()
                    if valid(ownAvatar) and valid(pc.Pawn) and ownAvatar:GetAddress()==pc.Pawn:GetAddress() then
                        local guardDown=pc:IsInputKeyDown({KeyName=FName(C.GuardKey)})
                        local activePulse=s.pulseUntil and now<s.pulseUntil
                        local wantsGuard=guardDown or activePulse
                        if wantsGuard then
                            if not s.ownedStance or not a["Stance Key Down"] then a["On Stance Key Down"](a) end
                            s.ownedStance=true
                        elseif s.ownedStance then
                            a["On Stance Key Release"](a)
                            s.ownedStance=false; s.pulseUntil=nil
                            if C.Debug then log("stance released automatically") end
                        end
                    end
                    adjustWindow(s.object,s,now,false)
                    updateParryAnimation(s.object,s.pulseUntil~=nil and now<s.pulseUntil)
                    local held=s.object["Stance Key Down"]
                    if C.Debug and held~=s.lastHeld then
                        log("guard held="..tostring(held).." presses="..acceptedPresses.." perfect="..s.object["Perfect Window"])
                    end
                    s.lastHeld=held
                else actors[name]=nil end
            end
        end)
        if not ok and not errorShown then
            errorShown=true; enabled=false; pcall(restore)
            log("ERROR; mod disabled: "..tostring(err))
        end
        return false
    end)
    log("0.2.2 ready; game-thread input polling; panel bridge online")
    end)
end
return M
