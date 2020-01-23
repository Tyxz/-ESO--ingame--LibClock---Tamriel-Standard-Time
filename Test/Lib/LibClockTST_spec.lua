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
    local TST = LibClockTST
    local const = TST.CONSTANTS

    describe("time", function()

        it("should calculate time", function()
            assert.truthy(LibClockTST:GetTime())
        end)

        it("should calculate time to be midnight", function()
            local midnight = const.time.lengthOfDay * 100 + const.time.startTime
            assert.are.same(TST:GetTime(midnight), {hour = 0, minute = 0, second = 0})
        end)

    end)

    describe("date", function()

        it("should calculate date", function()
            assert.truthy(LibClockTST:GetDate())
        end)

        it("should calculate date to be 4.4.2E582", function()
            local date = const.time.lengthOfDay * 93 + const.date.startTime
            assert.are.same(TST:GetDate(date), {era = 2, year = 582, month = 4, day = 4, weekDay = 5})
        end)

    end)

    describe("moon", function()

        it("should calculate moon", function()
            assert.truthy(LibClockTST:GetMoon())
        end)

        it("should calculate moon to be 51% full and first quarter", function()
            local time = 1579645663
            local moon = TST:GetMoon(time)
            assert.are.same({ math.floor(moon.percentageOfFullMoon*100), moon.currentPhaseName}, {51, "firstQuarter"})
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

                it("should throw error if subscribing multiple times with same handle", function()
                    LibClockTST:Register(subscription, f)
                    assert.has_error(function() LibClockTST:Register(subscription, f) end)
                    LibClockTST:CancelSubscription(subscription)
                end)

                it("should throw error if subscribing without handle", function()
                    assert.has_error(function() LibClockTST:Register(nil, f) end)
                end)

                it("should throw error if subscribing with empty handle", function()
                    assert.has_error(function() LibClockTST:Register("", f) end)
                end)

                it("should throw error if subscribing without function", function()
                    assert.has_error(function() LibClockTST:Register(subscription, nil) end)
                end)

            end)

            describe("cancel", function()
                it("should throw error if canceling without handle", function()
                    assert.has_error(function() LibClockTST:CancelSubscription(nil) end)
                end)

                it("should throw error if canceling with empty handle", function()
                    assert.has_error(function() LibClockTST:CancelSubscription("") end)
                end)

                it("should be able to register same handler after cancelation", function()
                    LibClockTST:Register(subscription, f)
                    LibClockTST:CancelSubscription(subscription)
                    assert.has_no.error(function()
                        LibClockTST:Register(subscription, f)
                    end)
                    LibClockTST:CancelSubscription(subscription)
                end)
            end)

        end)

        describe("time and date", function()

            it("should get the current time and date by update", function()
                LibClockTST:Register(subscription, f)
                local time = LibClockTST:GetTime()
                local date = LibClockTST:GetDate()
                assert.spy(f).was.called()
                assert.spy(f).was_called_with(time, date)
                LibClockTST:CancelSubscription(subscription)
            end)

            it("should get the current time by update", function()
                LibClockTST:RegisterForTime(subscription, f)
                local time = LibClockTST:GetTime()
                assert.spy(f).was.called()
                assert.spy(f).was_called_with(time)
                LibClockTST:CancelSubscriptionForTime(subscription)
            end)

            it("should get the current date by update", function()
                LibClockTST:RegisterForDate(subscription, f)
                local date = LibClockTST:GetDate()
                assert.spy(f).was.called()
                assert.spy(f).was_called_with(date)
                LibClockTST:CancelSubscriptionForDate(subscription)
            end)

        end)

        describe("moon", function()

            it("should get the current moon by update", function()
                LibClockTST:RegisterForMoon(subscription, f)
                local moon = LibClockTST:GetMoon()
                assert.spy(f).was.called()
                assert.spy(f).was_called_with(moon)
                LibClockTST:CancelSubscriptionForMoon(subscription)
            end)

        end)

    end)

end)
