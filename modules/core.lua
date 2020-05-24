--- Core module, contains essential core commands for the bot.

local localization = require("utilities.localization")

--The module's commands array
local commands = {}

--------------------------------[[ /cancel command ]]--------------------------------

function commands.cancel(message)
    if not message then return end
    return function(_, _, previous)
        if not previous then
            message.chat:sendMessage(localization.format(message.from.id, "core_cancel_no_active_command"))
        end

        return true --Unsubscribe instantly
    end
end

--------------------------------[[ Raw updates handler ]]--------------------------------

--The module's update handler
local function updateHandler() end

return {commands, updateHandler}