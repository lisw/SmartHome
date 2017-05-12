--[[
   Copyright (C) 2008 optivo GmbH

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; version 2 of the License.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
--]]

---	Logging facility.</br>
--
-- A logger consists of a category (to distinct different modules etc.) and an appender which actually
-- writes the message (to console, file etc.)
--
-- <h3>Configuration</h3>
-- A sample configuration file looks like this:<br />
-- <code class="lua">
--      local logger = require("log4lua.logger")<br />
--      local console = require("log4lua.appenders.console")<br />
--      local file = require("log4lua.appenders.file")<br />
--      local config = {}<br />
--      <br />
--      -- ROOT category must be configured.<br />
--      config["ROOT"] = logger.new(console.new(), "ROOT", logger.FATAL)<br />
--      config["foo"] = logger.new(file.new("foo-%s.log", "%Y-%m-%d"), "foo", logger.INFO)<br />
--      config["bar"] = logger.new(file.new("bar.log", nil, "%LEVEL: %MESSAGE\n"), "bar", logger.INFO)<br />
--      <br />
--      -- The config table must be returned.<br />
--      return config
-- </code><br />
--
-- Then you can load this configuration file "by hand" calling <code>loadConfig(fileName)</code> or you
-- can set a default configuration file using the environment variable <code>LOG4LUA_CONFIG_FILE</code>.
--
-- <h3>Patterns</h3>
-- Patterns may contain the following placeholders:
-- <ul>
--     <li>%DATE - Real time</li>
--     <li>%LEVEL</li>
--     <li>%MESSAGE</li>
--     <li>%FILE - the source filename w/o path</li>
--     <li>%LINE - the position in the source file</li>
--     <li>%FUNCTION - the function name</li>
--     <li>%STACKTRACE - the complete stack trace</li>
--     <li>%ERROR - an exception string like the one you get using pcall(...)</li>
-- </ul>
-- <em>Important performance note:</em> Using one of <code>%FILE, %LINE, %FUNCTION, %STACKTRACE</code> implies a quite huge performance
-- hit because <code>debug.traceback()</code> has to be called for every message logged. Note that the default pattern uses these placeholders.
--
-- Default pattern for all appenders is <code><%DATE> <%LEVEL> %MESSAGE at %FILE:%LINE(%METHOD)\n</code>
--
-- @author $Author: peter.romianowski $
-- @release $Date: 2008-09-23 08:20:56 +0200 (Di, 23 Sep 2008) $ $Rev: 90 $
module("log4lua.logger", package.seeall)

-- Class definition
local Logger = {}
Logger.__index = Logger

local _module = Logger

local console = require("log4lua.appenders.console")
local file = require("log4lua.appenders.file")
local utils = require("log4lua.utils")

--- Level constants.
_module.DEBUG = "DEBUG"
--- Level constants.
_module.INFO = "INFO"
--- Level constants.
_module.WARN = "WARN"
--- Level constants.
_module.ERROR = "ERROR"
--- Level constants.
_module.FATAL = "FATAL"
--- Level constants.
_module.OFF = "OFF"

_module.LOG_LEVELS = {
    DEBUG = 1,
    INFO = 2,
    WARN = 3,
    ERROR = 4,
    FATAL = 5,
    OFF = 6
}

-- Default pattern used for all appenders.
_module.DEFAULT_PATTERN = "<%DATE> <%LEVEL> %MESSAGE at %FILE:%LINE(%METHOD)\n"

-- Name of the environment variable that holds the path to the default config file.
local ENV_LOGGING_CONFIG_FILE = "LOG4LUA_CONFIG_FILE"

-- Map containing all configured loggers (key is category).
local _loggers = nil

--- Main method that returns a fully configured logger for the given category.<br />
-- The correct logger is found as follows:
-- <ul>
--    <li>If there is a configured logger with the exact category then use this.</li>
--    <li>Otherwise search for loggers with matching category.
--        Example: If there is a configured logger for category "test" then it is used for category "test.whatever", "testinger" etc.</li>
--    <li>Otherwise use the root category.</li>
-- </ul>
-- @param category the category of the desired logger.
function _module.getLogger(category)
    if (_loggers == nil) then
        -- Load default configuration found in environment variable.
        local configFile = os.getenv(ENV_LOGGING_CONFIG_FILE)
        if (configFile ~= nil) then
            _module.loadConfig(configFile);
        end;
        -- We need at least a root logger.
        if (_loggers == nil) then
            _loggers = {ROOT = Logger.new(console.new(), "ROOT", _module.INFO)};
        end

        assert(_loggers and _loggers.ROOT, "At least a log category 'ROOT' must be specified.")
    end

    local log = nil
    if (category ~= nil) then
        log = _loggers[category]
        if (log == nil) then
            for loggerCategory, logger in pairs(_loggers) do
                if (string.find(category, loggerCategory, 1, true) == 1) then
                    log = logger
                    break
                end
            end
        end
    end
    if (log == nil) then
        log = _loggers["ROOT"]
    end
    assert(log, "Logger cannot be empty. Check your configuration!")
    return log
end

--- Load a configuration file.
-- @param fileName path to a configuration file written in lua. The lua code must return a map (table) with loggers configured for each category.
function _module.loadConfig(fileName)
    local result = loadfile(fileName)

    if (result) then
        _loggers = result()
    end
end


--- Constructor.
-- @param appenders a single function or a table of functions taking a string as parameter that is responsible for writing the log message.
-- @param category the category (== name) of this logger
-- @param level the threshold level. Only messages for equal or higher levels will be logged.
function Logger.new(appenders, category, level)
    local self = {}
    setmetatable(self, Logger)
    assert(appenders ~= nil and (type(appenders) == "function" or type(appenders) == "table"), "Invalid value for appenders.")
    if (type(appenders) == "function") then
        appenders = {appenders}
    end
    for _, appender in ipairs(appenders) do
        assert(type(appender) == "function", "First parameter (the appender) must be a function.")
    end
    assert(category ~= nil, "Category not set.")
    self._appenders = appenders
    self._level = level or _module.INFO
    self._category = category

    return self
end

--- Set the log level threshold.
function Logger:setLevel(level)
    assert(_module.LOG_LEVELS[level] ~= nil, "Unknown log level '" .. level .. "'")
    self._level = level
end

--- Log the given message at the given level.
function Logger:log(level, message, exception)
	assert(_module.LOG_LEVELS[level] ~= nil, "Unknown log level '" .. level .. "'")
    if (_module.LOG_LEVELS[level] >= _module.LOG_LEVELS[self._level] and level ~= _module.OFF) then
        for _, appender in ipairs(self._appenders) do
			appender(self, level, message, exception)
        end
    end
end

--- Test whether the given level is enabled.
-- @return true if messages of the given level will be logged.
function Logger:isLevel(level)
    local levelPos = _module.LOG_LEVELS[level]
    assert(levelPos, "Invalid level '" .. tostring(level) .. "'")
    return levelPos >= _module.LOG_LEVELS[self._level]
end

--- Log message at DEBUG level.
function Logger:debug(message, exception)
    self:log(_module.DEBUG, message, exception)
end

--- Log message at INFO level.
function Logger:info(message, exception)
    self:log(_module.INFO, message, exception)
end

--- Log message at WARN level.
function Logger:warn(message, exception)
    self:log(_module.WARN, message, exception)
end

--- Log message at ERROR level.
function Logger:error(message, exception)
    self:log(_module.ERROR, message, exception)
end

--- Log message at FATAL level.
function Logger:fatal(message, exception)
    self:log(_module.FATAL, message, exception)
end

function Logger:formatMessage(pattern, level, message, exception)
    local result = pattern or _module.DEFAULT_PATTERN
    if (type(message) == "table") then
        message = utils.convertTableToString(message, 5)
    end
    message = string.gsub(tostring(message), "%%", "%%%%")

    -- If the pattern contains any traceback relevant placeholders process them.
    if (
        string.match(result, "%%FILE")
        or string.match(result, "%%LINE")
        or string.match(result, "%%METHOD")
        or string.match(result, "%%STACKTRACE")
    ) then
        -- Take no risk - format the stacktrace using pcall to prevent ugly errors.
        _, result = pcall(Logger._formatStackTrace, self, result)
    end

    result = string.gsub(result, "%%DATE", os.date("%Y/%m/%d %H:%M:%S"));
    result = string.gsub(result, "%%LEVEL", level)
    result = string.gsub(result, "%%MESSAGE", message)
    if exception ~= nil then
        result = string.gsub(result, "%%ERROR", exception)
    end

    return result
end

-- Format stack trace.
function Logger:_formatStackTrace(pattern)
    local result = pattern

    -- Handle stack trace and method.
    local stackTrace = debug.traceback()

    for line in string.gmatch(stackTrace, "[^\n]-%.lua:%d+: in [^\n]+") do
        if not string.match(line, ".-log4lua.-%.lua:%d+:") then
            local _,_,srcFile,srcLine,srcMethod = string.find(line, "%s(.-):(%d+): in (.*)")
            result = string.gsub(result, "%%FILE", srcFile or "n/a")
            result = string.gsub(result, "%%LINE", srcLine or "n/a")
            result = string.gsub(result, "%%METHOD", srcMethod or "n/a")
            result = string.gsub(result, "%%STACKTRACE", stackTrace)
            break
        end
    end

    return result
end

return _module
