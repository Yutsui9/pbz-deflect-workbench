local path=debug.getinfo(1,"S").source:gsub("^@","")
local dir=assert(path:match("^(.*[/\\])"))
local mod=assert(loadfile(dir.."combat.lua"))()
mod.start()
