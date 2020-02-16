--- Requires busted https://github.com/Olivine-Labs/busted
-- run luarocks install busted

require("Test.ZOMock")
require("Lib.LibClockTST")

describe("ZOMock", function()

    it("should result in a timestamp", function()
        local timestamp = os.time(os.date("!*t"))
        assert.are.same(timestamp, GetTimeStamp())
    end)

    it("should call update", function()
        local f = spy.new(function() end)
        EVENT_MANAGER:RegisterForUpdate("testEvent", 200, f)
        assert.spy(f).was.called()
    end)

    it("should call event", function()
        local f = spy.new(function() end)
        EVENT_MANAGER:RegisterForEvent("testEvent", nil, f)
        assert.spy(f).was.called()
    end)

end)

describe("LibClockTST", function()
    local TST = LibClockTST:Instance()
    local const = LibClockTST.CONSTANTS()

    it("should create a custom object", function()
        local tDelay, tMoonDelay = 1, 2
        local tLib = LibClockTST:New(tDelay, tMoonDelay)
        assert.is.equal(tDelay, tLib.updateDelay)
        assert.is.equal(tMoonDelay, tLib.moonUpdateDelay)
    end)

    it("should create independent instances", function()
        local tDelay1, tMoonDelay1 = 1, 2
        local tDelay2, tMoonDelay2 = 3, 4
        local tLib1 = LibClockTST:New(tDelay1, tMoonDelay1)
        local tLib2 = LibClockTST:New(tDelay2, tMoonDelay2)
        assert.is.equal(tDelay1, tLib1.updateDelay)
        assert.is.equal(tDelay2, tLib2.updateDelay)
    end)

    it("should reference instance", function()
        local tInstance1 = LibClockTST:Instance()
        local tInstance2 = LibClockTST:Instance()
        assert.is.equal(tInstance1, tInstance2)
    end)

    it("should throw error if functions are directly accessed", function()
        local tLib = LibClockTST:New(0,0)
        assert.has_no.error(function() tLib:GetTime() end)
        assert.has_error(function() LibClockTST:GetTime() end)
    end)

    describe("const", function()

        it("should get constant table", function()
            assert.is.equal("table", type(LibClockTST.CONSTANTS()))
        end)

        it("should be objects", function()
            local tConst = LibClockTST.CONSTANTS()
            tConst.time = 1
            assert.are_not.same(tConst, LibClockTST.CONSTANTS())
        end)

    end)

    describe("time", function()

        it("should calculate time", function()
            assert.truthy(TST:GetTime())
        end)

        it("should calculate time to be midnight", function()
            local midnight = const.time.lengthOfDay * 100 + const.time.startTime
            assert.are.same(TST:GetTime(midnight), {hour = 0, minute = 0, second = 0})
        end)

    end)

    describe("date", function()

        it("should calculate date", function()
            assert.truthy(TST:GetDate())
        end)

        it("should calculate date to be 4.4.2E582", function()
            local date = const.time.lengthOfDay * 93 + const.date.startTime
            assert.are.same(TST:GetDate(date), {era = 2, year = 582, month = 4, day = 4, weekDay = 5})
        end)

    end)

    describe("moon", function()
        describe("instance with count full moon as cycle", function()
            local iTST = LibClockTST:Instance()
            it("should calculate moon", function()
                assert.truthy(iTST:GetMoon())
            end)

            it("should calculate moon to be 51% full and first quarter", function()
                local time = 1579645663
                local moon = iTST:GetMoon(time)
                assert.are.same({
                    math.floor(moon.percentageOfFullMoon*100),
                    moon.currentPhaseName}, {57, "firstQuarter"})
            end)
            it("should ne smooth if full moon phase is counted as full", function()
                local time = os.time(os.date("!*t"))
                local lastPercentage = iTST:GetMoon(time).percentageOfFullMoon
                for i=time, time + 628650, 3000 do
                    local moon = iTST:GetMoon(i)
                    assert.is_true(math.abs(lastPercentage - moon.percentageOfFullMoon) < .05)
                    lastPercentage = moon.percentageOfFullMoon
                end
            end)
        end)
        describe("new without count full moon as cycle", function()
            local nTST = LibClockTST:New(200, 3600000, false)
            it("should calculate moon", function()
                assert.truthy(nTST:GetMoon())
            end)

            it("should calculate moon to be 51% full and first quarter", function()
                local time = 1579645663
                local moon = nTST:GetMoon(time)
                assert.are.same({
                    math.floor(moon.percentageOfFullMoon*100),
                    moon.currentPhaseName}, {51, "firstQuarter"})
            end)
            it("should be smooth if only full moon is counted as full", function()
                local time = os.time(os.date("!*t"))
                local lastPercentage = nTST:GetMoon(time).percentageOfFullMoon
                for i=time, time + 628650, 3000 do
                    local moon = nTST:GetMoon(i)
                    assert.is_true(math.abs(lastPercentage - moon.percentageOfFullMoon) < .05)
                    lastPercentage = moon.percentageOfFullMoon
                end
            end)
        end)
    end)

    insulate("an insulated test", function()
        local lastEntry
        _G.d = spy.new(function(entry) lastEntry = entry  end)
        describe("commands", function()
            it("should print time object when no argument", function()
                -- arrange
                local tTime = TST:GetTime()
                -- act
                SLASH_COMMANDS["/tst"]()
                -- assert
                assert.spy(d).was_called_with(tTime)
            end)
            it("should print time object", function()
                -- arrange
                local tArg = "time"
                local tTime = TST:GetTime()
                -- act
                SLASH_COMMANDS["/tst"](tArg)
                -- assert
                assert.spy(d).was_called_with(tTime)
            end)
            it("should print a specific time object", function()
                -- arrange
                local midnight = const.time.lengthOfDay * 100 + const.time.startTime
                local tArg = "time " .. midnight
                local tTime = TST:GetTime(midnight)
                -- act
                SLASH_COMMANDS["/tst"](tArg)
                -- assert
                assert.spy(d).was_called_with(tTime)
            end)
            it("should print date object", function()
                -- arrange
                local tArg = "date"
                local tDate = TST:GetDate()
                -- act
                SLASH_COMMANDS["/tst"](tArg)
                -- assert
                assert.spy(d).was_called_with(tDate)
            end)
            it("should print a specific date object", function()
                -- arrange
                local tTime = const.date.startTime
                local tArg = "date " .. tTime
                local tDate = TST:GetDate(tTime)
                -- act
                SLASH_COMMANDS["/tst"](tArg)
                -- assert
                assert.spy(d).was_called_with(tDate)
            end)
            it("should print moon object", function()
                -- arrange
                local tArg = "moon"
                local tMoon = TST:GetMoon()
                -- act
                SLASH_COMMANDS["/tst"](tArg)
                -- assert
                assert.spy(d).was_called_with(tMoon)
            end)
            it("should print a specific moon object", function()
                -- arrange
                local tTime = const.moon.startTime
                local tArg = "moon " .. tTime
                local tMoon = TST:GetMoon(tTime)
                -- act
                SLASH_COMMANDS["/tst"](tArg)
                -- assert
                assert.spy(d).was_called_with(tMoon)
            end)
            it("should print help string", function()
                -- arrange
                local tArg = "help"
                -- act
                SLASH_COMMANDS["/tst"](tArg)
                -- assert
                assert.spy(d).called()
                assert.is_true(type(lastEntry) == "string")
            end)
        end)
    end)

    describe("subscription", function()

        local subscription = "test"
        local f = spy.new(function(_, _) end)

        describe("error", function()

            describe("register", function()

                it("should throw error if subscribing without handle", function()
                    assert.has_error(function() TST:Register(nil, f) end)
                end)

                it("should throw error if subscribing with empty handle", function()
                    assert.has_error(function() TST:Register("", f) end)
                end)

                it("should throw error if subscribing without function", function()
                    assert.has_error(function() TST:Register(subscription, nil) end)
                end)

            end)

            describe("cancel", function()
                it("should throw error if canceling without handle", function()
                    assert.has_error(function() TST:CancelSubscription(nil) end)
                end)

                it("should throw error if canceling with empty handle", function()
                    assert.has_error(function() TST:CancelSubscription("") end)
                end)

                it("should be able to register same handler after cancelation", function()
                    TST:Register(subscription, f)
                    TST:CancelSubscription(subscription)
                    assert.has_no.error(function()
                        TST:Register(subscription, f)
                    end)
                    TST:CancelSubscription(subscription)
                end)
            end)

        end)

        describe("time and date", function()

            it("should get the current time and date by update", function()
                TST:Register(subscription, f)
                local time = TST:GetTime()
                local date = TST:GetDate()
                assert.spy(f).was.called()
                assert.spy(f).was_called_with(time, date)
                TST:CancelSubscription(subscription)
            end)

            it("should get the current time by update", function()
                TST:RegisterForTime(subscription, f)
                local time = TST:GetTime()
                assert.spy(f).was.called()
                assert.spy(f).was_called_with(time)
                TST:CancelSubscriptionForTime(subscription)
            end)

            it("should get the current date by update", function()
                TST:RegisterForDate(subscription, f)
                local date = TST:GetDate()
                assert.spy(f).was.called()
                assert.spy(f).was_called_with(date)
                TST:CancelSubscriptionForDate(subscription)
            end)

        end)

        describe("moon", function()

            it("should get the current moon by update", function()
                TST:RegisterForMoon(subscription, f)
                local moon = TST:GetMoon()
                assert.spy(f).was.called()
                assert.spy(f).was_called_with(moon)
                TST:CancelSubscriptionForMoon(subscription)
            end)

        end)

    end)

end)
