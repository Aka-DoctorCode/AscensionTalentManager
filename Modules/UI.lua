local addonName, ns = ...
local AT = ns.AT
local UI = AT:NewModule("UI", "AceEvent-3.0", "AceHook-3.0")
AT.Modules.UI = UI

function UI:OnInitialize()
    self.frame = nil
    self.floatingFrame = nil
    self.toggleButton = nil
end

function UI:OnEnable()
    if C_AddOns.IsAddOnLoaded("Blizzard_PlayerSpells") then
        self:CreateInterface()
    else
        self:RegisterEvent("ADDON_LOADED", function(_, addon)
            if addon == "Blizzard_PlayerSpells" then
                self:CreateInterface()
            end
        end)
    end
end

function UI:CreateInterface()
    local parent = _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.TalentsFrame
    if not parent or self.toggleButton then return end

    -- 1. Create the Toggle Button
    local btn = CreateFrame("Button", "AscensionTalentManagerToggleButton", parent)
    btn:SetSize(32, 32)
    btn:SetFrameLevel(parent:GetFrameLevel() + 100)
    btn:SetFrameStrata("HIGH")
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -75, -5) -- Moved slightly further left to avoid overlaps
    
    -- Icon setup
    btn:SetNormalTexture("Interface\\Icons\\Inv_misc_rune_01")
    btn:GetNormalTexture():SetTexCoord(0.08, 0.92, 0.08, 0.92)
    
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetBlendMode("ADD")
    border:SetAllPoints()
    border:SetAlpha(0.5)

    btn:SetScript("OnClick", function()
        self:ToggleOverlay()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end)

    btn:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:SetText("Ascension Talents")
        GameTooltip:AddLine("Click to manage your builds.", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)

    self.toggleButton = btn

    -- 2. Create the Overlay Panel
    local overlay = CreateFrame("Frame", "AscensionTalentManagerOverlay", parent, "BackdropTemplate")
    overlay:SetSize(250, 450)
    overlay:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -5, -45)
    overlay:SetFrameLevel(btn:GetFrameLevel() + 10)
    overlay:SetFrameStrata("DIALOG")
    overlay:Hide()

    -- Glassmorphism Aesthetic
    overlay:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    overlay:SetBackdropColor(0, 0, 0, 0.9) 
    overlay:SetBackdropBorderColor(0.8, 0.6, 0.2, 0.8) 

    -- Title
    overlay.title = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    overlay.title:SetPoint("TOPLEFT", 15, -15)
    overlay.title:SetText("Ascension Builds")
    overlay.title:SetTextColor(1, 0.82, 0)

    -- Close Button
    local close = CreateFrame("Button", nil, overlay, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    close:SetSize(24, 24)

    -- Search Box
    local search = CreateFrame("EditBox", nil, overlay, "SearchBoxTemplate")
    search:SetSize(230, 20)
    search:SetPoint("TOPLEFT", 10, -42)
    search:SetScript("OnTextChanged", function(eb)
        self:RefreshList(overlay)
    end)
    overlay.SearchBoxInput = search

    -- 3. ScrollBox for builds
    overlay.ScrollBox = CreateFrame("Frame", nil, overlay, "WowScrollBoxList")
    overlay.ScrollBox:SetPoint("TOPLEFT", 10, -65)
    overlay.ScrollBox:SetPoint("BOTTOMRIGHT", -25, 80) 

    overlay.ScrollBar = CreateFrame("EventFrame", nil, overlay, "MinimalScrollBar")
    overlay.ScrollBar:SetPoint("TOPLEFT", overlay.ScrollBox, "TOPRIGHT", 5, 0)
    overlay.ScrollBar:SetPoint("BOTTOMLEFT", overlay.ScrollBox, "BOTTOMRIGHT", 5, 0)
    
    -- Initialize the ScrollBox once
    self:SetupScrollBox(overlay)

    -- Bottom Buttons
    local saveBtn = CreateFrame("Button", nil, overlay, "UIPanelButtonTemplate")
    saveBtn:SetText("Save Current")
    saveBtn:SetSize(110, 25)
    saveBtn:SetPoint("BOTTOMLEFT", 10, 10)
    saveBtn:SetScript("OnClick", function()
        StaticPopup_Show("ASCENSION_TALENTS_SAVE_PROMPT")
    end)

    local importBtn = CreateFrame("Button", nil, overlay, "UIPanelButtonTemplate")
    importBtn:SetText("Import URL")
    importBtn:SetSize(110, 25)
    importBtn:SetPoint("BOTTOMRIGHT", -10, 10)
    importBtn:SetScript("OnClick", function()
        StaticPopup_Show("ASCENSION_TALENTS_IMPORT_PROMPT")
    end)

    self.frame = overlay

    -- Leveling Status
    overlay.levelingStatus = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    overlay.levelingStatus:SetPoint("BOTTOMLEFT", 15, 65)
    overlay.levelingStatus:SetTextColor(0, 1, 0)
    
    local clearLeveling = CreateFrame("Button", nil, overlay, "UIPanelButtonTemplate")
    clearLeveling:SetText("Stop Guide")
    clearLeveling:SetSize(80, 20)
    clearLeveling:SetPoint("BOTTOMRIGHT", -10, 62)
    clearLeveling:SetScript("OnClick", function()
        if AT.Modules.Leveling then
            AT.Modules.Leveling:SetActiveBuild(nil, nil)
            self:RefreshList()
        end
    end)
    overlay.clearLeveling = clearLeveling

    -- Recording Controls
    local stopRecBtn = CreateFrame("Button", nil, overlay, "UIPanelButtonTemplate")
    stopRecBtn:SetText("|cffff0000STOP REC|r")
    stopRecBtn:SetSize(230, 25)
    stopRecBtn:SetPoint("BOTTOM", 0, 38)
    stopRecBtn:Hide()
    stopRecBtn:SetScript("OnClick", function()
        if AT.Modules.Leveling then
            AT.Modules.Leveling:StopRecording()
            self:RefreshList()
        end
    end)
    overlay.stopRecBtn = stopRecBtn

    -- Register Static Popups
    StaticPopupDialogs["ASCENSION_TALENTS_SAVE_PROMPT"] = {
        text = "Enter a name for this build:",
        button1 = "Save",
        button2 = "Cancel",
        hasEditBox = true,
        OnAccept = function(dialog)
            local eb = dialog.editBox or dialog.EditBox
            local name = eb:GetText()
            if name and name ~= "" then
                AT.Modules.Manager:SaveCurrentAsCustom(name)
                self:RefreshList()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    StaticPopupDialogs["ASCENSION_TALENTS_IMPORT_PROMPT"] = {
        text = "Paste a Blizzard string or IcyVeins URL:",
        button1 = "Import",
        button2 = "Cancel",
        hasEditBox = true,
        OnAccept = function(dialog)
            local eb = dialog.editBox or dialog.EditBox
            local text = eb:GetText()
            StaticPopup_Show("ASCENSION_TALENTS_IMPORT_NAME_PROMPT", nil, nil, text)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    StaticPopupDialogs["ASCENSION_TALENTS_IMPORT_NAME_PROMPT"] = {
        text = "Give this imported build a name:",
        button1 = "Confirm",
        button2 = "Cancel",
        hasEditBox = true,
        OnAccept = function(dialog, data)
            local eb = dialog.editBox or dialog.EditBox
            local name = eb:GetText()
            local text = data
            if name and name ~= "" then
                local bStr, lOrder, err = AT.Modules.Importer:ImportFromText(text)
                if bStr then
                    AT.Modules.Manager:SaveCustomLoadout(name, bStr, lOrder)
                    self:RefreshList()
                else
                    AT:Printf("Import failed: %s", err)
                end
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    StaticPopupDialogs["ASCENSION_TALENTS_MASS_EXPORT"] = {
        text = "MASS EXPORT DATA: (Ctrl+C to copy)",
        button1 = "Done",
        hasEditBox = true,
        OnShow = function(dialog, data)
            local eb = dialog.editBox or dialog.EditBox
            eb:SetText(data)
            eb:HighlightText()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    StaticPopupDialogs["ASCENSION_TALENTS_MASS_IMPORT"] = {
        text = "PASTE MASS IMPORT DATA:",
        button1 = "Import",
        button2 = "Cancel",
        hasEditBox = true,
        OnAccept = function(dialog)
            local eb = dialog.editBox or dialog.EditBox
            local text = eb:GetText()
            local success, countOrErr = AT.Modules.Manager:MassImport(text)
            if success then
                AT:Printf("Mass imported |cffffd200%d|r builds.", countOrErr)
                self:RefreshList()
            else
                AT:Printf("|cffff0000Error:|r %s", countOrErr)
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }
end

function UI:ToggleOverlay()
    if not self.frame then return end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self.frame:Show()
        self:RefreshList(self.frame)
    end
end

function UI:SetupScrollBox(f)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(32) -- Critical for Retail ScrollBox to display items
    view:SetElementInitializer("Button", function(button, data)
        button:SetSize(220, 30)
        
        if not button.text then
            button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            button.text:SetPoint("LEFT", 10, 0)
            
            button.applyBtn = CreateFrame("Button", nil, button, "UIPanelButtonTemplate")
            button.applyBtn:SetText("Load")
            button.applyBtn:SetSize(55, 22)
            button.applyBtn:SetPoint("RIGHT", -5, 0)

            button.recBtn = CreateFrame("Button", nil, button, "UIPanelButtonTemplate")
            button.recBtn:SetText("Rec")
            button.recBtn:SetSize(35, 20)
            button.recBtn:SetPoint("RIGHT", button.applyBtn, "LEFT", -2, 0)
            
            button:SetNormalTexture("Interface\\Buttons\\UI-Listbox-Highlight")
            button:GetNormalTexture():SetAlpha(0.2)
        end
        
        button.text:SetText(data.name)
        button.applyBtn:SetScript("OnClick", function()
            AT.Modules.Manager:ApplyCustomLoadout(data.name)
            f:Hide()
        end)
        button.recBtn:RegisterForClicks("LeftButtonUp")
        button.recBtn:SetScript("OnClick", function()
            if AT.Modules.Leveling then
                if AT.Modules.Leveling.recordingBuildName == data.name then
                    AT.Modules.Leveling:StopRecording()
                else
                    AT.Modules.Leveling:StartRecording(data.name)
                end
                self:RefreshList()
            end
        end)
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(f.ScrollBox, f.ScrollBar, view)
end

function UI:ToggleFloatingManager()
    if not self.floatingFrame then
        self:CreateFloatingManager()
    end
    
    if self.floatingFrame:IsShown() then
        self.floatingFrame:Hide()
    else
        self.floatingFrame:Show()
        self:RefreshList(self.floatingFrame)
    end
end

function UI:CreateFloatingManager()
    local f = CreateFrame("Frame", "AscensionTalentManagerFloatingManager", UIParent, "BackdropTemplate")
    f:Hide()
    f:SetSize(450, 450)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("HIGH")
    
    -- Glassmorphism Aesthetic
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    f:SetBackdropColor(0, 0, 0, 0.95) 
    f:SetBackdropBorderColor(0.8, 0.6, 0.2, 1) 

    -- Title
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 15, -15)
    f.title:SetText("Talents List Manager")
    f.title:SetTextColor(0, 1, 0.5)

    -- Close Button
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    close:SetSize(24, 24)

    -- Search & Filter Section
    local filterBar = CreateFrame("Frame", nil, f)
    filterBar:SetSize(430, 30)
    filterBar:SetPoint("TOPLEFT", 10, -42)
    
    -- Aesthetic Search Box
    local search = CreateFrame("EditBox", "AscensionSearchBox", filterBar, "SearchBoxTemplate")
    search:SetSize(180, 22)
    search:SetPoint("LEFT", 0, 0)
    search:SetScript("OnTextChanged", function(eb) self:RefreshList(f) end)
    f.SearchBoxInput = search

    -- Quick Filter Icons (UI/UX enhancement)
    local contexts = {
        { id = "all", icon = "Interface\\Icons\\INV_Misc_Book_08", tip = "Show All" },
        { id = "raid", icon = "Interface\\Icons\\achievement_guildperk_massresurrection", tip = "Raid Builds" },
        { id = "dungeons", icon = "Interface\\Icons\\INV_Misc_GroupNeedMore", tip = "Dungeon/M+ Builds" },
        { id = "pvp", icon = "Interface\\Icons\\Achievement_PVP_A_A", tip = "PvP Builds" },
    }

    f.activeFilter = "all"
    f.filterButtons = {}

    for i, cfg in ipairs(contexts) do
        local btn = CreateFrame("Button", nil, filterBar, "BackdropTemplate")
        btn:SetSize(24, 24)
        btn:SetPoint("LEFT", search, "RIGHT", 10 + (i-1)*28, 0)
        btn:SetNormalTexture(cfg.icon)
        
        -- Style current active
        btn:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
        btn:SetBackdropBorderColor(1, 1, 1, cfg.id == "all" and 1 or 0)

        btn:SetScript("OnClick", function()
            f.activeFilter = cfg.id
            for _, b in pairs(f.filterButtons) do b:SetBackdropBorderColor(1, 1, 1, 0) end
            btn:SetBackdropBorderColor(0, 1, 0, 1)
            self:RefreshList(f)
        end)
        
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(cfg.tip)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", GameTooltip_Hide)
        
        f.filterButtons[cfg.id] = btn
    end

    -- ScrollBox
    f.ScrollBox = CreateFrame("Frame", nil, f, "WowScrollBoxList")
    f.ScrollBox:SetPoint("TOPLEFT", 10, -80)
    f.ScrollBox:SetPoint("BOTTOMRIGHT", -25, 80) 

    f.ScrollBar = CreateFrame("EventFrame", nil, f, "MinimalScrollBar")
    f.ScrollBar:SetPoint("TOPLEFT", f.ScrollBox, "TOPRIGHT", 5, 0)
    f.ScrollBar:SetPoint("BOTTOMLEFT", f.ScrollBox, "BOTTOMRIGHT", 5, 0)
    
    self:SetupScrollBox(f)
    
    -- Bottom Buttons
    local saveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    saveBtn:SetText("Save Current")
    saveBtn:SetSize(110, 25)
    saveBtn:SetPoint("BOTTOMLEFT", 10, 10)
    saveBtn:SetScript("OnClick", function() StaticPopup_Show("ASCENSION_TALENTS_SAVE_PROMPT") end)

    local importBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    importBtn:SetText("Import URL")
    importBtn:SetSize(110, 25)
    importBtn:SetPoint("BOTTOMRIGHT", -10, 10)
    importBtn:SetScript("OnClick", function() StaticPopup_Show("ASCENSION_TALENTS_IMPORT_PROMPT") end)

    self.floatingFrame = f
end

-- Duplicate ToggleOverlay removed
function UI:RefreshList(targetFrame)
    local f = targetFrame or self.frame
    if not f or not f:IsShown() then return end
    
    local searchText = f.SearchBoxInput and f.SearchBoxInput:GetText():lower() or ""
    local filter = f.activeFilter or "all"
    local list = AT.Modules.Manager:GetCustomLoadouts()
    local dataProvider = CreateDataProvider()
    
    local keys = {}
    for name in pairs(list) do table.insert(keys, name) end
    table.sort(keys)

    local count = 0
    for _, name in ipairs(keys) do
        local matchesText = searchText == "" or name:lower():find(searchText)
        local matchesFilter = true
        
        -- UI/UX Tip: We could detect context tags in names like [Raid]
        if filter ~= "all" then
            matchesFilter = name:lower():find(filter)
        end

        if matchesText and matchesFilter then
            dataProvider:Insert({name = name})
            count = count + 1
        end
    end
    
    f.ScrollBox:SetDataProvider(dataProvider)

    -- Results Counter (UX)
    if not f.resultsText then
        f.resultsText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.resultsText:SetPoint("BOTTOMLEFT", 12, 45)
    end
    f.resultsText:SetText(string.format("Showing %d builds", count))
    
    -- Update recording status
    local isRecording = AT.Modules.Leveling and AT.Modules.Leveling.recordingBuildName
    if f.stopRecBtn then
        if isRecording then
            f.stopRecBtn:Show()
            f.stopRecBtn:SetText("|cffff0000STOP REC: " .. isRecording .. "|r")
        else
            f.stopRecBtn:Hide()
        end
    end
end
