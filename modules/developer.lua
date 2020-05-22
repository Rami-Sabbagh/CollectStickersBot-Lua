--Developer module

local logger = require("utilities.logger")
local ltn12 = require("ltn12")
local http = require("http.compat.socket")
local telegram = require("telegram")

--------------------------------[[ Module Configuration ]]--------------------------------

local developerUsername, developerPassword

do
    local devConfig = STORAGE.developer.authorization

    developerUsername, developerPassword = devConfig.username, devConfig.password

    if not developerUsername then
        repeat
            developerUsername = logger.prompt("= Please input the developer's username: %{reset}@")
        until developerUsername ~= ""
        devConfig.username = developerUsername
        devConfig()
    end

    if not developerPassword then
        repeat
            developerPassword = logger.prompt("= Please input a password for developer's module: ")
        until developerPassword ~= ""
        devConfig.password = developerPassword
        devConfig()
    end
end

local reportChatID =  STORAGE.developer.report.chatID

do
    local loggerCritical = logger.critical

    local function report(...)
        if reportChatID then
            local ok, err = pcall(telegram.sendMessage, reportChatID, "*[CRITICAL]:* "..table.concat({...}, " ").." ⚠", "Markdown")
            if not ok then logger.error("Failed to send critical report:", err) end
        end
    end

    logger.critical = function(...)
        loggerCritical(...)
        pcall(report, ...)
    end
end

--------------------------------[[ Module Variables ]]--------------------------------

local isDeveloper = {}
DEVELOPERS = isDeveloper
local forceReply = telegram.structures.ForceReply(true) --Selective force reply markup object.

--The module's commands array
local commands = {}

--------------------------------[[ /developer command ]]--------------------------------

function commands.developer(message)
    if not message then return end
    local password = message.text:sub(string.len("/developer ")+1, -1)
    if message.chat.type ~= "private" then message.from = nil end --Disallow the command from non-private chats.
    if not message.from or (developerPassword ~= password and message.from.username ~= developerUsername) then
        STATSD:increment("modules.developer.attempted")
        if message.from then
            logger.warn(string.format("%s %s (@%s) [%d] attempted to authorize as developer with password '%s'.", message.from.firstName or "?", message.from.lastName or "?", message.from.username or "?", message.from.id, password))
        end
        message.chat:sendMessage("Unknown command `/developer`.", "Markdown")
        return
    end

    if developerPassword == password then
        STATSD:increment("modules.developer.authorized,method=password")
    else
        STATSD:increment("modules.developer.authorized.method=username")
    end

    if isDeveloper[message.from.id] then
        message.chat:sendMessage("Sir I still remember you 😉")
        logger.warn(string.format("%s %s (@%s) [%d] was already authorized as developer.", message.from.firstName or "?", message.from.lastName or "?", message.from.username or "?", message.from.id))
    else
        isDeveloper[message.from.id] = true
        message.chat:sendMessage("Welcome back sir 😎")
        local loggerFunction = message.from.username == developerUsername and logger.warn or logger.critical
        loggerFunction(string.format("%s %s (@%s) [%d] authorized as developer.", message.from.firstName or "?", message.from.lastName or "?", message.from.username or "?", message.from.id))
    end
end

--Developer commands
local dcommands = {}

--------------------------------[[ /shutdown command ]]--------------------------------

--Shutdown the bot
function dcommands.shutdown(message)
    logger.info(string.format("%s %s (@%s) [%d] requested to shutdown the bot.", message.from.firstName or "?", message.from.lastName or "?", message.from.username or "?", message.from.id))
    message.chat:sendMessage("It was nice to serve you sir!")
    error("SHUTDOWN")
end

--------------------------------[[ /restart command ]]--------------------------------

--Restart the bot
function dcommands.restart(message)
    logger.info(string.format("%s %s (@%s) [%d] requested to restart the bot.", message.from.firstName or "?", message.from.lastName or "?", message.from.username or "?", message.from.id))
    message.chat:sendMessage("Restarting...")
    error("RESTART")
end

--------------------------------[[ /cque_count command ]]--------------------------------

--Get the number of managed coroutines inside the main cqueue of the bot
function dcommands.cque_count(message)
    message.chat:sendMessage(string.format("There are `%d` managed coroutines in CQUE.", CQUE:count()), "Markdown")
end

--------------------------------[[ /error command ]]--------------------------------

--Cause an error in command execution
function dcommands.error(message)
    message.chat:sendMessage("Beep boop boop beeep ⚙")
    error(tostring(message.text))
end

--------------------------------[[ /flush_log command ]]--------------------------------

--Flush the log file
function dcommands.flush_log(message)
    logger.logFile:flush()
    message.chat:sendMessage("Flushed successfully sir ✅")
end

--------------------------------[[ /export_log command ]]--------------------------------

--Flush and upload the log file
function dcommands.export_log(message)
    logger.logFile:flush()

    local file = assert(io.open(logger.logPath, "rb"))
    local fileLength = file:seek("end")
    file:seek("set")

    if fileLength > 20*1024*1024 then
        message.chat:sendMessage("Sir, the log is larger than 20 MBs 😅\nTelegram won't allow me to upload it, so you'll have to pull it manually, sorry 😕")
    elseif fileLength == 0 then
        message.chat:sendMessage("Sir, the log is empty 😳")
    else
        message.chat:sendChatAction("upload_document")
        message.chat:sendDocument({filename=logger.logFilename, data=file, len=fileLength})
    end
    pcall(io.close, file)
end

--------------------------------[[ /new_log commands ]]--------------------------------

--End the current log and start a new one
function dcommands.new_log(message)
    local oldFilename = logger.logFilename
    logger.info("Log file ended under a request by a developer.")
    logger.newLogFile()
    logger.info("Continuation of logfile "..oldFilename)
    message.chat:sendMessage("Sir, I've started a new log file successfully ✅")
end

--------------------------------[[ /report_here command ]]--------------------------------

--Report critical errors in this chat
function dcommands.report_here(message)
    local report = STORAGE.developer.report
    report.chatID = message.chat.id
    report()
    reportChatID = message.chat.id
    message.chat:sendMessage("Sir, This channel has been configured for sending critical reports successfully ✅")
end

--------------------------------[[ /upgrade command ]]--------------------------------

--Upgrade the bot
local upgradeLock = false
function dcommands.upgrade(message)

    --Whether the message is running in selective mode or not.
    local selective = message.chat.type ~= "private" or nil

    --The markup to be used when sending messages (force reply only when selective).
    local replyMarkup = selective and forceReply

    --The last message which the user has sent.
    local response = message
    --The message id to reply to, nil when not selective.
    local replyToMessageID = selective and response.messageID

    --The last bot's message
    local lastMessage

    if upgradeLock then
        message.chat:sendMessage("An upgrade operation is already in process sir.", nil, nil, nil, replyToMessageID)
        return
    end

    local unsubscribe = false
    return function(update, overridden)
        if not update then --Interactive handler subscription call
            if overridden then --Cancel this interactive instance
                if upgradeLock then
                    message.chat:sendMessage("The upgrade process can't be canceled at this stage 🤖",
                        nil, nil, nil, replyToMessageID)
                else
                    message.chat:sendMessage("Cancelled the upgrade process successfully, few 😅",
                        nil, nil, nil, replyToMessageID)
                end
            else --New interactive instance
                lastMessage = message.chat:sendMessage("You sure sir? upload my replacement please 😐",
                    nil, nil, nil, replyToMessageID, replyMarkup)
            end

            return
        end

        if unsubscribe then return true end

        --Ignore non-messages updates.
        if not update.message then return end

        --Ignore non-reply messages when in selective mode.
        if selective and update.message.replyToMessage ~= lastMessage then return end

        --Update the user's response message.
        response = update.message

        --Update replyToMessageID when in selective mode.
        replyToMessageID = selective and response.messageID

        if upgradeLock then
            message.chat:sendMessage("Too late, an upgrade is already in process sir...",
                nil, nil, nil, replyToMessageID)
            return true
        end

        if not response.document then
            lastMessage = message.chat:sendMessage("Sir please send the upgrade package as a `.zip` file 📦",
                "Markdown", nil, nil, replyToMessageID, replyMarkup)
            return
        end

        if response.document.mimeType ~= "application/zip" then
            lastMessage = response.chat:sendMessage("I only know how to upgrade using `.zip` packages 🙃",
                "Markdown", nil, nil, replyToMessageID, replyMarkup)
            return
        end

        unsubscribe = true --No longer accept any new messages, we got the file we want
        upgradeLock = true --Disallow any further upgrade operations

        response.chat:sendMessage("Got it, Downloading my successor... 😔",
            nil, nil, nil, replyToMessageID)

        local ok1, tfile = pcall(response.document.getFile, response.document)
        if not ok1 then
            upgradeLock = false
            response.chat:sendMessage("Failed to request file information 😬\n`"..tostring(tfile).."`",
                "Markdown", nil, nil, replyToMessageID)
            return true
        end

        local turl = tfile:getURL()
        local fileSink = ltn12.sink.file(io.open("upgrade.zip", "wb"))

        local ok2, err2 = http.request{
            url = turl,
            sink = fileSink,
            method = "GET"
        }

        if not ok2 then
            upgradeLock = false
            response.chat:sendMessage("Failed to download file 😬\n`"..tostring(err2).."`",
                "Markdown", nil, nil, replyToMessageID)
            return true
        end

        response.chat:sendMessage("Downloaded successfully, goodbye 😒",
            nil, nil, nil, replyToMessageID)
        error("UPGRADE")

        return true
    end
end

--------------------------------[[ /forget_me command ]]--------------------------------

--No longer treat this user as a developer
function dcommands.forget_me(message)
    STATSD:increment("modules.developer.deauthorized")
    isDeveloper[message.from.id] = false
    logger.warn(string.format("%s %s (@%s) [%d] deauthorized him/herself.", message.from.firstName or "?", message.from.lastName or "?", message.from.username or "?", message.from.id))
    message.chat:sendMessage("*I SHALL NO LONGER CALL YOU SIR* 🎉", "Markdown")
end

--Wrap the developer commands and store them in the main commands array
for commandName, commandFunc in pairs(dcommands) do
    commands[commandName] = function(message)
        if not message then return end
        if not isDeveloper[message.from and message.from.id] then
            STATSD:increment("modules.developer.fooled,name="..commandName)
            message.chat:sendMessage("Unknown command `/"..commandName.."`.", "Markdown")
            logger.trace(string.format("%s %s (@%s) [%d] tried to use a developer command (/%s).", message.from.firstName or "?", message.from.lastName or "?", message.from.username or "?", message.from.id, commandName))
            return
        end

        return commandFunc(message)
    end
end

--------------------------------[[ Raw updates handler ]]--------------------------------

--The module's update handler
local function updateHandler() end

return {commands, updateHandler}