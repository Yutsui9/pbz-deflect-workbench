-- Panel names are persisted for compatibility; polling takes Unreal FKey names.
local M={}
local names={XButton1="ThumbMouseButton",XButton2="ThumbMouseButton2",
    RightMouseButton="RightMouseButton",LeftMouseButton="LeftMouseButton",
    MiddleMouseButton="MiddleMouseButton",LeftShift="LeftShift",
    LeftControl="LeftControl",SpaceBar="SpaceBar",Tab="Tab"}
for byte=65,90 do local s=string.char(byte);names[s]=s end
for i=1,12 do if i~=5 and i~=6 and i~=7 then names["F"..i]="F"..i end end
function M.make(name)
    return {KeyName=FName(assert(names[name],"Unsupported input key: "..tostring(name)))}
end
return M
