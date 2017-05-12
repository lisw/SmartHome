local time = require("time");

local timers = {};
local mt = {};

local function new(period, loop, func, params)
    if type(period) ~= "number" then
        local ticks = time.time();
        return function(timeout)
            local now = time.time();
            if now - ticks < (tonumber(timeout) or 1) then return; end;
            ticks = now;
            return true;
        end;
    end;

    if period <= 0 or #timers > 100 then return; end;
    if type(loop) == "function" then func,params,loop = loop,func; end;
    local timer = {period=period, loop=loop, func=func, time=time.time()};
    table.insert(timers, timer);
    return setmetatable(timer, {__index=mt});
end;

local function remove(timer)
    for i,t in ipairs(timers) do
        if t == timer then
            table.remove(timers, i);
            return;
        end;
    end;
end;

local function start(timer, loop)
    if type(timer) ~= "table" then return; end;
    timer.time = time.time();
    timer.loop = loop;
    timer.done = nil;
end;

local function test(timer)
    if type(timer) ~= "table" then return; end;
    if timer.done or (time.time()-timer.time) < timer.period then return; end;
    timer.loop = (tonumber(timer.loop) or 1) - 1;
    timer.time = timer.time + timer.period;
    timer.done = timer.loop == 0;
    if type(timer.func) == "function" then
        timer.func(timer.params);
    end;
    return true;
end;

local function step(timeout)
    timeout = tonumber(timeout) or 0;
    local ticks = time.time();
    while true do
        for k,v in ipairs(timers) do
            test(v);
        end;
        if time.time() - ticks >= timeout then break; end;
        time.sleep(0.0001);
    end;
end;

timers.new = new;
timers.step = step;

mt.test = test;
mt.start = start;
mt.free = remove;

return timers;
