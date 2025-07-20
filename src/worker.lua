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
    local spinner = "/"
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

        term.setCursorPos(width - 1, height)
        term.write(spinner)
        spinner = spinner_next[spinner]

        local event, key = os.pullEvent("key")
        if key == keys.q then
            term.clear()
            term.setCursorPos(1, 1)
            term.write("Worker stopped.")
            break
        end
    end
end

local function task_handler()
    while true do
        while task == nil do
            sleep(0.1)
        end

        error("Implement task handling logic here.")
    end
end

local function message_handler()
    while true do
        --- @type Message
        local msg = receive_queue:pop()

        if fishnet.is_same_protocol(msg.protocol, PROTOCOL_TASK) then
            if task == nil then
                task = {
                    program = msg.content.program,
                    args = msg.content.args or {},
                }
            end
        end
    end
end

parallel.waitForAny(
    fishnet.new_coroutine(send_queue, receive_queue),
    ui_handler,
    task_handler,
    message_handler
)