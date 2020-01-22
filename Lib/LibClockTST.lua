--[[----------------------------------------
    Location:   Lib/LibClockTST.lua
    Author:     Arne Rantzen (Tyx)
    Created:    2020-01-20
    Updated:    2020-01-22
    License:    GPL-3.0
----------------------------------------]]--
------------
-- LibClock - Tamriel Standard Time
-- Public functions to get information about the in-game time, date and moon
-- You can call them directly or subscribe to updates. 
-- Each function also gives the option to get information about a specific timestamp.
----

LibClockTST = {
	updateDelay = 200,
	moonUpdateDelay = 36000000,
}

-- -----------------
-- Utility
-- -----------------

-- Makes a table read-only
-- Source: http://andrejs-cainikovs.blogspot.com/2009/05/lua-constants.html
-- @param tbl any table to be made read-only
-- @return a read-only table
local function Protect(tbl)
	return setmetatable({}, {
		__index = tbl,
		__newindex = function(t, key, value)
			error("attempting to change constant " ..
				tostring(key) .. " to " .. tostring(value), 2)
		end
	})
end

-- Check if string is nil or empty
-- @param obj string to be checked
-- @return bool if it is not nil or empty
local function IsNotNilOrEmpty(obj) 
    return obj ~= nil and string.match(tostring(obj), "^%s*$") == nil
end

-- Check if object is a string
-- @param obj string to be checked
-- @return bool if it is a string
local function IsString(str) 
    return type(str) == "string"
end

-- Check if input is a timestamp
-- @param timestamp object to be checked
-- @return bool if it matches the condition
local function IsTimestamp(timestamp)
    timestamp = math.floor(tonumber(timestamp))
    return string.match(tostring(timestamp), "^%d%d%d%d%d%d%d%d%d%d$") ~= nil
end

-- -----------------
-- Constants
-- -----------------

local ID, MAJOR, MINOR = "LibClockTST", "LibClockTST-1.0", 0
local eventHandle = table.concat({MAJOR, MINOR}, "r")

local em = EVENT_MANAGER

--- Constants with all information about the time, date and moon
-- @field time information to calculate the Tamriel Standard Time
-- @field date information to calculate the Tamriel Standard Time date
-- @field moon information to calculate the moon position
-- @table CONSTANTS
LibClockTST.CONSTANTS = {}

--- Constant information to calculate the Tamriel Standard Time
LibClockTST.CONSTANTS.time = {
    lengthOfDay = 20955, -- length of one day in s (default 5.75h right now)
    lengthOfNight = 7200, -- length of only the night in s (2h)
    lengthOfHour = 873.125, -- length of an in-game hour in s
    startTime = 1398033648.5, -- exact unix time at ingame noon as unix timestamp 1398044126 minus offset from midnight 10477.5 (lengthOfDay/2) in s
}

--- Constant information to calculate the Tamriel Standard Time date
LibClockTST.CONSTANTS.date = {
    startTime = 1394617983.724, -- Eso Release  04.04.2014  UNIX: 1396569600 minus calculated offset to midnight 2801.2760416667 minus offset of days to 1.1.582, 1948815 ((31 + 28 + 31 + 3) * const.time.lengthOfDay)
    startWeekDay = 2, -- Start day was Friday (5) but start time of calculation is 93 days before. Therefore, the weekday is (4 - 93)%7
    startYear = 582, -- offset in years, because the game starts in 2E 582
    startEra = 2, -- era the world is in 
    yearLength = 365, -- length of the in-game year in days
}

--- Different length of month within the year in days
LibClockTST.CONSTANTS.date.monthLength = { 
    [1] = 31, -- Januar
    [2] = 28, -- Februar
    [3] = 31, -- March
    [4] = 30, -- April
    [5] = 31, -- May
    [6] = 30, -- June
    [7] = 31, -- July
    [8] = 31, -- August
    [9] = 30, -- September
    [10] = 31, -- October
    [11] = 30, -- November
    [12] = 31, -- December
}

--- Constant information to calculate the moon position
LibClockTST.CONSTANTS.moon = {
		startTime = 1436153095, -- 1435838770 from https://esoclock.uesp.net/ + half phase = 1436153095 - phaseOffsetToEnd * phaseLengthInSeconds = 1436112233
		phaseLength = 30, -- ingame days
		phaseLengthInSeconds = 628650, -- in s, phaseLength * dayLength
		singlePhaseLength = 3.75, -- in ingame days
		singlePhaseLengthInSeconds = 78581.25, -- in s, singlePhaseLength * dayLength
		phasesPercentageBetweenPhases = 0.125, -- length in percentage of whole phase of each single phase
} 

--- Percentage until end of phase  from https://esoclock.uesp.net/
LibClockTST.CONSTANTS.moon.phasesPercentage = {
    [1] = {
        name = "new",
        endPercentage = 0.06,
    }, -- new moon phase
    [2] = {
        name = "waxingCrescent",
        endPercentage = 0.185,
    }, -- waxing crescent moon phase
    [3] = {
        name = "firstQuarter",
        endPercentage = 0.31,
    }, -- first quarter moon phase
    [4] = {
        name = "waxingGibbonus",
        endPercentage = 0.435,
    }, -- waxing gibbonus moon phase
    [5] = {
        name = "full",
        endPercentage = 0.56,
    }, -- full moon phase
    [6] = {
        name = "waningGibbonus",
        endPercentage = 0.685,
    }, -- waning gibbonus moon phase
    [7] = {
        name = "thirdQuarter",
        endPercentage = 0.81,
    }, -- third quarter moon phase
    [8] = {
        name = "waningCrescent",
        endPercentage = 0.935,
    }, -- waning crescent moon phase
}

local const = Protect(LibClockTST.CONSTANTS)

LibClockTST.CONSTANTS = const

-- -----------------
-- Calculation
-- -----------------

local lastCalculatedHour
local needToUpdateDate = true
local time
local date
local moon

-- Get the lore time
-- If a parameter is given, the lore date of the UNIX timestamp will be returned,
-- otherwise it will be the current time.
-- @param[opt] timestamp UNIX timestamp in s
-- @return {hour, minute, second} table
local function CalculateLibClockTST(timestamp)
	local timeSinceStart = timestamp - const.time.startTime
	local secondsSinceMidnight = timeSinceStart % const.time.lengthOfDay
	local LibClockTST = 24 * secondsSinceMidnight / const.time.lengthOfDay

	local h = math.floor(LibClockTST)
	LibClockTST = (LibClockTST - h) * 60
	local m = math.floor(LibClockTST)
	LibClockTST = (LibClockTST - m) * 60
	local s = math.floor(LibClockTST)

	if h == 0 and h ~= lastCalculatedHour then
		needToUpdateDate = true
	end

	lastCalculatedHour = h

	return { hour = h, minute = m, second = s }
end

-- Get the lore date
-- If a parameter is given, the lore date of the UNIX timestamp will be returned,
-- otherwise it will be calculated from the current time.
-- @param[opt] timestamp UNIX timestamp in s
-- @return {era, year, month, day, weekDay} table
local function CalculateLibClockTSTDate(timestamp)
	local timeSinceStart = timestamp - const.date.startTime
	local daysPast = math.floor(timeSinceStart / const.time.lengthOfDay)
	local w = (daysPast + const.date.startWeekDay) % 7 + 1

	local y = math.floor(daysPast / const.date.yearLength)
	daysPast = daysPast - y * const.date.yearLength
	y = y + const.date.startYear
	local m = 1
	while daysPast >= const.date.monthLength[m] do
		daysPast = daysPast - const.date.monthLength[m]
		m = m + 1
	end
	local d = daysPast + 1

	needToUpdateDate = false

	return {era = const.date.startEra, year = y, month = m, day = d, weekDay = w }
end

-- Get the name of the current moon phase
-- @param phasePercentage percentage already pased in the current phase
-- @return current moon phase string
local function GetCurrentPhaseName(phasePercentage)
	for _, phase in ipairs(const.moon.phasesPercentage) do
		if phasePercentage < phase.endPercentage then return phase.name end
	end
end

-- Calculate the seconds until the moon is full again
-- returns 0 if the moon is already full
-- @param phasePercentage percentage already pased in the current phase
-- @return number of seconds until the moon is full again
local function GetSecondsUntilFullMoon(phasePercentage)
	local secondsOffset = -phasePercentage * const.moon.phaseLengthInSeconds
	if phasePercentage > const.moon.phasesPercentage[5].endPercentage then
		secondsOffset = secondsOffset + const.moon.phaseLengthInSeconds
	end
	local secondsUntilFull = const.moon.phasesPercentage[4].endPercentage * const.moon.phaseLengthInSeconds + secondsOffset
	return secondsUntilFull
end

-- Calculate the lore moon
-- @param timestamp UNIX to be calculated from
-- @return moon object { percentageOfPhaseDone, currentPhaseName, isWaxing,
--      percentageOfCurrentPhaseDone, secondsUntilNextPhase, daysUntilNextPhase,
--      secondsUntilFullMoon, daysUntilFullMoon, percentageOfFullMoon }
local function CalculateMoon(timestamp)
	local timeSinceStart = timestamp - const.moon.startTime
	local secondsSinceNewMoon = timeSinceStart % const.moon.phaseLengthInSeconds
	local phasePercentage = secondsSinceNewMoon / const.moon.phaseLengthInSeconds
	local isWaxing = phasePercentage <= const.moon.phasesPercentage[4].endPercentage
	local currentPhaseName = GetCurrentPhaseName(phasePercentage)
	local percentageOfNextPhase = phasePercentage % const.moon.phasesPercentageBetweenPhases
	local secondsUntilNextPhase = percentageOfNextPhase * const.moon.singlePhaseLengthInSeconds
	local daysUntilNextPhase = percentageOfNextPhase * const.moon.singlePhaseLength
	local secondsUntilFullMoon = GetSecondsUntilFullMoon(phasePercentage)
	local daysUntilFullMoon = secondsUntilFullMoon / const.time.lengthOfDay
    local percentageOfFullMoon
    if phasePercentage > 0.5 then  
        percentageOfFullMoon = 1 - (phasePercentage - 0.5) * 2
    else
        percentageOfFullMoon = phasePercentage * 2
    end

	return {
		percentageOfPhaseDone = phasePercentage,
		currentPhaseName = currentPhaseName,
		isWaxing = isWaxing,
		percentageOfCurrentPhaseDone = percentageOfNextPhase,
		secondsUntilNextPhase = secondsUntilNextPhase,
		daysUntilNextPhase = daysUntilNextPhase,
		secondsUntilFullMoon = secondsUntilFullMoon,
		daysUntilFullMoon = daysUntilFullMoon,
        percentageOfFullMoon = percentageOfFullMoon
	}
end

-- Update the time with the current timestamp and store it in the time variable
-- If neccessary, update the date and store in also
local function Update()
	local systemTime = GetTimeStamp()
	time = CalculateLibClockTST(systemTime)
	needToUpdateDate = true -- TODO: Remove
	if needToUpdateDate then
		date = CalculateLibClockTSTDate(systemTime)
	end
end

-- Update the moon with the current timestamp and store it in the moon variable
local function MoonUpdate()
	local systemTime = GetTimeStamp()
	moon = CalculateMoon(systemTime)
end

-- -----------------
-- Commands
-- -----------------

-- Event to update the time and date and its listeners
local function PrintHelp()
	d("Welcome to the |cFFD700LibClock|r - LibClockTST by |c5175ea@Tyx|r [EU] help menu\n"
		.. "To show the current time, write:\n"
		.. "\t\\LibClockTST time\n"
		.. "To show a specific time at a given UNIX timestamp in seconds, write:\n"
		.. "\t\\LibClockTST time [timestamp]\n"
		.. "To show the current date, write:\n"
		.. "\t\\LibClockTST date\n"
		.. "To show a specific date at a given UNIX timestamp in seconds, write:\n"
		.. "\t\\LibClockTST date [timestamp]\n"
		.. "To show the current moon phase, write:\n"
		.. "\t\\LibClockTST moon\n"
		.. "To show a specific moon phase at a given UNIX timestamp in seconds, write:\n"
		.. "\t\\LibClockTST moon [timestamp]\n")
end

-- Handel a given command
-- If time is given, the time table will be printed.
-- If date is given, the date table will be printed.
-- If moon is given, the moon table will be printed.
-- If the second argument is a timestamp, it will be the basis for the calculations.
-- @param options table of arguments
local function CommandHandler(options)
	if #options == 0 or options[1] == "help" or #options > 2 then
		PrintHelp()
	else
		local timestamp
		local tNeedToUpdateDate = needToUpdateDate
		if #options == 2 then
			if not string.match(options[2], "^%d%d%d%d%d%d%d%d%d%d$") then
				d("Please give only a 10 digit long timestamp as your seconds argument!")
				return
			else
				timestamp = tonumber(options[2])
			end
		end
		if options[1] == "time" then
			d(CalculateLibClockTST(timestamp))
		elseif options[1] == "date" then
			d(CalculateLibClockTSTDate(timestamp))
		elseif options[1] == "moon" then
			d(CalculateMoon(timestamp))
		else
			PrintHelp()
		end
		needToUpdateDate = tNeedToUpdateDate
	end
end

-- Register the slash command 'LibClockTST'
local function RegisterCommands()
	SLASH_COMMANDS["/tst"] = function (extra)
		local options = {}
		local searchResult = { string.match(extra,"^(%S*)%s*(.-)$") }
		for i,v in pairs(searchResult) do
			if (v ~= nil and v ~= "") then
				options[i] = string.lower(v)
			end
		end
		CommandHandler(options)
	end
end

-- -----------------
-- Initialize
-- -----------------

local dateListener = {}
local moonListener = {}
local timeListener = {}
local listener = {}

-- Event to update the time and date and its listeners
local function OnUpdate()
	Update()
	assert(time, "Time object is empty")
	assert(date, "Date object is empty")

	for _, f in pairs(listener) do
		f(time, date)
	end

	for _, f in pairs(timeListener) do
		f(time)
	end

    for _, f in pairs(dateListener) do
        f(date)
    end
end

-- Event to update the moon and its listeners
local function OnMoonUpdate()
	MoonUpdate()
	assert(moon, "Moon object is empty")
	for _, f in pairs(moonListener) do
		f(moon)
	end
end

-- Event to be called on Load
local function OnLoad(_, addonName)
	if addonName ~= ID then return end
	-- wait for the first loaded event
	em:UnregisterForEvent(eventHandle, EVENT_ADD_ON_LOADED)
	RegisterCommands()
end
em:RegisterForEvent(eventHandle, EVENT_ADD_ON_LOADED, OnLoad)


-- -----------------
-- Public
-- -----------------

--- Constructor
-- Create a object to use custom delays between updates.
-- Warning: Could lead to performance issues if you overdue this!
-- @param[opt] updateDelay delays between two updates in ms to calculate the time and date
-- @param[opt] moonUpdateDelay delays between two updates in ms to calculate the moon
-- @return LibClockTST object
function LibClockTST:New(updateDelay, moonUpdateDelay)
    updateDelay = tonumber(updateDelay)
    moonUpdateDelay = tonumber(moonUpdateDelay)
	self.updateDelay = updateDelay or self.updateDelay
	self.moonUpdateDelay = moonUpdateDelay or self.moonUpdateDelay
	return self
end

--- Get the lore time
-- If a parameter is given, the lore date of the UNIX timestamp will be returned,
-- otherwise it will be the current time.
-- @param[opt] timestamp UNIX timestamp in s
-- @return date object {era, year, month, day, weekDay}
function LibClockTST:GetTime(timestamp)
	if timestamp then
        assert(IsTimestamp(timestamp), "Please provide nil or a valid timestamp as an argument")
        timestamp = tonumber(timestamp)
		local tNeedToUpdateDate = needToUpdateDate
		local t = CalculateLibClockTST(timestamp)
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
-- @param[opt] timestamp UNIX timestamp in s
-- @return date object {era, year, month, day, weekDay}
function LibClockTST:GetDate(timestamp)
	if timestamp then
        assert(IsTimestamp(timestamp), "Please provide nil or a valid timestamp as an argument")
        timestamp = tonumber(timestamp)
		local tNeedToUpdateDate = needToUpdateDate
		local d = CalculateLibClockTSTDate(timestamp)
		needToUpdateDate = tNeedToUpdateDate
		return d
	else
		Update()
		return date
	end
end

--- Get the lore moon
-- If a parameter is given, the lore moon of the UNIX timestamp will be returned,
-- otherwise it will be calculated from the current time.
-- @param[opt] timestamp UNIX timestamp in s
-- @return moon object { phasePercentage, currentPhaseName, isWaxing,
--      percentageOfNextPhase, secondsUntilNextPhase, daysUntilNextPhase,
--      secondsUntilFullMoon, daysUntilFullMoon }
function LibClockTST:GetMoon(timestamp)
	if timestamp then
        assert(IsTimestamp(timestamp), "Please provide nil or a valid timestamp as an argument")
        timestamp = tonumber(timestamp)
		return CalculateMoon(timestamp)
	else
		MoonUpdate()
		return moon
	end
end

--- Register an addon to subscribe to date and time updates.
-- @param addonId Id of the addon to be registered
-- @param func function with two parameters for time and date to be called
function LibClockTST:Register(addonId, func)
	assert(IsNotNilOrEmpty(addonId), "Please provide an ID for the addon. Store it to cancel the subscription later.")
	assert(func, "Please provide a function: func(time, date) to be called every second for a time update.")
	assert(not listener[addonId], addonId .. " already subscribes.")
	listener[addonId] = func
	em:RegisterForUpdate(eventHandle, self.updateDelay, OnUpdate)
end

--- Cancel a subscription for the date and time updates.
-- Will also stop background calculations if no addon is subscribing anymore.
-- @param addonId Id of the addon previous registered
function LibClockTST:CancelSubscription(addonId)
	assert(IsNotNilOrEmpty(addonId), "Please provide an ID to cancel the subscription.")
	assert(listener[addonId], "Subscription could not be found.")
	listener[addonId] = nil
	if #listener == 0 then
		em:UnregisterForUpdate(eventHandle)
	end
end

--- Register an addon to subscribe to time updates.
-- @param addonId Id of the addon to be registered
-- @param func function with a parameter for time to be called
-- @see LibClockTST:Register
function LibClockTST:RegisterForTime(addonId, func)
	assert(IsNotNilOrEmpty(addonId), "Please provide an ID for the addon. Store it to cancel the subscription later.")
	assert(func, "Please provide a function: func(time) to be called every second for a time update.")
	assert(not timeListener[addonId], addonId .. " already subscribes.")
	timeListener[addonId] = func
	em:RegisterForUpdate(eventHandle, self.updateDelay, OnUpdate)
end

--- Cancel a subscription for the time updates.
-- @param addonId Id of the addon previous registered
-- @see LibClockTST:CancelSubscription
function LibClockTST:CancelSubscriptionForTime(addonId)
	assert(IsNotNilOrEmpty(addonId), "Please provide an ID to cancel the subscription.")
	assert(timeListener[addonId], "Subscription could not be found.")
	timeListener[addonId] = nil
	if #timeListener == 0 then
		em:UnregisterForUpdate(eventHandle.."-Time")
	end
end

--- Register an addon to subscribe to date updates.
-- @param addonId Id of the addon to be registered
-- @param func function with a parameter for date to be called
-- @see LibClockTST:Register
function LibClockTST:RegisterForDate(addonId, func)
	assert(IsNotNilOrEmpty(addonId), "Please provide an ID for the addon. Store it to cancel the subscription later.")
	assert(func, "Please provide a function: func(date) to be called every second for a time update.")
	assert(not dateListener[addonId], addonId .. " already subscribes.")
	dateListener[addonId] = func
	em:RegisterForUpdate(eventHandle, self.updateDelay, OnUpdate)
end

--- Cancel a subscription for the date updates.
-- @param addonId Id of the addon previous registered
-- @see LibClockTST:CancelSubscription
function LibClockTST:CancelSubscriptionForDate(addonId)
	assert(IsNotNilOrEmpty(addonId), "Please provide an ID to cancel the subscription.")
	assert(dateListener[addonId], "Subscription could not be found.")
	dateListener[addonId] = nil
	if #dateListener == 0 then
		em:UnregisterForUpdate(eventHandle.."-Date")
	end
end

--- Register an addon to subscribe to moon updates.
-- @param addonId Id of the addon to be registered
-- @param func function with a parameter for moon to be called
-- @see LibClockTST:Register
function LibClockTST:RegisterForMoon(addonId, func)
	assert(IsNotNilOrEmpty(addonId), "Please provide an ID for the addon. Store it to cancel the subscription later.")
	assert(func, "Please provide a function: func(moon) to be called every second for a time update.")
	assert(not moonListener[addonId], addonId .. " already subscribes.")
	moonListener[addonId] = func
	em:RegisterForUpdate(eventHandle.."-Moon", self.moonUpdateDelay, OnMoonUpdate) -- once per hour should be enough

	-- Update once
	MoonUpdate()
	func(moon)
end

--- Cancel a subscription for the moon updates.
-- @param addonId Id of the addon previous registered
-- @see LibClockTST:CancelSubscription
function LibClockTST:CancelSubscriptionForMoon(addonId)
	assert(IsNotNilOrEmpty(addonId), "Please provide an ID to cancel the subscription.")
	assert(moonListener[addonId], "Subscription could not be found.")
	moonListener[addonId] = nil
	if #moonListener == 0  then
		em:UnregisterForUpdate(eventHandle.."-Moon")
	end
end
