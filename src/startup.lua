local PersistentQueue = require("lib.persistent_queue")

---@diagnostic disable-next-line: lowercase-global
global = {
    message_queue = PersistentQueue.new("message_queue")
}

shell.run("worker.lua")