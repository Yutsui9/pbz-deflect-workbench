-- Local file protocol only. The panel can request APPLY or RESTORE; never execute request contents.
local B={}
local source=debug.getinfo(1,"S").source:gsub("^@","")
local dir=assert(source:match("^(.*[/\\])"))
function B.start(api)
    local handled,result,message="","ok","Ready"
    local beat=-1
    local function status()
        local f=io.open(dir.."control.status","w")
        if not f then return end
        f:write("version=0.1.8\nrequest="..handled.."\nenabled="..(api.enabled() and "1" or "0").."\nresult="..result.."\nmessage="..message:gsub("[\r\n]"," ").."\n")
        f:close()
    end
    LoopInGameThreadWithDelay(250,function()
        if api.stopped() then return true end
        local f=io.open(dir.."control.request","r")
        if f then
            local data=f:read(512) or "";f:close()
            local id,action=data:match("^([%w]+)\n([A-Z]+)\n?$")
            if id and id~=handled then
                handled=id
                local ok,err=pcall(function()
                    if action=="APPLY" then api.apply()
                    elseif action=="RESTORE" then api.restore()
                    else error("Unsupported panel command") end
                end)
                result=ok and "ok" or "error";message=ok and action or tostring(err)
                print("[YanyunGuard] Panel "..action..": "..message.."\n")
                status()
            end
        end
        local now=os.time()
        if now~=beat then beat=now;status() end
        return false
    end)
    status()
end
return B
