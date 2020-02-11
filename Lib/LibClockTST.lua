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

LibClockTST = {}

local Instance = {
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
		__newindex = function(_, key, value)
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
    startTime = 1398033648.5, -- unix timestamp in s at in-game noon 1398044126 - 10477.5 (lengthOfDay/2)
}

--- Constant information to calculate the Tamriel Standard Time date
-- Eso Release was the 04.04.2014 at UNIX 1396569600 real time
-- 93 days after 1.1.582 in-game
LibClockTST.CONSTANTS.date = {
    startTime = 1394617983.724, -- release - offset to midnight 2801.2760416667 - offset of days 1948815
    startWeekDay = 2, -- Start day Friday (5) - 93 days to 1.1. Therefore, the weekday is (4 - 93)%7
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
		startTime = 1436153095, -- start time calculated from https://esoclock.uesp.net/ values to be new moon
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

--- Get the lore time
-- If a parameter is given, the lore date of the UNIX timestamp will be returned,
-- otherwise it will be the current time.
-- @param[opt] timestamp UNIX timestamp in s
-- @return {hour, minute, second} table
 function Instance:CalculateTST(timestamp)
	local timeSinceStart = timestamp - const.time.startTime
	local secondsSinceMidnight = timeSinceStart % const.time.lengthOfDay
	local tst = 24 * secondsSinceMidnight / const.time.lengthOfDay

	local h = math.floor(tst)
	tst = (tst - h) * 60
	local m = math.floor(tst)
	tst = (tst - m) * 60
	local s = math.floor(tst)

	if h == 0 and h ~= self.lastCalculatedHour then
	 self.needToUpdateDate = true
	end

	self.lastCalculatedHour = h

	return { hour = h, minute = m, second = s }
end

--- Get the lore date
-- If a parameter is given, the lore date of the UNIX timestamp will be returned,
-- otherwise it will be calculated from the current time.
-- @param[opt] timestamp UNIX timestamp in s
-- @return {era, year, month, day, weekDay} table
 function Instance:CalculateTSTDate(timestamp)
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

	 self.needToUpdateDate = false

	return {era = const.date.startEra, year = y, month = m, day = d, weekDay = w }
end

--- Get the name of the current moon phase
-- @param phasePercentage percentage already pased in the current phase
-- @return current moon phase string
function Instance:GetCurrentPhaseName(phasePercentage)
	for _, phase in ipairs(const.moon.phasesPercentage) do
		if phasePercentage < phase.endPercentage then return phase.name end
	end
end

--- Calculate the seconds until the moon is full again
-- returns 0 if the moon is already full
-- @param phasePercentage percentage already pased in the current phase
-- @return number of seconds until the moon is full again
function Instance:GetSecondsUntilFullMoon(phasePercentage)
	local secondsOffset = -phasePercentage * const.moon.phaseLengthInSeconds
	if phasePercentage > const.moon.phasesPercentage[5].endPercentage then
		secondsOffset = secondsOffset + const.moon.phaseLengthInSeconds
	end
	local secondsUntilFull = const.moon.phasesPercentage[4].endPercentage * const.moon.phaseLengthInSeconds + secondsOffset
	return secondsUntilFull
end

--- Calculate the lore moon
-- @param timestamp UNIX to be calculated from
-- @return moon object { percentageOfPhaseDone, currentPhaseName, isWaxing,
--      percentageOfCurrentPhaseDone, secondsUntilNextPhase, daysUntilNextPhase,
--      secondsUntilFullMoon, daysUntilFullMoon, percentageOfFullMoon }
function Instance:CalculateMoon(timestamp)
	local timeSinceStart = timestamp - const.moon.startTime
	local secondsSinceNewMoon = timeSinceStart % const.moon.phaseLengthInSeconds
	local phasePercentage = secondsSinceNewMoon / const.moon.phaseLengthInSeconds
	local isWaxing = phasePercentage <= const.moon.phasesPercentage[4].endPercentage
	local currentPhaseName = self:GetCurrentPhaseName(phasePercentage)
	local percentageOfNextPhase = phasePercentage % const.moon.phasesPercentageBetweenPhases
	local secondsUntilNextPhase = percentageOfNextPhase * const.moon.singlePhaseLengthInSeconds
	local daysUntilNextPhase = percentageOfNextPhase * const.moon.singlePhaseLength
	local secondsUntilFullMoon = self:GetSecondsUntilFullMoon(phasePercentage)
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
-- @param instance of LibClockTST
local function Update(self)
	local systemTime = GetTimeStamp()
	self.time = self:CalculateTST(systemTime)
	if not self.date or self.needToUpdateDate then
		self.date = self:CalculateTSTDate(systemTime)
	end
end

-- Update the moon with the current timestamp and store it in the moon variable
-- @param instance of LibClockTST
local function MoonUpdate(self)
	local systemTime = GetTimeStamp()
	self.moon = self:CalculateMoon(systemTime)
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
	if options[1] == "help" or #options > 2 then
		PrintHelp()
	else
		local instance = LibClockTST:Instance()
		local timestamp = GetTimeStamp()
		local tNeedToUpdateDate = instance.needToUpdateDate
		if #options == 2 then
			if not IsTimestamp(options[2]) then
				d("Please give only a 10 digit long timestamp as your seconds argument!")
				return
			else
				timestamp = tonumber(options[2])
			end
		end
		if #options == 0 or options[1] == "time" then
			d(instance:CalculateTST(timestamp))
		elseif options[1] == "date" then
			d(instance:CalculateTSTDate(timestamp))
		elseif options[1] == "moon" then
			d(instance:CalculateMoon(timestamp))
		else
			PrintHelp()
		end
		instance.needToUpdateDate = tNeedToUpdateDate
	end
end

-- Register the slash command 'LibClockTST'
local function RegisterCommands()
	SLASH_COMMANDS["/tst"] = function (extra)
		local options = {}
		if extra then
			local searchResult = { string.match(extra,"^(%S*)%s*(.-)$") }
			for i,v in pairs(searchResult) do
				if (v ~= nil and v ~= "") then
					options[i] = string.lower(v)
				end
			end
		end
		CommandHandler(options)
	end
end

-- -----------------
-- Initialize
-- -----------------

-- Event to update the time and date and its listeners
local function OnUpdate()
	local instance = LibClockTST:Instance()
	Update(instance)
	assert(instance.time, "Time object is empty")
	assert(instance.date, "Date object is empty")

	for _, f in pairs(instance.listener) do
		f(instance.time, instance.date)
	end

	for _, f in pairs(instance.timeListener) do
		f(instance.time)
	end

    for _, f in pairs(instance.dateListener) do
        f(instance.date)
    end
end

-- Event to update the moon and its listeners
local function OnMoonUpdate()
	local instance = LibClockTST:Instance()
	MoonUpdate(instance)
	assert(instance.moon, "Moon object is empty")
	for _, f in pairs(instance.moonListener) do
		f(instance.moon)
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


--- Constructor
-- Create a object to use custom delays between updates.
-- @param[opt] updateDelay delays between two updates in ms to calculate the time and date
-- @param[opt] moonUpdateDelay delays between two updates in ms to calculate the moon
-- @return Instance object
function Instance:New(updateDelay, moonUpdateDelay)
	self.dateListener = {}
	self.moonListener = {}
	self.timeListener = {}
	self.listener = {}
	self.needToUpdateDate = true
	self.updateDelay = updateDelay or self.updateDelay
	self.moonUpdateDelay = moonUpdateDelay or self.moonUpdateDelay
	return self
end

-- -----------------
-- Public
-- -----------------
local instance

--- Constructor
-- Create a object to use custom delays between updates.
-- Warning: Could lead to performance issues if you overdue this!
-- @param[opt] updateDelay delays between two updates in ms to calculate the time and date
-- @param[opt] moonUpdateDelay delays between two updates in ms to calculate the moon
-- @return LibClockTST object
 function LibClockTST:New(updateDelay, moonUpdateDelay)
    updateDelay = tonumber(updateDelay)
	moonUpdateDelay = tonumber(moonUpdateDelay)
	if not (updateDelay or moonUpdateDelay) then
		d("You want to call LibClockTST:Instance() instead, if you don't need specific delays.")
	end
	return Instance:New(updateDelay, moonUpdateDelay)
end

--- Instace of library
-- You can either get a singleton instance,
-- or create your custom instance with your specific delays.
-- @return LibClockTST object
function LibClockTST:Instance()
	instance = instance or LibClockTST:New(Instance.updateDelay, Instance.moonUpdateDelay)
	return instance
end

--- Get the lore time
-- If a parameter is given, the lore date of the UNIX timestamp will be returned,
-- otherwise it will be the current time.
-- @param[opt] timestamp UNIX timestamp in s
-- @return date object {era, year, month, day, weekDay}
 function Instance:GetTime(timestamp)
	if timestamp then
        assert(IsTimestamp(timestamp), "Please provide nil or a valid timestamp as an argument")
        timestamp = tonumber(timestamp)
		local tNeedToUpdateDate = self.needToUpdateDate
		local t = self:CalculateTST(timestamp)
		self.needToUpdateDate = tNeedToUpdateDate
		return t
	else
		Update(self)
		return self.time
	end
end

--- Get the lore date
-- If a parameter is given, the lore date of the UNIX timestamp will be returned,
-- otherwise it will be calculated from the current time.
-- @param[opt] timestamp UNIX timestamp in s
-- @return date object {era, year, month, day, weekDay}
 function Instance:GetDate(timestamp)
	if timestamp then
        assert(IsTimestamp(timestamp), "Please provide nil or a valid timestamp as an argument")
        timestamp = tonumber(timestamp)
		local tNeedToUpdateDate = self.needToUpdateDate
		local d = self:CalculateTSTDate(timestamp)
		self.needToUpdateDate = tNeedToUpdateDate
		return d
	else
		Update(self)
		return self.date
	end
end

--- Get the lore moon
-- If a parameter is given, the lore moon of the UNIX timestamp will be returned,
-- otherwise it will be calculated from the current time.
-- @param[opt] timestamp UNIX timestamp in s
-- @return moon object { phasePercentage, currentPhaseName, isWaxing,
--      percentageOfNextPhase, secondsUntilNextPhase, daysUntilNextPhase,
--      secondsUntilFullMoon, daysUntilFullMoon }
 function Instance:GetMoon(timestamp)
	if timestamp then
        assert(IsTimestamp(timestamp), "Please provide nil or a valid timestamp as an argument")
        timestamp = tonumber(timestamp)
		return self:CalculateMoon(timestamp)
	else
		MoonUpdate(self)
		return self.moon
	end
end

--- Register an addon to subscribe to date and time updates.
-- @param addonId Id of the addon to be registered
-- @param func function with two parameters for time and date to be called
 function Instance:Register(addonId, func)
	assert(IsNotNilOrEmpty(addonId), "Please provide an ID for the addon. Store it to cancel the subscription later.")
	assert(func, "Please provide a function: func(time, date) to be called every second for a time update.")
	assert(not self.listener[addonId], addonId .. " already subscribes.")
	self.listener[addonId] = func
	em:RegisterForUpdate(eventHandle, self.updateDelay, OnUpdate)
end

--- Cancel a subscription for the date and time updates.
-- Will also stop background calculations if no addon is subscribing anymore.
-- @param addonId Id of the addon previous registered
 function Instance:CancelSubscription(addonId)
	assert(IsNotNilOrEmpty(addonId), "Please provide an ID to cancel the subscription.")
	assert(self.listener[addonId], "Subscription could not be found.")
	self.listener[addonId] = nil
	if #self.listener == 0 then
		em:UnregisterForUpdate(eventHandle)
	end
end

--- Register an addon to subscribe to time updates.
-- @param addonId Id of the addon to be registered
-- @param func function with a parameter for time to be called
-- @see LibClockTST:Register
 function Instance:RegisterForTime(addonId, func)
	assert(IsNotNilOrEmpty(addonId), "Please provide an ID for the addon. Store it to cancel the subscription later.")
	assert(func, "Please provide a function: func(time) to be called every second for a time update.")
	assert(not self.timeListener[addonId], addonId .. " already subscribes.")
	self.timeListener[addonId] = func
	em:RegisterForUpdate(eventHandle, self.updateDelay, OnUpdate)
end

--- Cancel a subscription for the time updates.
-- @param addonId Id of the addon previous registered
-- @see LibClockTST:CancelSubscription
 function Instance:CancelSubscriptionForTime(addonId)
	assert(IsNotNilOrEmpty(addonId), "Please provide an ID to cancel the subscription.")
	assert(self.timeListener[addonId], "Subscription could not be found.")
	self.timeListener[addonId] = nil
	if #self.timeListener == 0 then
		em:UnregisterForUpdate(eventHandle.."-Time")
	end
end

--- Register an addon to subscribe to date updates.
-- @param addonId Id of the addon to be registered
-- @param func function with a parameter for date to be called
-- @see LibClockTST:Register
 function Instance:RegisterForDate(addonId, func)
	assert(IsNotNilOrEmpty(addonId), "Please provide an ID for the addon. Store it to cancel the subscription later.")
	assert(func, "Please provide a function: func(date) to be called every second for a time update.")
	assert(not self.dateListener[addonId], addonId .. " already subscribes.")
	self.dateListener[addonId] = func
	em:RegisterForUpdate(eventHandle, self.updateDelay, OnUpdate)
end

--- Cancel a subscription for the date updates.
-- @param addonId Id of the addon previous registered
-- @see LibClockTST:CancelSubscription
 function Instance:CancelSubscriptionForDate(addonId)
	assert(IsNotNilOrEmpty(addonId), "Please provide an ID to cancel the subscription.")
	assert(self.dateListener[addonId], "Subscription could not be found.")
	self.dateListener[addonId] = nil
	if #self.dateListener == 0 then
		em:UnregisterForUpdate(eventHandle.."-Date")
	end
end

--- Register an addon to subscribe to moon updates.
-- @param addonId Id of the addon to be registered
-- @param func function with a parameter for moon to be called
-- @see LibClockTST:Register
-- @call moon = { percentageOfPhaseDone, currentPhaseName, isWaxing,
--      percentageOfCurrentPhaseDone, secondsUntilNextPhase, daysUntilNextPhase,
--      secondsUntilFullMoon, daysUntilFullMoon, percentageOfFullMoon }
 function Instance:RegisterForMoon(addonId, func)
	assert(IsNotNilOrEmpty(addonId), "Please provide an ID for the addon. Store it to cancel the subscription later.")
	assert(func, "Please provide a function: func(moon) to be called every second for a time update.")
	assert(not self.moonListener[addonId], addonId .. " already subscribes.")
	self.moonListener[addonId] = func
	em:RegisterForUpdate(eventHandle.."-Moon", self.moonUpdateDelay, OnMoonUpdate) -- once per hour should be enough

	-- Update once
	MoonUpdate(self)
	func(self.moon)
end

--- Cancel a subscription for the moon updates.
-- @param addonId Id of the addon previous registered
-- @see LibClockTST:CancelSubscription
 function Instance:CancelSubscriptionForMoon(addonId)
	assert(IsNotNilOrEmpty(addonId), "Please provide an ID to cancel the subscription.")
	assert(self.moonListener[addonId], "Subscription could not be found.")
	self.moonListener[addonId] = nil
	if #self.moonListener == 0  then
		em:UnregisterForUpdate(eventHandle.."-Moon")
	end
end
