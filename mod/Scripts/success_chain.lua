-- Pure state: one chain step per successful press, independent of hit count.
local M={}
function M.new() return {count=0,last=nil,press=0,lastSuccessPress=0} end
function M.reset(s) s.count=0;s.last=nil end
function M.expire(s,now,c)
    if s.last and (now<s.last or now-s.last>(c.SuccessChainTimeout or 6)) then M.reset(s) end
end
function M.miss(s,id)
    if id>s.lastSuccessPress then M.reset(s) end
end
function M.success(s,id,now,c)
    M.expire(s,now,c)
    if id>s.lastSuccessPress then
        s.count=s.count+1;s.last=now;s.lastSuccessPress=id
    end
    if c.SuccessChainEnabled==false then return 0,0,0 end
    local stacks=math.min(math.max(0,s.count-1),c.SuccessChainMaxStacks or 3)
    return stacks,stacks*(c.SuccessChainRefundStep or .02),stacks*(c.SuccessChainPoiseStep or .02)
end
return M
