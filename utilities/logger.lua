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

---Output a title log.
function logger.title(...)
    io.write(titleColor) print(...) io.write(resetColor)
end

---Output a loading log.
function logger.loading(...)
    io.write(loadingColor) print(...) io.write(resetColor)
end

---Output a subloading log.
function logger.subloading(...)
    io.write(subloadingColor) print(...) io.write(resetColor)
end

---Output a colored log.
function logger.colored(...)
    print(color(table.concat({...}, " ")))
end

---Request input from the user.
function logger.prompt(...)
    io.write(promptColor) io.write(color.noReset(table.concat({...}, " "))) io.write(resetColor)
    return io.read("*l")
end

function logger.critical(...)
    io.write(criticalColor) io.write(table.concat({...}, " ")) print(resetColor)
end

function logger.error(...)
    io.write(errorColor) print(...) io.write(resetColor)
end

function logger.warn(...)
    io.write(warnColor) print(...) io.write(resetColor)
end

function logger.info(...)
    io.write(infoColor) print(...) io.write(resetColor)
end

function logger.debug(...)
    io.write(debugColor) print(...) io.write(resetColor)
end

function logger.trace(...)
    io.write(traceColor) print(...) io.write(resetColor)
end

return logger