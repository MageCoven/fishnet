-- lib/queue.lua
-- version: 0.1.1
-- author: MageCoven
-- license: MIT

local Queue = {}
Queue.__index = Queue
Queue.VERSION = "0.1.0"

--- Queue class for managing a simple in-memory queue.
--- @class Queue
--- @field new fun(): Queue
--- @field push fun(self: Queue, item: unknown): nil
--- @field pop fun(self: Queue): unknown
--- @field is_empty fun(self: Queue): boolean
--- @field size fun(self: Queue): number

--- Create a new Queue instance.
--- @return Queue
function Queue.new()
    local self = setmetatable({}, Queue)
    self._items = {}
    self._size = 0

    return self
end

--- Push an item onto the queue.
--- @param item unknown The item to add to the queue.
function Queue:push(item)
    table.insert(self._items, item)
    self._size = self._size + 1
end

--- Pop an item from the queue, yield if the queue is empty.
--- @return unknown The item removed from the queue
function Queue:pop()
    while self._size == 0 do
        coroutine.yield()
    end

    local item = table.remove(self._items, 1)
    self._size = self._size - 1
    return item
end

--- Check if the queue is empty.
--- @return boolean True if the queue is empty, false otherwise.
function Queue:is_empty()
    return self._size == 0
end

--- Get the size of the queue.
--- @return number The number of items in the queue.
function Queue:size()
    return self._size
end

return Queue