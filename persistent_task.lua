local PersistentTask = {}

---@class PersistentTask
---@field file_path string
---@field task string
---@field args table
---@field data table
---@field methods table
---@field is_initialized boolean
---@field is_complete boolean
---@field new fun(task: string, args: table): nil
---@field init fun(self: PersistentTask, x: number, y: number, z: number): nil
---@field update fun(self: PersistentTask, x: number, y: number, z: number): nil
---@field save fun(self: PersistentTask): nil
---@field load fun(file_path: string): PersistentTask



--- Create a new PersistentTask instance.
---@param file_path string The file path where the task data is stored.
---@param task string The task to run.
---@param args table The arguments to pass to the task.
---@return PersistentTask
function PersistentTask.new(file_path, task, args)
    local self = setmetatable({}, { __index = PersistentTask })
    self.file_path = file_path
    self.task = task
    self.args = args
    self.data = {}
    self.methods = {}
    self.is_initialized = false
    self.is_complete = false

    self:save()

    return self
end

--- Initialize the task by loading its data from the file.
--- @param x number The x coordinate for the task.
--- @param y number The y coordinate for the task.
--- @param z number The z coordinate for the task.
function PersistentTask:init(x, y, z)
    local download_folder = settings.get("fishnet.download_folder")
    local file_path = fs.combine(download_folder, self.task)
    
    self.methods = require(file_path)
    self.data = self.methods.init(x, y, z, self.data, self.args)
    self.is_initialized = true
    self:save()
end

function PersistentTask:update(x, y, z)
    if not self.is_initialized then
        error("Task is not initialized")
    end

    self.data = self.methods.update(x, y, z, self.data, self.args)
    if self.data == nil then
        self.is_complete = true
    end
    
    self:save()
end

--- Save the task data to the file.
function PersistentTask:save()
    local file = fs.open(self.file_path, "w")
    if not file then
        error("Could not open file for writing: " .. self.file_path)
    end
    file.write(textutils.serialize({
        task = self.task,
        args = self.args,
        data = self.data,
        is_initialized = self.is_initialized,
        is_complete = self.is_complete
    }))
    file.close()
end

--- Load the task data from the file.
--- @param file_path string The file path to load the task data from.
--- @return PersistentTask|nil
function PersistentTask.load(file_path)
    if not fs.exists(file_path) then
        return nil
    end

    local file = fs.open(file_path, "r")
    if not file then
        return nil
    end

    local content = file.readAll()
    file.close()

    local data = textutils.unserialize(content)
    if not data then
        error("Failed to unserialize content from file: " .. file_path, 2)
    end

    local task = PersistentTask.new(data.file_path, data.task, data.args)
    task.data = data.data
    task.is_initialized = data.is_initialized
    task.is_complete = data.is_complete

    if task.is_initialized then
        local file_path = fs.combine(settings.get("fishnet.download_folder"), data.task)
        task.methods = require(file_path)
    end

    return task
end

return PersistentTask