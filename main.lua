local name, _ = ...

--- @class NAM : AceAddon, AceEvent-3.0
local NAM = LibStub("AceAddon-3.0"):NewAddon(name, "AceEvent-3.0")
NumyAutoMarker = NAM

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

local CONFIG_STYLE_FIXED_UNITS = 1
local CONFIG_STYLE_CUSTOMIZABLE_UNITS = 2

local MARKERS_MAP = {
    [1] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t Star |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:0|t",
    [2] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:0|t Circle |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:0|t",
    [3] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:0|t Diamond |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:0|t",
    [4] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:0|t Triangle |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:0|t",
    [5] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:0|t Moon |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:0|t",
    [6] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:0|t Square |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:0|t",
    [7] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:0|t Cross |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:0|t",
    [8] = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t Skull |TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:0|t",
}
local MARKERS_MAP_WITH_DISABLED = Mixin({[0] = "[Disabled]"}, MARKERS_MAP)

--- @class NAM_MarkerConfig
--- @field style number
--- @field interval number
--- @field running boolean
--- @field listen boolean
--- @field useEvent boolean
--- @field markers table<string, number>

function NAM:OnInitialize()
    local defaults = {
        configurations = {
            singleTarget = {
                style = CONFIG_STYLE_CUSTOMIZABLE_UNITS,
                interval = 50,
                running = false,
                listen = false,
                useEvent = false,
                markers = {
                    ["focus"] = 5,
                }
            },
            mainTanks = {
                style = CONFIG_STYLE_FIXED_UNITS,
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
                style = CONFIG_STYLE_FIXED_UNITS,
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
        },
    }
    NAMDB = NAMDB or defaults
    self.db = NAMDB
    for k, v in pairs(defaults) do
        if self.db[k] == nil then
            self.db[k] = v
        end
    end
    for k, v in pairs(defaults.configurations) do
        if self.db.configurations[k] == nil then
            self.db.configurations[k] = v
        end
        if type(v) == "table" then
            for k2, v2 in pairs(v) do
                if self.db.configurations[k][k2] == nil then
                    self.db.configurations[k][k2] = v2
                end
            end
        end
    end
    --- @type table<NAM_MarkerConfig, cbObject>
    self.tickers = {}
    self.lastMsgTime = 0
    self.lastMTMsgTime = 0

    --- @type NAM_MarkerConfig
    for _, configuration in pairs(self.db.configurations) do
        if configuration.running then
            self:StartTimer(configuration)
        end
    end

    self:RegisterEvent("RAID_TARGET_UPDATE")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("GROUP_JOINED")

    local increment = CreateCounter()
    local optionsTable = {
        type = "group",
        args = {
            description = {
                type = "description",
                name = "To apply any of the changes, enable and disable auto-marking.",
                order = increment(),
            },
            singleTargetMarking = self:GetConfigurationOptions(increment(), self.db.configurations.singleTarget, "Single Target Auto-Marking"),
            mainTanksMarking = self:GetConfigurationOptions(
                increment(),
                self.db.configurations.mainTanks,
                "Main Tanks Auto-Marking",
                {MT1 = "Main Tank 1", MT2 = "Main Tank 2"},
                {MT1 = 1, MT2 = 2}
            ),
            dungeonMarking = self:GetConfigurationOptions(
                increment(),
                self.db.configurations.dungeon,
                "Dungeon Auto-Marking",
                {tank = "Tank", heal = "Healer"},
                {tank = 1, heal = 2}
            ),
        },
    }

    AceConfig:RegisterOptionsTable(name, optionsTable)
    AceConfigDialog:AddToBlizOptions(name)

    SLASH_NUMY_AUTO_MARKER1 = "/nam"
    SlashCmdList["NUMY_AUTO_MARKER"] = function() Settings.OpenToCategory(name) end
end

function NAM:GetConfigurationOptions(groupOrder, dbTable, configName, unitNameMap, orderMap)
    unitNameMap = unitNameMap or {}
    orderMap = orderMap or {}

    local markerSettings = {}
    local subIncrement = CreateCounter(100)
    if dbTable.style == CONFIG_STYLE_FIXED_UNITS then
        for k, _ in pairs(dbTable.markers) do
            markerSettings['marker' .. k] = {
                type = "select",
                style = "dropdown",
                name = "Marker for " .. (unitNameMap[k] or k),
                values = MARKERS_MAP_WITH_DISABLED,
                sorting = {0, 1, 2, 3, 4, 5, 6, 7, 8},
                order = orderMap[k] or subIncrement(),
                width = 0.75,
                get = function() return dbTable.markers[k] end,
                set = function(_, val) dbTable.markers[k] = tonumber(val) end,
            }
        end
    elseif dbTable.style == CONFIG_STYLE_CUSTOMIZABLE_UNITS then
        markerSettings ['targetDescription'] = {
            type = "description",
            name = "Check http://warcraft.wiki.gg/wiki/UnitId for info about UnitID. In addition to these, you can also use 'MT1' & 'MT2' for the maintanks, 'MA1' & 'MA2' for the mainassists, 'tank' & 'heal' for the party tank/healer",
            order = subIncrement(),
        }
        -- for now only support 1 unit
        markerSettings['unit_custom_unit'] = {
            type = "input",
            name = "Marked UnitID",
            order = subIncrement(),
            get = function() return next(dbTable.markers) end,
            set = function(_, val) dbTable.markers = {[val] = dbTable.markers[next(dbTable.markers)]} end,
        }
        markerSettings['marker_custom_unit'] = {
            type = "select",
            style = "dropdown",
            name = "Marker",
            values = MARKERS_MAP,
            sorting = {1, 2, 3, 4, 5, 6, 7, 8},
            order = subIncrement(),
            width = 0.75,
            get = function() return select(2, next(dbTable.markers)) end,
            set = function(_, val) dbTable.markers[next(dbTable.markers)] = tonumber(val) end,
        }
    end

    local increment = CreateCounter()
    local subOptions = {
        type = "group",
        inline = true,
        name = configName,
        order = groupOrder,
        args = {
            enable = {
                type = "toggle",
                name = "Enable",
                order = increment(),
                width = "full",
                desc = "Toggle " .. configName,
                descStyle = "inline",
                get = function() return dbTable.running or dbTable.listen end,
                set = function(_, val) if(val) then self:StartTimer(dbTable) else self:StopTimer(dbTable) end end,
            },
            useEvent = {
                type = "toggle",
                name = "UseEvent",
                order = increment(),
                width = "full",
                desc = "Use events rather than timers (recommended, but only available for group/raid units)",
                -- todo: disable if not a group/raid unit
                descStyle = "inline",
                get = function() return dbTable.useEvent end,
                set = function(_, val) self:ToggleEventStyle(dbTable, val) end,
            },
            interval = {
                type = "range",
                name = "Interval",
                order = increment(),
                -- todo: hide unless useEvent is disabled
                min = 50,
                max = 1000,
                step = 50,
                get = function() return dbTable.interval end,
                set = function(_, val) dbTable.interval = val end,
            },
        },
    }
    local currentCount = increment()
    for k, v in pairs(markerSettings) do
        v.order = currentCount + v.order
        subOptions.args[k] = v
    end

    return subOptions
end

function NAM:RAID_TARGET_UPDATE()
    RunNextFrame(function() self:HandleEventTrigger() end)
end
function NAM:GROUP_ROSTER_UPDATE()
    self:HandleEventTrigger()
end
function NAM:GROUP_JOINED()
    self:HandleEventTrigger()
end

function NAM:HandleEventTrigger()
    for _, configuration in pairs(self.db.configurations) do
        if configuration.listen then
            self:ProcessMarkers(configuration)
        end
    end
end

--- @param dbTable NAM_MarkerConfig
function NAM:ProcessMarkers(dbTable)
    for target, marker in pairs(dbTable.markers) do
        if marker > 0 then
            self:Mark(target, marker)
        end
    end
end

--- @param unitID string
--- @param checkDungeonUnits boolean
--- @return string
function NAM:ReplaceUnitIDs(unitID, checkDungeonUnits)
    if checkDungeonUnits then
        local tank, heal
        for _, unit in ipairs({"party1", "party2", "party3", "party4", "player"}) do
            if UnitGroupRolesAssigned(unit) == "TANK" then
                tank = unit
            elseif UnitGroupRolesAssigned(unit) == "HEALER" then
                heal = unit
            end
        end

        unitID = tank and gsub(unitID, "tank", tank) or unitID
        unitID = heal and gsub(unitID, "heal", heal) or unitID
    end
    local mainTank1, mainTank2 = GetPartyAssignment("MAINTANK")
    local mainAssist1, mainAssist2 = GetPartyAssignment("MAINASSIST")

    unitID = mainTank1 and gsub(unitID, "mt1", "raid" .. mainTank1) or unitID
    unitID = mainTank2 and gsub(unitID, "mt2", "raid" .. mainTank2) or unitID
    unitID = mainAssist1 and gsub(unitID, "ma1", "raid" .. mainAssist1) or unitID
    unitID = mainAssist2 and gsub(unitID, "ma2", "raid" .. mainAssist2) or unitID

    return unitID
end

--- @param unitID string
--- @param marker number
function NAM:Mark(unitID, marker)
    unitID = strlower(unitID)
	local inRaid = IsInRaid()

    if inRaid then
        --check if assist or lead
        local _, rank, _ = GetRaidRosterInfo(UnitInRaid("player"))
        if rank == 0 then return end
    end

	local _, instanceType = IsInInstance()
    local checkDungeonUnits = not inRaid and IsInGroup() and (instanceType == "party" or instanceType == "scenario")

	unitID = self:ReplaceUnitIDs(unitID, checkDungeonUnits)
    if not UnitExists(unitID) or GetRaidTargetIndex(unitID) then
        return
    end

    SetRaidTarget(unitID, marker)
end

--- @param dbTable NAM_MarkerConfig
--- @param useEvent boolean
function NAM:ToggleEventStyle(dbTable, useEvent)
    if useEvent then
        dbTable.listen = dbTable.running
        if dbTable.running then self:StopTimer(dbTable) end
        dbTable.useEvent = true
    else
        dbTable.useEvent = false
        if dbTable.listen then
            dbTable.listen = false
            self:StartTimer(dbTable)
        end
    end
end

--- @param dbTable NAM_MarkerConfig
function NAM:StartTimer(dbTable)
    if self.tickers[dbTable] then
        self.tickers[dbTable]:Cancel()
    end

    dbTable.running = true
    print("Your NAM timer has been started!")

    --mark once to force the new mark to appear
    self:ProcessMarkers(dbTable)
    if dbTable.useEvent then
        dbTable.running = false
        dbTable.listen = true
        return
    end
    local interval = dbTable.interval / 1000
    self.tickers[dbTable] = C_Timer.NewTicker(interval, function() self:ProcessMarkers(dbTable) end)
end

function NAM:StopTimer(dbTable)
    print("Your NAM timer has stopped")
    dbTable.running = false
    if dbTable.useEvent then
        dbTable.listen = false
        return
    end

    if not self.tickers[dbTable] then return end
    self.tickers[dbTable]:Cancel()
end
