--Stickers module

local logger = require("utilities.logger")
local ltn12 = require("ltn12")
local http = require("http.compat.socket")
local cqueues = require("cqueues")
local telegram = require("telegram")
local localization = require("utilities.localization")
local lfs = require("lfs")

local workDelay = 3 --Cooldown time (in seconds) between each sticker process.
local workQueueLimit = 10
local workerPerChat = 1
local workQueue = STORAGE.stickers.workQueue
local workChats = STORAGE.stickers.workChats
local workCQUE = cqueues.new()
local terminateWorkers = false
local imagesDirectory = "/run/shm/stickers/"

--- Create the images processing directory.
do
    if lfs.attributes(imagesDirectory, "mode") ~= "directory" then
        assert(lfs.mkdir(imagesDirectory))
    end

    for item in lfs.dir(imagesDirectory) do
        if lfs.attributes(imagesDirectory..item, "mode") == "file" then
            logger.warn("- Images tmp cleanup:", item)
            os.remove(imagesDirectory..item)
        end
    end
end

--- Attempt to download a file.
-- @tparam string url The url of the file to download.
-- @tparam ?string filepath Download into a file.
-- @treturn boolean `true` on success, `false` otherwise.
-- @treturn ?string The downloaded file's content (if not downloading into a file) on success, or the failure reason otherwise.
local function downloadFile(url, filepath)
    local dataTable = {}
    local dataSink = filepath and ltn12.sink.file(io.open(filepath, "wb")) or ltn12.sink.table(dataTable)

    local ok, err = http.request{
        url = url,
        sink = dataSink,
        method = "GET"
    }

    if ok then
        return true, table.concat(dataTable)
    else
        return false, err
    end
end

--- Add the sticker to the user's collections.
-- @tparam Message response The user's message containing the sticker.
-- @tparam Sticker sticker The sticker to clone.
-- @tparam string stickerData The sticker's downloaded data.
-- @treturn boolean `true` when the sticker has been cloned successfully.
-- @treturn string On success, the sticker set name. On failure, the failure reason.
-- @treturn boolean `true` when a new stickers set has been created.
local function processSticker(request)

    local startTime = cqueues.monotime()

    --Send the typing indicator because this can be a lengthy operation.
    telegram.sendChatAction(request.chatID, "typing")

    local messageID = request.messageID
    local chatID = request.chatID
    local userID = request.userID
    local userFirstName = request.userFirstName
    local fileID = request.fileID
    local emoji = request.emoji
    local isPhoto = request.isPhoto
    local photoType = request.photoType
    local isAnimated = request.isAnimated
    local maskPosition = request.maskPosition and telegram.structures.MaskPosition(unpack(request.maskPosition))

    --Get the sticker file object.
    local stickerFile = telegram.getFile(fileID)
    --Get the sticker download url.
    local stickerURL = stickerFile:getURL()
    --Download the sticker's data.
    local ok1, stickerData = downloadFile(stickerURL, isPhoto and string.format("%s%d_%d.%s", imagesDirectory, chatID, messageID, photoType))

    if not ok1 then
        STATSD:increment("modules.stickers.process.failure,stage=download,reason="..tostring(stickerData):gsub(",", ""))
        logger.error("Failure while downloading a sticker, fileID:", fileID, "error:", stickerData)
        telegram.sendMessage(chatID, localization.format(userID, "stickers_clone_failure_download"), nil, nil, nil, messageID)
        return
    end

    if isPhoto then
        local source = string.format("%s%d_%d.%s", imagesDirectory, chatID, messageID, photoType)
        local destination = string.format("%s%d_%d.png", imagesDirectory, chatID, messageID)
        local exitcode = os.execute(string.format("convert %s -resize 512x512 %s", source, destination))
        if exitcode ~= 0 then
            STATSD:increment("modules.stickers.process.failure,stage=convert,reason=exitcode "..tostring(exitcode))
            logger.error("Failure while converting a sticker, exitcode:", tostring(exitcode))
            telegram.sendMessage(chatID, localization.format(userID, "stickers_photo_conversion_failure"), nil, nil, nil, messageID)
            return
        end

        local file = assert(io.open(destination, "rb"))
        stickerData = assert(file:read("*a"))
        file:close()

        os.remove(source)
        os.remove(destination)

        if #stickerData > 512*1024 then
            STATSD:increment("modules.stickers.process.failure,stage=convert,reason=too large")
            logger.error("Sticker too large:", #stickerData/1024)
            telegram.sendMessage(chatID, localization.format(userID, "stickers_photo_too_large", math.ceil(#stickerData/1024)), nil, nil, nil, messageID)
            return
        end
    end

    local maxStickers, pngSticker, tgsSticker
    if isAnimated then
        maxStickers = 50
        tgsSticker = {filename="sticker.tgs", data=stickerData}
    else
        maxStickers = 120
        pngSticker = {filename="sticker.png", data=stickerData}
    end

    local ok2, setName, newSet
    local volume = 1
    while true do
        local name = string.format(DEVELOPERS[userID] and "Developer_%d_%d_by_%s" or "Collection_%d_%d_by_%s", volume, userID, ME.username)
        local ok, stickerSet = pcall(telegram.getStickerSet, name)
        if ok then --Check if the sticker can be added to this set
            if stickerSet.isAnimated == request.isAnimated and #stickerSet.stickers < maxStickers then
                if (stickerSet.containesMasks and maskPosition) or not (stickerSet.containesMasks or maskPosition) then
                    --The sticker can be added to the set.
                    local ok3, err = pcall(telegram.addStickerToSet, userID, name, pngSticker, tgsSticker, emoji or "⚠", maskPosition)
                    if not ok3 then ok2, setName = false, err break end

                    ok2, setName = true, name
                    break
                end
            end
        else --Create a new sticker set
            newSet = true
            local title = localization.format(userID, "stickers_clone_new_pack_name", userFirstName, volume)
            local ok3, err = pcall(telegram.createNewStickerSet, userID, name, title, pngSticker, tgsSticker, emoji or "⚠", not not maskPosition, maskPosition)
            if not ok3 then ok2, setName = false, err break end

            ok2, setName = true, name
            break
        end

        volume = volume + 1
    end

    if ok2 then
        local stickerSet = telegram.getStickerSet(setName)
        telegram.sendMessage(chatID, localization.format(userID, "stickers_clone_success"..(newSet and "_new" or ""), stickerSet.title, setName), "Markdown", nil, nil, messageID)
        local stickerType = isPhoto and "photo" or isAnimated and "animated" or maskPosition and "mask" or "static"
        STATSD:increment("modules.stickers.process.success,type="..stickerType)
    else
        STATSD:increment("modules.stickers.process.failure,stage="..(newSet and "new" or "add")..",reason="..tostring(setName):gsub(",", ""))
        logger.error("Failed to add sticker:", setName)
        telegram.sendMessage(chatID, localization.format(userID, "stickers_clone_failure_add"), nil, nil, nil, messageID)
    end

    local endTime = cqueues.monotime()
    local processingTime = math.floor((endTime - startTime)*1000)
    STATSD:gauge("modules.stickers.process.time,type="..(ok2 and "success" or "failure"), processingTime)
end

--- Summon a new worker for a chat.
-- @tparam number chatID The chat ID to create the worker for.
local function newChatWorker(chatID)
    local sChatID = tostring(chatID)
    workCQUE:wrap(function()
        STATSD:increment("modules.stickers.worker,action=started")

        while workQueue[sChatID] and #workQueue[sChatID] > 0 and not terminateWorkers do
            local request = workQueue[sChatID][#workQueue[sChatID]] --The last one in the queue.
            workQueue[sChatID][#workQueue[sChatID]] = nil --Remove it from the queue.

            local ok, err = pcall(processSticker, request)
            if not ok then
                STATSD:increment("modules.stickers.worker.error")
                logger.critical("Stickers worker failure:", err)
            end

            if workQueue[sChatID] and #workQueue[sChatID] > 0 and not terminateWorkers then
                telegram.sendChatAction(chatID, "typing")
                cqueues.sleep(workDelay)
            end
        end

        if not workQueue[sChatID] or #workQueue[sChatID] == 0 then
            workChats[sChatID] = workChats[sChatID] - 1
            if workChats[sChatID] <= 0 then
                workQueue[sChatID] = nil
                workChats[sChatID] = nil
            end
        end

        STATSD:increment("modules.stickers.worker,action=finished")
    end)
end

--- Resume the terminated chat workers.
local function resumeChatWorkers()
    for chatID, active in pairs(workChats) do
        if active then
            for _=1, tonumber(active) or 1 do
                newChatWorker(tonumber(chatID))
            end
        end
    end
end

--------------------------------[[ Resume chat works since last bot execution ]]--------------------------------

resumeChatWorkers()

--------------------------------[[ Connect workCQUE with the main CQUE ]]--------------------------------

CQUE:wrap(function()
    while not terminateWorkers do
        STATSD:gauge("modules.stickers.worker.active", workCQUE:count())
        assert(workCQUE:step())
        cqueues.sleep()
    end
end)

--------------------------------[[ Exit Handler ]]--------------------------------

EQUE:wrap(function()
    --Save the current work queues
    workQueue()
    workChats()

    terminateWorkers = true
    if workCQUE:count() == 0 then return true end

    logger.loading("Finishing the under-processing stickers queue.")
    for err in workCQUE:errors() do
        logger.error("- Error while finishing workCQUE:", err)
    end
    logger.subloading("- Finished the under-processing stickers queue.")
end)

--------------------------------[[ Commands ]]--------------------------------

--The module's commands array
local commands = {}

--------------------------------[[ /packs command ]]--------------------------------

function commands.packs(message)
    if not message then return "Lists your collections packs 📦" end

    pcall(message.chat.sendChatAction, message.chat, "typing")

    local lastVolume = 0
    local function nextPackLink()
        lastVolume = lastVolume + 1
        local name = string.format(DEVELOPERS[message.from.id] and "Developer_%d_%d_by_%s" or "Collection_%d_%d_by_%s", lastVolume, message.from.id, ME.username)

        local ok, stickerSet = pcall(telegram.getStickerSet, name)
        if not ok then return end
        return string.format("[%s](https://t.me/addstickers/%s)", stickerSet.title, name)
    end

    local links = {}

    for link in nextPackLink do
        table.insert(links, link)
    end

    if #links == 0 then
        links = localization.format(message.from.id, "stickers_list_empty")
    else
        links = localization.format(message.from.id, "stickers_list_success", #links, table.concat(links, "\n"))
    end

    message.chat:sendMessage(links, "Markdown", true)
end

--------------------------------[[ Raw updates handler ]]--------------------------------

local function stickerHandler(update)
    local response = update.message
    if not response then return end --Filter non-message updates

    if INTERACTIVES[response.chat.id] then return end --Filter messages on chats with an active interactive commands.

    local chatID = tostring(response.chat.id)
    workQueue[chatID] = workQueue[chatID] or {}

    local request = {}

    if not response.sticker and not response.photo then --Filter non sticker and non photo messages
        if not response.text or response.text:sub(1,1) == "/" then return end
        STATSD:increment("modules.stickers.handler,action=invalid")
        response.chat:sendMessage(localization.format(response.from.id, "stickers_handler_invalid"), nil, nil, nil, response.messageID)
        if workChats[chatID] then response:sendChatAction("typing") end
        return
    end

    if #workQueue[chatID] >= workQueueLimit then
        STATSD:increment("modules.stickers.handler,action=full")
        response.chat:sendMessage(localization.format(response.from.id, "stickers_handler_queue_full"), nil, nil, nil, response.messageID)
        response.chat:sendChatAction("typing")
        return
    end

    if response.sticker and response.sticker.emoji then
        request = {
            messageID = response.messageID,
            chatID = response.chat.id,
            userID = response.from.id,
            userFirstName = response.from.firstName,
            fileID = response.sticker.fileID,
            emoji = response.sticker.emoji,
            isAnimated = response.sticker.isAnimated
        }

        if response.sticker.maskPosition then
            request.maskPosition = {
                response.sticker.maskPosition.point,
                response.sticker.maskPosition.xShift,
                response.sticker.maskPosition.yShift,
                response.sticker.maskPosition.scale
            }
        end
    elseif response.sticker then
        request = {
            messageID = response.messageID,
            chatID = response.chat.id,
            userID = response.from.id,
            userFirstName = response.from.firstName,
            fileID = response.sticker.fileID,
            emoji = "🖼",
            isAnimated = false,
            isPhoto = true,
            photoType = "webp"
        }
    elseif response.photo then
        local bestMatch = response.photo[1]
        local bestMax = math.max(bestMatch.width, bestMatch.height)
        for _, photo in pairs(response.photo) do
            local max = math.max(photo.width, photo.height)
            if (bestMax < 512 and max > bestMax) or (max >= 512 and max < bestMax) then
                bestMatch = photo
            end
        end

        request = {
            messageID = response.messageID,
            chatID = response.chat.id,
            userID = response.from.id,
            userFirstName = response.from.firstName,
            fileID = bestMatch.fileID,
            emoji = "🖼",
            isAnimated = false,
            isPhoto = true,
            photoType = "jpg"
        }
    end

    --Add the sticker to the work queue
    table.insert(workQueue[chatID], 1, request)

    --This is a new queue
    if not workChats[chatID] then
        workChats[chatID] = 1
        newChatWorker(response.chat.id)
    elseif workChats[chatID] < workerPerChat then
        workChats[chatID] = workChats[chatID] + 1
        cqueues.sleep(2)
        newChatWorker(response.chat.id)
    end

    STATSD:increment("modules.stickers.handler,action=success")
end

--The module's update handler
local function updateHandler(update)
    local ok, err = pcall(stickerHandler, update)
    if not ok then logger.critical("Failed to execute stickers handler:", err) end
end

return {commands, updateHandler}