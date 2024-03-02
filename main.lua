local name, _ = ...

NumyAutoMarker = CreateFrame("Frame")
local NAM = NumyAutoMarker

NAM:SetScript("OnEvent", function (self, event, ...) self[event](self, ...) end)
NAM:RegisterEvent("ADDON_LOADED")

function NAM:Initialize()
    local defaults = {
        singleTarget = {
            interval = 50,
            running = false,
            listen = false,
            useEvent = false,
            markers = {
                ["focus"] = 5,
            }
        },
        mainTanks = {
            interval = 50,
            running = false,
            listen = false,
            useEvent = false,
            markers = {
                ["MT1"] = 6,
                ["MT2"] = 2,
            }
        },
        dungeon = {
            interval = 50,
            running = false,
            listen = false,
            useEvent = false,
            markers = {
                ["tank"] = 6,
                ["heal"] = 5,
            }
        },
        -- in the future, add a custom one, where you can add any number of marker setups?
    }
    NAMDB = NAMDB or defaults
    self.db = NAMDB
    for k, v in pairs(defaults) do
        if self.db[k] == nil then
            self.db[k] = v
        end
    end
    for k, v in pairs(defaults.timer) do
        if self.db.timer[k] == nil then
            self.db.timer[k] = v
        end
    end
    for k, v in pairs(defaults.MTtimer) do
        if self.db.MTtimer[k] == nil then
            self.db.MTtimer[k] = v
        end
    end
    self.ticker = nil
    self.MTticker = nil
    self.lastMsgTime = 0
    self.lastMTMsgTime = 0

    if self.db.timer.running then
        self:StartTimer(self.db.timer.target, self.db.timer.marker, self.db.timer.interval)
    end
    if self.db.MTtimer.running then
        self:StartMTTimer(self.db.MTtimer.mark1, self.db.MTtimer.mark2, self.db.MTtimer.interval)
    end

    self:RegisterEvent("RAID_TARGET_UPDATE")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("GROUP_JOINED")


    local markersMap = {
        [1] = "Star |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t",
        [2] = "Circle |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:0|t",
        [3] = "Diamond |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:0|t",
        [4] = "Triangle |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:0|t",
        [5] = "Moon |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:0|t",
        [6] = "Square |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:0|t",
        [7] = "Cross |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:0|t",
        [8] = "Skull |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t",
    }
    local markersMapWithDisabled = Mixin({[9] = "Disabled"}, markersMap)
    local count = 1;
    local function increment() count = count+1; return count end;
    function NAM:GetSubOptions(markersMap, increment, db, typeName)
        return {
            type = "group",
            name = typeName,
            order = increment(),
            args = {
                enable = {
                    type = "toggle",
                    name = "Enable",
                    order = increment(),
                    width = "full",
                    desc = "Toggle " .. typeName,
                    descStyle = "inline",
                    get = function() return db.running or db.listen; end,
                    set = function(_, val) if(val) then self:StartTimer(db.target, db.marker, db.interval); else self:StopTimer(); end end,
                },
                useEvent = {
                    type = "toggle",
                    name = "UseEvent",
                    order = increment(),
                    width = "full",
                    desc = "Use events rather than timers",
                    descStyle = "inline",
                    get = function() return db.useEvent; end,
                    set = function(_, val) self:ToggleSingleTargetEventStyle(val); end,
                },
                interval = {
                    type = "range",
                    name = "Interval",
                    order = increment(),
                    min = 50,
                    max = 1000,
                    step = 50,
                    get = function() return db.interval; end,
                    set = function(_, val) db.interval = val; end,
                },
                marker = {
                    type = "select",
                    style = "dropdown",
                    name = "Marker",
                    values = markersMap,
                    order = increment(),
                    width = 0.75,
                    get = function() return db.marker; end,
                    set = function(_, val) db.marker = val; end,
                },
                target = {
                    type = "input",
                    name = "Marked UnitID",
                    order = increment(),
                    get = function() return db.target; end,
                    set = function(_, val) db.target = val; end,
                },
                targetDescription = {
                    type = "description",
                    name = "Check http://warcraft.wiki.gg/wiki/UnitId for info about UnitID; in addition to these you can also use 'MT1' & 'MT2' for the maintanks, and 'MA1' & 'MA2' for the mainassists",
                    order = increment(),
                },
            },
        }
    end
    local optionsTable = {
        type = "group",
        args = {
            description = {
                type = "description",
                name = "To apply any of the changes, enable and disable auto-marking.",
                order = increment(),
            },
            singleTargetMarking = self:GetSubOptions(markersMap, increment, self.db.timer, "Single Target Auto-Marking"),
            header = {
                type = "header",
                name = "Single target marking",
                order = increment(),
            },
            enable = {
                type = "toggle",
                name = "Enable",
                order = increment(),
                width = "full",
                desc = "Enables/disables single target auto-marking",
                descStyle = "inline",
                get = function() return self.db.timer.running or self.db.timer.listen; end,
                set = function(_, val) if(val) then self:StartTimer(self.db.timer.target, self.db.timer.marker, self.db.timer.interval); else self:StopTimer(); end end,
            },
            useEventST = {
                type = "toggle",
                name = "UseEvent",
                order = increment(),
                width = "full",
                desc = "Use events rather than timers (only reliable for group/raid units)",
                descStyle = "inline",
                get = function() return self.db.timer.useEvent; end,
                set = function(_, val) self:ToggleSingleTargetEventStyle(val); end,
            },
            mrker = {
                type = "select",
                style = "dropdown",
                name = "Marker",
                values = markersMap,
                order = increment(),
                width = 0.75,
                get = function() return self.db.timer.marker; end,
                set = function(_, val) self.db.timer.marker = val; end,
            },
            target = {
                type = "input",
                name = "Marked UnitID",
                order = increment(),
                get = function() return self.db.timer.target; end,
                set = function(_, val) self.db.timer.target = val; end,
            },
            targetDescription = {
                type = "description",
                name = "Check http://warcraft.wiki.gg/wiki/UnitId for info about UnitID; in addition to these you can also use 'MT1' & 'MT2' for the maintanks, and 'MA1' & 'MA2' for the mainassists",
                order = increment(),
            },
            MTheader = {
                type = "header",
                name = "Maintanks marking",
                order = increment(),
            },
            MTenable = {
                type = "toggle",
                name = "Enable",
                order = increment(),
                width = "full",
                desc = "Enables/disables maintanks auto-marking",
                descStyle = "inline",
                get = function() return self.db.MTtimer.running or self.db.MTtimer.listen; end,
                set = function(_, val) if(val) then self:StartMTTimer(self.db.MTtimer.mark1, self.db.MTtimer.mark2, self.db.MTtimer.interval); else self:StopMTTimer(); end end,
            },
            useEventMT = {
                type = "toggle",
                name = "UseEvent",
                order = increment(),
                width = "full",
                desc = "Use events rather than timers",
                descStyle = "inline",
                get = function() return self.db.MTtimer.useEvent; end,
                set = function(_, val) self:ToggleMTEventStyle(val); end,
            },
            MTmarker1 = {
                type = "select",
                style = "dropdown",
                name = "Marker for MT 1",
                values = markersMap,
                order = increment(),
                width = 0.75,
                get = function() return self.db.MTtimer.mark1; end,
                set = function(_, val) local self.db.MTtimer.mark1 = val; end,
            },
            MTmarker2 = {
                type = "select",
                style = "dropdown",
                name = "Marker for MT 2",
                values = markersMap,
                order = increment(),
                width = 0.75,
                get = function() return self.db.MTtimer.mark2; end,
                set = function(info, val) self.db.MTtimer.mark2 = val; end,
            },
        },
    }

    LibStub('AceConfig-3.0'):RegisterOptionsTable(name, optionsTable)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(name)

    SLASH_MMH1="/NAM"
    SlashCmdList["NAM"] = function(msg) LibStub("AceConfigDialog-3.0"):Open(name) end
end

function NAM:ADDON_LOADED(addon)
    if addon ~= name then
        return
    end
    self:Initialize()
    self:UnregisterEvent("ADDON_LOADED")
end

function NAM:RAID_TARGET_UPDATE()
    self:HandleEventTrigger();
end
function NAM:GROUP_ROSTER_UPDATE()
    self:HandleEventTrigger();
end
function NAM:GROUP_JOINED()
    self:HandleEventTrigger();
end

function NAM:HandleEventTrigger()
    if self.db.timer.listen then
        self:Mark(self.db.timer.target, self.db.timer.marker, true)
    end

    if self.db.MTtimer.listen then
        self:MarkMainTanks(self.db.MTtimer.mark1, self.db.MTtimer.mark2, true)
    end
end

function NAM:MarkMainTanks(mark1, mark2, calledByTimer)
    -- find out who MTs are
    local mt1, mt2 = GetPartyAssignment("MAINTANK")
    if not mt1 and not mt2 then
        --no MTs
        if (GetTime() - self.lastMTMsgTime) > 10000 then
            self.lastMTMsgTime = GetTime()
            print("NAM - Warning: There are no MainTanks set.")
        end
        return
    end

    if mt1 then
        self:Mark("raid"..mt1, tonumber(mark1), calledByTimer)
    end
    if mt2 then
        self:Mark("raid"..mt2, tonumber(mark2), calledByTimer)
    end
end

function NAM:Mark(target, marker, calledByTimer)
    target = strlower(target)
    local inParty = IsInGroup()
	local inRaid = IsInRaid()

    local mainTank1NotFound = 0;
    local mainTank2NotFound = 0;
    local mainAssist1NotFound = 0;
    local mainAssist2NotFound = 0;
    local mainTank1, mainTank2 = GetPartyAssignment("MAINTANK");
    local mainAssist1, mainAssist2 = GetPartyAssignment("MAINASSIST");
    if mainTank1 then
        target = gsub(target, "mt1", "raid"..mainTank1)
    else
        target, mainTank1NotFound = gsub(target, "mt1", "")
    end
    if mainTank2 then
        target = gsub(target, "mt2", "raid"..mainTank2)
    else
        target, mainTank2NotFound = gsub(target, "mt2", "")
    end
    if mainAssist1 then
        target = gsub(target, "ma1", "raid"..mainAssist1)
    else
        target, mainAssist1NotFound = gsub(target, "ma1", "")
    end
    if mainAssist2 then
        target = gsub(target, "ma2", "raid"..mainAssist2)
    else
        target, mainAssist2NotFound = gsub(target, "ma2", "")
    end
    if mainTank1NotFound or mainTank2NotFound or mainAssist1NotFound or mainAssist2NotFound then
        if (GetTime() - self.lastMTMsgTime) > 10000 then
            self.lastMTMsgTime = GetTime()
            print("NAM - Warning: MT1, MT2, MA1, or MA2 was used while it's not set. (target used instead:", target, ")")
        end
    end

    if not UnitExists(target) then return end

    marker = tonumber(marker)

    if calledByTimer and GetRaidTargetIndex(target) or GetRaidTargetIndex(target) == marker then
        --already marked with a marker
        return
    end

    if inRaid then
        --check if assist or lead
        local _, rank, _ = GetRaidRosterInfo(UnitInRaid("player"))
        if rank > 0 then
            SetRaidTarget(target,marker)
        else
            --not allowed, warning at most every 10 seconds
            if (GetTime() - self.lastMsgTime) > 10000 then
                self.lastMsgTime = GetTime()
                print("NAM - Warning: You need to have raid lead or assist to mark targets")
            end
        end
        return
    end

    SetRaidTarget(target, marker)
end

function NAM:ToggleMTEventStyle(useEvent)
    if useEvent then
        self.db.MTtimer.listen = self.db.MTtimer.running
        if self.db.MTtimer.running then self:StopMTTimer() end
        self.db.MTtimer.useEvent = true;
    else
        self.db.MTtimer.useEvent = false;
        if self.db.MTtimer.listen then
            self.db.MTtimer.listen = false
            self:StartMTTimer(self.db.MTtimer.mark1, self.db.MTtimer.mark2, self.db.MTtimer.interval)
        end
    end
end

function NAM:ToggleSingleTargetEventStyle(useEvent)
    if useEvent then
        self.db.timer.listen = self.db.timer.running
        if self.db.timer.running then self:StopTimer() end
        self.db.timer.useEvent = true;
    else
        self.db.timer.useEvent = false;
        if self.db.timer.listen then
            self.db.timer.listen = false
            self:StartTimer(self.db.timer.target, self.db.timer.marker, self.db.timer.interval)
        end
    end
end

function NAM:StartTimer(target, marker, msInterval, dbTable)
    if dbTable.ticker then
        dbTable:Cancel()
    end
    msInterval = tonumber(msInterval)

    local interval = (math.max(msInterval, 50) / 1000)
    dbTable.interval = msInterval
    dbTable.target = target
    dbTable.marker = marker
    dbTable.running = true
    print("Your NAM timer has been started!")

    --mark once to force the new mark to appear
    self:Mark(self.db.timer.target, self.db.timer.marker)
    if dbTable.useEvent then
        dbTable.running = false
        dbTable.listen = true
        return
    end
    dbTable.ticker = C_Timer.NewTicker(interval, function() self:Mark(dbTable.target, dbTable.marker, true) end)
end

function NAM:StopTimer(dbTable)
    print("Your NAM timer has stopped")
    dbTable.running = false
    if dbTable.useEvent then
        dbTable.listen = false
        return
    end

    if not dbTable.ticker then
        return
    end
    dbTable.ticker:Cancel()
end

function NAM:StartMTTimer(mark1, mark2, msInterval)
    if self.MTticker then
        self.MTticker:Cancel()
    end
    msInterval = tonumber(msInterval)
    local interval = (math.max(msInterval, 50) / 1000)

    mark1 = tonumber(mark1)
    mark2 = tonumber(mark2)

    self.db.MTtimer.interval = msInterval
    self.db.MTtimer.mark1 = mark1
    self.db.MTtimer.mark2 = mark2
    self.db.MTtimer.running = true
    print("Your NAM MainTank timer has been started!")

    -- mark once to force the new marks to appear
    self:MarkMainTanks(mark1, mark2)
    if self.db.MTtimer.useEvent then
        self.db.MTtimer.running = false
        self.db.MTtimer.listen = true
        return
    end
    self.MTticker = C_Timer.NewTicker(interval, function() self:MarkMainTanks(mark1, mark2, true) end)
end

function NAM:StopMTTimer()
    print("Your NAM MainTank timer has stopped")
    self.db.MTtimer.running = false
    if self.db.MTtimer.useEvent then
        self.db.MTtimer.listen = false
        return
    end

    if not self.MTticker then
        return
    end
    self.MTticker:Cancel()
end

