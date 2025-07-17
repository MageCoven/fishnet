local URL = "https://raw.githubusercontent.com/MageCoven/fishnet/refs/heads/main/src/"

local files = {
    "lib/fishnet.lua",
    "lib/persistent_queue.lua",
    "lib/persistent_task.lua",
    "receive.lua",
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
end

for _, file in ipairs(files) do
    if not fs.exists(file) then
        print("Downloading " .. file .. "...")
        downloadFile(file, file)
    else
        fs.delete(file)
        print("Downloading " .. file .. "...")
        downloadFile(file, file)
    end
end