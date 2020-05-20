local logger = require("utilities.logger")

logger.title("---------------------------")
logger.title(" CollectStickersBot V1.0.0 ")
logger.title(" By Rami Sabbagh           ")
logger.title("---------------------------")
print("")
logger.loading("Picking up some books...")

local telegram = require("telegram")
local cqueues = require("cqueues")
local lfs = require("lfs")

--The bot's storage system
STORAGE = require("utilities.storage")

logger.loading("Getting my keyring...")

CONFIG = STORAGE.core.configuration

if not CONFIG.token then
    repeat
        CONFIG.token = logger.prompt("= Please input my authorization token (as provided by @BotFather): ")
    until CONFIG.token ~= ""
    CONFIG() --Save the configuration
end

if not CONFIG.timeout then
    repeat
        CONFIG.timeout = logger.prompt("= Please input the requests timeout (default: 10): ")
        if CONFIG.timeout == "" then CONFIG.timeout = "10" end
        CONFIG.timeout = tonumber(CONFIG.timeout, 10)
    until CONFIG.timeout
    CONFIG() --Save the configuration
end

if not CONFIG.pollingTimeout then
    repeat
        CONFIG.pollingTimeout = logger.prompt("= Please input the updates polling timeout (default: 20): ")
        if CONFIG.pollingTimeout == "" then CONFIG.pollingTimeout = "20" end
        CONFIG.pollingTimeout = tonumber(CONFIG.pollingTimeout, 10)
    until CONFIG.pollingTimeout
    CONFIG() --Save the configuration
end

telegram.setToken(CONFIG.token)
telegram.setTimeout(CONFIG.timeout)

logger.loading("Learning about myself...")
local me = telegram.getMe()
local myTag = "@"..me.username
ME = me

logger.loading("Creating my work queues...")

--The main bot cqueue
local que = cqueues.new()
CQUE = que

--The on exit cqueue
EQUE = cqueues.new()

logger.loading("Calling friends...")

local handlers = {}
local commands = {}
local descriptions = {}
local interactives = {}

for moduleName in lfs.dir("modules") do
    if moduleName ~= "." and moduleName ~= ".." then
        local module = dofile("modules/"..moduleName)
        for commandName, commandFunc in pairs(module[1]) do
            local description = commandFunc()
            if commands[commandName] then error("Conflict in command '"..commandName.."' while loading module '"..module.."'.") end
            if #commandName > 32 then error("Command name too long '"..commandName.."' in module '"..moduleName.."' (must be <= 32 characters).") end
            if description and (#description < 3 or #description > 256) then error("Command description too long or short '"..commandName.."' in module '"..moduleName.."' (Must be [3,256]).") end
            commands[commandName] = commandFunc
            descriptions[commandName] = description
        end
        table.insert(handlers, module[2])
        logger.subloading("- Loaded "..moduleName)
    end
end

logger.loading("Checking my abilties...")
do
    local current = telegram.getMyCommands()
    local updateNeeded = false
    for k,v in pairs(current) do
        if descriptions[k] ~= v then updateNeeded = true end
    end
    for k,v in pairs(descriptions) do
        if current[k] ~= v then updateNeeded = true end
    end
    if updateNeeded then
        assert(telegram.setMyCommands(descriptions))
        logger.subloading("- Updated my abilities successfully.")
    else
        logger.subloading("- Already up to date.")
    end
end

logger.loading("Getting ready for work...")

local lastUpdateID = STORAGE.core.last_update.id

if lastUpdateID then logger.subloading("- Loaded last_update successfully.") end

--Save lastUpdateID on exit
EQUE:wrap(function()
    if lastUpdateID then
        local container = STORAGE.core.last_update
        container.id = lastUpdateID
        container()

        logger.subloading("- Updated last_update successfully.")
    end
end)

local function pullUpdates(timeout)
    local ok, updates = false, {}
    local nextIndex = 1

    local function iterator()
        --Pull new updates
        while nextIndex > #updates or #updates == 0 do
            while true do
                ok, updates = pcall(telegram.getUpdates, lastUpdateID and lastUpdateID+1, 100, timeout)
                if not ok then logger.warn("- Polling error:", updates) else break end
            end
            nextIndex = 1

            while lastUpdateID and nextIndex <= #updates and updates[nextIndex].updateID <= lastUpdateID do
                nextIndex = nextIndex + 1
            end
        end

        local update = updates[nextIndex]
        nextIndex, lastUpdateID = nextIndex + 1, update.updateID
        return update
    end

    return iterator
end

local function checkError(err)
    if not err then return end
    if err:sub(-10, -1) == ": SHUTDOWN" then
        error("SHUTDOWN", 2)
    elseif err:sub(-9, -1) == ": RESTART" then
        error("RESTART", 2)
    elseif err:sub(-9, -1) == ": UPGRADE" then
        error("UPGRADE", 2)
    end
end

local function commandHandler(update)
    if not update.message then return end --Ignore non-messages updates
    if not update.message.text then return end --Ignore non-text messages
    if update.message.text:sub(1,1) ~= "/" then return end --Ignore non-command messages

    local commandName = update.message.text:match("^/%S*"):lower():sub(2,-1)
    local targetBot = commandName:match("@%S*$")
    if targetBot and targetBot ~= myTag then return end  --Ignore commands for other bots
    if update.message.chat.type ~= "private" and not targetBot then return end --Ignore raw commands in groups
    commandName = commandName:gsub("@%S*$", "") --Remove the bot tag

    return function()
        local commandFunc = commands[commandName]
        if commandFunc then
            local ok, interactive = pcall(commandFunc, update.message)
            if ok then
                if interactive then
                    local chatID = update.message.chat.id
                    --Tell the current interactive command that it lost control
                    if interactives[chatID] then
                        local ok2, err2 = pcall(interactives[chatID], false, true)
                        if not ok2 then
                            checkError(err2)
                            logger.error("Error while overriding an interactive handler:", err2)
                        end
                    end
                    local previous = interactives[chatID]

                    --Set the new interactive handler for this chat
                    interactives[chatID] = interactive

                    --Tell the new interactive handler that it got control
                    local ok3, err3 = pcall(interactives[chatID], false, false, previous)
                    if ok3 then
                        if err3 then interactives[chatID] = nil end --Unsubscribe instantly
                    else
                        checkError(err3)
                        logger.error("Error while overriding an interactive handler:", err3)
                    end
                end
            else
                checkError(interactive)
                logger.error("Failed to execute command '"..commandName.."':", interactive)
            end
        else
            pcall(update.message.chat.sendMessage, update.message.chat, "Unknown command `/"..commandName.."`.", "Markdown")
        end
    end
end

local function interactiveHandler(update, handler, chatID)
    return function()
        local ok, unsubscribe = pcall(handler, update)
        if ok then
            if unsubscribe then interactives[chatID] = nil end
        else
            checkError(unsubscribe)
            logger.error("Failed to execute interactive handler:", unsubscribe)
        end
    end
end

--The main bot loop
que:wrap(function()
    for update in pullUpdates(CONFIG.pollingTimeout) do
        --Trigger the command handler
        local commandHandle = commandHandler(update)
        if commandHandle then que:wrap(commandHandle) end

        --Trigger the updates handlers
        for _, handler in ipairs(handlers) do
            local async = handler(update)
            if async then que:wrap(async) end
        end

        --Trigger the interactive commands handlers
        for chatID, handler in pairs(interactives) do
            --Filter the commands messages from the interactive handlers.
            if not (update.message and update.message.text and update.message.text:sub(1,1) == "/") then
                local message = update.message or update.editedMessage or update.channelPost or update.editedChannelPost
                if message and message.chat and message.chat.id == chatID then
                    que:wrap(interactiveHandler(update, handler, chatID))
                end
            end
        end
    end
end)

print("")
logger.colored("%{bright green}Ready.")
print("")

local ok, err = que:loop()

print("")
logger.info("Exitting...")

for err2 in EQUE:errors() do
    logger.error("- Error while executing EQUE:", err2)
end

if not ok then
    print("")
    logger.error(err)

    local ok2, err2 = pcall(function()
        local file = assert(io.open("error.txt", "wb"))
        assert(file:write(err))
        file:close()
    end)

    if not ok2 then logger.critical("Failed to write error.txt: "..tostring(err2)) end
end