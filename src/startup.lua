-- startup.lua
-- version: 0.1.1
-- author: MageCoven
-- license: MIT

if fs.exists("worker.lua") and turtle then
    shell.run("worker.lua")
end