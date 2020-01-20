


-------------------
-- Constants
-------------------
local TST = {}
LibClockTST = TST

local ID, MAJOR, MINOR = "LibClockTST", "LibClockTST-1.0", 0
local eventHandle = table.concat({MAJOR, MINOR}, "r")

local em = EVENT_MANAGER

local const = TST.constants

const = {
    time = {
        lengthOfDay = 20955, -- length of one day in s (default 5.75h right now)
        lengthOfNight = 7200, -- length of only the night in s (2h)
        lengthOfHour = 873.125,
        startTime = 1398044126, -- exact unix time at ingame noon to calculated game time start in s
        startTimeOffset = -10477.5 -- offset in s, because we need 12 am not pm
    },
    date = {
        startDate = 1396569600, -- Eso Release  04.04.2014  UNIX: 1396569600
        startDateOffset = -1969770, -- in s; 4th day + 4th month (31 + 28 + 31) = 94 days gone in the first year at start
        startDateTimeOffset = -18153.5, -- in s; difference between the synced time at midnight and the start date
        startWeekDay = 5,
        startYear = 582, -- offset in years, because the game starts in 2E 582
        startEra = 2,
        monthLength = {
            [1] = 31,
            [2] = 28,
            [3] = 31,
            [4] = 30,
            [5] = 31,
            [6] = 30,
            [7] = 31,
            [8] = 31,
            [9] = 30,
            [10] = 31,
            [11] = 30,
            [12] = 31,
        }, -- length of months
        yearLength = 365,
    },
    moon = {
        --Unix time of the start of the full moon phase in s - old 1425169441 and 1407553200
        moonStartTime = 1435838770 --Source: https://esoclock.uesp.net/
    },
}

local gameStartTime = const.time.startTime + const.time.startTimeOffset
local gameDateStartTime = const.date.startDate + const.date.startDateOffset + const.date.startDateTimeOffset

-------------------
-- Calculation
-------------------

local lastCalculatedHour
local needToUpdateDate = true
local time
local date

local function CalculateTSTDate(timestamp)
    local timeSinceStart = timestamp - gameDateStartTime
    local daysPast = math.floor(timeSinceStart / const.time.lengthOfDay)
    local w = (daysPast + const.date.startWeekDay) % 7 + 1

    local y = math.floor(daysPast / const.date.yearLength)
    daysPast = daysPast - y * const.date.yearLength
    y = y + const.date.startYear
    local m = 1
    while daysPast > const.date.monthLength[m] do
        daysPast = daysPast - const.date.monthLength[m]
        m = m + 1
    end
    local d = daysPast

    needToUpdateDate = false

    return {era = const.date.startEra, year = y, month = m, day = d, weekDay = w }
end

local function CalculateTST(timestamp) 
    local timeSinceStart = timestamp - gameStartTime
    local secondsSinceMidnight = timeSinceStart % const.time.lengthOfDay
    local tst = 24 * secondsSinceMidnight / const.time.lengthOfDay

    local h = math.floor(tst)
    tst = (tst - h) * 60
    local m = math.floor(tst)
    tst = (tst - m) * 60
    local s = math.floor(tst)

    if h == 0 and h ~= lastCalculatedHour then
        needToUpdateDate = true
    end

    lastCalculatedHour = h

    return { hour = h, minute = m, second = s }
end

local function Update() 
    local systemTime = GetTimeStamp()
    time = CalculateTST(systemTime)
    if needToUpdateDate then
        date = CalculateTSTDate(systemTime)
    end
end
-------------------
-- Initialize
-------------------

local timeListener = {}
local dateListener = {}
local listener = {}

local function OnUpdate()
    local tNeedToUpdateDate = needToUpdateDate
    Update()
    if tNeedToUpdateDate then
        for _, f in pairs(dateListener) do
            f(date)
        end
    end

    for _, f in pairs(listener) do
        f(time, date)
    end

    for _, f in pairs(timeListener) do
        f(time)
    end
end

local function test(time, date)
    d(time)
    d(date)
end

local function OnLoad(_, addonName)
    if addonName ~= ID then return end
    -- wait for the first loaded event
    em:UnregisterForEvent(eventHandle, EVENT_ADD_ON_LOADED)
end
em:RegisterForEvent(eventHandle, EVENT_ADD_ON_LOADED, OnLoad)

-------------------
-- Public
-------------------

--- Get the lore time
-- If a parameter is given, the lore date of the UNIX timestamp will be returned, 
-- otherwise it will be the current time.
-- @param timestamp [optional]
-- @return date object {era, year, month, day, weekDay}
function TST:GetTime(timestamp)    
    local t = time
    if timestamp then
        local tNeedToUpdateDate = needToUpdateDate
        local t = CalculateTST(timestamp)
        needToUpdateDate = tNeedToUpdateDate
        return t
    else
        Update()
        return time
    end 
end

--- Get the lore date
-- If a parameter is given, the lore date of the UNIX timestamp will be returned, 
-- otherwise it will be calculated from the current time.
-- @param timestamp [optional]
-- @return date object {era, year, month, day, weekDay}
function TST:GetDate(timestamp)
    if timestamp then
        local tNeedToUpdateDate = needToUpdateDate
        local d = CalculateTSTDate(timestamp)
        needToUpdateDate = tNeedToUpdateDate
        return d
    else
        Update()
        return date
    end 
end

--- Register an addon to subscribe to date and time updates.
-- @param addonId Id of the addon to be registered
-- @param func function with two parameters for time and date to be called
function TST:Register(addonId, func)
    assert(addonId, "Please provide an ID for the addon. Store it to cancel the subscription later.")
    assert(func, "Please provide a function: func(time, date) to be called every second for a time update.")
    assert(not listener[addonId] , addonId .. " already subscribes.")
    listener[addonId] = func
    em:RegisterForUpdate(eventHandle, 1000, OnUpdate)
end

--- Cancel a subscription for the date and time updates.
-- Will also stop background calculations if no addon is subscribing anymore.
-- @param addonId Id of the addon previous registered
function TST:CancelSubscription(addonId)
    assert(addonId, "Please provide an ID to cancel the subscription.")
    assert(listener[addonId], "Subscription could not be found.")
    listener[addonId] = nil
    if #timeListener == 0 and #dateListener == 0 and #listener == 0 then
        em:UnregisterForUpdate(eventHandle)
    end
end

--- Register an addon to subscribe to time updates.
-- @param addonId Id of the addon to be registered
-- @param func function with a parameter for time to be called
-- @see TST:Register
function TST:RegisterForTime(addonId, func)
    assert(addonId, "Please provide an ID for the addon. Store it to cancel the subscription later.")
    assert(func, "Please provide a function: func(time) to be called every second for a time update.")
    assert(not timeListener[addonId], addonId .. " already subscribes.")
    timeListener[addonId] = func
    em:RegisterForUpdate(eventHandle, 1000, OnUpdate)
end

--- Cancel a subscription for the time updates.
-- @param addonId Id of the addon previous registered
-- @see TST:CancelSubscription
function TST:CancelTimeSubscription(addonId)
    assert(addonId, "Please provide an ID to cancel the subscription.")
    assert(timeListener[addonId], "Subscription could not be found.")
    timeListener[addonId] = nil
    if #timeListener == 0 and #dateListener == 0 and #listener == 0 then
        em:UnregisterForUpdate(eventHandle)
    end
end

--- Register an addon to subscribe to date updates.
-- @param addonId Id of the addon to be registered
-- @param func function with a parameter for date to be called
-- @see TST:Register
function TST:RegisterForDate(addonId, func)
    assert(addonId, "Please provide an ID for the addon. Store it to cancel the subscription later.")
    assert(func, "Please provide a function: func(date) to be called every second for a time update.")
    assert(not dateListener[addonId], addonId .. " already subscribes.")
    dateListener[addonId] = func
    em:RegisterForUpdate(eventHandle, 1000, OnUpdate)
end

--- Cancel a subscription for the date updates.
-- @param addonId Id of the addon previous registered
-- @see TST:CancelSubscription
function TST:CancelDateSubscription(addonId)
    assert(addonId, "Please provide an ID to cancel the subscription.")
    assert(dateListener[addonId], "Subscription could not be found.")
    dateListener[addonId] = nil
    if #timeListener == 0 and #dateListener == 0 and #listener == 0 then
        em:UnregisterForUpdate(eventHandle)
    end
end
