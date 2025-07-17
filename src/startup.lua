local PersistentQueue = require("lib.persistent_queue")

---@diagnostic disable-next-line: lowercase-global
global = {
    message_queue = PersistentQueue.new("message_queue")
}

local function openTabWithName(script_path, name)
    local tab = shell.openTab(script_path)
    multishell.setTitle(tab, name)
    return tab
end

openTabWithName("receive.lua", "Receiver")

if fs.exists("worker.lua") then
    openTabWithName("worker.lua", "Worker")
end