-- startup.lua
-- version: 1.0.0
-- author: MageCoven
-- license: MIT

if fs.exists("worker.lua") then
    shell.run("worker.lua")
end