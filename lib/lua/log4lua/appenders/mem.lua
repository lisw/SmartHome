local _module = {};
local log = require("log4lua.logger");

-- @param levelThreshold a level constant(logger.DEBUG, logger.WARN etc.) If given then
--   only messages with a higher or equal level are sent.
function _module.new(levelThreshold, pattern)
    log.fifo = {};
    local last_msg;
    return
        function(logger, level, message, exception)
            if (not levelThreshold or log.LOG_LEVELS[level] >= log.LOG_LEVELS[levelThreshold]) then
                local msg = log:formatMessage(pattern, level, message, exception);
                if msg == last_msg then return end;
                last_msg = msg;
                if #log.fifo >= 20 then
                    table.remove(log.fifo, 1);
                end;
                table.insert(log.fifo, msg);
            end;
        end;
end;

return _module;
