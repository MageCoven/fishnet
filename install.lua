-- install.lua
-- version: 0.1.1
-- author: MageCoven
-- license: MIT

local args = { ... }
local URL_BASE = "https://raw.githubusercontent.com/MageCoven/fishnet/refs/heads/main/"
local URL = URL_BASE .. "src/"

local files = {
    "lib/fishnet.lua",
    "lib/queue.lua",
    "startup.lua",
    "worker.lua"
}

local function downloadFile(url, dest)
    if fs.exists(dest) then
        error("File already exists: " .. dest, 2)
    end

    local response = http.get(url)
    if not response then
        error("Failed to download " .. url, 0)
    end
    local content = response.readAll()
    response.close()

    local file = fs.open(dest, "w")
    if not file then
        error("Could not open file for writing: " .. dest)
    end

    file.write(content)
    file.close()

    local version = content:match("version:%s*(%d+%.%d+%.%d+)")
    return version or "unknown"
end

if #args > 0 and args[1] == "update" then
    print("Updating installer...")
    fs.delete("install.lua")
    local version = downloadFile(URL_BASE .. "install.lua", "install.lua")
    print("Updated installer (version: " .. version .. ")")
    return
end

for _, file in ipairs(files) do
    if not fs.exists(file) then
        local version = downloadFile(URL .. file, file)
        print("Downloaded " .. file .. " (version: " .. version .. ")")
    else
        fs.delete(file)
        local version = downloadFile(URL .. file, file)
        print("Replaced " .. file .. " (version: " .. version .. ")")
    end
end