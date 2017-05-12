local time = require("time");
local gettime = time.time;
  
local copas = {};

-- indicator for the loop running
copas.running = false;

local _sleeping = {
    times = {},  -- list with wake-up times
    cos = {},    -- list with coroutines, index matches the 'times' list
    lethargy = {}, -- list of coroutines sleeping without a wakeup time

    push = function(self, sleeptime, co)
        if not co then return end
        if sleeptime<0 then
            --sleep until explicit wakeup through copas.wakeup
            self.lethargy[co] = true
            return
        else
            sleeptime = gettime() + sleeptime
        end
        local t, c = self.times, self.cos
        local i, cou = 1, #t
        --TODO: do a binary search
        while i<=cou and t[i]<=sleeptime do i=i+1 end
        table.insert(t, i, sleeptime)
        table.insert(c, i, co)
    end,
    -- find the thread that should wake up to the time
    pop = function(self)
        local t, c = self.times, self.cos
        if #t==0 or gettime()<t[1] then return end
        table.remove(t, 1)
        return table.remove(c, 1)
    end,
    wakeup = function(self, co)
        local let = self.lethargy
        if let[co] then
            self:push(0, co)
            let[co] = nil
        else
            let = self.cos
            for i=1,#let do
                if let[i]==co then
                    table.remove(let, i)
                    table.remove(self.times, i)
                    self:push(0, co)
                    return
                end
            end
        end
    end
} --_sleeping

-------------------------------------------------------------------------------
-- Thread handling
-------------------------------------------------------------------------------

local function _doTick (co, ...)
  if not co then return end

  local ok, res, new_q = coroutine.resume(co, ...)

  if not ok then
    print(res)
  elseif res and new_q then
    new_q:push(res, co)
  end;
end

-------------------------------------------------------------------------------
-- Adds an new coroutine thread to Copas dispatcher
-------------------------------------------------------------------------------
function copas.addthread(thread, ...)
  if type(thread) ~= "thread" then
    thread = coroutine.create(thread)
  end
  _doTick(thread, ...)
  return thread
end

-- yields the current coroutine and wakes it after 'sleeptime' seconds.
-- If sleeptime<0 then it sleeps until explicitly woken up using 'wakeup'
function copas.sleep(sleeptime)
    coroutine.yield(sleeptime or 0, _sleeping)
end

-- Wakes up a sleeping coroutine 'co'.
function copas.wakeup(co)
    _sleeping:wakeup(co)
end

-------------------------------------------------------------------------------
-- Dispatcher loop step.
-------------------------------------------------------------------------------
function copas.step(timeout)
  while true do
    local co = _sleeping:pop(gettime());
    if not co then break end;
    _doTick(co);
  end;
end

-------------------------------------------------------------------------------
-- Check whether there is something to do.
-- returns false if there are no tasks scheduled
-- (which means Copas is in an empty spin)
-------------------------------------------------------------------------------
function copas.finished()
  return not _sleeping.times[1]
end

-------------------------------------------------------------------------------
-- Dispatcher endless loop.
-- Listen to client requests and handles them forever
-------------------------------------------------------------------------------
function copas.loop(timeout)
  copas.running = true
  while not copas.finished() do copas.step(timeout) end
  copas.running = false
end

-------------------------------------------------------------------------------
-- Reinitialize copas
-- clear all threads, added by Sherwin lee(lisw@guet.cn) 2014-06-22
-------------------------------------------------------------------------------
function copas.init()
  _sleeping.times = {};
  _sleeping.cos = {};
  _sleeping.lethargy = {};
end;

return copas
