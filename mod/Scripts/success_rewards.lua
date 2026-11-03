-- Rewards consume completed native impacts, not input presses or predicted receive frames.
local R={}
local H=require("UEHelpers")
local dir=debug.getinfo(1,"S").source:gsub("^@",""):match("^(.*[/\\])")
local chain=assert(loadfile(dir.."success_chain.lua"))()
local path="/PBZDeflectSystem/BPL_DeflectUtils.BPL_DeflectUtils_C:Play Impact"
_G.PBZGuardImpactRouter=_G.PBZGuardImpactRouter or {hooked=false}
local router=_G.PBZGuardImpactRouter
local state={taps={},seen={},queue={},attrs={},lastMaintenance=-10}
state.chain=chain.new()
local function valid(o) return o and o:IsValid() end
local function log(s) print("[YanyunGuard] "..s.."\n") end
local function perfect(tag)
    local root="Deflect.Result.Perfect"
    return tag==root or tag:sub(1,#root+1)==root.."."
end
state.accept=function(tag) return tag:sub(1,15)=="Deflect.Result." end
local function install()
    if router.hooked or not valid(StaticFindObject(path)) then return end
    local preId,postId=RegisterHook(path,function(_,ability,handle,result)
        local owner=router.owner
        if not owner then return end
        local ok,err=pcall(function()
            local data=result:get()
            local defender,attacker=data.DefenderAvatar,data.SourceAvatar
            if not valid(defender) or not valid(attacker) then return end
            local pc=H.GetPlayerController()
            if not valid(pc) or not valid(pc.Pawn) or defender:GetAddress()~=pc.Pawn:GetAddress() then return end
            local tag=data.DeflectResult.TagName:ToString()
            if owner.config.Debug then log("Native impact result="..tag.." hit="..tostring(data.IsHit).." time="..data.HitGameTime) end
            if not owner.accept(tag) then return end
            if #owner.queue<128 then
                owner.queue[#owner.queue+1]={defender=defender,attacker=attacker,handle=handle:get(),time=data.HitGameTime,tag=tag}
            end
        end)
        if not ok then log("Impact observation skipped: "..tostring(err)) end
    end)
    router.preId=preId;router.postId=postId
    router.hooked=true
    log("Completed-impact listener ready")
end
local function attributes(actor)
    local key=actor:GetAddress()
    local cached=state.attrs[key]
    if cached and valid(cached.actor) then return cached end
    local asc=StaticFindObject("/Script/GameplayAbilities.Default__AbilitySystemBlueprintLibrary"):GetAbilitySystemComponent(actor)
    assert(valid(asc),"actor has no ability system")
    local out={};asc:GetAllAttributes(out)
    local a={actor=actor,storage=out}
    for _,entry in ipairs(out.OutAttributes or out) do
        local attr=entry:get();local name=attr.AttributeName:ToString()
        if name=="Shachi" then a.current=attr elseif name=="Shachi_Max" then a.maximum=attr elseif name=="Health" then a.health=attr end
    end
    assert(a.current and a.maximum,"native Shachi attributes unavailable")
    state.attrs[key]=a;return a
end
function R.arm(avatar,c,now)
    state.config=c;router.owner=state
    if state.avatar and state.avatar~=avatar:GetAddress() then chain.reset(state.chain);state.taps={} end
    state.avatar=avatar:GetAddress()
    local deadline=now+c.WindowSeconds
    for _,a in ipairs(FindAllOf("BP_PlayerDeflectPassive_C") or {}) do
        if not a:GetFullName():find("Default__",1,true) then
            local owner=a:GetAvatarActorFromActorInfo()
            if valid(owner) and owner:GetAddress()==avatar:GetAddress() then deadline=math.min(deadline,a["Perfect Window"]) end
        end
    end
    state.chain.press=state.chain.press+1
    state.taps[#state.taps+1]={avatar=avatar,start=now,deadline=deadline,id=state.chain.press}
    while #state.taps>16 do table.remove(state.taps,1) end
end
local function reward(e,now,c)
    if not valid(e.defender) or not valid(e.attacker) then return end
    local tapMatched=false
    for i=#state.taps,1,-1 do
        local tap=state.taps[i]
        if valid(tap.avatar) and tap.avatar:GetAddress()==e.defender:GetAddress() and e.time>=tap.start-0.05 and e.time<=tap.deadline+0.075 then tapMatched=tap;break end
    end
    if not tapMatched then if c.Debug then log("Impact reward skipped: no matching tap window") end;return end
    local key=e.defender:GetAddress()..":"..e.attacker:GetAddress()..":"..e.handle..":"..string.format("%.6f",e.time)
    if state.seen[key] then return end
    state.seen[key]=now
    if not perfect(e.tag) then
        if not tapMatched.success then tapMatched.failed=true;chain.miss(state.chain,tapMatched.id) end
        return
    end
    -- Expire earlier empty presses before awarding a later success.
    for _,tap in ipairs(state.taps) do
        if tap.id<tapMatched.id and not tap.success and tap.deadline+.15<e.time then chain.miss(state.chain,tap.id);tap.failed=true end
    end
    if tapMatched.failed then return end
    tapMatched.success=true
    local stacks,bonusRefund,bonusPoise=chain.success(state.chain,tapMatched.id,e.time,c)
    if c.SuccessChainEnabled~=false then
        for _,passive in ipairs(FindAllOf("BP_PlayerDeflectPassive_C") or {}) do
            if not passive:GetFullName():find("Default__",1,true) then
                local avatar=passive:GetAvatarActorFromActorInfo()
                if valid(avatar) and avatar:GetAddress()==e.defender:GetAddress() then
                    local ok,err=pcall(function() passive["Reset Perfect Window Punishment"](passive) end)
                    if not ok then log("Success punishment reset skipped: "..tostring(err)) end
                end
            end
        end
    end
    if c.Debug then log(string.format("Success chain count=%d stacks=%d bonus refund=%.3f poise=%.3f",state.chain.count,stacks,bonusRefund,bonusPoise)) end
    local amount=c.PerfectParryRefundPercent or 0.20
    assert(amount>=0 and amount<=0.25,"PerfectParryRefundPercent must be 0..0.25")
    amount=math.min(.50,amount+bonusRefund)
    local a=attributes(e.defender)
    local lib=StaticFindObject("/Script/SGameAttributes.Default__AttributeUtils")
    local before=lib:GetCharacterAttributeValue(e.defender,a.current)
    local maximum=lib:GetCharacterAttributeValue(e.defender,a.maximum)
    local gain=math.max(0,math.min(maximum-before,maximum*amount))
    if gain>0 then lib:ModifyCharacterAttributeValue(e.defender,a.current,0,gain) end
    local after=lib:GetCharacterAttributeValue(e.defender,a.current)
    if c.Debug then log(string.format("Perfect success refund %.4f: %.4f -> %.4f (max %.4f, hit %.6f)",gain,before,after,maximum,e.time)) end
    if e.attacker:GetAddress()~=e.defender:GetAddress() then
        local ok,err=pcall(function()
            local fraction=c.PerfectParryPoisePercent or 0.08
            assert(fraction>=0 and fraction<=0.25,"PerfectParryPoisePercent must be 0..0.25")
            fraction=math.min(.50,fraction+bonusPoise)
            local enemy=attributes(e.attacker)
            local original=lib:GetCharacterAttributeValue(e.attacker,enemy.current)
            local limit=lib:GetCharacterAttributeValue(e.attacker,enemy.maximum)
            local damage=math.max(0,math.min(original,limit*fraction))
            if damage>0 then lib:ModifyCharacterAttributeValue(e.attacker,enemy.current,0,-damage) end
            local remaining=lib:GetCharacterAttributeValue(e.attacker,enemy.current)
            if c.Debug then log(string.format("Perfect success instant poise %.4f: %.4f -> %.4f (max %.4f) target=%s",damage,original,remaining,limit,e.attacker:GetFullName())) end
        end)
        if not ok then log("Instant poise skipped: "..tostring(err)) end
    end
end
function R.tick(now,c)
    state.config=c;router.owner=state
    assert(type(c.SuccessChainEnabled or false)=="boolean","Invalid SuccessChainEnabled")
    assert((c.SuccessChainTimeout or 6)>=1 and (c.SuccessChainTimeout or 6)<=15,"Invalid SuccessChainTimeout")
    local cap=c.SuccessChainMaxStacks or 3
    assert(cap>=1 and cap<=5 and cap==math.floor(cap),"Invalid SuccessChainMaxStacks")
    for _,v in ipairs({c.SuccessChainRefundStep or .02,c.SuccessChainPoiseStep or .02}) do assert(v>=0 and v<=.05,"Invalid success chain bonus") end
    if now<state.lastMaintenance or now-state.lastMaintenance>=1 then
        install();state.lastMaintenance=now
        for key,a in pairs(state.attrs) do if not valid(a.actor) then state.attrs[key]=nil end end
        for key,time in pairs(state.seen) do if now<time or now-time>10 then state.seen[key]=nil end end
    end
    local events=state.queue
    if #events>0 then state.queue={} end
    for _,e in ipairs(events) do
        local ok,err=pcall(reward,e,now,c)
        if not ok then log("Perfect reward skipped: "..tostring(err)) end
    end
    chain.expire(state.chain,now,c)
    for _,tap in ipairs(state.taps) do
        if not tap.success and not tap.failed and now>tap.deadline+.15 then tap.failed=true;chain.miss(state.chain,tap.id) end
    end
    local pc=H.GetPlayerController()
    if not valid(pc) or not valid(pc.Pawn) or (state.avatar and pc.Pawn:GetAddress()~=state.avatar) then chain.reset(state.chain)
    elseif state.chain.count>0 then
        local ok,dead=pcall(function()
            local a=attributes(pc.Pawn)
            return a.health and StaticFindObject("/Script/SGameAttributes.Default__AttributeUtils"):GetCharacterAttributeValue(pc.Pawn,a.health)<=0
        end)
        if ok and dead then chain.reset(state.chain) end
    end
end
function R.clear()
    if router.owner==state then router.owner=nil end
    state.queue={};state.taps={};state.seen={};state.attrs={};state.lastMaintenance=-10
    state.chain=chain.new();state.avatar=nil
end
return R
