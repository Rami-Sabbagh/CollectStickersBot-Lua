--Basic module

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

--------------------------------[[ /ping command ]]--------------------------------

function commands.ping(message)
    if not message then return end
    message.chat:sendMessage("Pong 🏓")
end

--------------------------------[[ Raw updates handler ]]--------------------------------

--The module's update handler
local function updateHandler() end

return {commands, updateHandler}