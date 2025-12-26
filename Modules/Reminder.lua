local addonName, ns = ...
local AT = ns.AT
local Reminder = AT:NewModule("Reminder", "AceEvent-3.0")
AT.Modules.Reminder = Reminder

local L = {
    WORLD = "Open World",
    DUNGEONS = "Dungeons (incl. M+)",
    RAID = "Raid",
    FARMING = "Farming/Legacy",
    DELVE = "Delve",
    PVP = "PvP",
}

Reminder.Contexts = {"world", "dungeons", "raid", "farming", "delve", "pvp"}

function Reminder:OnInitialize()
    -- Optional initialization
end

function Reminder:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "CheckContext")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "CheckContext")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "CheckContext")
    self:RegisterEvent("TRAIT_CONFIG_UPDATED", "CheckContext")
end

function Reminder:IsLegacyContent()
    if C_Loot and C_Loot.IsLegacyLootModeEnabled and C_Loot.IsLegacyLootModeEnabled() then
        return true
    end
    -- Torghast check (Map IDs)
    local mapID = select(8, GetInstanceInfo())
    if mapID and mapID >= 2160 and mapID <= 2400 then return true end
    return false
end

function Reminder:GetContext()
    local _, instanceType, difficultyID, _, _, _, _, mapID = GetInstanceInfo()
    
    if self:IsLegacyContent() then return "farming" end
    if instanceType == "none" then return "world" end
    if instanceType == "pvp" or instanceType == "arena" then return "pvp" end
    
    -- Mythic+ Affix detection for context
    if difficultyID == 8 then -- Mythic Keystone
        -- M+ logic here
    end

    if difficultyID == 205 then return "delve" end 
    if instanceType == "party" then return "dungeons" end
    if instanceType == "raid" then return "raid" end
    
    return "world"
end

function Reminder:CanSwapTalents()
    if InCombatLockdown() then return false end
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then 
        return false 
    end
    return true
end

function Reminder:GetActiveLoadoutName()
    local spec = GetSpecialization()
    if not spec then return nil end
    local specID = GetSpecializationInfo(spec)
    if not specID then return nil end
    
    -- Check if we are currently using a custom loadout
    if self.lastCustomLoadoutName then
        local currentString = C_Traits.GenerateImportString(C_ClassTalents.GetActiveConfigID())
        local savedString = AT.Modules.Manager:GetCustomLoadouts()[self.lastCustomLoadoutName]
        if currentString == savedString then
            return self.lastCustomLoadoutName
        end
    end

    local configID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
    if not configID then return nil end
    
    local configInfo = C_Traits.GetConfigInfo(configID)
    return configInfo and configInfo.name
end

function Reminder:CheckContext(force)
    if type(force) == "string" then force = false end
    if not AT.db.profile.reminder.enabled and not force then return end
    
    local context = self:GetContext()
    local spec = GetSpecialization()
    if not spec then return end
    local specID = GetSpecializationInfo(spec)
    
    local desiredLoadout = AT.db.profile.reminder.perSpec[specID] and AT.db.profile.reminder.perSpec[specID][context]
    if not desiredLoadout or desiredLoadout == "-" then return end
    
    local currentLoadout = self:GetActiveLoadoutName()
    
    if currentLoadout ~= desiredLoadout then
        if AT.db.profile.reminder.autoSwap and self:CanSwapTalents() then
            AT:Printf("Auto-swapping to '|cffffd200%s|r' for %s.", desiredLoadout, context)
            AT.Modules.Manager:ApplyCustomLoadout(desiredLoadout)
        else
            self:ShowPopup(context, currentLoadout, desiredLoadout)
        end
    end
end

function Reminder:ShowPopup(context, current, desired)
    -- This will call the UI module
    if AT.Modules.ReminderUI then
        AT.Modules.ReminderUI:Show(context, current, desired)
    end
end
