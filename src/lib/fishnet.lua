-- lib/fishnet.lua
-- version: 0.1.0
-- author: MageCoven
-- license: MIT

local Queue = require("lib.queue")

local fishnet = {}

fishnet.VERSION = "0.1.0"
fishnet.PROTOCOL = "fishnet"
fishnet.PROTOCOL_FTP = "fishnet_ftp"
fishnet.PROTOCOL_SIMPLE = "fishnet_simple"

settings.define("fishnet.download_folder", {
    type = "string",
    default = "fishnet/downloads",
    description = "The folder where downloaded files will be saved."
})

settings.define("fishnet.allow_ftp", {
    type = "boolean",
    default = true,
    description = "Allow FTP protocol for file transfers."
})

--- The message object structure.
--- @class Message
--- @field address number The address of the sender/receiver.
--- @field content any The content of the message.
--- @field protocol string The protocol used for the message.

--- Helper function to create a message object.
---@param address number The address of the message sender/receiver.
---@param content any The content of the message.
---@param protocol string The protocol for the message. Defaults to fishnet.PROTOCOL.
---@return Message
function fishnet.message(address, content, protocol)
    return {
        address = address,
        content = content,
        protocol = protocol
    }
end

--- Check if the given protocol matches the specified pattern.
---@param protocol string The protocol to check.
---@param pattern string The pattern to match against.
---@return boolean True if the protocol matches the pattern, false otherwise.
function fishnet.does_protocol_match(protocol, pattern)
    local effective_pattern = pattern:gsub("^%*", ""):gsub("%*$", "")

    if #effective_pattern == 0 then
        return true
    end

    local starts_with_wildcard = pattern:sub(1, 1) == "*"
    local ends_with_wildcard = pattern:sub(-1, -1) == "*"

    if starts_with_wildcard and ends_with_wildcard then
        return protocol:find(effective_pattern, 1, true) ~= nil
    elseif starts_with_wildcard then
        return protocol:sub(-#effective_pattern) == effective_pattern
    elseif ends_with_wildcard then
        return protocol:sub(1, #effective_pattern) == effective_pattern
    else
        return protocol == effective_pattern
    end
end

--- Send a message over the fishnet protocol.
---@param message Message The message to send.
---@return nil
function fishnet.send(message)
    rednet.send(message.address, message.content, message.protocol)
end

--- Receive a message over the fishnet protocol.
---@overload fun(pattern: string): Message
---@overload fun(protocol: string, timeout: number): Message|nil
function fishnet.receive(pattern, timeout)
    local id, content, protocol
    while true do
        id, content, protocol = rednet.receive(nil, timeout)
        if not id then
            return nil
        end

        if fishnet.does_protocol_match(protocol, pattern) then
            return fishnet.message(id, content, protocol)
        end
    end
end

--- Send a file over the fishnet protocol.
--- @param address number
--- @param file_path string
function fishnet.send_file(address, file_path)
    if not fs.exists(file_path) then
        error("File does not exist: " .. file_path, 2)
    end

    local file = fs.open(file_path, "r")
    if not file then
        error("Could not open file for reading: " .. file_path, 2)
    end

    local content = file.readAll()
    file.close()

    local file_name = fs.getName(file_path)
    local message = {
        type = "file",
        file_name = file_name,
        content = content
    }

    fishnet.send(fishnet.message(address, message, fishnet.PROTOCOL_FTP))
end

--- Receive a file over the fishnet protocol.
--- @param send_queue Queue<Message>
--- @param receive_queue Queue<Message>
function fishnet.new_coroutine(send_queue, receive_queue)
    return function()
        parallel.waitForAny(
            function()
                while true do
                    local msg = send_queue:pop()
                    if msg then
                        fishnet.send(msg)
                    end
                end
            end,
            function()
                while true do
                    local msg = fishnet.receive("*")

                    if fishnet.does_protocol_match(msg.protocol, fishnet.PROTOCOL_FTP .. "*") then
                        if settings.get("fishnet.allow_ftp") then
                            local file_path = settings.get("fishnet.download_folder") .. "/" .. msg.content.file_name
                            local file = fs.open(file_path, "w")
                            if not file then
                                error("Could not open file for writing: " .. file_path, 2)
                            end

                            file.write(msg.content.content)
                            file.close()

                            receive_queue:push(
                                fishnet.message(
                                    msg.address,
                                    {
                                        type = "file_received",
                                        file_name = msg.content.file_name,
                                        file_path = file_path
                                    },
                                    fishnet.PROTOCOL_FTP
                                )
                            )
                        end
                    else
                        receive_queue:push(msg)
                    end
                end
            end
        )
    end
end

return fishnet