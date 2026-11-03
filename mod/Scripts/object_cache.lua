-- Shared across feedback modules and F5 reloads. Never retain dead world objects.
local key="PBZGuardObjectCacheV1"
if _G[key] then return _G[key] end
local M={}
local entries,clock={},0
function M.tick(now)
    if now<clock then entries={} end
    clock=now
end
function M.clear() entries={} end
function M.get(class)
    local e=entries[class]
    if not e or clock-e.time>=1 then
        e={time=clock,objects=FindAllOf(class) or {}}
        entries[class]=e
    end
    for i=#e.objects,1,-1 do
        local o=e.objects[i]
        if not o or not o:IsValid() then table.remove(e.objects,i) end
    end
    return e.objects
end
_G[key]=M
return M
