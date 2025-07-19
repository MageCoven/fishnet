-- worker.lua
-- version: 1.0.0
-- author: MageCoven
-- license: MIT

local fishnet = require("lib.fishnet")
local PersistentTask = require("lib.persistent_task")
local PersistentQueue = require("lib.persistent_queue")

---@type PersistentQueue
local message_queue = PersistentQueue.new("message_queue")
message_queue:load()

local task_queue = PersistentQueue.new("task_queue")
local current_task = PersistentTask.load("current_task")

local function handleReceivingMessages()
    while true do
        local msg, err = fishnet.receive_any()
        if err then
            error("Error receiving message: " .. err, 0)
        end

        message_queue:push(msg)
    end
end

local function handleTasks()
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
end

parallel.waitForAny(
    handleReceivingMessages,
    handleTasks
)