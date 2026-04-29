-------------------------------------------------------------------------------
-- Project: AscensionTalentManager
-- Author: Aka-DoctorCode
-- File: Core.lua
-- Version: 16
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in
-- derivative works without express written permission.
-------------------------------------------------------------------------------
local ADDON_NAME, private = ...
--------------------------------------------------------------------------------
-- AscensionTalentManager - Core
--------------------------------------------------------------------------------

-- Initialize
private.Core = CreateFrame("Frame")
local ATS = private.Core

-- API Wrapper
private.API = {
    IsInInstance = IsInInstance,
    GetInstanceInfo = GetInstanceInfo
}

-- Default settings
local DEFAULTS = {
    enabled = true,
    debug = false,
    perSpec = {}
}

-- Database handling
local function EnsureDB()
    if type(AscensionTalentManagerDB) ~= "table" then
        AscensionTalentManagerDB = {}
    end
    for k, v in pairs(DEFAULTS) do
        if AscensionTalentManagerDB[k] == nil then
            AscensionTalentManagerDB[k] = v
        end
    end
end

-- Helper: Get Config Info
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

-- Helper: Get Spec ID
function private.GetSpecID()
    local specIndex = GetSpecialization()
    if not specIndex then return nil end
    local id, _ = GetSpecializationInfo(specIndex)
    return id
end

local function CanSwapTalents()
    if InCombatLockdown() then return false end
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then return false end
    return true
end

local function GetCurrentContext()
    local inInstance, instanceType = private.API.IsInInstance()
    if inInstance then
        if instanceType == "pvp" or instanceType == "arena" then
            return "pvp"
        elseif instanceType == "raid" then
            local isLegacy = false
            if C_Loot and C_Loot.IsLegacyLootModeEnabled then isLegacy = C_Loot.IsLegacyLootModeEnabled() end
            return isLegacy and "raid_farming" or "raid"
        elseif instanceType == "party" then
            return "dungeons"
        elseif instanceType == "scenario" then
            return "delve"
        end
    end
    return "world"
end

local function GetActiveLoadout()
    local specIndex = GetSpecialization()
    if not specIndex then return nil, nil end

    local specID = GetSpecializationInfo(specIndex)
    if not specID then return nil, nil end

    local activeID = C_ClassTalents.GetActiveConfigID()
    local activeName = nil

    if activeID then
        local info = private.GetConfigInfo(activeID)
        if info then activeName = info.name end
    end

    if not activeName then
        local savedID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
        if savedID then
            if not activeID then activeID = savedID end
            local info = private.GetConfigInfo(savedID)
            if info then activeName = info.name end
        end
    end

    return activeID, activeName
end

local function FindLoadoutIDByName(targetName)
    if not targetName or targetName == "" then return nil end

    local specIndex = GetSpecialization()
    if not specIndex then return nil end

    local specID = GetSpecializationInfo(specIndex)
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

-- Core Logic
local lastContextSignature = nil

local function CheckAndPromptSwitch(force)
    if not AscensionTalentManagerDB or not AscensionTalentManagerDB.enabled then return end
    if not CanSwapTalents() then return end

    local context = GetCurrentContext()
    local specIndex = GetSpecialization()
    if not specIndex then return end

    local specID = GetSpecializationInfo(specIndex)
    if not specID then return end

    if not AscensionTalentManagerDB.perSpec then AscensionTalentManagerDB.perSpec = {} end
    if not AscensionTalentManagerDB.perSpec[specID] then AscensionTalentManagerDB.perSpec[specID] = {} end

    local desiredLoadoutName = AscensionTalentManagerDB.perSpec[specID][context]
    if not desiredLoadoutName or desiredLoadoutName == "" or desiredLoadoutName == "-" then return end

    local desiredID = FindLoadoutIDByName(desiredLoadoutName)
    if not desiredID then return end

    local activeID, activeName = GetActiveLoadout()

    if not force then
        if activeID and activeID == desiredID then return end

        if activeName and desiredLoadoutName then
            local cleanActive = strtrim(string.lower(activeName))
            local cleanDesired = strtrim(string.lower(desiredLoadoutName))
            if cleanActive == cleanDesired then return end
        end

        local lastSavedID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
        if lastSavedID and lastSavedID == desiredID then return end
    end

    local _, _, _, _, _, _, _, mapID = private.API.GetInstanceInfo()
    local currentSignature = string.format("%s:%s:%s:%s", context, tostring(mapID), tostring(desiredID),
        tostring(activeID or "nil"))

    if not force and lastContextSignature == currentSignature then return end
    lastContextSignature = currentSignature

    if private.ShowSwitchPrompt then
        private.ShowSwitchPrompt(context, activeName or "Unknown", desiredLoadoutName, desiredID)
    end
end

-- Events
ATS:RegisterEvent("PLAYER_LOGIN")
ATS:RegisterEvent("PLAYER_ENTERING_WORLD")
ATS:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ATS:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ATS:RegisterEvent("PLAYER_REGEN_ENABLED")
ATS:RegisterEvent("PLAYER_STOPPED_MOVING")

--------------------------------------------------------------------------------
-- Retry / Persistence Logic
--------------------------------------------------------------------------------
private.PendingLoadout = nil

function private.CancelRetry()
    private.PendingLoadout = nil
    if private.UpdateStatus then private.UpdateStatus("") end
    if private.HidePrompt then private.HidePrompt() end
end

local function ProcessRetry()
    if not private.PendingLoadout then return end

    -- 1. Check Combat
    if InCombatLockdown() then
        if private.UpdateStatus then
            private.UpdateStatus("Paused: In Combat...", 1, 0.2, 0.2)
        end
        return
    end

    -- 2. Check Movement
    if GetUnitSpeed("player") > 0 then
        if private.UpdateStatus then
            private.UpdateStatus("Paused: Moving...", 1, 0.8, 0.0)
        end
        return
    end

    -- 3. Attempt Switch
    if private.UpdateStatus then private.UpdateStatus("Attempting switch...", 1, 1, 1) end

    local loadoutID = private.PendingLoadout.id
    local specID = private.GetSpecID()
    local STARTER_BUILD_ID = (Constants and Constants.TraitConsts and Constants.TraitConsts.STARTER_BUILD_TRAIT_CONFIG_ID) or
    -1

    if loadoutID == STARTER_BUILD_ID then
        local result = C_ClassTalents.SetStarterBuildActive(true)
        if result == 0 then
            private.CancelRetry()
        else
            if private.UpdateStatus then private.UpdateStatus("Failed to set Starter Build", 1, 0, 0) end
        end
        return
    end

    local result = C_ClassTalents.LoadConfig(loadoutID, true)

    if result == 0 then
        -- Success
        if C_ClassTalents.UpdateLastSelectedSavedConfigID and specID then
            C_ClassTalents.UpdateLastSelectedSavedConfigID(specID, loadoutID)
        end
        if PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame and PlayerSpellsFrame.TalentsFrame.LoadSystem then
            pcall(function() PlayerSpellsFrame.TalentsFrame.LoadSystem:SetSelectionID(loadoutID) end)
        end
        private.CancelRetry()
    elseif result == 4 then
        -- Busy
        if private.UpdateStatus then private.UpdateStatus("System Busy, Retrying...", 1, 1, 0) end
    else
        -- Other error
        if private.UpdateStatus then private.UpdateStatus("Error " .. tostring(result) .. ". Retrying...", 1, 0, 0) end
    end
end

function private.RequestLoadoutChange(id, name)
    private.PendingLoadout = { id = id, name = name }
    ProcessRetry()
end

ATS:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        EnsureDB()
        if private.initUI then private.initUI() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if private.PendingLoadout then
            ProcessRetry()
        else
            C_Timer.After(0.5, function() CheckAndPromptSwitch(false) end)
        end
    elseif event == "PLAYER_STOPPED_MOVING" then
        if private.PendingLoadout then
            ProcessRetry()
        end
    else
        if not private.PendingLoadout then
            C_Timer.After(1.5, function() CheckAndPromptSwitch(false) end)
        end
    end
end)

--------------------------------------------------------------------------------
-- Slash Commands
--------------------------------------------------------------------------------
-- the command is not working, it is not opening the config frame
SLASH_AscensionTalentManager1 = "/atm"

SlashCmdList["AscensionTalentManager"] = function()
    if private.toggleConfig then
        private.toggleConfig()
    end
end
