local ok, bit = pcall(require, "bit")
bit=nil;

local bxor = bit and bit.bxor or
function(a,b)
  local r = 0
  for i = 0, 31 do
    local a0 = a % 2
    local b0 = b % 2
    if a0 ~= b0 then
      r = r + 2^i
    end;
    a = (a - a0) / 2
    b = (b - b0) / 2
  end
  return r
end

local bxor16 = bit and bit.bxor or function(a,b)
  local r = 0
  for i = 0, 15 do
    local a0 = a % 2
    local b0 = b % 2
    if a0 ~= b0 then
      r = r + 2^i
    end;
    a = (a - a0) / 2
    b = (b - b0) / 2
  end
  return r
end

-- CRC-32-IEEE 802.3 (V.42)
local POLY = 0xEDB88320

local crc_table = {};
for i=0,255 do
  local crc = i;
  for j=1,8 do
    local b = crc % 2;
    crc = (crc - b) / 2;
    if b == 1 then crc = bxor(crc, POLY) end;
  end
  crc_table[i] = crc;
end;

local function crc32(s, crc)
  crc = 0xffffffff - (crc or 0)
  for i=1,#s do
    local lo = crc % 256;
    local hi = (crc - lo) / 256;
    crc = bxor(crc_table[bxor(lo, s:byte(i))], hi);
  end
  return 0xffffffff - crc
end

-- CRC-16
local POLY = 0xA001

local crc_table16 = {};
for i=0,255 do
  local crc = i;
  for j=1,8 do
    local b = crc % 2;
    crc = (crc - b) / 2;
    if b == 1 then crc = bxor16(crc, POLY) end;
  end
  crc_table16[i] = crc;
end;

local function crc16(s, crc)
  crc = 0xffff - (crc or 0)
  for i=1,#s do
    local lo = crc % 256;
    local hi = (crc - lo) / 256;
    crc = bxor16(crc_table16[bxor16(lo, s:byte(i))], hi);
  end
  return crc
end

return {crc32=crc32; crc16=crc16}
