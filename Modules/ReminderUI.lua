local addonName, ns = ...
local AT = ns.AT
local ReminderUI = {}
AT.Modules.ReminderUI = ReminderUI

local CTX_COLORS = {
    world = {0.1, 0.8, 0.1},
    dungeons = {0.1, 0.5, 0.9},
    raid = {0.9, 0.1, 0.1},
    farming = {0.8, 0.5, 0.1},
    delve = {0.6, 0.2, 0.8},
    pvp = {1, 0.8, 0},
}

function ReminderUI:Show(context, currentName, desiredName)
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
    end

    if not self.frame then
        self:CreateFrame()
    end

    local displayCtx = context == "farming" and "FARMING/LEGACY" or context:upper()
    self.frame.contextText:SetText(displayCtx)
    local color = CTX_COLORS[context] or {1,1,1}
    self.frame.contextBadge:SetBackdropColor(color[1], color[2], color[3], 0.2)
    self.frame.contextText:SetTextColor(color[1], color[2], color[3])
    
    local msg = string.format("Detected activity: |cffffd200%s|r\n\nYour active loadout is |cffff4444%s|r.\nRecommended loadout: |cff00ff00%s|r\n\n|cffaaaaaa(If Auto-Swap failed, click below to change)|r", 
        displayCtx, currentName or "None", desiredName)
    
    self.frame.descText:SetText(msg)
    self.frame.desiredName = desiredName
    self.frame:Show()
    PlaySound(8959) -- IG_PLAYER_INVITE
end

function ReminderUI:CreateFrame()
    local frame = CreateFrame("Frame", "AscensionTalentManagerReminderPopup", UIParent, "BackdropTemplate")
    self.frame = frame
    tinsert(UISpecialFrames, "AscensionTalentManagerReminderPopup")
    
    frame:SetSize(400, 160)
    frame:SetPoint("CENTER", 0, 100)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.9)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("Ascension Talent Manager: Loadout Check")

    local badge = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    badge:SetSize(100, 20)
    badge:SetPoint("TOPRIGHT", -15, -15)
    badge:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    frame.contextBadge = badge
    
    local ctxText = badge:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ctxText:SetPoint("CENTER")
    frame.contextText = ctxText

    local desc = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", 20, -50)
    desc:SetPoint("TOPRIGHT", -20, -50)
    desc:SetJustifyH("LEFT")
    frame.descText = desc

    local btnIgnore = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btnIgnore:SetSize(100, 25)
    btnIgnore:SetPoint("BOTTOMLEFT", 20, 20)
    btnIgnore:SetText("Ignore")
    btnIgnore:SetScript("OnClick", function() frame:Hide() end)

    local btnSwitch = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btnSwitch:SetSize(140, 25)
    btnSwitch:SetPoint("BOTTOMRIGHT", -20, 20)
    btnSwitch:SetText("Switch Loadout")
    btnSwitch:SetScript("OnClick", function()
        self:AttemptSwitch(frame.desiredName)
        frame:Hide()
    end)
    frame.btnSwitch = btnSwitch
end

function ReminderUI:AttemptSwitch(loadoutName)
    if not AT.Modules.Reminder:CanSwapTalents() then
        UIErrorsFrame:AddMessage("Cannot switch talents right now!", 1, 0, 0)
        return
    end
    
    local spec = GetSpecialization()
    local specID = GetSpecializationInfo(spec)
    -- Try custom loadouts first
    local customLoadouts = AT.Modules.Manager:GetCustomLoadouts()
    if customLoadouts[loadoutName] then
        if AT.Modules.Manager:ApplyCustomLoadout(loadoutName) then
            AT.Modules.Reminder.lastCustomLoadoutName = loadoutName
            return
        end
    end

    local configIDs = C_ClassTalents.GetConfigIDsBySpecID(specID)
    
    local targetID
    for _, id in ipairs(configIDs) do
        local info = C_Traits.GetConfigInfo(id)
        if info and info.name == loadoutName then
            targetID = id
            break
        end
    end
    
    if targetID then
        local success = C_ClassTalents.LoadConfig(targetID, true)
        if success == Enum.LoadConfigResult.Error then
            print("|cffff0000Ascension Talents:|r Failed to load configuration.")
        else
            AT.Modules.Reminder.lastCustomLoadoutName = nil -- Reset custom tracker if switching to native
        end
    else
        print("|cffff0000Ascension Talents:|r Could not find loadout named: " .. loadoutName)
    end
end
