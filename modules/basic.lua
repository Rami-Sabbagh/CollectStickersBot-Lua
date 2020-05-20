--Basic module

--The module's commands array
local commands = {}

--------------------------------[[ /ping command ]]--------------------------------

function commands.ping(message)
    if not message then return end
    message.chat:sendMessage("Pong 🏓")
end

--------------------------------[[ Raw updates handler ]]--------------------------------

--The module's update handler
local function updateHandler() end

return {commands, updateHandler}