-------------------------------------------------------------------------------
-- Project: AscensionCDMProfilesSync
-- Author: Aka-DoctorCode
-- File: core.lua
-------------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field, inject-field

local addonName, addonTable = ...
local AceAddon = LibStub("AceAddon-3.0")
local AceDB = LibStub("AceDB-3.0")

local addon = AceAddon:NewAddon(addonName, "AceEvent-3.0")

local dropdownFrame = nil
local savedDataKey = "cooldownProfiles"

function addon:printMessage(msg)
    print("|cFF80CCFF[" .. addonName .. "]|r " .. msg)
end

function addon:getCurrentClassAndSpec()
    local _, classToken = UnitClass("player")
    classToken = string.lower(classToken)
    local currentSpec = GetSpecialization()
    local specID = currentSpec and GetSpecializationInfo(currentSpec) or 0
    return classToken, specID
end

function addon:OnInitialize()
    local defaults = {
        global = {
            [savedDataKey] = {}
        }
    }
    self.db = AceDB:New("AscensionCDMSyncDB", defaults)
    
    local suitUI = LibStub:GetLibrary("AscensionSuit-UI", true)
    if suitUI then
        self.uiContext = suitUI:CreateContext()
    end

    if not self.db.global[savedDataKey] then
        self.db.global[savedDataKey] = {}
    end
    
    self:CreateCooldownViewerDropdown()
end

function addon:CreateCooldownViewerDropdown()
    if dropdownFrame then return end
    
    -- We wait until CooldownViewerSettings exists
    if not _G["CooldownViewerSettings"] then
        C_Timer.After(1, function() self:CreateCooldownViewerDropdown() end)
        return
    end

    local parent = _G["CooldownViewerSettings"]
    
    if self.uiContext then
        dropdownFrame = self.uiContext:createButton({
            parent = parent,
            text = "Profiles",
            onClick = function()
                addon:ToggleCooldownProfilesMenu(dropdownFrame)
            end,
            width = 120,
            height = 24
        })
        dropdownFrame:ClearAllPoints()
        dropdownFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 120, 0)
        dropdownFrame:SetFrameStrata("DIALOG")
        dropdownFrame:SetFrameLevel(100)
    else
        dropdownFrame = CreateFrame("Button", "AscensionCooldownProfilesDropdown", parent, "UIMenuButtonStretchTemplate")
        dropdownFrame:SetSize(120, 24)
        dropdownFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 50, -120)
        dropdownFrame:SetFrameStrata("DIALOG")
        dropdownFrame:SetFrameLevel(100)
        dropdownFrame:SetText("Profiles")
        
        dropdownFrame:SetScript("OnClick", function(self)
            addon:ToggleCooldownProfilesMenu(self)
        end)
    end
end

function addon:SaveCooldownProfile(profileName)
    if not C_CooldownViewer or not C_CooldownViewer.IsCooldownViewerAvailable() then
        addon:printMessage("Cooldown Viewer not available.")
        return
    end
    
    local classToken, specID = self:getCurrentClassAndSpec()
    if specID == 0 then return end
    
    local data = C_CooldownViewer.GetLayoutData()
    if not data then return end
    
    if not self.db.global[savedDataKey][classToken] then
        self.db.global[savedDataKey][classToken] = {}
    end
    if not self.db.global[savedDataKey][classToken][specID] then
        self.db.global[savedDataKey][classToken][specID] = {}
    end
    
    self.db.global[savedDataKey][classToken][specID][profileName] = data
    addon:printMessage("Cooldown profile '" .. profileName .. "' saved.")
end

function addon:LoadCooldownProfile(profileName)
    if not C_CooldownViewer or not C_CooldownViewer.IsCooldownViewerAvailable() then
        addon:printMessage("Cooldown Viewer not available.")
        return
    end
    
    local classToken, specID = self:getCurrentClassAndSpec()
    if specID == 0 then return end
    
    local profileData = self.db.global[savedDataKey] and self.db.global[savedDataKey][classToken] and self.db.global[savedDataKey][classToken][specID] and self.db.global[savedDataKey][classToken][specID][profileName]
    
    if profileData then
        C_CooldownViewer.SetLayoutData(profileData)
        
        addon:printMessage("Cooldown profile '" .. profileName .. "' loaded.")
        StaticPopup_Show("ASCENSION_RELOAD_FOR_COOLDOWN")
    else
        addon:printMessage("Profile not found.")
    end
end

function addon:refreshCooldownViewerUI(profileData, profileName)
    local settingsFrame = _G["CooldownViewerSettings"]
    if not settingsFrame then return end

    local dataProvider = settingsFrame.GetDataProvider and settingsFrame:GetDataProvider()
    local layoutManager = dataProvider and dataProvider.GetLayoutManager and dataProvider:GetLayoutManager()

    if layoutManager then
        if layoutManager.ImportLayout and profileData then
            -- Simulate the user pasting the string into the Import UI
            pcall(layoutManager.ImportLayout, layoutManager, profileData, profileName)
        end
    end

    if settingsFrame.UpdateDropdown then
        pcall(settingsFrame.UpdateDropdown, settingsFrame)
    end

    if settingsFrame.UpdateLayoutDropdown then
        pcall(settingsFrame.UpdateLayoutDropdown, settingsFrame)
    end

    if EventRegistry and EventRegistry.TriggerEvent then
        pcall(EventRegistry.TriggerEvent, EventRegistry, "CooldownViewerSettings.OnDataChanged")
        pcall(EventRegistry.TriggerEvent, EventRegistry, "EditMode.LayoutApplied")
    end

    local viewerFrames = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer" }
    for _, frameName in ipairs(viewerFrames) do
        local viewerFrame = _G[frameName]
        if viewerFrame then
            if viewerFrame.GetSerializer then
                local serializer = viewerFrame:GetSerializer()
                if serializer and serializer.Init then
                    local dataProvider = viewerFrame.GetDataProvider and viewerFrame:GetDataProvider()
                    local layoutManager = dataProvider and dataProvider.GetLayoutManager and dataProvider:GetLayoutManager()
                    
                    if not layoutManager then
                        local settingsDP = settingsFrame.GetDataProvider and settingsFrame:GetDataProvider()
                        layoutManager = settingsDP and settingsDP.GetLayoutManager and settingsDP:GetLayoutManager()
                    end

                    pcall(serializer.Init, serializer, layoutManager)
                end
            end

            if viewerFrame.GetDataProvider then
                local dataProvider = viewerFrame:GetDataProvider()
                if dataProvider and dataProvider.MarkDirty then
                    pcall(dataProvider.MarkDirty, dataProvider)
                end
            end

            if viewerFrame.RefreshData then
                pcall(viewerFrame.RefreshData, viewerFrame)
            end
            if viewerFrame.RefreshLayout then
                pcall(viewerFrame.RefreshLayout, viewerFrame)
            end
        end
    end

    if EventRegistry and EventRegistry.TriggerEvent then
        pcall(EventRegistry.TriggerEvent, EventRegistry, "CooldownViewerSettings.OnDataChanged")
        pcall(EventRegistry.TriggerEvent, EventRegistry, "EditMode.LayoutApplied")
    end


    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("COOLDOWN_VIEWER_DATA_LOADED")
    C_Timer.After(0.05, function()
        if EventUtil and EventUtil.GenerateFrameEvent then
            pcall(EventUtil.GenerateFrameEvent, eventFrame, "COOLDOWN_VIEWER_DATA_LOADED")
        end
        eventFrame:UnregisterAllEvents()
        eventFrame = nil
    end)
end

function addon:DeleteCooldownProfile(profileName)
    local classToken, specID = self:getCurrentClassAndSpec()
    if specID == 0 then return end
    
    if self.db.global[savedDataKey] and self.db.global[savedDataKey][classToken] and self.db.global[savedDataKey][classToken][specID] then
        self.db.global[savedDataKey][classToken][specID][profileName] = nil
        addon:printMessage("Cooldown profile '" .. profileName .. "' deleted.")
    end
end

-- Using custom UI context menu from AscensionSuit
local lastMenuToggle = 0
function addon:ToggleCooldownProfilesMenu(anchor)
    if GetTime() - lastMenuToggle < 0.5 then return end
    lastMenuToggle = GetTime()
    
    local classToken, specID = self:getCurrentClassAndSpec()
    if specID == 0 then return end
    
    local profiles = self.db.global[savedDataKey] and self.db.global[savedDataKey][classToken] and self.db.global[savedDataKey][classToken][specID] or {}
    
    local suitUI = LibStub:GetLibrary("AscensionSuit-UI", true)
    if suitUI and suitUI.UX then
        local menuOptions = {}
        
        for name, data in pairs(profiles) do
            table.insert(menuOptions, {
                text = "Load: " .. name,
                func = function()
                    addon:LoadCooldownProfile(name)
                end
            })
            table.insert(menuOptions, {
                text = "Delete: " .. name,
                func = function()
                    addon:DeleteCooldownProfile(name)
                end
            })
        end
        
        if #menuOptions > 0 then
            table.insert(menuOptions, { text = "---" })
        end
        
        table.insert(menuOptions, {
            text = "Save Current as New Profile",
            func = function()
                if addon.showCustomInputDialog then
                    addon:showCustomInputDialog("Save Profile", "Enter profile name:", function(text)
                        if text and text ~= "" then
                            addon:SaveCooldownProfile(text)
                        end
                    end)
                else
                    StaticPopup_Show("ASCENSION_COOLDOWN_PROFILE_SAVE")
                end
            end
        })
        
        suitUI.UX:showContextMenu(anchor, menuOptions)
    else
        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(anchor, function(owner, rootDescription)
                rootDescription:CreateTitle("Cooldown Profiles")
                
                for name, data in pairs(profiles) do
                    local profileMenu = rootDescription:CreateButton(name)
                    
                    profileMenu:CreateButton("Load", function()
                        addon:LoadCooldownProfile(name)
                    end)
                    
                    profileMenu:CreateButton("Delete", function()
                        addon:DeleteCooldownProfile(name)
                    end)
                end
                
                rootDescription:CreateDivider()
                
                rootDescription:CreateButton("Save Current as New Profile", function()
                    if addon.showCustomInputDialog then
                        addon:showCustomInputDialog("Save Profile", "Enter profile name:", function(text)
                            if text and text ~= "" then
                                addon:SaveCooldownProfile(text)
                            end
                        end)
                    else
                        StaticPopup_Show("ASCENSION_COOLDOWN_PROFILE_SAVE")
                    end
                end)
            end)
        else
            addon:printMessage("Menu system not available.")
        end
    end
end

StaticPopupDialogs["ASCENSION_COOLDOWN_PROFILE_SAVE"] = {
    text = "Enter a name for the current Cooldown profile:",
    button1 = "Save",
    button2 = "Cancel",
    hasEditBox = true,
    OnAccept = function(self)
        local text = self.editBox:GetText()
        if text and text ~= "" then
            addon:SaveCooldownProfile(text)
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local text = self:GetText()
        if text and text ~= "" then
            addon:SaveCooldownProfile(text)
        end
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["ASCENSION_RELOAD_FOR_COOLDOWN"] = {
    text = "A UI reload is required for the Cooldown profile to be fully applied to Blizzard's Layout Menu. Reload now?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function addon:showCustomInputDialog(title, text, onAccept, onCancel)
    if not self.uiContext then return end

    if not self.customInputDialog then
        local frame = CreateFrame("Frame", "AscensionProfilesCustomInputDialog", _G.UIParent, "BackdropTemplate")
        frame:SetSize(360, 150)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetClampedToScreen(true)
        
        local styles = self.uiContext.styles
        frame:SetBackdrop({
            bgFile = styles.files.bgFile,
            edgeFile = styles.files.edgeFile,
            edgeSize = 3,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        frame:SetBackdropColor(unpack(styles.colors.backgroundDark or styles.colors.mainBackground or {0.02, 0.02, 0.03, 0.95}))
        frame:SetBackdropBorderColor(unpack(styles.colors.primary or {0.3, 0, 0.4, 1}))
        
        local titleStr = frame:CreateFontString(nil, "OVERLAY", styles.fonts.header)
        titleStr:SetPoint("TOP", 0, -12)
        titleStr:SetTextColor(unpack(styles.colors.gold))
        frame.titleStr = titleStr
        
        local textStr = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        textStr:SetPoint("TOP", titleStr, "BOTTOM", 0, -6)
        textStr:SetWidth(320)
        textStr:SetJustifyH("CENTER")
        frame.textStr = textStr
        
        local inputFrame = self.uiContext:createInput({
            parent = frame,
            width = 280,
            yOffset = -55,
            xOffset = 40
        })
        frame.inputFrame = inputFrame
        
        local saveBtn = self.uiContext:createButton({
            parent = frame,
            text = "Save",
            onClick = function()
                frame:Hide()
                local val = inputFrame.editBox:GetText()
                if frame.onAccept then frame.onAccept(val) end
            end,
            width = 90,
            height = 24
        })
        saveBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 60, 15)
        
        local cancelBtn = self.uiContext:createButton({
            parent = frame,
            text = "Cancel",
            onClick = function()
                frame:Hide()
                if frame.onCancel then frame.onCancel() end
            end,
            width = 90,
            height = 24
        })
        cancelBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -60, 15)

        inputFrame.editBox:SetScript("OnEditFocusLost", function(self)
            if styles.colors.surfaceLight then self:SetBackdropColor(unpack(styles.colors.surfaceLight)) end
            if styles.colors.blackDetail then self:SetBackdropBorderColor(unpack(styles.colors.blackDetail)) end
        end)

        inputFrame.editBox:SetScript("OnEnterPressed", function(self)
            frame:Hide()
            local val = self:GetText()
            if frame.onAccept then frame.onAccept(val) end
        end)
        inputFrame.editBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
            frame:Hide()
            if frame.onCancel then frame.onCancel() end
        end)
        
        self.customInputDialog = frame
    end
    
    local frame = self.customInputDialog
    frame.titleStr:SetText(title)
    frame.textStr:SetText(text)
    frame.onAccept = onAccept
    frame.onCancel = onCancel
    frame.inputFrame.editBox:SetText("")
    frame.inputFrame.editBox:SetFocus()
    frame:Show()
end