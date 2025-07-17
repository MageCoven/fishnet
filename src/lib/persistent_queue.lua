local PersistentQueue = {}

--- PersistentQueue class for managing a queue stored in a file.
--- @class PersistentQueue
--- @field filename string The file where the queue is stored.
--- @field queue table The in-memory representation of the queue.
--- @field new fun(self: PersistentQueue, filename: string): PersistentQueue
--- @field push fun(self: PersistentQueue, item: any): nil
--- @field pop fun(self: PersistentQueue): any
--- @field save fun(self: PersistentQueue): nil
--- @field load fun(self: PersistentQueue): nil

--- Create a new PersistentQueue instance.
--- @param filename string The file where the queue will be stored.
--- @return PersistentQueue
function PersistentQueue:new(filename)
    local obj = { filename = filename, queue = {} }
    setmetatable(obj, self)
    self.__index = self
    return obj
end

--- Push an item onto the queue. Note that this will also save the queue to the
--- file.
--- @param item any The item to add to the queue.
function PersistentQueue:push(item)
    table.insert(self.queue, item)
    self:save()
end

--- Pop an item from the queue. Note that this will also save the queue to the
--- file.
--- @return any The item removed from the queue, or nil if the queue is empty.
function PersistentQueue:pop()
    local item = table.remove(self.queue, 1)
    self:save()
    return item
end

--- Load the queue from the file. If the file does not exist, it initializes an
--- existing queue.
function PersistentQueue:save()
    local file = fs.open(self.filename, "w")
    if not file then
        error("Could not open file for writing: " .. self.filename)
    end
    file.write(textutils.serialize(self.queue))
    file.close()
end

--- Load the queue from the file. If the file does not exist, it initializes an
--- empty queue.
function PersistentQueue:load()
    if fs.exists(self.filename) then
        local file = fs.open(self.filename, "r")
        if not file then
            error("Could not open file for reading: " .. self.filename)
        end
        local content = file.readAll()
        file.close()
        self.queue = textutils.unserialize(content) or {}
    else
        self.queue = {}
    end
end

return PersistentQueue