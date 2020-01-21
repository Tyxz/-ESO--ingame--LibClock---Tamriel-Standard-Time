--- Mocks the ZO functions for ESO
--- luarocks install luasocket

local updateListener = {}
Dump = require("pl.pretty").dump
Sleep = require("socket").sleep

local Update = function(n)
  for i = 1, n do
    Sleep(1)
    for _, v in pairs(updateListener) do
      v()
    end
  end
end


GetTimeStamp = function() return os.time(os.date("!*t")) end

EVENT_MANAGER = {}

function EVENT_MANAGER:RegisterForUpdate(eventHandle, updateDelay, OnUpdate)
  updateListener[eventHandle] = OnUpdate
  Update(1)
end

function EVENT_MANAGER:UnregisterForUpdate(eventHandle) 
  updateListener[eventHandle] = nil
end

function EVENT_MANAGER:RegisterForEvent(eventHandle, event, OnCall)
  OnCall()
end

function EVENT_MANAGER:UnregisterForEvent(eventHandle, event) end

SLASH_COMMANDS = {}