-------------------------------------------------------------------------------
-- Project: AscensionTalentManager
-- Author: Aka-DoctorCode 
-- File: AscensionTalentManager.lua
-- Version: 12.0.0
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in 
-- derivative works without express written permission.
-------------------------------------------------------------------------------
local ADDON_NAME, private = ...
-- ==========================================================
-- AscensionTalentManager - Core
-- ==========================================================

-- Initialize the shared Core frame in the private namespace
private.Core = CreateFrame("Frame")
local ATS = private.Core

-- Default settings
local DEFAULTS = {
    enabled = true,
    debug = false,
    perSpec = {} -- Stores format: [specID] = { ["raid"] = "LoadoutName", ... }
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

-- Logging
local function Log(msg, ...)
    if AscensionTalentManagerDB and AscensionTalentManagerDB.debug then
        print("|cff00ccff[AscensionTalentManager]|r:", msg, ...)
    end
end

-- Compatibility Wrapper for WoW 11.0.7+
local function GetConfigInfo(configID)
    if not configID then return nil end
    if C_Traits and C_Traits.GetConfigInfo then
        return C_Traits.GetConfigInfo(configID)
    end
    if C_ClassTalents and C_ClassTalents.GetConfigInfo then
        return C_ClassTalents.GetConfigInfo(configID)
    end
    return nil
end

local function CanSwapTalents()
    if InCombatLockdown() then return false end
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then return false end
    return true
end

local function GetCurrentContext()
    local inInstance, instanceType = IsInInstance()
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

    -- Attempt to get the real active ID
    local activeConfigID = C_ClassTalents.GetActiveConfigID()

    -- If nil (due to unsaved changes), use the last known saved config
    if not activeConfigID then
        activeConfigID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
    end

    if activeConfigID then
        local info = GetConfigInfo(activeConfigID)
        return activeConfigID, (info and info.name) or nil
    end
    return nil, nil
end

local function FindLoadoutIDByName(targetName)
    if not targetName or targetName == "" then return nil end
    
    local specIndex = GetSpecialization()
    if not specIndex then return nil end
    
    local specID = GetSpecializationInfo(specIndex)
    if not specID then return nil end

    local configIDs = C_ClassTalents.GetConfigIDsBySpecID(specID)
    if not configIDs then return nil end

    for _, configID in ipairs(configIDs) do
        local info = GetConfigInfo(configID)
        -- Compare names ignoring case
        if info and info.name and string.lower(info.name) == string.lower(targetName) then
            return configID
        end
    end
    return nil
end

-- Core Logic
local lastContextSignature = nil

local function CheckAndPromptSwitch(force)
    -- 1. Ensure DB exists before reading 'enabled'
    if not AscensionTalentManagerDB then return end
    if not AscensionTalentManagerDB.enabled then return end
    
    if not CanSwapTalents() then return end

    local context = GetCurrentContext()
    local specIndex = GetSpecialization()
    if not specIndex then return end

    local specID = GetSpecializationInfo(specIndex)
    -- 2. Added nil check for specID to prevent indexing nil later
    if not specID then return end

    -- 3. Robust nil check for nested table initialization
    if not AscensionTalentManagerDB.perSpec then
        AscensionTalentManagerDB.perSpec = {}
    end

    if not AscensionTalentManagerDB.perSpec[specID] then
        AscensionTalentManagerDB.perSpec[specID] = {}
    end

    local desiredLoadoutName = AscensionTalentManagerDB.perSpec[specID][context]
    if not desiredLoadoutName or desiredLoadoutName == "" or desiredLoadoutName == "-" then return end

    local activeID, activeName = GetActiveLoadout()
    local desiredID = FindLoadoutIDByName(desiredLoadoutName)

    if not desiredID then return end -- Loadout does not exist (deleted or renamed)

    -- If we are already in the desired loadout, do nothing
    if activeID == desiredID and not force then return end

    -- Prevent prompt spam if it was already shown for this situation
    local _, _, _, _, _, _, _, mapID = GetInstanceInfo()
    local currentSignature = string.format("%s:%s:%s", context, tostring(mapID), tostring(desiredID))

    if not force and lastContextSignature == currentSignature then return end
    lastContextSignature = currentSignature

    -- Use the function from the private namespace
    if private.ShowSwitchPrompt then
        private.ShowSwitchPrompt(context, activeName, desiredLoadoutName, desiredID)
    end
end

-- Events
ATS:RegisterEvent("PLAYER_LOGIN")
ATS:RegisterEvent("PLAYER_ENTERING_WORLD")
ATS:RegisterEvent("ZONE_CHANGED_NEW_AREA")
ATS:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
ATS:RegisterEvent("PLAYER_REGEN_ENABLED")

ATS:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        EnsureDB()
        -- Call InitUI from private namespace
        if private.InitUI then private.InitUI() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        C_Timer.After(0.5, function() CheckAndPromptSwitch(false) end)
    else
        C_Timer.After(1.5, function() CheckAndPromptSwitch(false) end)
    end
end)

-- Slash Commands
SLASH_AscensionTalentManagerS1 = "/ats"
SLASH_AscensionTalentManagerS2 = "/AscensionTalentManagers"

SlashCmdList["AscensionTalentManagerS"] = function(msg)
    local cmd = msg:lower()
    if cmd == "debug" then
        if AscensionTalentManagerDB then
            AscensionTalentManagerDB.debug = not AscensionTalentManagerDB.debug
            print("AscensionTalentManager Debug:", AscensionTalentManagerDB.debug)
        end
    elseif cmd == "check" then
        lastContextSignature = nil
        print("AscensionTalentManager: Checking talents...")
        CheckAndPromptSwitch(true)
    else
        -- Call ToggleConfig from private namespace
        if private.ToggleConfig then private.ToggleConfig() end
    end
end
