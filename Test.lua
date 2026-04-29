-------------------------------------------------------------------------------
-- Project: AscensionTalentManager
-- Author: Aka-DoctorCode 
-- File: Test.lua
-- Version: 16
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in 
-- derivative works without express written permission.
-------------------------------------------------------------------------------
local ADDON_NAME, private = ...

-- Function called by UI buttons when Test Mode is active
function private.TriggerTestContext(context)
    -- 1. Mock the API
    _G.IsInInstance = function()
        if context == "world" then return false, "" end
        if context == "pvp" then return true, "pvp" end
        if context == "raid" then return true, "raid" end
        if context == "dungeons" then return true, "party" end
        if context == "delve" then return true, "scenario" end
        return false, ""
    end

    _G.GetInstanceInfo = function()
        return "Simulated Zone", (context == "world" and "none" or context), 0, "", 0, 0, 0, 999
    end

    -- 2. Force Addon Update
    if private.Core then
        private.Core:GetScript("OnEvent")(private.Core, "ZONE_CHANGED_NEW_AREA")
    end
end

local ATS = private.Core
if not ATS then return end

--------------------------------------------------------------------------------
-- Simulation Mocking Logic
--------------------------------------------------------------------------------

local currentTestContext = "world"

local function SetMockContext(contextType)
    currentTestContext = contextType
    
    _G.IsInInstance = function()
        if contextType == "world" then return false, "" end
        if contextType == "pvp" then return true, "pvp" end
        if contextType == "raid" then return true, "raid" end
        if contextType == "dungeons" then return true, "party" end
        if contextType == "delve" then return true, "scenario" end
        return false, ""
    end

    _G.GetInstanceInfo = function()
        return "Test Map", contextType, 0, "", 0, 0, 0, 1234
    end

    print("|cff00ccff[ATM Test]|r Context set to: " .. contextType)
    
    ATS:GetScript("OnEvent")(ATS, "ZONE_CHANGED_NEW_AREA")
end

--------------------------------------------------------------------------------
-- Test Mode Interactive Logic
--------------------------------------------------------------------------------

-- Popup explanation
function private.ShowTestModePopup()
    StaticPopupDialogs["ATM_TEST_MODE_HELP"] = {
        text = "Test Mode Active!\n\nIn this mode, clicking on the context names (e.g., 'Open World', 'Raid') in the main window will simulate entering that environment.\n\nThis allows you to verify if the addon correctly detects your settings and prompts for the right loadout.",
        button1 = "Got it",
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("ATM_TEST_MODE_HELP")
end

-- Function called by UI labels when clicked in test mode
function private.TriggerTestContext(context)
    _G.IsInInstance = function()
        if context == "world" then return false, "" end
        if context == "pvp" then return true, "pvp" end
        if context == "raid" then return true, "raid" end
        if context == "dungeons" then return true, "party" end
        if context == "delve" then return true, "scenario" end
        return false, ""
    end

    _G.GetInstanceInfo = function()
        return "Test Zone", (context == "world" and "none" or context), 0, "", 0, 0, 0, 999
    end

    if private.Core then
        private.Core:GetScript("OnEvent")(private.Core, "ZONE_CHANGED_NEW_AREA")
    end
    
    print("|cff00ccff[ATM Test]|r Simulated context change to: " .. context)
end