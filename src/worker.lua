-- worker.lua
-- version: 0.1.1
-- author: MageCoven
-- license: MIT

local fishnet = require("lib.fishnet")
local Queue = require("lib.queue")

local PROTOCOL = "worker"
local PROTOCOL_STATUS = "worker::status"
local PROTOCOL_TASK = "worker::task"

local send_queue = Queue.new()
local receive_queue = Queue.new()
local task = nil

local function ui_handler()
    local spinner = 0
    local spinner_next = {
        ["/"] = "-",
        ["-"] = "\\",
        ["\\"] = "|",
        ["|"] = "/"
    }

    while true do
        local width, height = term.getSize()
        
        term.clear()
        term.setCursorPos(1, 1)
        
        if task then
            print("Current Task: " .. task.name)
            print("Status: " .. (task.status or "Running"))
        else
            print("No current task.")
        end

        print("Pending Messages: " .. receive_queue:size())
        print("Press 'q' to quit.")

        term.setCursorPos(width, height)
        term.write(spinner)
        spinner = (spinner + 1) % 4

        sleep(0.1)
    end
end

local function input_handler()
    while true do
        local event, key = os.pullEvent("key")
        if key == keys.q then
            term.clear()
            term.setCursorPos(1, 1)
            print("Worker stopped.")
            break
        end
    end
end

parallel.waitForAny(
    fishnet.new_coroutine(send_queue, receive_queue),
    input_handler,
    ui_handler
)