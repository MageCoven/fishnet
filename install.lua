-- install.lua
-- version: 1.0.0
-- author: MageCoven
-- license: MIT

local URL = "https://raw.githubusercontent.com/MageCoven/fishnet/refs/heads/main/src/"

local files = {
    "lib/fishnet.lua",
    "lib/persistent_queue.lua",
    "lib/persistent_task.lua",
    "startup.lua",
    "worker.lua"
}

local function downloadFile(path, dest)
    if fs.exists(dest) then
        error("File already exists: " .. dest, 2)
    end

    local url = URL .. path
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

for _, file in ipairs(files) do
    if not fs.exists(file) then
        local version = downloadFile(file, file)
        print("Downloaded " .. file .. " (version: " .. version .. ")")
    else
        fs.delete(file)
        local version = downloadFile(file, file)
        print("Replaced " .. file .. " (version: " .. version .. ")")
    end
end