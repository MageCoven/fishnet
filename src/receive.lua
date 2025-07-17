local fishnet = require("fishnet")

---@diagnostic disable-next-line: undefined-global
local global = global
---@type PersistentQueue
local message_queue = global.message_queue

while true do
    local msg, err = fishnet.receive_any()
    if err then
        error("Error receiving message: " .. err, 0)
    end

    message_queue:push(msg)
end