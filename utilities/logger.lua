--- A simple logging module.
-- @moduler logger
local logger = {}

--[[
critical - A critical runtime error.
error - Other runtime errors or unexpected conditions. Expect these to be immediately visible on a status console.
warn - Use of deprecated APIs, poor use of API, 'almost' errors, other runtime situations that are undesirable or unexpected, but not necessarily "wrong". Expect these to be immediately visible on a status console.
info - Interesting runtime events (startup/shutdown). Expect these to be immediately visible on a console, so be conservative and keep to a minimum.
debug - detailed information on the flow through the system. Expect these to be written to logs only.
trace - more detailed information. Expect these to be written to logs only.
]]

local color = require("ansicolors")

local titleColor = color.noReset("%{yellow}")
local loadingColor = color.noReset("%{bright blue}")
local subloadingColor = color.noReset("%{bright cyan}")
local promptColor = color.noReset("%{blink bright yellow}")
local criticalColor = color.noReset("%{dim black redbg}")
local errorColor = color.noReset("%{blink bright red}")
local warnColor = color.noReset("%{yellow}")
local infoColor = color.noReset("%{green}")
local debugColor = color.noReset("%{bright magenta}")
local traceColor = color.noReset("%{magenta}")
local resetColor = color.noReset("%{reset}")

local lfs = require("lfs")

if lfs.attributes("logs", "mode") ~= "directory" then
    assert(lfs.mkdir("logs"))
end

logger.logFilename = os.date("%Y%m%d_%H%M%S", os.time())..".txt"
logger.logPath = "logs/" .. logger.logFilename
logger.logFile = assert(io.open(logger.logPath ,"wb"))

---Open a new log file
function logger.newLogFile()
    logger.logFile:close()
    logger.logFilename = os.date("%Y%m%d_%H%M%S", os.time())..".txt"
    logger.logPath = "logs/" .. logger.logFilename
    logger.logFile = assert(io.open(logger.logPath ,"wb"))
end

---Write into the log file.
function logger.write(level, ...)
    if io.type(logger.logFile) ~= "file" then return end
    local content = {...}
    for k,v in pairs(content) do content[k] = tostring(v) end
    content = table.concat(content, " ")

    local ok, err = logger.logFile:write(string.format("[%s] <%s>: %s\n", os.date("%Y/%m/%d %H:%M:%S", os.time()), string.upper(level), content))
    if not ok then print(color("%{blink bright red}Failed to write into log file:"), err) end
end

---Output a title log.
function logger.title(...)
    logger.write("title", ...)
    io.write(titleColor) print(...) io.write(resetColor)
end

---Output a loading log.
function logger.loading(...)
    logger.write("loading", ...)
    io.write(loadingColor) print(...) io.write(resetColor)
end

---Output a subloading log.
function logger.subloading(...)
    logger.write("subloading", ...)
    io.write(subloadingColor) print(...) io.write(resetColor)
end

---Output a colored log.
function logger.colored(...)
    logger.write("colored", ...)
    print(color(table.concat({...}, " ")))
end

---Request input from the user.
function logger.prompt(...)
    logger.write("prompt", ...)
    io.write(promptColor) io.write(color.noReset(table.concat({...}, " "))) io.write(resetColor)
    return io.read("*l")
end

function logger.critical(...)
    logger.write("critical", ...)
    io.write(criticalColor) io.write(table.concat({...}, " ")) print(resetColor)
end

function logger.error(...)
    logger.write("error", ...)
    io.write(errorColor) print(...) io.write(resetColor)
end

function logger.warn(...)
    logger.write("warn", ...)
    io.write(warnColor) print(...) io.write(resetColor)
end

function logger.info(...)
    logger.write("info", ...)
    io.write(infoColor) print(...) io.write(resetColor)
end

function logger.debug(...)
    logger.write("debug", ...)
    io.write(debugColor) print(...) io.write(resetColor)
end

function logger.trace(...)
    logger.write("trace", ...)
    io.write(traceColor) print(...) io.write(resetColor)
end

return logger