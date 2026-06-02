-------------------------------------------------------------------------------
-- Project: AscensionTalentManager
-- Author: Aka-DoctorCode
-- File: Core.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

local ADDON_NAME, private = ...

local ATS = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0")

private.API = {
    IsInInstance = IsInInstance,
    GetInstanceInfo = GetInstanceInfo
}

local DEFAULTS = {
    enabled = true,
    debug = false,
    minimap = true,
    minimapAngle = 220,
    perSpec = {}
}

local function EnsureDB()
    if type(AscensionTalentManagerDB) ~= "table" then
        AscensionTalentManagerDB = {}
    end
    local DB = AscensionTalentManagerDB
    for k, v in pairs(DEFAULTS) do
        if DB[k] == nil then
            DB[k] = type(v) == "table" and {} or v
        end
    end

    -- Migrate old data structure
    for specID, ctxMap in pairs(DB.perSpec) do
        if type(ctxMap) == "table" then
            for ctx, val in pairs(ctxMap) do
                if type(val) == "string" then
                    ctxMap[ctx] = { talent = strtrim(val), equip = nil }
                elseif type(val) == "table" then
                    if val.talent then val.talent = strtrim(val.talent) end
                    if val.equip then val.equip = strtrim(val.equip) end
                end
            end
        end
    end
end

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------
function private.GetConfigInfo(configID)
    if not configID then return nil end
    if C_Traits and C_Traits.GetConfigInfo then
        return C_Traits.GetConfigInfo(configID)
    end
    if C_ClassTalents and C_ClassTalents.GetConfigInfo then
        return C_ClassTalents.GetConfigInfo(configID)
    end
    return nil
end

function private.GetSpecID()
    local specIndex = GetSpecialization()
    if not specIndex then return nil end
    local id = GetSpecializationInfo(specIndex)
    return id
end

function private.CanSwapTalents()
    if InCombatLockdown() then return false end
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then return false end
    return true
end

function private.CanSwapEquipment()
    return not InCombatLockdown()
end

function private.IsCastingOrChanneling()
    return (UnitCastingInfo("player") or UnitChannelInfo("player")) ~= nil
end

local function IsLegacyLootMode()
    if C_Loot and C_Loot.IsLegacyLootModeEnabled then return C_Loot.IsLegacyLootModeEnabled() end
    if IsLegacyLootModeEnabled then return IsLegacyLootModeEnabled() end
    return false
end

local function GetCurrentContext()
    local inInstance, instanceType = private.API.IsInInstance()
    if inInstance then
        if instanceType == "pvp" or instanceType == "arena" then return "pvp" end
        if instanceType == "raid" then return IsLegacyLootMode() and "raid_legacy" or "raid" end
        if instanceType == "party" then return "dungeons" end
        if instanceType == "scenario" then return "delve" end
    end
    return "world"
end

-- -----------------------------------------------------------------------------
-- Talents
-- -----------------------------------------------------------------------------
function private.GetActiveLoadout()
    local specIndex = GetSpecialization()
    if not specIndex then return nil, nil end
    
    local specID = GetSpecializationInfo(specIndex)
    if not specID then return nil, nil end
    
    local savedID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
    local activeID = C_ClassTalents.GetActiveConfigID() or savedID
    local activeName = nil
    
    -- Prioritize the saved loadout ID since staging IDs might drop the name
    if savedID then
        local configInfo = private.GetConfigInfo(savedID)
        if configInfo and configInfo.name and strtrim(configInfo.name) ~= "" then
            activeName = configInfo.name
            activeID = savedID
        end
    end
    
    -- Fallback to activeID if the saved ID lookup fails
    if not activeName and activeID then
        local configInfo = private.GetConfigInfo(activeID)
        if configInfo and configInfo.name and strtrim(configInfo.name) ~= "" then
            activeName = configInfo.name
        end
    end
    
    return activeID, activeName
end

function private.FindLoadoutIDByName(targetName)
    if not targetName or targetName == "" then return nil end
    local specID = private.GetSpecID()
    if not specID then return nil end
    local configIDs = C_ClassTalents.GetConfigIDsBySpecID(specID)
    if not configIDs then return nil end

    local cleanTarget = strtrim(string.lower(targetName))
    for _, configID in ipairs(configIDs) do
        local info = private.GetConfigInfo(configID)
        if info and info.name and strtrim(string.lower(info.name)) == cleanTarget then
            return configID
        end
    end
    return nil
end

-- -----------------------------------------------------------------------------
-- Equipment
-- -----------------------------------------------------------------------------
function private.ListEquipSets()
    local ids = C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs and C_EquipmentSet.GetEquipmentSetIDs() or {}
    local byName = {}
    local byID = {}
    local activeID, activeName
    for _, id in ipairs(ids) do
        local info = C_EquipmentSet.GetEquipmentSetInfo(id)
        local name, icon, isEquipped
        if type(info) == "table" then
            name = info.name; icon = info.icon; isEquipped = info.isEquipped
        else
            name, icon, _, isEquipped = C_EquipmentSet.GetEquipmentSetInfo(id)
        end
        if name and name ~= "" then
            local lower = strtrim(string.lower(name))
            byName[lower] = id
            byID[id] = { name = name, icon = icon, isEquipped = isEquipped and true or false }
            if isEquipped then activeID, activeName = id, name end
        end
    end
    return byName, byID, activeID, activeName
end

function private.FindEquipSetIDByName(name)
    name = strtrim(name)
    if not name or name == "" then return nil end
    if C_EquipmentSet and C_EquipmentSet.GetEquipmentSetID then
        local id = C_EquipmentSet.GetEquipmentSetID(name)
        if id then return id end
    end
    local byName = private.ListEquipSets()
    if type(byName) == "table" then
        return byName[strtrim(string.lower(name))]
    end
    return nil
end

function private.GetActiveEquipSet()
    local _, byID, activeID, activeName = private.ListEquipSets()
    if activeID then return activeID, activeName end
    for id, data in pairs(byID or {}) do
        if data.isEquipped then return id, data.name end
    end
    return nil, nil
end

-- -----------------------------------------------------------------------------
-- Logic
-- -----------------------------------------------------------------------------
local lastContextSignature = nil
private.ignoredContextBase = nil

function private.CheckAndPromptSwitch(force)
    if not AscensionTalentManagerDB or not AscensionTalentManagerDB.enabled then return end

    local ctx = GetCurrentContext()
    local specID = private.GetSpecID()
    if not specID then return end

    if not force and private.ignoredContextBase and private.ignoredContextBase == ctx then return end
    if private.ignoredContextBase and private.ignoredContextBase ~= ctx then private.ignoredContextBase = nil end

    if not AscensionTalentManagerDB.perSpec then AscensionTalentManagerDB.perSpec = {} end
    if not AscensionTalentManagerDB.perSpec[specID] then AscensionTalentManagerDB.perSpec[specID] = {} end

    local desired = AscensionTalentManagerDB.perSpec[specID][ctx]
    if not desired or (not desired.talent and not desired.equip) then return end

    local activeTalentID, activeTalentName = private.GetActiveLoadout()
    local desiredTalentID = desired.talent and private.FindLoadoutIDByName(desired.talent) or nil
    local talentsMatch = (not desired.talent or desired.talent == "" or desired.talent == "-") or (activeTalentID == desiredTalentID)
    if desired.talent and activeTalentName then
        if strtrim(string.lower(activeTalentName)) == strtrim(string.lower(desired.talent)) then
            talentsMatch = true
        end
    end

    local activeEquipID, activeEquipName = private.GetActiveEquipSet()
    local desiredEquipID = desired.equip and private.FindEquipSetIDByName(desired.equip) or nil
    local equipMatch = (not desired.equip or desired.equip == "" or desired.equip == "-") or (activeEquipID == desiredEquipID)

    if talentsMatch and equipMatch and not force then return end

    local _, _, _, _, _, _, _, mapID = private.API.GetInstanceInfo()
    local currentSignature = string.format("%s:%s:%s:%s", ctx, tostring(mapID), tostring(desiredTalentID), tostring(desiredEquipID))

    if not force and lastContextSignature == currentSignature then return end
    lastContextSignature = currentSignature

    if private.showSwitchPrompt then
        private.showSwitchPrompt(
            ctx,
            { talent = activeTalentName or "-", equip = activeEquipName or "-" },
            { talent = desired.talent or "-", equip = desired.equip or "-" },
            { talentID = desiredTalentID, equipID = desiredEquipID, mismatchTalent = not talentsMatch, mismatchEquip = not equipMatch }
        )
    end
end

-- -----------------------------------------------------------------------------
-- Queues
-- -----------------------------------------------------------------------------
private.PendingTalent = nil
private.PendingEquip = nil

function private.CancelRetry()
    private.PendingTalent = nil
    private.PendingEquip = nil
    if private.HidePrompt then private.HidePrompt() end
end

function private.ProcessEquipQueue()
    if not private.PendingEquip then return end
    if not private.CanSwapEquipment() then return end
    if private.IsCastingOrChanneling() then
        C_Timer.After(0.4, private.ProcessEquipQueue)
        return
    end

    local id = private.PendingEquip.id
    local name = private.PendingEquip.name
    C_EquipmentSet.UseEquipmentSet(id)

    C_Timer.After(0.25, function()
        local curID = private.GetActiveEquipSet()
        if curID == id then
            -- Only print if debug mode is enabled
            if AscensionTalentManagerDB.debug then
                print("|cff33ff99ATM|r: Equipment switched to " .. (name or ("ID " .. id)))
            end
            private.PendingEquip = nil
        else
            private.PendingEquip.tries = (private.PendingEquip.tries or 0) + 1
            if private.PendingEquip.tries < 5 then
                C_Timer.After(0.5, private.ProcessEquipQueue)
            else
                -- Only print if debug mode is enabled
                if AscensionTalentManagerDB.debug then
                    print("|cff33ff99ATM|r: Equipment switch failed for " .. (name or ("ID " .. id)))
                end
                private.PendingEquip = nil
            end
        end
    end)
end

function private.ProcessTalentQueue()
    if not private.PendingTalent then return end
    if InCombatLockdown() or GetUnitSpeed("player") > 0 then return end

    local loadoutID = private.PendingTalent.id
    local specID = private.GetSpecID()
    local STARTER_BUILD_ID = (Constants and Constants.TraitConsts and Constants.TraitConsts.STARTER_BUILD_TRAIT_CONFIG_ID) or -1

    if loadoutID == STARTER_BUILD_ID then
        local loadConfigResult = C_ClassTalents.SetStarterBuildActive(true)
        
        -- In Enum.LoadConfigResult, 0 indicates an Error. 
        -- We only want to set the expected ID if the action succeeds.
        if loadConfigResult ~= 0 then 
            private.ExpectedTalentID = loadoutID
        end
        private.PendingTalent = nil
        return
    end

    if C_ClassTalents.UpdateLastSelectedSavedConfigID and specID then
        C_ClassTalents.UpdateLastSelectedSavedConfigID(specID, loadoutID)
    end
    
    local loadConfigResult = C_ClassTalents.LoadConfig(loadoutID, true)
    
    -- Ensure ExpectedTalentID is queued on success so the TRAIT_CONFIG_UPDATED event updates the UI
    if loadConfigResult ~= 0 then
        private.ExpectedTalentID = loadoutID
    end
    private.PendingTalent = nil
end

function private.RequestSwitch(talentID, talentName, equipID, equipName)
    if talentID and private.CanSwapTalents() then
        private.PendingTalent = { id = talentID, name = talentName }
        private.ProcessTalentQueue()
    end
    if equipID then
        private.PendingEquip = { id = equipID, name = equipName, tries = 0 }
        private.ProcessEquipQueue()
    end
end

-- -----------------------------------------------------------------------------
-- Ace3 Lifecycle & Events
-- -----------------------------------------------------------------------------

function ATS:OnInitialize()
    EnsureDB()
    if private.initUI then private.initUI() end
end

function ATS:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "CheckContext")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "CheckContext")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "CheckContext")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_STOPPED_MOVING")
    self:RegisterEvent("UNIT_SPELLCAST_STOP")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    self:RegisterEvent("UNIT_SPELLCAST_FAILED")
    self:RegisterEvent("TRAIT_CONFIG_UPDATED")

    if C_ChallengeMode then
        self:RegisterEvent("CHALLENGE_MODE_START", "CheckContext")
        self:RegisterEvent("CHALLENGE_MODE_COMPLETED", "CheckContext")
        self:RegisterEvent("CHALLENGE_MODE_RESET", "CheckContext")
    end

    self:RegisterChatCommand("atm", "ToggleConfig")
end

function ATS:CheckContext()
    if not private.PendingTalent and not private.PendingEquip then
        C_Timer.After(1.5, function() private.CheckAndPromptSwitch(false) end)
    end
end

function ATS:PLAYER_REGEN_ENABLED()
    private.ProcessEquipQueue()
    if private.PendingTalent then
        private.ProcessTalentQueue()
    else
        C_Timer.After(0.5, function() private.CheckAndPromptSwitch(false) end)
    end
end

function ATS:PLAYER_STOPPED_MOVING()
    if private.PendingTalent then
        private.ProcessTalentQueue()
    end
end

function ATS:UNIT_SPELLCAST_STOP(event, unit)
    if unit == "player" then private.ProcessEquipQueue() end
end

function ATS:UNIT_SPELLCAST_CHANNEL_STOP(event, unit)
    if unit == "player" then private.ProcessEquipQueue() end
end

function ATS:UNIT_SPELLCAST_INTERRUPTED(event, unit)
    if unit == "player" then
        C_Timer.After(0.5, function() private.CheckAndPromptSwitch(true) end)
        private.ExpectedTalentID = nil
    end
end

function ATS:UNIT_SPELLCAST_FAILED(event, unit)
    if unit == "player" then
        C_Timer.After(0.5, function() private.CheckAndPromptSwitch(true) end)
        private.ExpectedTalentID = nil
    end
end

function ATS:TRAIT_CONFIG_UPDATED()
    if private.ExpectedTalentID then
        local expectedID = private.ExpectedTalentID
        private.ExpectedTalentID = nil
        C_Timer.After(0.2, function()
            local specID = private.GetSpecID()
            if C_ClassTalents.UpdateLastSelectedSavedConfigID and specID then
                C_ClassTalents.UpdateLastSelectedSavedConfigID(specID, expectedID)
            end
            if PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame then
                pcall(function() 
                    if PlayerSpellsFrame.TalentsFrame.LoadSystem then
                        PlayerSpellsFrame.TalentsFrame.LoadSystem:UpdateSelection()
                    end
                    
                    -- Clear staged visual changes to reset the Apply button
                    if PlayerSpellsFrame.TalentsFrame.Rollback then
                        PlayerSpellsFrame.TalentsFrame:Rollback()
                    end
                end)
            end
        end)
    end
end

function ATS:ToggleConfig(input)
    input = strtrim(input or "")
    
    if input == "test" then
        private.CheckAndPromptSwitch(true)
    elseif input == "minimap" then
        AscensionTalentManagerDB.minimap = not AscensionTalentManagerDB.minimap
        if private.UpdateMinimapVisible then private.UpdateMinimapVisible() end
        
        -- Only print if debug mode is enabled
        if AscensionTalentManagerDB.debug then
            print("|cff33ff99ATM|r: Minimap button " .. (AscensionTalentManagerDB.minimap and "ON" or "OFF"))
        end
    else
        if private.toggleConfig then private.toggleConfig() end
    end
end
