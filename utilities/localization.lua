--- Localization system
local localization = {}

--The ftcsv library for parsing the localization.csv file.
local ftcsv = require("ftcsv")

--The parsed ftcsv localization file.
local rows, headers = ftcsv.parse("localization.csv", ",")

---The localization data, the first index is the language id, the second index is the field id, and the value is the text for that language.
local data = {}

--Restructure the localization data parsed from localization.csv into the data array.
do
    --Create the languages tables
    for _, language in pairs(headers) do
        if language then
            data[language] = {}
        end
    end

    --Set the language fields
    for _, row in pairs(rows) do
        for k, value in pairs(row) do
            data[k][row.debug] = value
        end
    end
end

--The language configuration for each user
local users = STORAGE.core.localization

--- Get the formatted message to send to the user.
-- @tparam number|string userID The identifier of the user.
-- @tparam string locID The id of the field you want.
-- @tparam any ... The arguments to pass to string.format.
-- @treturn string The formatted message.
function localization.format(userID, locID, ...)
    local lang = localization.getLanguage(userID)

    lang = data[lang]
    if not lang then return locID end --The language configured doesn't exist.

    local text = lang[locID]
    if not text or text == "" then return locID end --The field doesn't exist for this language

    return string.format(text, ...)
end

--- Get the formatted message to send to the user.
-- @tparam string lang The identifier of the language.
-- @tparam string locID The id of the field you want.
-- @tparam any ... The arguments to pass to string.format.
-- @treturn string The formatted message.
function localization.formatLanguage(lang, locID, ...)
    lang = data[lang] and lang or "en"

    lang = data[lang]
    if not lang then return locID:gsub("_", ".") end --The language configured doesn't exist.

    local text = lang[locID]
    if not text or text == "" then return locID:gsub("_", ".") end --The field doesn't exist for this language

    return string.format(text, ...)
end

--- Get the configured language for a user.
-- @tparam number|string userID The identifier of the user.
-- @treturn string The language configured for the user.
function localization.getLanguage(userID)
    if not users[tostring(userID)] then localization.setLanguage(userID, "en") end
    return users[tostring(userID)]
end

--- Set the configured language for a user.
-- @tparam number|string userID The identifier of the user.
-- @tparam string language The language ID to set for the user.
function localization.setLanguage(userID, language)
    users[tostring(userID)] = language
    users()
end

--- Get a list of the supported languages.
-- @treturn {string} Table of language ids, the key is the language id, the value is the language title.
function localization.supportedLanguages()
    local supported = {}
    for _, v in ipairs(headers) do
        if v and v ~= "debug" then
            supported[v] = data[v].language_title or v
        end
    end
    return supported
end

return localization