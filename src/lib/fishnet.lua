-- fishnet.lua
-- version: 1.0.0
-- author: MageCoven
-- license: MIT

settings.define("fishnet.download_folder", {
    type = "string",
    default = "downloads",
    description = "Folder where files received via Fishnet will be saved."
})

local peripheral_names = peripheral.getNames()
local modem_name = nil
for _, name in ipairs(peripheral_names) do
    if peripheral.getType(name) == "modem" then
        modem_name = name
        break
    end
end
if not modem_name then
    error("No modem found.", 0)
end

rednet.open(modem_name)

local fishnet = {
    PROTOCOL = "fishnet",
    PROTOCOL_STATUS = "fishnet.:status",
    PROTOCOL_FILE = "fishnet.:file"
}

--- Send a message to a specific receiver.
---@param receiver_id integer
---@param message any
---@param protocol string|nil
function fishnet.send(receiver_id, message, protocol)
    rednet.send(receiver_id, message, protocol or "fishnet")
end

--- Receive a message from any sender.
---@param protocol string|nil
---@param timeout number|nil
function fishnet.receive(protocol, timeout)
    return rednet.receive(protocol, timeout)
end

--- Send a status message to a specific receiver.
---@param receiver_id integer
---@param status any
function fishnet.send_status(receiver_id, status)
    fishnet.send(receiver_id, status, fishnet.PROTOCOL_STATUS)
end

--- Handle a received status message.
---@param id integer
---@param message any
---@param protocol string
local function handle_receive_status(id, message, protocol)
    return id, message, protocol
end

--- Receive a status message from any sender.
---@param timeout number|nil
function fishnet.receive_status(timeout)
    local id, message, protocol = fishnet.receive(fishnet.PROTOCOL_STATUS, timeout)
    return handle_receive_status(id, message, protocol)
end

--- Send a file to a specific receiver.
---@param receiver_id integer
---@param file_path string
function fishnet.send_file(receiver_id, file_path)
    local file = fs.open(file_path, "r")
    if not file then
        error("Failed to open file: " .. file_path, 2)
    end

    local data = file.readAll()
    file.close()

    fishnet.send(receiver_id, {
        file_name = fs.getName(file_path),
        data = data
    }, fishnet.PROTOCOL_FILE)
end

--- Handle a received file message.
--- @param id integer
--- @param message any
--- @param protocol string
--- @return string|nil, string
local function handle_receive_file(id, message, protocol)
    if type(message) ~= "table" or not message.file_name or not message.data then
        return nil, "Invalid file message format"
    end

    local folder = settings.get("fishnet.download_folder")
    local file_path = fs.combine(folder, message.file_name)
    local file = fs.open(file_path, "w")
    if not file then
        return nil, "Failed to open file for writing: " .. file_path
    end

    file.write(message.data)
    file.close()

    return file_path, ""
end

--- Receive a file from any sender.
---@param timeout number|nil
---@return string|nil, string
function fishnet.receive_file(timeout)
    local id, message = fishnet.receive(fishnet.PROTOCOL_FILE, timeout)
    return handle_receive_file(id, message, fishnet.PROTOCOL_FILE)
end

--- Host a service with a specific hostname.
---@param hostname string
function fishnet.host(hostname)
    rednet.host(fishnet.PROTOCOL, hostname)
end

--- Unhost a service with a specific hostname.
---@param hostname string
function fishnet.unhost(hostname)
    rednet.unhost(fishnet.PROTOCOL, hostname)
end

--- Find a service with a specific hostname.
---@param hostname string
---@return integer|nil
function fishnet.lookup(hostname)
    local ids = {rednet.lookup(fishnet.PROTOCOL, hostname)}
    return ids[1]
end

--- Close the modem connection.
function fishnet.close()
    rednet.close()
end

--- Receive any message with a specific protocol.
---@param timeout number|nil
---@return table, string|nil
function fishnet.receive_any(timeout)
    local id, message, protocol = rednet.receive(nil, timeout)
    if not message then
        return {}, "No message received"
    end

    if protocol == fishnet.PROTOCOL_STATUS then
        return {
            type = "status",
            id = id,
            data = {
                handle_receive_status(id, message, protocol)
            }
        }, nil
    elseif protocol == fishnet.PROTOCOL_FILE then
        return {
            type = "file",
            id = id,
            data = {
                handle_receive_file(id, message, protocol)
            }
        }, nil
    elseif protocol == fishnet.PROTOCOL then
        return {
            type = "message",
            id = id,
            data = {
                message = message,
            }
        }, nil
    else
        return {}, "Unknown protocol: " .. protocol
    end
end

return fishnet