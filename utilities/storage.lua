--- JSON based storage system.
-- @module storage
local storage = {}

local lfs = require("lfs")
local cjson = require("cjson")

--- Create a directory if it doesn't exist.
-- @tparam string path The path of the directory.
-- @raise Error on creation failure.
local function makeDirectory(path)
    if lfs.attributes(path, "mode") ~= "directory" then
        assert(lfs.mkdir(path))
        STATSD:increment("storage.container.new")
    end
end

--- Create a new JSON file table.
-- Loads the data automatically, saves when called as a function.
-- @tparam string path The path to the JSON file location.
-- @treturn table The created JSON file table.
-- @raise Error on filesystem or json decode failure.
local function newFile(path)
    local data = {}

    --Load saved data if exists.
    if lfs.attributes(path, "mode") == "file" then
        local file = assert(io.open(path, "r"))
        local rawdata = assert(file:read("*a"))
        file:close()

        data = cjson.decode(rawdata)
        STATSD:increment("storage.file.load")
    else
        STATSD:increment("storage.file.new")
    end

    local meta = {}

    --- Save the JSON file, by calling the table as a function.
    -- @raise Error on filesystem or json encode failure.
    function meta.__call()
        local rawdata = cjson.encode(data)
        local file = assert(io.open(path, "w"))
        assert(file:write(rawdata))
        file:close()
        STATSD:incremnet("storage.file.save")
    end

    return setmetatable(data, meta)
end

--- Create a new JSON storage container.
-- It's like a directory of JSON files.
-- @tparam string name The name of the container.
-- @treturn table The created JSON storage container.
local function newContainer(name)
    makeDirectory("storage/"..name)

    local container, meta = {}, {}

    --Weak table.
    meta.__mode = "kv"

    function meta.__index(t, k)
        local file = newFile(string.format("storage/%s/%s.json", name, tostring(k)))
        rawset(t, k, file)
        return file
    end

    return setmetatable(container, meta)
end

local storageMeta = {}

--Weak table.
storageMeta.__mode = "kv"

--- Create a new JSON storage container.
-- It's like a directory of JSON files.
-- @tparam table t The module's table.
-- @tparam any k The container name.
-- @treturn table The created JSON storage container.
function storageMeta.__index(t, k)
    local container = newContainer(tostring(k))
    rawset(t, k, container)
    return container
end

makeDirectory("storage") --Make sure that the root storage directory exists.

return setmetatable(storage, storageMeta)