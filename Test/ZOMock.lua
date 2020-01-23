--- Mocks the ZO functions for ESO
--- luarocks install luasocket

local updateListener = {}
Dump = require("pl.pretty").dump

GetTimeStamp = function() return os.time(os.date("!*t")) end

EVENT_MANAGER = {}

function d(...)
  for _, v in ipairs(arg) do
    require("pl.pretty").dump(v)
  end
end

function EVENT_MANAGER:RegisterForUpdate(eventHandle, updateDelay, OnUpdate)
  updateListener[eventHandle] = OnUpdate
  OnUpdate()
end

function EVENT_MANAGER:UnregisterForUpdate(eventHandle) 
  updateListener[eventHandle] = nil
end

function EVENT_MANAGER:RegisterForEvent(eventHandle, event, OnCall)
  OnCall(nil, "LibClockTST")
end

function EVENT_MANAGER:UnregisterForEvent(eventHandle, event) end

SLASH_COMMANDS = {}