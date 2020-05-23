--Spy module

local logger = require("utilities.logger")
local users = STORAGE.spy.users

--The module's commands array
local commands = {}

--------------------------------[[ Raw updates handler ]]--------------------------------

--The module's update handler
local function updateHandler(update)
    if update.message and update.message.from then
        local user = update.message.from
        if not users[tostring(user.id)] then
            logger.info("We got a new user:", user.id, user.firstName)
            users[tostring(user.id)] = {
                firstName = user.firstName,
                lastName = user.lastName,
                username = user.username,
                languageCode = user.languageCode
            }
            users()
        end
    end
end

return {commands, updateHandler}