-- worker.lua
-- version: 0.1.2
-- author: MageCoven
-- license: MIT

local fishnet = require("lib.fishnet")
local Queue = require("lib.queue")

local PROTOCOL = "worker"
local PROTOCOL_TASK = "worker_task"

settings.define("worker.task_folder", {
    type = "string",
    default = "fishnet/downloads",
    description = "The folder where task files are stored."
})

settings.define("worker.task_data_file", {
    type = "string",
    default = ".worker/task_data.lt",
    description = "The file where task data is stored."
})

local send_queue = Queue.new()
local receive_queue = Queue.new()
local task = nil
---@type "north"|"east"|"south"|"west"
local direction = "north"

local function determine_direction()
    if turtle.getFuelLevel() < 2 then
        error("Turtle needs fuel to determine direction.", 2)
    end

    local start_x, start_y, start_z = gps.locate()
    if not start_x then
        error("GPS location not available to determine direction.", 2)
    end

    for i = 1, 4, 1 do
        if turtle.forward() then
            break
        end
        turtle.turnRight()
    end

    local end_x, end_y, end_z = gps.locate()
    if not end_x then
        error("GPS location not available after moving.", 2)
    end

    turtle.back()  -- Move back to the original position

    if end_x > start_x then
        direction = "east"
    elseif end_x < start_x then
        direction = "west"
    elseif end_y > start_y then
        direction = "south"
    elseif end_y < start_y then
        direction = "north"
    else
        error("Could not determine direction based on GPS coordinates.", 2)
    end
end

local function load_task_if_any()
    if not fs.exists(settings.get("worker.task_data_file")) then
        task = nil
    end

    local file = fs.open(settings.get("worker.task_data_file"), "r")
    if not file then
        error("Could not open task data file for reading: " .. settings.get("worker.task_data_file"), 2)
    end

    local content = file.readAll()
    file.close()

    local data = textutils.unserialize(content)
    if not data or type(data) ~= "table" then
        error("Invalid task data file format.", 2)
    end

    local methods = require(settings.get("worker.task_folder") .. "/" .. data.name)
    if type(methods) ~= "table" or not methods.init or not methods.update then
        error("Task file must return a table with 'init' and 'update' methods.", 2)
    end

    task = {
        file_path = settings.get("worker.task_folder") .. "/" .. data.name .. ".lua",
        name = data.name,
        args = data.args,
        status = data.status or "setup",
        data = data.data,
        init = methods.init,
        update = methods.update
    }
end

--- Deep copies a table
--- @param original table
--- @return table
local function deep_copy_table(original)
    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            copy[k] = deep_copy_table(v)
        else
            copy[k] = v
        end
    end
    return copy
end

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

        term.setCursorPos(width, height)
        term.write(spinner)
        spinner = spinner_next[spinner]

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

local function message_handler()
    while true do
        ---@type Message
        local message = receive_queue:pop()
        assert(message, "Something went wrong with the message queue.")

        if fishnet.does_protocol_match(message.protocol, PROTOCOL_TASK) then
            assert(task == nil, "Not implemented: Task already running.")

            local task_name = message.content.task_name
            local task_file = task_name .. ".lua"
            local args = message.content.args

            if type(task_file) ~= "string" then
                error("Not implemented: Task file name must be a string.", 2)
            end

            if type(args) ~= "table" then
                error("Not implemented: Task arguments must be a table.", 2)
            end

            local task_path = settings.get("worker.task_folder") .. "/" .. task_file

            if not fs.exists(task_path) then
                error("Not implemented: Task file does not exist: " .. task_path, 2)
            end

            local require_path = settings.get("worker.task_folder") .. "/" .. task_name
            local methods = require(require_path)
            if type(methods) ~= "table" or not methods.init or not methods.update then
                error("Task file must return a table with 'init' and 'update' methods.", 2)
            end
            if not methods.init then
                error("Task file must have an 'init' method.", 0)
            end
            if not methods.update then
                error("Task file must have an 'update' method.", 0)
            end
            if type(methods.init) ~= "function" or type(methods.update) ~= "function" then
                error("Task file must have 'init' and 'update' methods as functions.", 0)
            end

            task = {
                file_path = task_path,
                name = task_file,
                args = args,
                status = "setup",
                data = {},
                init = methods.init,
                update = methods.update
            }
        elseif fishnet.does_protocol_match(message.protocol, PROTOCOL .. "*") then
            error("Unhandled message protocol: " .. message.protocol, 2)
        end
    end
end

local function task_handler()
    while true do
        while task == nil do
            sleep(0.1)
        end

        local x, y, z = gps.locate()
        if not x then
            error("GPS location not available.", 2)
        end

        local position = { x = x, y = y, z = z }
        local args_copy = deep_copy_table(task.args)

        local task_data = {
            name = task.name,
            args = task.args,
            status = task.status,
            data = task.data,
        }
        local file = fs.open(settings.get("worker.task_data_file"), "w")
        if not file then
            error("Could not open task data file for writing: " .. settings.get("worker.task_data_file"), 2)
        end
        file.write(textutils.serialize(task_data))
        file.close()

        if task.status == "setup" then
            task.status = "init"
        elseif task.status == "init" then
            task.status = task.init(args_copy, position, direction, task.data)
        elseif task.status == "running" then
            task.status = task.update(args_copy, position, direction, task.data)
        elseif task.status == "done" then
            -- Task completed, reset task
            task = nil
            if fs.exists(settings.get("worker.task_data_file")) then
                fs.delete(settings.get("worker.task_data_file"))
            end
        else
            error("Unknown task status: " .. tostring(task.status), 2)
        end
    end
end

determine_direction()
parallel.waitForAny(
    fishnet.new_coroutine(send_queue, receive_queue),
    input_handler,
    ui_handler,
    message_handler,
    task_handler
)