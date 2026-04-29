-------------------------------------------------------------------------------
-- Project: AscensionTalentManager
-- Author: Aka-DoctorCode
-- File: UI.lua
-- Version: 16
-------------------------------------------------------------------------------
-- Copyright (c) 2025–2026 Aka-DoctorCode. All Rights Reserved.
--
-- This software and its source code are the exclusive property of the author.
-- No part of this file may be copied, modified, redistributed, or used in
-- derivative works without express written permission.z
-------------------------------------------------------------------------------
local ADDON_NAME, private = ...

-------------------------------------------------------------------------------
-- 1. Global Variables
-------------------------------------------------------------------------------

local activeDropdown = nil
local configFrame = nil
local testHelpFrame = nil
local promptFrame = nil

local COLORS = {
    primary = { 0.498, 0.075, 0.925, 1.0 },           -- #7f13ec
    gold = { 1.000, 0.800, 0.200, 1.0 },              -- #ffcc33
    world_green = { 0.267, 1.000, 0.267, 1.0 },       -- #44ff44
    dungeon_blue = { 0.235, 0.509, 0.960, 1.0 },      -- #3fb3ff
    raid_red = { 1.000, 0.267, 0.267, 1.0 },          -- #ff4444
    farming_orange = { 0.917, 0.796, 0.235, 1.0 },    -- #ffd966
    delve_violet = { 0.659, 0.333, 0.969, 1.0 },      -- #a855f7
    pvp_orange = { 0.960, 0.545, 0.223, 1.0 },        -- #f7833f
    danger = { 0.8, 0.2, 0.2, 1 },                    -- #CC3333FF

    background_dark = { 0.020, 0.020, 0.031, 0.95 },  -- #050508
    surface_dark = { 0.047, 0.039, 0.082, 1.0 },      -- #0c0a15
    surface_highlight = { 0.165, 0.141, 0.239, 1.0 }, -- #2a243d
    black_detail = { 0.0, 0.0, 0.0, 1.0 },            -- #000000
    white_detail = { 1, 1, 1, 1 },                    -- #ffffff
    text_light = { 0.886, 0.910, 0.941, 1.0 },        -- #e2e8f0
    text_dim = { 0.580, 0.640, 0.720, 1.0 },          -- #9ca3af
}

local CONTEXT_METADATA = {
    world = {
        label = "Open World",
        desc = "Questing & Exploration",
        color = COLORS.world_green -- #44ff44
    },
    dungeon = {
        label = "Dungeon",
        desc = "5-Man Content",
        color = COLORS.dungeon_blue -- #3fb3ff
    },
    raid = {
        label = "Raid",
        desc = "Boss Encounters",
        color = COLORS.raid_red -- #ff4444
    },
    farming = {
        label = "Farming",
        desc = "Material Gathering",
        color = COLORS.farming_orange -- #ffd966
    },
    delve = {
        label = "Delve",
        desc = "Solo Challenges",
        color = COLORS.delve_violet -- #a855f7
    },
    pvp = {
        label = "PvP",
        desc = "Arena & Battlegrounds",
        color = COLORS.pvp_orange -- #f7833f
    },
}

local FILES = {
    bgfile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgefile = "Interface\\Tooltips\\UI-Tooltip-Border",
    arrow = "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up",
    white8x8 = "Interface\\Buttons\\WHITE8X8",
    questionmark = "Interface/Icons/INV_Misc_QuestionMark",
}

-------------------------------------------------------------------------------
-- 2. Helper Functions
-------------------------------------------------------------------------------
local function GetLoadoutNames()
    local specID = private.GetSpecID()
    if not specID then return {} end
    local names = { "-" }
    if not C_ClassTalents or not C_ClassTalents.GetConfigIDsBySpecID then return names end
    local configIDs = C_ClassTalents.GetConfigIDsBySpecID(specID)
    if not configIDs then return names end
    for _, id in ipairs(configIDs) do
        local info = private.GetConfigInfo(id)
        if info and info.name then table.insert(names, info.name) end
    end
    return names
end

-------------------------------------------------------------------------------
-- 3. Visual Components
-------------------------------------------------------------------------------

local function CreateButton(parent, text, customColor)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")

    btn:SetBackdrop({ bgFile = FILES.bgfile, edgeFile = FILES.edgefile, edgeSize = 12, insets = { left = 2, right = 2, top = 2, bottom = 2 } })

    local color = COLORS.surface_highlight
    if customColor then
        if type(customColor) == "string" and COLORS[customColor] then
            color = COLORS[customColor]
        elseif type(customColor) == "table" then
            color = customColor
        end
    end

    btn:SetBackdropColor(unpack(color))                     -- #e2e8f0
    btn:SetBackdropBorderColor(unpack(COLORS.black_detail)) -- #000000

    -- Background color
    btn.bgColor = color

    -- Text
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text)
    btn.text:SetTextColor(unpack(COLORS.text_light))

    -- Button color change on hover
    btn:SetScript("OnEnter", function(self)
        local r, g, b = unpack(COLORS.primary)
        self:SetBackdropColor(math.min(r + 0.1, 1), math.min(g + 0.1, 1), math.min(b + 0.1, 1), 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(self.bgColor))
    end)

    return btn
end

local function CreateDropdown(parent, ctxKey, width)
    local frame = CreateFrame("Button", nil, parent, "BackdropTemplate")
    frame:SetSize(width, 24)
    frame:SetBackdrop({ bgFile = FILES.bgfile, edgeFile = FILES.edgefile, edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    frame:SetBackdropColor(unpack(COLORS.surface_highlight))  -- #e2e8f0
    frame:SetBackdropBorderColor(unpack(COLORS.black_detail)) -- #000000

    -- Text Label
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    frame.text:SetPoint("LEFT", 10, 0)
    frame.text:SetPoint("RIGHT", -20, 0)
    frame.text:SetJustifyH("LEFT")
    frame.text:SetTextColor(unpack(COLORS.text_light)) -- #e2e8f0
    frame.text:SetText("-")

    -- Arrow
    local arrow = frame:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(20, 20)
    arrow:SetPoint("RIGHT", -5, 0)
    arrow:SetTexture(FILES.arrow)
    arrow:SetDesaturated(true)
    arrow:SetVertexColor(unpack(COLORS.white_detail)) -- #ffffff

    -- Dropdown List
    local listFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    listFrame:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -2)
    listFrame:SetWidth(width + 40)
    listFrame:SetFrameStrata("DIALOG")
    listFrame:Hide()
    listFrame:SetBackdrop({ bgFile = FILES.bgfile, edgeFile = FILES.edgefile, edgeSize = 12, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    listFrame:SetBackdropColor(unpack(COLORS.surface_dark))            -- #0c0a15
    listFrame:SetBackdropBorderColor(unpack(COLORS.surface_highlight)) -- #2a243d

    frame.UpdateSelection = function(self)
        local specID = private.GetSpecID()
        local val = "-"
        if specID and AscensionTalentManagerDB and AscensionTalentManagerDB.perSpec and AscensionTalentManagerDB.perSpec[specID] then
            val = AscensionTalentManagerDB.perSpec[specID][ctxKey] or "-"
        end
        self.text:SetText(val)
    end

    frame:SetScript("OnClick", function(self)
        if listFrame:IsShown() then
            listFrame:Hide()
            activeDropdown = nil
        else
            if activeDropdown and activeDropdown ~= listFrame then activeDropdown:Hide() end
            local options = GetLoadoutNames()
            local buttonHeight = 24
            listFrame:SetHeight(#options * buttonHeight + 10)

            if not self.buttons then self.buttons = {} end
            for _, b in ipairs(self.buttons) do b:Hide() end

            for i, name in ipairs(options) do
                local btn = self.buttons[i]
                if not btn then
                    btn = CreateFrame("Button", nil, listFrame, "BackdropTemplate")
                    btn:SetBackdrop({ bgFile = FILES.bgfile })
                    btn:SetBackdropColor(unpack(COLORS.black_detail)) -- #000000

                    -- List Item Text
                    local t = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    t:SetPoint("LEFT", 8, 0)
                    t:SetTextColor(unpack(COLORS.text_light)) -- #e2e8f0
                    btn.text = t

                    btn:SetScript("OnEnter", function(b)
                        b:SetBackdropColor(unpack(COLORS.surface_highlight)) -- #2a243d
                        b.text:SetTextColor(unpack(COLORS.text_light))       -- #e2e8f0
                    end)
                    btn:SetScript("OnLeave", function(b)
                        b:SetBackdropColor(unpack(COLORS.black_detail)) -- #000000
                        b.text:SetTextColor(unpack(COLORS.text_light))  -- #e2e8f0
                    end)

                    btn:SetScript("OnClick", function(b)
                        local selected = b.text:GetText()
                        local specID = private.GetSpecID()
                        if specID and AscensionTalentManagerDB then
                            if not AscensionTalentManagerDB.perSpec then AscensionTalentManagerDB.perSpec = {} end
                            if not AscensionTalentManagerDB.perSpec[specID] then AscensionTalentManagerDB.perSpec[specID] = {} end
                            AscensionTalentManagerDB.perSpec[specID][ctxKey] = (selected ~= "-") and selected or nil
                        end
                        frame:UpdateSelection()
                        listFrame:Hide()
                        activeDropdown = nil
                    end)
                    self.buttons[i] = btn
                end
                btn:Show()
                btn:SetSize(listFrame:GetWidth(), buttonHeight)
                btn:SetPoint("TOPLEFT", 0, -5 - ((i - 1) * buttonHeight))
                btn.text:SetText(name)
            end
            listFrame:Show()
            activeDropdown = listFrame
        end
    end)
    return frame
end

--------------------------------------------------------------------------------
-- 4. Test Mode Popup
--------------------------------------------------------------------------------

local function ShowTestModePopup()
    if not testHelpFrame then
        testHelpFrame = CreateFrame("Frame", "ATS_TestHelp", configFrame or UIParent, "BackdropTemplate")
        testHelpFrame:SetSize(250, 100)
        testHelpFrame:SetPoint("CENTER", 0, 0)
        testHelpFrame:SetFrameStrata("DIALOG")
        testHelpFrame:RegisterForDrag("LeftButton")
        testHelpFrame:SetMovable(true)
        testHelpFrame:EnableMouse(true)
        testHelpFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        testHelpFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        testHelpFrame:SetBackdrop({ bgFile = FILES.bgfile, edgeFile = FILES.edgefile, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        testHelpFrame:SetBackdropColor(unpack(COLORS.surface_dark))
        testHelpFrame:SetBackdropBorderColor(unpack(COLORS.gold))

        local title = testHelpFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOP", 0, -10)
        title:SetText("Test Mode Enabled")
        title:SetTextColor(unpack(COLORS.gold))

        local text = testHelpFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("TOP", 0, -30)
        text:SetWidth(200)
        text:SetText("Click one of the context cards to simulate a loadout change.")
        text:SetJustifyH("CENTER")
        text:SetJustifyV("MIDDLE")
        text:SetTextColor(unpack(COLORS.text_light))

        local btn = CreateButton(testHelpFrame, "OK", "GameFontNormal")
        btn:SetSize(80, 24)
        btn:SetPoint("BOTTOM", 0, 5)
        btn:SetScript("OnClick", function() testHelpFrame:Hide() end)
    end
    testHelpFrame:Show()
end

-------------------------------------------------------------------------------
-- 5. Main Window
-------------------------------------------------------------------------------

local function createConfigFrame()
    if configFrame then return end

    configFrame = CreateFrame("Frame", "ATS_configFrame", UIParent, "BackdropTemplate")
    configFrame:SetSize(350, 450)
    configFrame:SetPoint("CENTER")
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")

    configFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    configFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    configFrame:SetBackdrop({
        bgFile = FILES.bgfile,
        edgeFile = FILES.edgefile,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    configFrame:SetBackdropColor(unpack(COLORS.background_dark))         -- #050508
    configFrame:SetBackdropBorderColor(unpack(COLORS.surface_highlight)) -- #2a243d

    -- Header
    local header = CreateFrame("Frame", nil, configFrame)
    header:SetSize(340, 40)
    header:SetPoint("TOP", 0, -5)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("CENTER", 0, 0)
    title:SetText("Ascension Talent Manager")
    title:SetTextColor(unpack(COLORS.text_light)) -- #e2e8f0

    -- Close Button
    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetFrameLevel(header:GetFrameLevel() + 10)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPoint("RIGHT", -10, 0)

    local closeIcon = closeBtn:CreateTexture(nil, "OVERLAY")
    closeIcon:SetAllPoints()
    closeIcon:SetTexture(130833)
    closeIcon:SetDesaturated(true)

    closeBtn:SetScript("OnClick", function()
        if configFrame then
            configFrame:Hide()
        end
    end)

    -- Separator
    local separator = header:CreateTexture(nil, "ARTWORK")
    separator:SetHeight(1)
    separator:SetPoint("BOTTOMLEFT", 10, 0)
    separator:SetPoint("BOTTOMRIGHT", -10, 0)
    separator:SetColorTexture(unpack(COLORS.surface_highlight)) -- #2a243d

    -- Cards List
    local orderedContexts = { "world", "dungeon", "raid", "farming", "delve", "pvp" }
    configFrame.dropdowns = {}
    configFrame.contextCards = {}

    local startY = -35
    local cardHeight = 55
    local gap = 4

    for i, ctx in ipairs(orderedContexts) do
        local meta = CONTEXT_METADATA[ctx]

        local card = CreateFrame("Frame", nil, configFrame, "BackdropTemplate")
        card:SetSize(330, cardHeight)
        card:SetPoint("TOP", 0, startY - ((i - 1) * (cardHeight + gap)))

        card:SetBackdrop({
            bgFile = FILES.bgfile,
            edgeFile = FILES.edgefile,
            edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        card:SetBackdropColor(unpack(COLORS.surface_dark))            -- #0c0a15
        card:SetBackdropBorderColor(unpack(COLORS.surface_highlight)) -- #2a243d

        local nameText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        nameText:SetPoint("TOPLEFT", card, "TOPLEFT", 15, -8)
        nameText:SetText(meta.label)
        nameText:SetTextColor(unpack(COLORS.text_light)) -- #e2e8f0

        local descText = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        descText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -2)
        descText:SetText(meta.desc)
        descText:SetTextColor(unpack(COLORS.text_dim)) -- #9ca3af

        local dd = CreateDropdown(card, ctx, 150)
        dd:SetPoint("TOPRIGHT", -8, -5)
        table.insert(configFrame.dropdowns, dd)

        card:EnableMouse(true)
        card:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(unpack(meta.color))
        end)
        card:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(unpack(COLORS.surface_highlight)) -- #2a243d
        end)
        card:SetScript("OnMouseDown", function(self, button)
            if AscensionTalentManagerDB and AscensionTalentManagerDB.testMode then
                if private.TriggerTestContext then
                    private.TriggerTestContext(ctx)
                    self:SetBackdropColor(meta.color[1] * 0.3, meta.color[2] * 0.3, meta.color[3] * 0.3, 0.8)
                    C_Timer.After(0.2, function()
                        self:SetBackdropColor(unpack(COLORS.surface_dark)) -- #0c0a15
                    end)
                end
            end
        end)

        configFrame.contextCards[ctx] = card
    end

    -- Footer
    local footer = CreateFrame("Frame", nil, configFrame, "BackdropTemplate")
    footer:SetSize(330, 50)
    footer:SetPoint("BOTTOM", 0, 15)

    footer:SetBackdrop({
        bgFile = FILES.bgfile,
        edgeFile = FILES.edgefile,
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    footer:SetBackdropColor(COLORS.surface_dark[1] + 0.05, COLORS.surface_dark[2] + 0.05, COLORS.surface_dark[3] + 0.05,
        1)
    footer:SetBackdropBorderColor(unpack(COLORS.gold))

    local testIcon = footer:CreateTexture(nil, "ARTWORK")
    testIcon:SetTexture(134939)
    testIcon:SetSize(20, 20)
    testIcon:SetPoint("LEFT", 15, 0)

    local testTitle = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    testTitle:SetPoint("LEFT", testIcon, "RIGHT", 10, 0)
    testTitle:SetText("Test Mode")
    testTitle:SetTextColor(unpack(COLORS.gold))

    local toggle = CreateFrame("CheckButton", nil, footer, "UICheckButtonTemplate")
    toggle:SetPoint("RIGHT", -10, 0)
    toggle.text:SetText("")

    toggle:SetScript("OnClick", function(self)
        local enabled = self:GetChecked()
        AscensionTalentManagerDB.testMode = enabled
        if enabled then ShowTestModePopup() end
    end)
    configFrame.testToggle = toggle

    configFrame:SetScript("OnShow", function()
        for _, dd in ipairs(configFrame.dropdowns) do dd:UpdateSelection() end
        if AscensionTalentManagerDB then
            configFrame.testToggle:SetChecked(AscensionTalentManagerDB.testMode or false)
        end
    end)

    configFrame:Hide()
end

function private.toggleConfig()
    if not configFrame then
        createConfigFrame()
    end
    if configFrame then
        if configFrame:IsShown() then
            configFrame:Hide()
        else
            configFrame:Show()
        end
    end
end

function private.initUI()
    if not configFrame then
        createConfigFrame()
    end
end

-------------------------------------------------------------------------------
-- 6. Prompt
-------------------------------------------------------------------------------

function private.HidePrompt()
    if promptFrame then promptFrame:Hide() end
end

local function createpromptFrame()
    if promptFrame then return end

    -- Main Frame
    promptFrame = CreateFrame("Frame", "ATS_promptFrame", UIParent, "BackdropTemplate")
    promptFrame:SetSize(340, 120)
    promptFrame:SetPoint("TOP", 0, -200)
    promptFrame:SetFrameStrata("DIALOG")
    promptFrame:RegisterForDrag("LeftButton")
    promptFrame:SetMovable(true)
    promptFrame:EnableMouse(true)
    promptFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    promptFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    -- Background
    promptFrame:SetBackdrop({
        bgFile = FILES.bgfile,
        edgeFile = FILES.edgefile,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    promptFrame:SetBackdropColor(unpack(COLORS.surface_dark)) -- #0c0a15

    -- Header Section
    local header = CreateFrame("Frame", nil, promptFrame)
    header:SetSize(340, 60)
    header:SetPoint("TOP", 0, -4)

    -- Icon with Border
    local iconFrame = CreateFrame("Frame", nil, header, "BackdropTemplate")
    iconFrame:SetSize(44, 44)
    iconFrame:SetPoint("LEFT", 15, 0)
    iconFrame:SetBackdrop({
        edgeFile = FILES.edgefile,
        edgeSize = 10,
    })
    iconFrame:SetBackdropBorderColor(unpack(COLORS.surface_highlight)) -- #2a243d

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    promptFrame.icon = icon

    -- Indicator Dot
    local dot = header:CreateTexture(nil, "OVERLAY")
    dot:SetSize(8, 8)
    dot:SetPoint("TOPRIGHT", iconFrame, "TOPRIGHT", 2, 2)
    dot:SetTexture(FILES.white8x8)
    dot:SetVertexColor(unpack(COLORS.raid_red)) -- #ff4444
    promptFrame.indicatorDot = dot

    -- Text Info
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", iconFrame, "RIGHT", 12, 6)
    title:SetText("VOID WEAVER")
    title:SetTextColor(unpack(COLORS.gold)) -- #ffcc33
    promptFrame.title = title

    local subtext = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    subtext:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    subtext:SetText("Detected: Raid")
    subtext:SetTextColor(unpack(COLORS.text_light)) -- #e2e8f0
    promptFrame.subText = subtext

    -- Footer Section
    local footer = CreateFrame("Frame", nil, promptFrame, "BackdropTemplate")
    footer:SetSize(334, 45)
    footer:SetPoint("BOTTOM", 0, 3)
    footer:SetBackdrop({ bgFile = FILES.bgfile })
    footer:SetBackdropColor(unpack(COLORS.surface_highlight)) -- #2a243d

    -- Status Text (Left)
    local statusIcon = footer:CreateTexture(nil, "OVERLAY")
    statusIcon:SetSize(6, 6)
    statusIcon:SetPoint("TOPLEFT", 12, -12)
    statusIcon:SetTexture(FILES.white8x8)
    statusIcon:SetVertexColor(unpack(COLORS.raid_red)) -- #ff4444
    promptFrame.statusIcon = statusIcon

    local statusMsg = footer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusMsg:SetPoint("LEFT", statusIcon, "RIGHT", 6, 0)
    statusMsg:SetText("Waiting...")
    statusMsg:SetTextColor(unpack(COLORS.text_dim)) -- #9ca3af
    promptFrame.status = statusMsg

    -- Decorative Bottom Line
    local line = promptFrame:CreateTexture(nil, "OVERLAY")
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", 3, 3)
    line:SetPoint("BOTTOMRIGHT", -3, 3)
    line:SetTexture(FILES.white8x8)
    line:SetVertexColor(unpack(COLORS.raid_red)) -- #ff4444
    promptFrame.bottomLine = line

    promptFrame:Hide()
end

function private.showSwitchPrompt(context, currentName, desiredName, desiredID)
    if not promptFrame then createpromptFrame() end

    local meta = CONTEXT_METADATA[context] or { color = COLORS.primary, label = "Unknown" }
    local c = meta.color

    -- Apply Colors to frame elements
    if promptFrame then
        promptFrame.targetLoadoutID = desiredID
        promptFrame.targetName = desiredName
        if promptFrame.SetBackdropBorderColor then
            promptFrame:SetBackdropBorderColor(unpack(c))
        end
        if promptFrame.indicatorDot and promptFrame.indicatorDot.SetVertexColor then
            promptFrame.indicatorDot:SetVertexColor(unpack(c))
        end
        if promptFrame.statusIcon and promptFrame.statusIcon.SetVertexColor then
            promptFrame.statusIcon:SetVertexColor(unpack(c))
        end
        if promptFrame.bottomLine and promptFrame.bottomLine.SetVertexColor then
            promptFrame.bottomLine:SetVertexColor(unpack(c))
        end

        if promptFrame.btnSwitch and promptFrame.btnSwitch.Hide then
            promptFrame.btnSwitch:Hide()
        end
        if promptFrame.btnIgnore and promptFrame.btnIgnore.Hide then
            promptFrame.btnIgnore:Hide()
        end
    end

    -- Create Switch button with context color
    local btnSwitch = CreateButton(promptFrame, "SWITCH", c)
    btnSwitch:SetSize(80, 25)
    btnSwitch:SetPoint("BOTTOMRIGHT", -10, 10)
    if btnSwitch and btnSwitch.SetFrameLevel and promptFrame and promptFrame.GetFrameLevel then
        btnSwitch:SetFrameLevel(promptFrame:GetFrameLevel() + 10)
    end
    btnSwitch:SetScript("OnClick", function()
        local loadoutID = nil
        if promptFrame then
            loadoutID = promptFrame.targetLoadoutID
        end
        local currentSpec = GetSpecialization and GetSpecialization() or nil
        local specID = nil

        if private.GetSpecID then
            specID = private.GetSpecID()
        elseif currentSpec and GetSpecializationInfo then
            specID = GetSpecializationInfo(currentSpec)
        end

        local STARTER_BUILD_ID = (Constants and Constants.TraitConsts and Constants.TraitConsts.STARTER_BUILD_TRAIT_CONFIG_ID) or
            -1

        if not loadoutID then return end

        if not C_ClassTalents then return end

        if loadoutID == STARTER_BUILD_ID then
            if C_ClassTalents.SetStarterBuildActive then
                local result = C_ClassTalents.SetStarterBuildActive(true)
                if result == 0 then
                    if promptFrame and promptFrame.Hide then
                        promptFrame:Hide()
                    end
                end
            end
            return
        end

        if C_ClassTalents.GetStarterBuildActive and C_ClassTalents.GetStarterBuildActive() then
            if C_ClassTalents.SetStarterBuildActive then
                C_ClassTalents.SetStarterBuildActive(false)
            end
        end

        local result = nil
        if C_ClassTalents.LoadConfig then
            result = C_ClassTalents.LoadConfig(loadoutID, true)
        end

        local successEnum = Enum and Enum.ConfigOperationResult and Enum.ConfigOperationResult.Success or 0
        local loadInProgressEnum = Enum and Enum.ConfigOperationResult and Enum.ConfigOperationResult.LoadInProgress or 4

        if result == 0 or result == successEnum then
            if C_ClassTalents.UpdateLastSelectedSavedConfigID and specID then
                C_ClassTalents.UpdateLastSelectedSavedConfigID(specID, loadoutID)
            end
            if PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame and PlayerSpellsFrame.TalentsFrame.LoadSystem then
                pcall(function()
                    PlayerSpellsFrame.TalentsFrame.LoadSystem:SetSelectionID(loadoutID)
                end)
            end
            if promptFrame and promptFrame.Hide then
                promptFrame:Hide()
            end
        elseif result == 4 or result == loadInProgressEnum then
            if C_ClassTalents.UpdateLastSelectedSavedConfigID and specID then
                C_ClassTalents.UpdateLastSelectedSavedConfigID(specID, loadoutID)
            end
            if promptFrame and promptFrame.Hide then
                promptFrame:Hide()
            end
        end
    end)
    promptFrame.btnSwitch = btnSwitch

    -- Ignore button
    local btnIgnore = CreateButton(promptFrame, "IGNORE", "danger")
    btnIgnore:SetSize(80, 25)
    btnIgnore:SetPoint("BOTTOMRIGHT", -90, 10)
    if btnIgnore and btnIgnore.SetFrameLevel and promptFrame and promptFrame.GetFrameLevel then
        btnIgnore:SetFrameLevel(promptFrame:GetFrameLevel() + 10)
    end
    if btnIgnore and btnIgnore.SetScript then
        btnIgnore:SetScript("OnClick", function()
            if promptFrame and promptFrame.Hide then
                promptFrame:Hide()
            end
            if private and private.CancelRetry then
                private.CancelRetry()
            end
        end)
    end

    if promptFrame then
        promptFrame.btnIgnore = btnIgnore
    end

    local safeName = desiredName and string.upper(desiredName) or "UNKNOWN"
    local safeContextLabel = meta.label or context or "Unknown Context"

    if promptFrame then
        if promptFrame.title and promptFrame.title.SetText then
            promptFrame.title:SetText(safeName)
        end
        if promptFrame.subText and promptFrame.subText.SetText then
            promptFrame.subText:SetText("Detected: " .. safeContextLabel)
        end
        if promptFrame.status and promptFrame.status.SetText then
            promptFrame.status:SetText("Waiting...")
        end
    end

    local specIcon = nil
    if FILES and FILES.questionmark then
        specIcon = FILES.questionmark
    end

    local currentSpecIndex = GetSpecialization and GetSpecialization() or nil

    if currentSpecIndex and GetSpecializationInfo then
        local _, _, _, icon = GetSpecializationInfo(currentSpecIndex)
        if icon then
            specIcon = icon
        end
    end

    if promptFrame then
        if promptFrame.icon and promptFrame.icon.SetTexture and specIcon then
            promptFrame.icon:SetTexture(specIcon)
        end
        if promptFrame.Show then
            promptFrame:Show()
        end
    end
end
