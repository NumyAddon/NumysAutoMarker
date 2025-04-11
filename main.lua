local name, _ = ...

--- @class NAM : AceAddon, AceEvent-3.0
local NAM = LibStub("AceAddon-3.0"):NewAddon(name, "AceEvent-3.0")
NumyAutoMarker = NAM

local DELVE_DIFFICULTY_ID = 208
local DEFAULT_INTERVAL = 50

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
local MARKERS_ORDER = {1, 2, 3, 4, 5, 6, 7, 8}
local MARKERS_ORDER_WITH_DISABLED = {0, 1, 2, 3, 4, 5, 6, 7, 8}

local CROSS = C_Texture.GetAtlasInfo('Radial_Wheel_Icon_Close')
local WIDTH_MULTIPLIER = 170

------- hack to allow tooltips to work on nameless execute icons
local MAGIC_TOOLTIP_TEXTS = {
    remove = "NumyAutoMarker_MagicTooltipRemove",
}
do
    local lastSetOwnerCall
    local ACDTooltip = LibStub("AceConfigDialog-3.0").tooltip
    hooksecurefunc(ACDTooltip, 'SetOwner', function(_, ...)
        lastSetOwnerCall = {...}
    end)
    hooksecurefunc(ACDTooltip, 'AddLine', function(tooltip, text, r, g, b, wrap)
        local title, desc
        if text == MAGIC_TOOLTIP_TEXTS.remove then
            title = "Remove"
            desc = "Remove custom auto-marker"
        end
        if title then
            -- setting text to an empty string seems to clear the owner and effectively resets the tooltip :/
            tooltip:SetOwner(unpack(lastSetOwnerCall))
            tooltip:SetText(title, 1, .82, 0, true)
            tooltip:AddLine(desc, r, g, b, wrap)
        end
    end)
end

--- @class NAM_MarkerConfig
--- @field enabled boolean
--- @field markers table<string, number>
--- @field isCustom? boolean

function NAM:OnInitialize()
    local defaults = {
        --- @type table<string, NAM_MarkerConfig>
        configurations = {
            mainTanks = {
                enabled = true,
                markers = {
                    ["MT1"] = 6,
                    ["MT2"] = 2,
                },
            },
            dungeon = {
                enabled = true,
                markers = {
                    ["tank"] = 6,
                    ["heal"] = 5,
                },
            },
        },
        customConfigsEnabled = true,
        --- @type NAM_MarkerConfig[]
        customConfigs = {
            {
                isCustom = true,
                enabled = false,
                markers = { ["focus"] = 5 },
            },
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
    --- @type table<NAM_MarkerConfig, FunctionContainer>
    self.tickers = {}

    for _, configuration in pairs(self.db.configurations) do
        if configuration.enabled then self:EnableAutoMarking(configuration) end
    end
    for _, configuration in pairs(self.db.customConfigs) do
        if self.db.customConfigsEnabled and configuration.enabled then self:EnableAutoMarking(configuration) end
    end

    self:RegisterEvent("RAID_TARGET_UPDATE")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("GROUP_JOINED")

    self:RegisterOptions()

    SLASH_NUMY_AUTO_MARKER1 = "/nam"
    SlashCmdList["NUMY_AUTO_MARKER"] = function(msg)
        local arg1, arg2, _ = strsplit(" ", msg)
        arg1 = arg1 and arg1:lower() or ''
        arg2 = arg2 and arg2:lower() or ''
        if arg1 == 'toggle' or arg1 == 't' then
            local config
            if arg2 == 'maintanks' or arg2 == 'mt' then
                config = self.db.configurations.mainTanks
            elseif arg2 == 'dungeon' or arg2 == 'd' then
                config = self.db.configurations.dungeon
            else
                local index = tonumber(arg2)
                if index and self.db.customConfigs[index] then
                    config = self.db.customConfigs[index]
                end
            end
            if not config then
                print("No automarker config found for " .. arg2)
                print("Try '/nam toggle mainTanks', '/nam toggle dungeon', or '/nam toggle 1' (or another number for custom configs)")
                print("You can also use the shorter versions '/nam t mt', '/nam t d', or '/nam t 1'")
                return
            end
            if config.enabled then
                print("Disabling auto-marking for " .. arg2)
                self:DisableAutoMarking(config)
            else
                print("Enabling auto-marking for " .. arg2)
                self:EnableAutoMarking(config)
            end
            self:RegisterOptions()

            return
        end
        Settings.OpenToCategory(self.configName)
    end
end

local initialized = false
function NAM:RegisterOptions()
    self.configName = "Numy's Auto Marker";
    if not initialized then
        initialized = true
        LibStub("AceConfig-3.0"):RegisterOptionsTable(self.configName, function() return self:GetOptionsTable() end)
        LibStub("AceConfigDialog-3.0"):AddToBlizOptions(self.configName)
    else
        LibStub("AceConfigRegistry-3.0"):NotifyChange(self.configName)
    end
end

function NAM:GetOptionsTable()
    local increment = CreateCounter()
    return {
        type = "group",
        name = self.configName,
        args = {
            description = {
                type = "description",
                name = "Units are only marked if they don't already have a marker applied, this is to prevent addons fighting over markers.",
                order = increment(),
            },
            mainTanksMarking = self:GetConfigurationOptions(
                increment(),
                self.db.configurations.mainTanks,
                "Main Tanks Auto-Marking (Raid-only)",
                "'/nam toggle maintanks' or '/nam t mt' to toggle",
                {MT1 = "Main Tank 1", MT2 = "Main Tank 2"},
                {MT1 = 1, MT2 = 2}
            ),
            dungeonMarking = self:GetConfigurationOptions(
                increment(),
                self.db.configurations.dungeon,
                "Dungeon Auto-Marking",
                "'/nam toggle dungeon' or '/nam t d' to toggle",
                {tank = "Tank", heal = "Healer"},
                {tank = 1, heal = 2}
            ),
            custom = self:GetCustomConfigurationOptions(increment(), self.db.customConfigs),
        },
    }
end

--- @param groupOrder number
---@param configurations table<string, NAM_MarkerConfig>
function NAM:GetCustomConfigurationOptions(groupOrder, configurations)
    self.newUnitMarker = self.newUnitMarker or 5

    local increment = CreateCounter()
    local subOptions = {
        type = "group",
        inline = true,
        name = "Custom Auto-Markers",
        order = groupOrder,
        args = {
            enable = {
                type = "toggle",
                name = "Enable",
                order = increment(),
                width = "full",
                desc = "Global toggle for all custom auto-markers",
                descStyle = "inline",
                get = function() return self.db.customConfigsEnabled end,
                set = function(_, val)
                    self.db.customConfigsEnabled = val
                    for _, configuration in pairs(configurations) do
                        if val and configuration.enabled then
                            self:EnableAutoMarking(configuration)
                        else
                            self:DisableAutoMarking(configuration, true)
                        end
                    end
                end,
            },
            unitIdDescription = {
                type = "description",
                name = [[Check http://warcraft.wiki.gg/wiki/UnitId for info about UnitID. Player names will often also work, but may need to include realm name.
In addition to these, you can also use 'MT1' & 'MT2' for the maintanks or 'MA1' & 'MA2' for the mainassists while in a raid group.
In dungeons, 'tank' & 'heal' can be used for the party tank/healer, and e.g. 'tank[deathknight]' & 'heal[druid]' for the tank/healer of a specific class.
You can combine these custom units with target, pet, etc. e.g. 'MA1target' would mark the target of the first main assist.]],
                order = increment(),
            },
            addCustomConfig = {
                type = "input",
                name = "Add custom unit to mark",
                order = increment(),
                get = function() return "" end,
                set = function(_, val)
                    if val == "" then return end
                    --- @type NAM_MarkerConfig
                    local newConfig = {
                        isCustom = true,
                        enabled = true,
                        markers = { [val] = self.newUnitMarker },
                    }
                    table.insert(self.db.customConfigs, newConfig)
                    self:EnableAutoMarking(newConfig)
                    self:RegisterOptions()
                end,
            },
            markerForNewUnit = {
                type = "select",
                style = "dropdown",
                name = "Marker",
                desc = "Marker to use for newly added units",
                values = MARKERS_MAP,
                sorting = MARKERS_ORDER,
                order = increment(),
                get = function() return self.newUnitMarker end,
                set = function(_, val)
                    self.newUnitMarker = val
                end,
            },
            customConfigs = {
                type = "group",
                inline = true,
                name = "",
                order = increment(),
                args = {},
            },
        },
    }

    local iconWidth = 26
    local options = subOptions.args.customConfigs;
    for index, dbTable in ipairs(configurations) do
        options.args["enable" .. index] = {
            type = "toggle",
            name = "Enable",
            desc = "Or use '/nam toggle " .. index .. "' or '/nam t " .. index .. "' in a macro",
            width = 70 / WIDTH_MULTIPLIER,
            order = increment(),
            get = function() return dbTable.enabled end,
            set = function(_, val) if(val) then self:EnableAutoMarking(dbTable) else self:DisableAutoMarking(dbTable) end end,
        };
        options.args["unit" .. index] = {
            type = "input",
            name = "Marked UnitID",
            width = 160 / WIDTH_MULTIPLIER,
            order = increment(),
            get = function() return next(dbTable.markers) end,
            set = function(_, val)
                dbTable.markers = {[val] = dbTable.markers[next(dbTable.markers)]}
                if dbTable.enabled then
                    self:EnableAutoMarking(dbTable)
                end
            end,
        };
        options.args["marker" .. index] = {
            type = "select",
            style = "dropdown",
            name = "Marker",
            values = MARKERS_MAP,
            sorting = MARKERS_ORDER,
            width = 150 / WIDTH_MULTIPLIER,
            order = increment(),
            get = function() return select(2, next(dbTable.markers)) end,
            set = function(_, val) dbTable.markers[next(dbTable.markers)] = tonumber(val) end,
        };
        options.args["remove" .. index] = {
            type = "execute",
            name = "",
            desc = MAGIC_TOOLTIP_TEXTS.remove,
            width = iconWidth / WIDTH_MULTIPLIER,
            order = increment(),
            func = function()
                self:DisableAutoMarking(dbTable)
                table.remove(self.db.customConfigs, index)
                self:RegisterOptions()
            end,
            image = CROSS.file,
            imageWidth = 16,
            imageHeight = 16,
            imageCoords = {
                CROSS.leftTexCoord, CROSS.rightTexCoord, CROSS.topTexCoord, CROSS.bottomTexCoord,
            },
        };
        options.args["spacer" .. index] = {
            order = increment(),
            name = "",
            type = "description",
            width = "full",
        };
    end

    return subOptions
end

---@param groupOrder number
---@param dbTable NAM_MarkerConfig
---@param configName string
---@param macroDesc string
---@param unitNameMap table<string, string> # unitID -> display name
---@param orderMap table<string, number> # unitID -> display order
function NAM:GetConfigurationOptions(groupOrder, dbTable, configName, macroDesc, unitNameMap, orderMap)
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
                desc = macroDesc,
                descStyle = "inline",
                get = function() return dbTable.enabled end,
                set = function(_, val) if(val) then self:EnableAutoMarking(dbTable) else self:DisableAutoMarking(dbTable) end end,
            },
        },
    }

    local orderOffset = increment()
    for k, _ in pairs(dbTable.markers) do
        subOptions.args['marker' .. k] = {
            type = "select",
            style = "dropdown",
            name = "Marker for " .. unitNameMap[k],
            values = MARKERS_MAP_WITH_DISABLED,
            sorting = MARKERS_ORDER_WITH_DISABLED,
            order = orderMap[k] + orderOffset,
            width = 0.75,
            get = function() return dbTable.markers[k] end,
            set = function(_, val) dbTable.markers[k] = tonumber(val) end,
        }
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
        if configuration.enabled then
            self:ProcessMarkers(configuration)
        end
    end
    if self.db.customConfigsEnabled then
        for _, configuration in pairs(self.db.customConfigs) do
            if configuration.enabled then
                self:ProcessMarkers(configuration)
            end
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
    local difficultyID = select(3, GetInstanceInfo())
    local checkDungeonUnits = not inRaid and IsInGroup() and (instanceType == "party" or instanceType == "scenario") and difficultyID ~= DELVE_DIFFICULTY_ID

    unitID = self:ReplaceUnitIDs(unitID, checkDungeonUnits)
    if not UnitExists(unitID) or GetRaidTargetIndex(unitID) then
        return
    end

    SetRaidTarget(unitID, marker)
end

--- @param unitID string
--- @param checkDungeonUnits boolean
--- @return string
function NAM:ReplaceUnitIDs(unitID, checkDungeonUnits)
    if checkDungeonUnits then
        local tank, heal
        local tankClass, healClass
        for _, unit in ipairs({"party1", "party2", "party3", "party4", "player"}) do
            if UnitGroupRolesAssigned(unit) == "TANK" then
                tank = unit
                tankClass = select(2, UnitClass(unit))
            elseif UnitGroupRolesAssigned(unit) == "HEALER" then
                heal = unit
                healClass = select(2, UnitClass(unit))
            end
        end
        if tank then
            unitID = gsub(unitID, ("tank%%[%s%%]"):format(tankClass:lower()), tank)
            if unitID:find("tank%[") then
                return ""
            end
            unitID = gsub(unitID, "tank", tank)
        end
        if heal then
            unitID = gsub(unitID, ("heal%%[%s%%]"):format(healClass:lower()), heal)
            if unitID:find("heal%[") then
                return ""
            end
            unitID = gsub(unitID, "heal", heal)
        end
    end
    local mainTank1, mainTank2 = GetPartyAssignment("MAINTANK")
    local mainAssist1, mainAssist2 = GetPartyAssignment("MAINASSIST")

    unitID = mainTank1 and gsub(unitID, "mt1", "raid" .. mainTank1) or unitID
    unitID = mainTank2 and gsub(unitID, "mt2", "raid" .. mainTank2) or unitID
    unitID = mainAssist1 and gsub(unitID, "ma1", "raid" .. mainAssist1) or unitID
    unitID = mainAssist2 and gsub(unitID, "ma2", "raid" .. mainAssist2) or unitID

    return unitID
end

--- @param dbTable NAM_MarkerConfig
--- @return boolean
function NAM:ShouldUseEventStyle(dbTable)
    for unitToken, _ in pairs(dbTable.markers) do
        if not (
            unitToken:find("^party%d$")
            or unitToken:find("^raid%d+$")
            or unitToken:find("^player$")
            or unitToken == "tank"
            or unitToken == "heal"
            or unitToken == "MT1"
            or unitToken == "MT2"
            or unitToken == "MA1"
            or unitToken == "MA2"
        ) then
            return false
        end
    end

    return true
end

--- @param dbTable NAM_MarkerConfig
function NAM:EnableAutoMarking(dbTable)
    if self.tickers[dbTable] then
        self.tickers[dbTable]:Cancel()
        self.tickers[dbTable] = nil
    end

    dbTable.enabled = true
    if dbTable.isCustom and not self.db.customConfigsEnabled then return end

    --mark once to force the new mark to appear
    self:ProcessMarkers(dbTable)
    if self:ShouldUseEventStyle(dbTable) then return end

    local interval = DEFAULT_INTERVAL / 1000
    self.tickers[dbTable] = C_Timer.NewTicker(interval, function()
        if dbTable.enabled and (not dbTable.isCustom or self.db.customConfigsEnabled) then
            self:ProcessMarkers(dbTable)
        end
    end)
end

--- @param dbTable NAM_MarkerConfig
function NAM:DisableAutoMarking(dbTable, noUpdate)
    if self.tickers[dbTable] then
        self.tickers[dbTable]:Cancel()
        self.tickers[dbTable] = nil
    end

    if noUpdate then return end
    dbTable.enabled = false
end
