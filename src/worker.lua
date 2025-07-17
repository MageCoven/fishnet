local fishnet = require("fishnet")
local PersistentTask = require("persistent_task")
local PersistentQueue = require("persistent_queue")

---@diagnostic disable-next-line: undefined-global
local global = global
---@type PersistentQueue
local message_queue = global.message_queue


local task_queue = PersistentQueue.new("task_queue")
local current_task = PersistentTask.load("current_task")

while true do
    local msg = message_queue:pop()
    if msg then
        if msg.type == "add_task" then
            local task = msg.data
            task_queue:push(task)
        end
    end

    local x, y, z = gps.locate()
    if not x or not y or not z then
        error("GPS location not available", 0)
    end

    if current_task then
        current_task:update(x, y, z)
        if current_task.is_complete then
            current_task = nil
        end
    else
        local next_task = task_queue:pop()
        if next_task then
            current_task = PersistentTask.new(
                "current_task",
                next_task.program,
                next_task.args
            )
            current_task:init(x, y, z)
            current_task:update(x, y, z)
        end
    end
    
    sleep(0) -- Yield to allow other processes to run
end