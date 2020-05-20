--Stickers module

local logger = require("utilities.logger")
local ltn12 = require("ltn12")
local http = require("http.compat.socket")
local telegram = require("telegram")

--- Add the sticker to the user's collections.
-- @tparam Message response The user's message containing the sticker.
-- @tparam Sticker sticker The sticker to clone.
-- @tparam string stickerData The sticker's downloaded data.
-- @treturn boolean `true` when the sticker has been cloned successfully.
-- @treturn string On success, the sticker set name. On failure, the failure reason.
-- @treturn boolean `true` when a new stickers set has been created.
local function addSticker(response, sticker, stickerData)
    local maxStickers, pngSticker, tgsSticker
    if sticker.isAnimated then
        maxStickers = 50
        tgsSticker = {filename="sticker.tgs", data=stickerData}
    else
        maxStickers = 120
        pngSticker = {filename="sticker.png", data=stickerData}
    end

    local volume = 1
    while true do
        local name = string.format("Collection_%d_%d_by_%s", volume, response.from.id, ME.username)
        local ok, stickerSet = pcall(telegram.getStickerSet, name)
        if ok then --Check if the sticker can be added to this set
            if stickerSet.isAnimated == sticker.isAnimated and #stickerSet.stickers < maxStickers then
                if (stickerSet.containesMasks and sticker.maskPosition) or not (stickerSet.containesMasks or sticker.maskPosition) then
                    --The sticker can be added to the set.
                    local ok2, err = pcall(telegram.addStickerToSet, response.from.id, name, pngSticker, tgsSticker, sticker.emoji or "⚠", sticker.maskPosition)
                    if not ok2 then return false, err end

                    return true, name
                end
            end
        else --Create a new sticker set
            local title = string.format("%s's collection vol.%d", response.from.firstName, volume)
            local ok2, err = pcall(telegram.createNewStickerSet, response.from.id, name, title, pngSticker, tgsSticker, sticker.emoji or "⚠", not not sticker.maskPosition, sticker.maskPosition)
            if not ok2 then return false, err end
            return true, name, true
        end

        volume = volume + 1
    end
end

local function sendHelp(chat)
    chat:sendMessage(table.concat({
        "I can help you clone stickers into your own collection packs",
        "",
        "Just send me the sticker and I'll take care of creating the stickers pack and reuploading the sticker.",
        "",
        "Then you can manage the stickers packs using the @Stickers bot."
    }, "\n"))
end

--The module's commands array
local commands = {}

--------------------------------[[ /start command ]]--------------------------------

function commands.start(message)
    if not message then return end
    sendHelp(message.chat)
end

--------------------------------[[ /help command ]]--------------------------------

function commands.help(message)
    if not message then return "What can this bot do?" end
    sendHelp(message.chat)
end

--------------------------------[[ Raw updates handler ]]--------------------------------

local function stickerHandler(update)
    local response = update.message
    if not response then return end --Filter non message updates

    if INTERACTIVES[response.chat.id] then return end --Filter messages on chats with an active interactive commands.

    local replyToMessageID = response.messageID

    if not response.sticker then
        if not response.text or response.text:sub(1,1) == "/" then return end
        response.chat:sendMessage("Please send the sticker you want to add into your collections\nSend /help for help", nil, nil, nil, replyToMessageID)
        return
    end

    local sticker = response.sticker

    response.chat:sendChatAction("typing")

    local stickerFile = sticker:getFile()
    local stickerURL = stickerFile:getURL(CONFIG.token)

    local stickerData = {}
    local stickerSink = ltn12.sink.table(stickerData)

    local ok, err = http.request{
        url = stickerURL,
        sink = stickerSink,
        method = "GET"
    }

    if not ok then
        logger.error("Failure while downloading a sticker, fileID:", sticker.fileID, "error:", err)
        response.chat:sendMessage("Error while adding the sticker, please re-send the sticker to try again", nil, nil, nil, replyToMessageID)
        return
    end

    stickerData = table.concat(stickerData)

    local ok2, setName, newSet = addSticker(response, sticker, stickerData)
    if ok2 then
        local stickerSet = telegram.getStickerSet(setName)
        response.chat:sendMessage("Added into ["..stickerSet.title.."](https://t.me/addstickers/"..setName..") "..(newSet and "**(New)** " or "").."successfully ✅\nThe sticker will take a while to show in the pack.", "Markdown", nil, nil, replyToMessageID)
        --response.chat:sendSticker(stickerSet.stickers[#stickerSet.stickers].fileID)
    else
        logger.error("Failed to add sticker:", setName)
        response.chat:sendMessage("Failed to add the sticker, please re-send the sticker to try again", nil, nil, nil, replyToMessageID)
    end
end

--The module's update handler
local function updateHandler(update)
    local ok, err = pcall(stickerHandler, update)
    if not ok then logger.error("Failed to execute stickers handler:", err) end
end

return {commands, updateHandler}