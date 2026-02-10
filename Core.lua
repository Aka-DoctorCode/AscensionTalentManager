-------------------------------------------------------------------------------
-- Project: AscensionTalentManager
-- Author: Aka-DoctorCode 
-- File: Core.lua
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

-- Helper: Get Config Info (Shared)
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

-- Helper: Get Spec ID (Shared)
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

    -- 1. Intentamos obtener el ID activo real
    local activeID = C_ClassTalents.GetActiveConfigID()
    local activeName = nil

    -- Intentamos sacar el nombre del ID activo
    if activeID then
        local info = private.GetConfigInfo(activeID)
        if info then activeName = info.name end
    end

    -- 2. CORRECCIÓN CRITICA:
    -- Si no logramos obtener un nombre (porque activeID es temporal/nil),
    -- consultamos el "Último ID Guardado" como respaldo fiable.
    if not activeName then
        local savedID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
        if savedID then
            -- Si el activo era nil, adoptamos el guardado como el "activo" lógico
            if not activeID then activeID = savedID end
            
            -- Buscamos el nombre del guardado
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

    for _, configID in ipairs(configIDs) do
        local info = private.GetConfigInfo(configID)
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
    -- 1. Validaciones básicas
    if not AscensionTalentManagerDB or not AscensionTalentManagerDB.enabled then return end
    if not CanSwapTalents() then return end

    local context = GetCurrentContext()
    local specIndex = GetSpecialization()
    if not specIndex then return end

    local specID = GetSpecializationInfo(specIndex)
    if not specID then return end

    -- Inicializar DB si hace falta
    if not AscensionTalentManagerDB.perSpec then AscensionTalentManagerDB.perSpec = {} end
    if not AscensionTalentManagerDB.perSpec[specID] then AscensionTalentManagerDB.perSpec[specID] = {} end

    -- Obtener qué build queremos
    local desiredLoadoutName = AscensionTalentManagerDB.perSpec[specID][context]
    if not desiredLoadoutName or desiredLoadoutName == "" or desiredLoadoutName == "-" then return end

    -- Buscar el ID del build deseado
    local desiredID = FindLoadoutIDByName(desiredLoadoutName)
    if not desiredID then return end 

    -- Obtener estado actual (usando la función corregida arriba)
    local activeID, activeName = GetActiveLoadout()

    if not force then
        -- A. Si los IDs coinciden exactamente, listo.
        if activeID and activeID == desiredID then return end

        -- B. Comparación de Nombres (Blindaje contra IDs temporales)
        -- Usamos strtrim y lower para asegurar que coincidan aunque haya espacios invisibles
        if activeName and desiredLoadoutName then
            local cleanActive = strtrim(string.lower(activeName))
            local cleanDesired = strtrim(string.lower(desiredLoadoutName))
            if cleanActive == cleanDesired then return end
        end
        
        -- C. Verificación extra: El juego dice que este es el último guardado cargado
        local lastSavedID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
        if lastSavedID and lastSavedID == desiredID then return end
    end

    -- Evitar spam de la misma alerta
    local _, _, _, _, _, _, _, mapID = GetInstanceInfo()
    local currentSignature = string.format("%s:%s:%s", context, tostring(mapID), tostring(desiredID))

    if not force and lastContextSignature == currentSignature then return end
    lastContextSignature = currentSignature

    -- Mostrar alerta
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

-- ==========================================================
-- Slash Commands
-- ==========================================================
-- Definitions for the command aliases
SLASH_AscensionTalentManager1 = "/atm"

-- The key "AscensionTalentManager" must match the suffix of the variables above
SlashCmdList["AscensionTalentManager"] = function()
    -- Directly toggle the configuration UI
    if private.ToggleConfig then 
        private.ToggleConfig() 
    end
end
