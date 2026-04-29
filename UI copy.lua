--------------------------------------------------------------------------------
-- Project: AscensionTalentManager
-- Author: Aka-DoctorCode 
-- File: UI.lua
-- Version: 16
--------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in 
-- derivative works without express written permission.
--------------------------------------------------------------------------------
local ADDON_NAME, private = ...
--------------------------------------------------------------------------------
-- AscensionTalentManager - UI
--------------------------------------------------------------------------------
-- Shared Constants
local CONTEXT_LABELS = {
    world = "Open World",
    dungeons = "Dungeon",
    raid = "Raid",
    farming = "Farming",
    delve = "Delve",
    pvp = "PvP"
}

local CONTEXT_COLORS = {
    world = { 0.2, 0.8, 0.2 },    -- Green
    dungeons = { 0.2, 0.5, 0.8 }, -- Blue
    raid = { 0.8, 0.2, 0.2 },     -- Red
    farming = { 0.8, 0.7, 0.2 },  -- Gold
    delve = { 0.6, 0.2, 0.8 },    -- Purple
    pvp = { 0.8, 0.1, 0.1 }       -- Dark Red
}

local COLORS = {
    bg                = { 0.1, 0.1, 0.1, 0.95 }, -- Black
    window_border     = { 0.4, 0.4, 0.4 }, -- Gray
    text_title        = { 1.0, 0.8, 0.0 }, -- Gold
    text_normal       = { 0.9, 0.9, 0.9 }, -- White
    text_dim          = { 0.6, 0.6, 0.6 }, -- Gray
    text_highlight    = { 1.0, 1.0, 1.0 }, -- White
    input_bg          = { 0.15, 0.15, 0.15 }, -- Transparent Black
    input_border      = { 0.3, 0.3, 0.3 }, -- Gray
    input_focus       = { 0.8, 0.7, 0.2 }, -- Gold
    menu_bg           = { 0.08, 0.08, 0.08, 0.95 }, -- Black
    button_primary    = { 0.2, 0.5, 0.8 }, -- Blue
    button_normal     = { 0.3, 0.3, 0.3 }, -- Gray
    button_danger     = { 0.8, 0.2, 0.2 }, -- Red
    button_hover      = { 0.4, 0.4, 0.4 }, -- Gray
    accent            = { 0.8, 0.7, 0.2 }, -- Gold
}

--------------------------------------------------------------------------------
-- Styled Button Factory
--------------------------------------------------------------------------------

local function CreateStyledButton(parent, text, style)
    style = style or "normal"
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })

    local bgColor
    if style == "primary" then
        bgColor = COLORS.button_primary
    elseif style == "danger" then
        bgColor = COLORS.button_danger
    else
        bgColor = COLORS.button_normal
    end
    btn:SetBackdropColor(unpack(bgColor))
    btn:SetBackdropBorderColor(unpack(COLORS.window_border))

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text)
    btn.text:SetTextColor(unpack(COLORS.text_normal))

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(COLORS.button_hover))
        self.text:SetTextColor(unpack(COLORS.text_highlight))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(bgColor))
        self.text:SetTextColor(unpack(COLORS.text_normal))
    end)

    return btn
end

--------------------------------------------------------------------------------
-- Style Input Box
--------------------------------------------------------------------------------

local function StyleInputBox(editBox)
    editBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    editBox:SetBackdropColor(unpack(COLORS.input_bg))
    editBox:SetBackdropBorderColor(unpack(COLORS.input_border))
    editBox:SetTextColor(unpack(COLORS.text_normal))
    editBox:SetFontObject(GameFontHighlight)

    editBox:HookScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(unpack(COLORS.input_focus))
    end)
    editBox:HookScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(unpack(COLORS.input_border))
    end)
end

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

--------------------------------------------------------------------------------
-- 1. Configuration UI
--------------------------------------------------------------------------------

local function CreateSafeDropdown(parent, ctxKey, width)
    -- Main dropdown button
    local frame = CreateStyledButton(parent, "-", "normal")
    frame:SetSize(width, 30)
    frame:SetNormalFontObject(GameFontHighlight)

    -- Arrow
    local arrow = frame:CreateTexture(nil, "OVERLAY")
    arrow:SetSize (30, 30)
    arrow:SetPoint("RIGHT", -4, 0)
    arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    arrow:SetVertexColor(unpack(COLORS.text_dim))
    frame.arrow = arrow

    -- Dropdown list frame
    local listFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -2)
    listFrame:SetWidth(width)
    listFrame:SetFrameStrata("DIALOG")
    listFrame:Hide()
    listFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    listFrame:SetBackdropColor(unpack(COLORS.menu_bg))
    listFrame:SetBackdropBorderColor(unpack(COLORS.window_border))
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
        
        if self.text then
            self.text:SetText(val)
        end
    end

    frame:SetScript("OnClick", function(self)
        if listFrame:IsShown() then
            listFrame:Hide()
            ActiveDropdown = nil
        else
            if ActiveDropdown and ActiveDropdown ~= listFrame then ActiveDropdown:Hide() end
            local options = GetLoadoutNames()
            local buttonHeight = 25
            listFrame:SetHeight(#options * buttonHeight + 10)

            if not self.buttons then self.buttons = {} end
            for _, b in ipairs(self.buttons) do b:Hide() end

            for i, name in ipairs(options) do
                local btn = self.buttons[i]
                if not btn then
                    btn = CreateFrame("Button", nil, listFrame, "BackdropTemplate")
                    btn:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight")
                    btn:SetBackdrop({
                        bgFile = "Interface\\Buttons\\WHITE8x8",
                        edgeFile = "Interface\\Buttons\\WHITE8x8",
                        edgeSize = 1,
                    })
                    btn:SetBackdropColor(0,0,0,0)
                    
                    local t = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    t:SetPoint("LEFT", 8, 0)
                    t:SetTextColor(unpack(COLORS.text_normal))
                    btn.Text = t

                    btn:SetScript("OnEnter", function(b)
                        b:SetBackdropColor(unpack(COLORS.button_hover))
                        b.Text:SetTextColor(unpack(COLORS.text_highlight))
                    end)
                    btn:SetScript("OnLeave", function(b)
                        b:SetBackdropColor(0,0,0,0)
                        b.Text:SetTextColor(unpack(COLORS.text_normal))
                    end)

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
                btn:SetPoint("TOPLEFT", 2, -5 - ((i-1) * buttonHeight))
                btn.Text:SetText(name)
            end
            listFrame:Show()
            ActiveDropdown = listFrame
        end
    end)
    return frame
end

local TestHelpFrame = nil
local function ShowTestModePopup()
    if not TestHelpFrame then
        TestHelpFrame = CreateFrame("Frame", "ATS_TestHelp", ConfigFrame, "BackdropTemplate")
        TestHelpFrame:SetSize(320, 180)
        TestHelpFrame:SetPoint("CENTER", 0, 0)
        TestHelpFrame:SetFrameStrata("DIALOG")
        
        -- 1. Background & Border (Matching Addon Style)
        TestHelpFrame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        TestHelpFrame:SetBackdropColor(unpack(COLORS.bg))
        TestHelpFrame:SetBackdropBorderColor(unpack(COLORS.accent))
        
        -- 2. Title
        local title = TestHelpFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -15)
        title:SetText("Test Mode Enabled")
        title:SetTextColor(unpack(COLORS.text_title))
        
        -- 3. Explanation Text
        local msg = "Right-Click on any context name (e.g., 'Raid', 'PvP') in the list to simulate entering that environment.\n\nThis forces the addon to check your loadouts immediately without moving your character."
        local text = TestHelpFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("TOPLEFT", 20, -50)
        text:SetPoint("BOTTOMRIGHT", -20, 40)
        text:SetText(msg)
        text:SetJustifyH("CENTER")
        text:SetTextColor(unpack(COLORS.text_normal))
        
        -- 4. Close Button
        local btn = CreateStyledButton(TestHelpFrame, "Understood", "primary")
        btn:SetSize(120, 25)
        btn:SetPoint("BOTTOM", 0, 15)
        btn:SetScript("OnClick", function() TestHelpFrame:Hide() end)
    end
    TestHelpFrame:Show()
end

local function CreateConfigFrame()
    if ConfigFrame then return end

    ConfigFrame = CreateFrame("Frame", "ATS_ConfigFrame", UIParent, "BackdropTemplate")
    ConfigFrame:SetSize(400, 400)
    ConfigFrame:SetPoint("CENTER")
    ConfigFrame:SetMovable(true)
    ConfigFrame:EnableMouse(true)
    ConfigFrame:RegisterForDrag("LeftButton")
    
    ConfigFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    ConfigFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Backdrop
    ConfigFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    ConfigFrame:SetBackdropColor(unpack(COLORS.bg))
    ConfigFrame:SetBackdropBorderColor(unpack(COLORS.window_border))

    -- Title
    local title = ConfigFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("Ascension Talent Manager")
    title:SetTextColor(unpack(COLORS.text_title))

    -- Close button
    local closeBtn = CreateFrame("Button", nil, ConfigFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    -- Layout
    local yOffset = -60
    local orderedContexts = { "world", "dungeons", "raid", "farming", "delve", "pvp" }
    ConfigFrame.Dropdowns = {}

    for _, ctx in ipairs(orderedContexts) do
        -- Label
        local labelBtn = CreateFrame("Button", nil, ConfigFrame)
        labelBtn:SetSize(120, 20)
        labelBtn:SetPoint("TOPLEFT", 20, yOffset + 3)
        
        labelBtn.Text = labelBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        labelBtn.Text:SetPoint("LEFT")
        labelBtn.Text:SetText(CONTEXT_LABELS[ctx])
        labelBtn.Text:SetTextColor(unpack(COLORS.text_normal))

        -- Interaction Logic
        labelBtn:SetScript("OnEnter", function(self)
            if AscensionTalentManagerDB.testMode then
                self.Text:SetTextColor(unpack(COLORS.accent))
            end
        end)
        labelBtn:SetScript("OnLeave", function(self)
            self.Text:SetTextColor(unpack(COLORS.text_normal))
        end)
        labelBtn:RegisterForClicks("RightButtonUp")
        labelBtn:SetScript("OnClick", function(self, button)
            if AscensionTalentManagerDB.testMode and button == "RightButton" then
                if private.TriggerTestContext then 
                    private.TriggerTestContext(ctx) 
                else
                    print("Test.lua not loaded!")
                end
            end
        end)

        -- Dropdown
        local dd = CreateSafeDropdown(ConfigFrame, ctx, 160)
        dd:SetPoint("TOPRIGHT", -20, yOffset + 2)
        table.insert(ConfigFrame.Dropdowns, dd)
        yOffset = yOffset - 55
    end

    ConfigFrame:SetScript("OnShow", function()
        for _, dd in ipairs(ConfigFrame.Dropdowns) do dd:UpdateSelection() end
    end)

    -- Test Mode Toggle
    local testCheck = CreateFrame("CheckButton", nil, ConfigFrame, "UICheckButtonTemplate")
    testCheck:SetPoint("BOTTOMLEFT", 10, 3)
    
    testCheck.text = testCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    testCheck.text:SetPoint("LEFT", testCheck, "RIGHT", 10, 0)
    testCheck.text:SetText("Test Mode")
    
    -- Update text color based on state
    local function UpdateTestToggleColor(self)
        if self:GetChecked() then
            self.text:SetTextColor(unpack(COLORS.accent))
        else
            self.text:SetTextColor(unpack(COLORS.text_dim))
        end
    end

    testCheck.text:SetTextColor(unpack(COLORS.text_dim))

    testCheck:SetScript("OnClick", function(self)
        local enabled = self:GetChecked()
        AscensionTalentManagerDB.testMode = enabled
        UpdateTestToggleColor(self)
        
        if enabled then
            ShowTestModePopup()
        end
    end)

    ConfigFrame:HookScript("OnShow", function()
        if AscensionTalentManagerDB then
            testCheck:SetChecked(AscensionTalentManagerDB.testMode or false)
            UpdateTestToggleColor(testCheck)
        end
    end)

    ConfigFrame:Hide()
end

function private.ToggleConfig()
    if not ConfigFrame then CreateConfigFrame() end
    if ConfigFrame:IsShown() then ConfigFrame:Hide() else ConfigFrame:Show() end
end

--------------------------------------------------------------------------------
-- 2. Prompt UI
--------------------------------------------------------------------------------

function private.UpdateStatus(msg, r, g, b)
    if PromptFrame and PromptFrame.Status then
        PromptFrame.Status:SetText(msg)
        if r then PromptFrame.Status:SetTextColor(r, g, b) end
    end
end

function private.HidePrompt()
    if PromptFrame then PromptFrame:Hide() end
end

local function CreatePromptFrame()
    -- Create the main frame
    PromptFrame = CreateFrame("Frame", "ATS_PromptFrame", UIParent, "BackdropTemplate")
    PromptFrame:SetSize(350, 130)
    PromptFrame:SetPoint("TOP", 0, -200)
    PromptFrame:SetFrameStrata("DIALOG")
    PromptFrame:EnableMouse(true)

    PromptFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    PromptFrame:SetBackdropColor(unpack(COLORS.bg))
    PromptFrame:SetBackdropBorderColor(unpack(COLORS.window_border))
    
    -- Icon
    local icon = PromptFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(50, 50)
    icon:SetPoint("TOPLEFT", PromptFrame, "TOPLEFT", 20, -20)
    PromptFrame.Icon = icon

    -- Title
    local text = PromptFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    text:SetPoint("LEFT", icon, "RIGHT", 15, 10)
    text:SetWidth(240)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(true)
    text:SetTextColor(unpack(COLORS.text_title))
    PromptFrame.Title = text

    -- Subtitle
    local subtext = PromptFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subtext:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -4)
    subtext:SetTextColor(unpack(COLORS.text_dim))
    subtext:SetJustifyH("LEFT")
    PromptFrame.SubText = subtext

    -- Status Text (Added)
    local status = PromptFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("BOTTOMLEFT", 15, 15)
    status:SetWidth(200)
    status:SetJustifyH("LEFT")
    status:SetText("")
    PromptFrame.Status = status

    -- Switch Button
    local btnSwitch = CreateStyledButton(PromptFrame, "Switch", "primary")
    btnSwitch:SetSize(80, 25)
    btnSwitch:SetPoint("BOTTOMRIGHT", -10, 10)
    btnSwitch:SetFrameLevel(PromptFrame:GetFrameLevel() + 10)

    btnSwitch:SetScript("OnClick", function()
        local loadoutID = PromptFrame.targetLoadoutID
        local targetName = PromptFrame.targetName
        if not loadoutID then return end
        
        -- Delegate logic to Core
        if private.RequestLoadoutChange then
            private.RequestLoadoutChange(loadoutID, targetName)
        end
    end)

    -- Ignore/Cancel Button
    local btnIgnore = CreateStyledButton(PromptFrame, "Ignore", "danger")
    btnIgnore:SetSize(80, 25)
    btnIgnore:SetPoint("BOTTOMRIGHT", -90, 10)
    btnIgnore:SetFrameLevel(PromptFrame:GetFrameLevel() + 10)
    
    btnIgnore:SetScript("OnClick", function()
        if private.CancelRetry then private.CancelRetry() end
        PromptFrame:Hide()
    end)
    
    PromptFrame:Hide()
end

function private.ShowSwitchPrompt(context, currentName, desiredName, desiredID)
    if not PromptFrame then CreatePromptFrame() end

    PromptFrame.targetLoadoutID = desiredID
    PromptFrame.targetName = desiredName

    local color = CONTEXT_COLORS[context] or { 1, 1, 1 }
    PromptFrame:SetBackdropBorderColor(unpack(color))
    PromptFrame.SubText:SetText(CONTEXT_LABELS[context] or context)

    if PromptFrame.Status then 
        PromptFrame.Status:SetText("") 
    end
    
    -- Update Text
    PromptFrame.Title:SetText("Switch to: " .. desiredName)
    if PromptFrame.Status then PromptFrame.Status:SetText("") 
    end

    local _, _, _, specIcon = GetSpecializationInfo(GetSpecialization())
    PromptFrame.Icon:SetTexture(specIcon or "Interface/Icons/INV_Misc_QuestionMark")

    -- Dynamic height
    local titleHeight = PromptFrame.Title:GetStringHeight()
    local subHeight = PromptFrame.SubText:GetStringHeight()
    local calculatedHeight = 20 + titleHeight + 4 + subHeight + 30
    if calculatedHeight < 90 then calculatedHeight = 90 end
    
    PromptFrame:SetHeight(calculatedHeight)
    PromptFrame:Show()
end