-------------------------------------------------------------------------------
-- Project: AscensionTalentManager
-- Author: Aka-DoctorCode
-- File: UI.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

local ADDON_NAME, private = ...

local lib = LibStub:GetLibrary("AscensionSuit-UI", true)
if not lib then
    print("|cffff0000AscensionTalentManager requires AscensionSuit!|r")
    return
end

local ctx = lib:CreateContext()

local configFrame = nil
local promptFrame = nil

-- Context mappings
local CONTEXTS = {
    { key = "world",        label = "Open World",
    color = { 0.082, 0.369, 0.153, 1.0 } }, -- #155E27
    { key = "dungeons",     label = "Dungeons",
    color = { 0.118, 0.251, 0.686, 1.0 } }, -- #1E40AF
    { key = "raid",         label = "Raid",
    color = { 0.600, 0.106, 0.106, 1.0 } }, -- #991B1B
    { key = "raid_legacy",  label = "Raid (Legacy)",
    color = { 0.792, 0.541, 0.016, 1.0 } }, -- #CA8A04
    { key = "delve",        label = "Delve",
    color = { 0.420, 0.129, 0.659, 1.0 } }, -- #6B21A8
    { key = "pvp",          label = "PvP",
    color = { 0.918, 0.345, 0.047, 1.0 } }, -- #EA580C
}

local function GetContextColor(key)
    for _, c in ipairs(CONTEXTS) do
        if c.key == key then return c.color end
    end
    return ctx.styles.colors.primary
end

local function GetContextLabel(key)
    for _, c in ipairs(CONTEXTS) do
        if c.key == key then return c.label end
    end
    return string.upper(key or "UNKNOWN")
end

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------
local function GetTalentOptions()
    local specID = private.GetSpecID()
    local opts = { { label = "-", value = "-" } }
    if not specID then return opts end
    local configIDs = C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID and C_ClassTalents.GetConfigIDsBySpecID(specID)
    if configIDs then
        for _, id in ipairs(configIDs) do
            local info = private.GetConfigInfo(id)
            if info and info.name then
                table.insert(opts, { label = info.name, value = info.name })
            end
        end
    end
    return opts
end



-- -----------------------------------------------------------------------------
-- Main Configuration Panel
-- -----------------------------------------------------------------------------
local talentDropdowns = {}

local contextBoxes = {}

local function PopulateDropdowns()
    for _, dd in ipairs(talentDropdowns) do
        if dd then dd:Hide() end
    end
    talentDropdowns = {}

    local tOpts = GetTalentOptions()

    for _, c in ipairs(CONTEXTS) do
        local box = contextBoxes[c.key]
        if box then
            -- Talent Dropdown (50% of box width = 146, on the right)
            local ddTalent = ctx:createDropdown({
                parent = box,
                options = tOpts,
                width = 140,
                yOffset = -16,
                xOffset = 142,
                getter = function()
                    local specID = private.GetSpecID()
                    if specID and AscensionTalentManagerDB.perSpec[specID] and AscensionTalentManagerDB.perSpec[specID][c.key] then
                        return AscensionTalentManagerDB.perSpec[specID][c.key].talent or "-"
                    end
                    return "-"
                end,
                setter = function(val)
                    local specID = private.GetSpecID()
                    if not specID then return end
                    if not AscensionTalentManagerDB.perSpec[specID] then AscensionTalentManagerDB.perSpec[specID] = {} end
                    if not AscensionTalentManagerDB.perSpec[specID][c.key] then AscensionTalentManagerDB.perSpec[specID][c.key] = {} end
                    AscensionTalentManagerDB.perSpec[specID][c.key].talent = (val ~= "-") and val or nil
                end
            })
            table.insert(talentDropdowns, ddTalent)
        end
    end
end



local function createConfigFrame()
    if configFrame then return end

    configFrame = CreateFrame("Frame", "ATS_ConfigFrame", UIParent, "BackdropTemplate")
    configFrame:SetSize(325, 475) -- Slightly taller to fit 500 comfortably
    configFrame:SetPoint("CENTER")
    configFrame:SetFrameStrata("HIGH")

    if lib.UX and lib.UX.makeMovable then
        lib.UX:makeMovable(configFrame)
    else
        configFrame:RegisterForDrag("LeftButton")
        configFrame:SetMovable(true)
        configFrame:EnableMouse(true)
        configFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        configFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    end

    if lib.UX and lib.UX.makeClosableWithEscape then
        lib.UX:makeClosableWithEscape(configFrame)
    end

    configFrame:SetBackdrop({
        bgFile = ctx.styles.files.bgFile,
        edgeFile = ctx.styles.files.edgeFile,
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    configFrame:SetBackdropColor(unpack(ctx.styles.colors.mainBackground or {0.05, 0.05, 0.05, 0.95}))
    configFrame:SetBackdropBorderColor(unpack(ctx.styles.colors.surfaceLight or {0.25, 0.25, 0.25, 1}))

    -- Header
    local title = configFrame:CreateFontString(nil, "OVERLAY", ctx.styles.fonts.header)
    title:SetPoint("TOPLEFT", 15, -15)
    title:SetText("Ascension Talent Reminder")
    title:SetTextColor(unpack(ctx.styles.colors.gold))

    local closeBtn = ctx:createCloseButton(configFrame, function() configFrame:Hide() end)
    closeBtn:SetPoint("TOPRIGHT", -10, -10)

    -- Section Divider
    local divider = configFrame:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(0.58, 0.64, 0.72, 1) -- #94A3B8
    divider:SetSize(292, 3)
    divider:SetPoint("TOP", 0, -40)

    -- Boxes
    local startY = -50
    local boxHeight = 60
    local gap = 10
    local boxWidth = 292 -- 90% of 325

    for i, c in ipairs(CONTEXTS) do
        local y = startY - ((i - 1) * (boxHeight + gap))

        local box = CreateFrame("Frame", nil, configFrame, "BackdropTemplate")
        box:SetSize(boxWidth, boxHeight)
        box:SetPoint("TOP", 0, y)
        box:SetBackdrop({ bgFile = ctx.styles.files.bgFile })
        box:SetBackdropColor(unpack(ctx.styles.colors.surfaceDark or {0.15, 0.15, 0.15, 0.9}))
        
        local lbl = box:CreateFontString(nil, "OVERLAY", ctx.styles.fonts.label)
        lbl:SetPoint("LEFT", 15, 0)
        lbl:SetText(c.label)
        lbl:SetTextColor(unpack(ctx.styles.colors.gold))

        contextBoxes[c.key] = box
    end
    
    configFrame:HookScript("OnShow", function()
        PopulateDropdowns()
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

-- -----------------------------------------------------------------------------
-- Dynamic Reminder Popup
-- -----------------------------------------------------------------------------
local function createPromptFrame()
    if promptFrame then return end

    promptFrame = CreateFrame("Frame", "ATS_PromptFrame", UIParent, "BackdropTemplate")
    promptFrame:SetSize(420, 150)
    promptFrame:SetPoint("CENTER", 0, 250)
    promptFrame:SetFrameStrata("DIALOG")

    if lib.UX and lib.UX.makeMovable then
        lib.UX:makeMovable(promptFrame)
    else
        promptFrame:RegisterForDrag("LeftButton")
        promptFrame:SetMovable(true)
        promptFrame:EnableMouse(true)
        promptFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        promptFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    end

    promptFrame:SetBackdrop({
        bgFile = ctx.styles.files.bgFile,
        edgeFile = ctx.styles.files.edgeFile,
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    promptFrame:SetBackdropColor(unpack(ctx.styles.colors.mainBackground or {0.05, 0.05, 0.05, 0.95}))
    promptFrame:SetBackdropBorderColor(unpack(ctx.styles.colors.surfaceLight or {0.25, 0.25, 0.25, 1}))

    -- Top Left Spec Icon
    local iconFrame = CreateFrame("Frame", nil, promptFrame, "BackdropTemplate")
    iconFrame:SetSize(48, 48)
    iconFrame:SetPoint("TOPLEFT", 15, -15)
    iconFrame:SetBackdrop({ edgeFile = ctx.styles.files.edgeFile, edgeSize = 2 })
    iconFrame:SetBackdropBorderColor(unpack(ctx.styles.colors.surfaceLight or {0.25, 0.25, 0.25, 1}))

    promptFrame.specIcon = iconFrame:CreateTexture(nil, "ARTWORK")
    promptFrame.specIcon:SetPoint("TOPLEFT", 2, -2)
    promptFrame.specIcon:SetPoint("BOTTOMRIGHT", -2, 2)
    promptFrame.specIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Title
    promptFrame.title = promptFrame:CreateFontString(nil, "OVERLAY", ctx.styles.fonts.header)
    promptFrame.title:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 15, -5)
    promptFrame.title:SetText("Talent change")
    promptFrame.title:SetTextColor(unpack(ctx.styles.colors.textLight))

    -- Context Badge (Top Right)
    promptFrame.badge = CreateFrame("Frame", nil, promptFrame, "BackdropTemplate")
    promptFrame.badge:SetSize(120, 28)
    promptFrame.badge:SetPoint("TOPRIGHT", -15, -15)
    promptFrame.badge:SetBackdrop({ bgFile = ctx.styles.files.bgFile, edgeFile = ctx.styles.files.edgeFile, edgeSize = 2 })

    promptFrame.badgeText = promptFrame.badge:CreateFontString(nil, "OVERLAY", ctx.styles.fonts.label)
    promptFrame.badgeText:SetPoint("CENTER")
    promptFrame.badgeText:SetText("CONTEXT")

    -- Mismatch Displays
    local function createRow(yOffset, label)
        local f = CreateFrame("Frame", nil, promptFrame)
        f:SetSize(390, 20)
        f:SetPoint("TOPLEFT", 15, yOffset)

        local title = f:CreateFontString(nil, "OVERLAY", ctx.styles.fonts.label)
        title:SetPoint("LEFT", 0, 0)
        title:SetText(label .. ":")
        title:SetWidth(80)
        title:SetJustifyH("LEFT")
        title:SetTextColor(0.58, 0.64, 0.72, 1.0) -- #94A3B8

        local current = f:CreateFontString(nil, "OVERLAY", ctx.styles.fonts.label)
        current:SetPoint("LEFT", title, "RIGHT", 10, 0)
        current:SetWidth(140)
        current:SetJustifyH("LEFT")

        local desired = f:CreateFontString(nil, "OVERLAY", ctx.styles.fonts.label)
        desired:SetPoint("LEFT", current, "RIGHT", 20, 0)
        desired:SetWidth(140)
        desired:SetJustifyH("LEFT")

        return current, desired
    end

    promptFrame.talentCurr, promptFrame.talentDes = createRow(-70, "Talents")

    -- Header labels for current vs desired
    local textDim = { 0.58, 0.64, 0.72, 1.0 } -- #94A3B8
    local hdCurr = promptFrame:CreateFontString(nil, "OVERLAY", ctx.styles.fonts.desc)
    hdCurr:SetPoint("BOTTOMLEFT", promptFrame.talentCurr, "TOPLEFT", 0, 2)
    hdCurr:SetText("Current")
    hdCurr:SetTextColor(unpack(textDim))

    local hdDes = promptFrame:CreateFontString(nil, "OVERLAY", ctx.styles.fonts.desc)
    hdDes:SetPoint("BOTTOMLEFT", promptFrame.talentDes, "TOPLEFT", 0, 2)
    hdDes:SetText("Desired")
    hdDes:SetTextColor(unpack(textDim))

    -- Action Buttons
    promptFrame.btnIgnore = ctx:createButton({
        parent = promptFrame,
        text = "Ignore (Esc)",
        width = 120, height = 32,
        yOffset = -105, xOffset = 15,
        onClick = function()
            if private.ignoredContextBase == nil then
                private.ignoredContextBase = promptFrame.currentContext
            end
            private.CancelRetry()
            promptFrame:Hide()
        end
    })
    promptFrame.btnIgnore:SetBackdropColor(unpack(ctx.styles.colors.surfaceLight or {0.25, 0.25, 0.25, 1}))

    promptFrame.btnSwitch = ctx:createButton({
        parent = promptFrame,
        text = "Switch (Enter)",
        width = 140, height = 32,
        yOffset = -105, xOffset = 265,
        onClick = function()
            private.RequestSwitch(
                promptFrame.targetTalentID, promptFrame.targetTalentName
            )
            promptFrame:Hide()
        end
    })

    -- Keybinds
    promptFrame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            promptFrame.btnIgnore:Click()
            self:SetPropagateKeyboardInput(false)
        elseif key == "ENTER" then
            if promptFrame.btnSwitch:IsEnabled() then
                promptFrame.btnSwitch:Click()
            end
            self:SetPropagateKeyboardInput(false)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    promptFrame:Hide()
end

function private.showSwitchPrompt(ctxKey, currentData, desiredData, matchData)
    if not matchData.mismatchTalent then return end
    if not promptFrame then createPromptFrame() end
    if not promptFrame then return end

    promptFrame.currentContext = ctxKey
    promptFrame.targetTalentID = matchData.talentID
    promptFrame.targetTalentName = desiredData.talent

    local cColor = GetContextColor(ctxKey) or { 0.5, 0.5, 0.5, 1.0 }
    promptFrame:SetBackdropBorderColor(unpack(cColor))
    
    if promptFrame.badge then
        local r = (cColor[1] or 1) * 0.5
        local g = (cColor[2] or 1) * 0.5
        local b = (cColor[3] or 1) * 0.5
        promptFrame.badge:SetBackdropColor(r, g, b, 1)
        promptFrame.badge:SetBackdropBorderColor(unpack(cColor))
    end
    
    if promptFrame.badgeText then
        promptFrame.badgeText:SetText(GetContextLabel(ctxKey))
        promptFrame.badgeText:SetTextColor(unpack(ctx.styles.colors.textLight))
    end

    local specIcon = 134400 -- FileID for INV_Misc_QuestionMark
    local specIndex = GetSpecialization and GetSpecialization() or nil
    if specIndex then
        local _, _, _, icon = GetSpecializationInfo(specIndex)
        if icon then specIcon = icon end
    end
    promptFrame.specIcon:SetTexture(specIcon)

    -- warning / alert color
    local WARNING_COLOR = ctx.styles.colors.textLight
    local SUCCESS_COLOR = ctx.styles.colors.textLight

    promptFrame.talentCurr:SetText(currentData.talent)
    promptFrame.talentDes:SetText(desiredData.talent)
    if matchData.mismatchTalent then
        promptFrame.talentCurr:SetTextColor(unpack(WARNING_COLOR))
        promptFrame.talentDes:SetTextColor(unpack(WARNING_COLOR))
    else
        promptFrame.talentCurr:SetTextColor(unpack(SUCCESS_COLOR))
        promptFrame.talentDes:SetTextColor(unpack(SUCCESS_COLOR))
    end

    if matchData.mismatchTalent then
        promptFrame.btnSwitch:Enable()
        promptFrame.btnSwitch:SetBackdropColor(unpack(ctx.styles.colors.primary))
        promptFrame.btnSwitch.text:SetTextColor(unpack(ctx.styles.colors.textLight))
    else
        local textDim = { 0.58, 0.64, 0.72, 1.0 }
        promptFrame.btnSwitch:Disable()
        promptFrame.btnSwitch:SetBackdropColor(unpack(ctx.styles.colors.surfaceLight or {0.25, 0.25, 0.25, 1}))
        promptFrame.btnSwitch.text:SetTextColor(unpack(textDim))
    end

    promptFrame:Show()
end

function private.UpdateMinimapVisible()
end

function private.initUI()
    if not configFrame then createConfigFrame() end
    if not promptFrame then createPromptFrame() end
end

-- Force hide default UI parts if requested (optional)
function private.HidePrompt()
    if promptFrame then promptFrame:Hide() end
end
