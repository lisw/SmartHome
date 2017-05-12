local ffi=require"ffi";
ffi.cdef[[
int  UartConfig(const char *devName, int nBaudrate,
    int nDataBits, int cParity, int nStopBits);
int  UartCheck(int ch);
int  UartGetC(int ch);
int  UartGetS(int ch, void *pBuffer, int nLen);
int  UartGetB(int ch, void *pBuffer, int nLength);
int  UartPutB(int ch, const void *pBuffer, int nLength);
void UartPutS(int ch, const char *pBuffer);
void UartClose(int ch);
void UartSet485(int ch, int bEnable);
int  UartGetStatus(int ch);
void UartSetStatus(int ch, int status);
int  UartGetMctrl(int hComm);
void UartSetMctrl(int hComm, int mctrl);
unsigned msticks(void);
void msleep(int ms);
]]

local uart=ffi.load("uart");

local buffer = ffi.new("char[1024]");
local function get(o)
  local c = uart.UartCheck(o.handle);
  if c == 0 then
    return;
  end;
  local n = uart.UartGetB(o.handle, buffer, 1024);
  return ffi.string(buffer, n);
end;

local function getline(o)
  local buf=o.linebuf;
  while uart.UartCheck(o.handle) ~= 0 do
    local n = uart.UartGetB(o.handle, buffer, 1024);
    buf = buf .. ffi.string(buffer, n);
  end;

  local line;
  local pos=buf:find("\n",1,true);
  if pos then
    line = buf:sub(1, pos-1);
    buf = buf:sub(pos+1);
  end;
  o.linebuf = buf;
  return line;
end;

local function put(o, data)
  return uart.UartPutB(o.handle, data, #data);
end;

local function set485(o, enable)
  uart.UartSet485(o.handle, enable or 0);
end;

local function close(o)
  if o.handle and o.handle ~= 0 then
    uart.UartClose(o.handle);
  end;
end;

local function getStatus(o)
  return uart.UartGetStatus(o.handle);
end;

local function setStatus(o, status)
  uart.UartSetStatus(o.handle, status);
end;

local function getMctrl(o)
  return uart.UartGetMctrl(o.handle);
end;

local function setMctrl(o, mctrl)
  uart.UartSetMctrl(o.handle, mctrl);
end;

-- meta table for session
local mt = {
  __index = {get=get, put=put, getline=getline, close=close,
    getStatus=getStatus, setStatus=setStatus, set485=set485, 
    getMctrl=getMctrl, setMctrl=setMctrl};
  __gc = close
};

local function new(dev, baud, databits, parity, stopbits)
  local o = setmetatable({}, mt);
  o.handle = uart.UartConfig(dev, baud, databits or 8, parity or 0, stopbits or 1);
  if o.handle ~= 0 then
    o.linebuf="";
    return o;
  end;
end;

return {new=new, open=new, msticks=uart.msticks, msleep=uart.msleep};
