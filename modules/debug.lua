--Debug module

local logger = require("utilities.logger")

--The module's commands array
local commands = {}

local lastForwardedMessage
local lastContact

--------------------------------[[ /debug command ]]--------------------------------

function commands.debug(message)
    if not message then return end

    local content = {}

    table.insert(content, string.format("Chat ID: `%d`", message.chat.id))
    if message.from then table.insert(content, string.format("Message from User ID: `%s`", message.from.id)) end
    if message.replyToMessage then table.insert(content, string.format("Reply to Message ID: `%d`", message.replyToMessage.messageID)) end
    if message.replyToMessage and message.replyToMessage.from then
        table.insert(content, string.format("Reply to a message from User ID: `%s`", message.replyToMessage.from.id))
    end
    if lastContact then
        table.insert(content, string.format("Contact phone number: `%s`", lastContact.phoneNumber))
        table.insert(content, string.format("Contact first name: `%s`", lastContact.firstName))
        if lastContact.lastName then table.insert(content, string.format("Contact last name: `%s`", lastContact.lastName)) end
        if lastContact.userID then table.insert(content, string.format("Contact User ID: `%s`", lastContact.userID)) end
        if lastContact.vcard then table.insert(content, string.format("Contact vcard size: `%d`", #lastContact.vcard)) end
    end
    if lastForwardedMessage then
        if lastForwardedMessage.forwardFrom then table.insert(content, string.format("Last forwarded message was from user ID: `%d`", lastForwardedMessage.forwardFrom.id)) end
        if lastForwardedMessage.forwardFromChat then table.insert(content, string.format("Last forwarded meassed was from chat ID: `%d`", lastForwardedMessage.forwardFromChat.id)) end
        if lastForwardedMessage.forwardFromMessageID then table.insert(content, string.format("Last forwarded message was from message ID: `%d`", lastForwardedMessage.forwardFromMessageID)) end
    end

    logger.debug("/debug had the following output")
    for _, line in ipairs(content) do
        logger.debug("- "..line)
    end

    content = table.concat(content, "\n")

    message.chat:sendMessage(content, "Markdown")
end

--------------------------------[[ Raw updates handler ]]--------------------------------

--The module's update handler
local function updateHandler(update)
    if update.message then
        local message = update.message
        if message.forwardFrom or message.forwardFromChat or message.forwardFromMessageID then
            lastForwardedMessage = message
        end
        if message.contact then
            lastContact = message.contact
        end
    end
end

return {commands, updateHandler}