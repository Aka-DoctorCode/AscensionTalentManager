-------------------------------------------------------------------------------
-- Project: AscensionTalentManager
-- Author: Aka-DoctorCode 
-- File: UI.lua
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
-- AscensionTalentManager - UI
-- ==========================================================
-- Shared Constants
local CONTEXT_LABELS = {
    world = "Open World",
    dungeons = "Dungeon",
    raid = "Raid",
    raid_farming = "Raid Farming",
    delve = "Delve",
    pvp = "PvP"
}

local CONTEXT_COLORS = {
    world = { 0.2, 0.6, 1.0 },
    dungeons = { 0.2, 1.0, 0.4 },
    raid = { 1.0, 0.5, 0.0 },
    raid_farming = { 0.7, 0.7, 0.7 },
    delve = { 0.8, 0.8, 0.2 },
    pvp = { 1.0, 0.2, 0.2 }
}

local ConfigFrame = nil
local PromptFrame = nil
local ActiveDropdown = nil

local function GetLoadoutNames()
    local specID = private.GetSpecID()
    if not specID then return {} end

    local names = { "-" }
    if not C_ClassTalents or not C_ClassTalents.GetConfigIDsBySpecID then return names end

    local configIDs = C_ClassTalents.GetConfigIDsBySpecID(specID)
    if not configIDs then return names end

    for _, id in ipairs(configIDs) do
        local info = private.GetConfigInfo(id)
        if info and info.name then
            table.insert(names, info.name)
        end
    end
    return names
end

-- ============================================================================
-- 1. Configuration UI (Custom Dropdowns)
-- ============================================================================

local function CreateSafeDropdown(parent, ctxKey, width)
    local frame = CreateFrame("Button", nil, parent, "BackdropTemplate")
    frame:SetSize(width, 30) -- Height 30 for larger text
    frame:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    frame:SetBackdropColor(0.15, 0.15, 0.15, 1)
    frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", 8, 0)
    text:SetPoint("RIGHT", -20, 0)
    text:SetJustifyH("LEFT")
    text:SetText("-")
    frame.Text = text

    local arrow = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arrow:SetPoint("RIGHT", -6, 0)
    arrow:SetText("v")

    local listFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
    listFrame:SetWidth(width)
    listFrame:SetFrameStrata("DIALOG")
    listFrame:Hide()
    listFrame:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    listFrame:SetBackdropColor(0.1, 0.1, 0.1, 1)
    frame.List = listFrame

    frame.UpdateSelection = function(self)
        local specID = private.GetSpecID()
        local val = "-"
        
        if specID 
        and AscensionTalentManagerDB 
        and AscensionTalentManagerDB.perSpec 
        and AscensionTalentManagerDB.perSpec[specID] then
            val = AscensionTalentManagerDB.perSpec[specID][ctxKey] or "-"
        end
        
        if self.Text then
            self.Text:SetText(val)
        end
    end

    frame:SetScript("OnClick", function(self)
        if listFrame:IsShown() then
            listFrame:Hide()
            ActiveDropdown = nil
        else
            if ActiveDropdown and ActiveDropdown ~= listFrame then ActiveDropdown:Hide() end
            local options = GetLoadoutNames()
            local buttonHeight = 25 -- Larger buttons
            listFrame:SetHeight(#options * buttonHeight + 10)

            if not self.buttons then self.buttons = {} end
            for _, b in ipairs(self.buttons) do b:Hide() end

            for i, name in ipairs(options) do
                local btn = self.buttons[i]
                if not btn then
                    btn = CreateFrame("Button", nil, listFrame)
                    btn:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight")
                    local t = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    t:SetPoint("LEFT", 8, 0)
                    btn.Text = t
                    btn:SetScript("OnClick", function(b)
                        local selected = b.Text:GetText()
                        local specID = private.GetSpecID()
                        if specID and AscensionTalentManagerDB then
                            
                            if not AscensionTalentManagerDB.perSpec then AscensionTalentManagerDB.perSpec = {} end
                            if not AscensionTalentManagerDB.perSpec[specID] then AscensionTalentManagerDB.perSpec[specID] = {} end
                            
                            AscensionTalentManagerDB.perSpec[specID][ctxKey] = (selected ~= "-") and selected or nil
                        end
                        frame:UpdateSelection()
                        listFrame:Hide()
                        ActiveDropdown = nil
                    end)
                    self.buttons[i] = btn
                end
                btn:Show()
                btn:SetSize(width - 4, buttonHeight)
                btn:SetPoint("TOPLEFT", 2, -5 - ((i - 1) * buttonHeight))
                btn.Text:SetText(name)
            end
            listFrame:Show()
            ActiveDropdown = listFrame
        end
    end)
    return frame
end

local function CreateConfigFrame()
    if ConfigFrame then return end

    ConfigFrame = CreateFrame("Frame", "ATS_ConfigFrame", UIParent, "BackdropTemplate")
    ConfigFrame:SetSize(400, 480)
    ConfigFrame:SetPoint("CENTER")
    ConfigFrame:SetMovable(true)
    ConfigFrame:EnableMouse(true)
    ConfigFrame:RegisterForDrag("LeftButton")
    
    -- Wrapped in anonymous function to prevent 'ScriptRegion' errors
    ConfigFrame:SetScript("OnDragStart", function(self) 
        self:StartMoving() 
    end)
    ConfigFrame:SetScript("OnDragStop", function(self) 
        self:StopMovingOrSizing() 
    end)

    ConfigFrame:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = false,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    ConfigFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    ConfigFrame:SetBackdropBorderColor(0.4, 0.4, 0.4)

    local title = ConfigFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("AscensionTalentManager")

    local closeBtn = CreateFrame("Button", nil, ConfigFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    local yOffset = -60
    local orderedContexts = { "world", "dungeons", "raid", "raid_farming", "delve", "pvp" }
    ConfigFrame.Dropdowns = {}

    for _, ctx in ipairs(orderedContexts) do
        local label = ConfigFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        label:SetPoint("TOPLEFT", 20, yOffset)
        label:SetText(CONTEXT_LABELS[ctx])

        local dd = CreateSafeDropdown(ConfigFrame, ctx, 160)
        dd:SetPoint("TOPRIGHT", -20, yOffset + 2)
        table.insert(ConfigFrame.Dropdowns, dd)
        yOffset = yOffset - 55
    end

    ConfigFrame:SetScript("OnShow", function()
        for _, dd in ipairs(ConfigFrame.Dropdowns) do dd:UpdateSelection() end
    end)
    ConfigFrame:Hide()
end

-- Exported to private namespace instead of global
function private.ToggleConfig()
    if not ConfigFrame then CreateConfigFrame() end
    if ConfigFrame:IsShown() then ConfigFrame:Hide() else ConfigFrame:Show() end
end

-- ============================================================================
-- 2. Prompt UI
-- ============================================================================

local function CreatePromptFrame()
    PromptFrame = CreateFrame("Frame", "ATS_PromptFrame", UIParent, "BackdropTemplate")
    PromptFrame:SetSize(350, 100) 
    PromptFrame:SetPoint("TOP", 0, -200)
    PromptFrame:SetFrameStrata("DIALOG")
    PromptFrame:EnableKeyboard(true)
    PromptFrame:SetPropagateKeyboardInput(true)

    PromptFrame:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8x8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    PromptFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    
    -- 1. Icon (Fixed size)
    local icon = PromptFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(50, 50)
    icon:SetPoint("LEFT", PromptFrame, "LEFT", 15, 0)
    PromptFrame.Icon = icon

    -- 2. Title (Constrained Width)
    local text = PromptFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    text:SetPoint("LEFT", icon, "RIGHT", 15, 10)
    text:SetWidth(240)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(true)
    PromptFrame.Title = text

    -- 3. SubText
    local subtext = PromptFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subtext:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -4)
    subtext:SetTextColor(0.7, 0.7, 0.7)
    subtext:SetJustifyH("LEFT")
    PromptFrame.SubText = subtext

    -- 4. Hint
    local hint = PromptFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    -- Anchor hint relative to bottom of frame
    hint:SetPoint("BOTTOMRIGHT", -10, 8) 
    hint:SetText("[ENTER] to Switch - [ESC] to Ignore")
    hint:SetAlpha(0.6)

    -- Logic to apply switch
    PromptFrame.ApplySwitch = function(self)
        if not self.targetLoadoutID then return end
        local result = C_ClassTalents.LoadConfig(self.targetLoadoutID, true)
        if result then
            print("|cff00ff00[AscensionTalentManager]|r Switching to " .. (self.targetName or "..."))
            local specID = private.GetSpecID()
            if specID and C_ClassTalents.UpdateLastSelectedSavedConfigID then
                C_ClassTalents.UpdateLastSelectedSavedConfigID(specID, self.targetLoadoutID)
            end
        end
        self:Hide()
    end

    PromptFrame:SetScript("OnKeyDown", function(self, key)
        if key == "ENTER" then
            self:ApplySwitch()
        elseif key == "ESCAPE" then
            self:Hide()
        end
    end)
    
    PromptFrame:Hide()
end

-- Exported to private namespace instead of global
function private.ShowSwitchPrompt(context, currentName, desiredName, desiredID)
    if not PromptFrame then CreatePromptFrame() end

    PromptFrame.targetLoadoutID = desiredID
    PromptFrame.targetName = desiredName

    local color = CONTEXT_COLORS[context] or { 1, 1, 1 }
    PromptFrame:SetBackdropBorderColor(unpack(color))
    
    -- Update Text
    PromptFrame.Title:SetText("Switch to: " .. desiredName)
    PromptFrame.SubText:SetText(CONTEXT_LABELS[context] or context)

    local _, _, _, specIcon = GetSpecializationInfo(GetSpecialization())
    PromptFrame.Icon:SetTexture(specIcon or "Interface/Icons/INV_Misc_QuestionMark")

    -- DYNAMIC SIZING LOGIC
    local titleHeight = PromptFrame.Title:GetStringHeight()
    local subHeight = PromptFrame.SubText:GetStringHeight()
    
    -- Formula: TopMargin(20) + Title(var) + Gap(4) + SubText(var) + BottomMargin(30)
    local calculatedHeight = 20 + titleHeight + 4 + subHeight + 30
    
    -- Enforce a minimum height
    if calculatedHeight < 90 then calculatedHeight = 90 end
    
    PromptFrame:SetHeight(calculatedHeight)
    PromptFrame:Show()
end

-- Exported to private namespace
function private.InitUI()
    -- Reserved for future init logic
end
