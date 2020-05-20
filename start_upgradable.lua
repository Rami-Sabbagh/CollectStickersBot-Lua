--A Lua script for processing bot upgrades
while true do
    os.remove("error.txt")
    os.execute("luajit start_bot.lua")

    local errorFile = io.open("error.txt", "rb")
    if not errorFile then break end

    local errorString = errorFile:read("*a")
    errorFile:close()
    if not errorString then break end

    if errorString:sub(-10,-1) == ": SHUTDOWN" then
        os.remove("error.txt")
        break
    elseif errorString:sub(-9,-1) == ": UPGRADE" then
        print ("Upgrading myself...")
        local logfile = assert(io.open("upgrade-log.txt", "wb"))

        local unzip = io.popen("unzip -o upgrade.zip", "r")
        assert(logfile:write(assert(unzip:read("*a"))))
        unzip:close()

        assert(logfile:write("\n"))

        local rm = assert(io.popen("rm upgrade.zip"))
        assert(logfile:write(assert(rm:read("*a"))))
        rm:close()

        logfile:close()

        os.remove("error.txt")
    elseif errorString:sub(-9,-1) == ": RESTART" then
        os.remove("error.txt")
    else
        --The bot has crashed.
        break
    end
end