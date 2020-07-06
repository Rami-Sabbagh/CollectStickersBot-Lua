--Basic module

local logger = require("utilities.logger")
local telegram = require("telegram")
local localization = require("utilities.localization")
local supportedLanguages = localization.supportedLanguages()

local InlineKeyboardButton = telegram.structures.InlineKeyboardButton
local InlineKeyboardMarkup = telegram.structures.InlineKeyboardMarkup

local function promptForLanguage(chat, from)
    local keyboard = {}
    for id, title in pairs(supportedLanguages) do
        local button = InlineKeyboardButton(title)
        button.callbackData = "set_language:"..id
        table.insert(keyboard, {button})
    end
    local markup = InlineKeyboardMarkup(keyboard)
    chat:sendMessage(localization.formatLanguage(from.languageCode, "language_select"), nil, nil, nil, nil, markup)
end

local function sendHelp(chat, from)
    chat:sendMessage(localization.format(from.id, "basic_help"))
end

--The module's commands array
local commands = {}

--------------------------------[[ /start command ]]--------------------------------

function commands.start(message)
    if not message then return end
    promptForLanguage(message.chat, message.from)
end

--------------------------------[[ /language command ]]--------------------------------

function commands.language(message)
    if not message then return "Select the language of the bot 🌐" end
    promptForLanguage(message.chat, message.from)
end

--------------------------------[[ /help command ]]--------------------------------

function commands.help(message)
    if not message then return "What can this bot do? 🤔" end
    sendHelp(message.chat, message.from)
end

--------------------------------[[ /ping command ]]--------------------------------

function commands.ping(message)
    if not message then return end
    message.chat:sendMessage("Pong 🏓")
end

--------------------------------[[ Raw updates handler ]]--------------------------------

local function callbackQueryHandler(query)
    local data = query.data

    if data and data:match("^set_language:") then
        local lang = data:gsub("^set_language:", "")
        localization.setLanguage(query.from.id, lang)
        STATSD:increment("language.selected,lang="..tostring(lang))
        if query.message then
            query.message:deleteMessage()
            query:answerCallbackQuery(localization.format(query.from.id, "language_selected"))
            sendHelp(query.message.chat, query.from)
        else
            query:answerCallbackQuery(localization.format(query.from.id, "language_selected"))
        end
    end
end

--The module's update handler
local function updateHandler(update)
    if update.callbackQuery then
        local ok, err = pcall(callbackQueryHandler, update.callbackQuery)
        if not ok then logger.critical("Failed to execute the callback query handler:", err) end
    end
end

return {commands, updateHandler}