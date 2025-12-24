local addonName, ns = ...
local AT = ns.AT
local Manager = AT:NewModule("Manager", "AceEvent-3.0")
AT.Modules.Manager = Manager

function Manager:OnInitialize()
    -- Ensure tables exist
    AT.db.profile.manager = AT.db.profile.manager or {}
    AT.db.profile.manager.customLoadouts = AT.db.profile.manager.customLoadouts or {}
    AT.db.profile.manager.parentMapping = AT.db.profile.manager.parentMapping or {} -- [classID][specID][customName] = blizzardConfigID

    -- Ensure current class/spec path exists in DB
    local classID = select(3, UnitClass("player"))
    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)
    if classID and specID then
        AT.db.profile.manager.customLoadouts[classID] = AT.db.profile.manager.customLoadouts[classID] or {}
        AT.db.profile.manager.customLoadouts[classID][specID] = AT.db.profile.manager.customLoadouts[classID][specID] or {}
    end
end

function Manager:OnEnable()
    self:RegisterEvent("TRAIT_CONFIG_UPDATED", "SyncParent")
end

function Manager:SyncParent()
    local activeConfigID = C_ClassTalents.GetActiveConfigID()
    if not activeConfigID then return end
    
    local classID = select(3, UnitClass("player"))
    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)
    if not specID then return end

    local mapping = AT.db.profile.manager.parentMapping[classID] 
                    and AT.db.profile.manager.parentMapping[classID][specID]
    if not mapping then return end

    for customName, parentConfigID in pairs(mapping) do
        if parentConfigID == activeConfigID then
            local currentString = C_Traits.GenerateImportString(activeConfigID)
            local data = AT.db.profile.manager.customLoadouts[classID][specID][customName]
            
            if data and type(data) == "table" and data.importString ~= currentString then
                data.importString = currentString
                -- AT:Printf("Synced '|cffffd200%s|r' with changes in Blizzard slot.", customName)
            end
        end
    end
end

function Manager:SetParent(customName, parentConfigID)
    local classID = select(3, UnitClass("player"))
    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)
    if not specID then return end
    
    AT.db.profile.manager.parentMapping[classID] = AT.db.profile.manager.parentMapping[classID] or {}
    AT.db.profile.manager.parentMapping[classID][specID] = AT.db.profile.manager.parentMapping[classID][specID] or {}
    AT.db.profile.manager.parentMapping[classID][specID][customName] = parentConfigID
end

function Manager:GetParent(customName)
    local classID = select(3, UnitClass("player"))
    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)
    if not specID then return nil end
    
    if AT.db.profile.manager.parentMapping[classID] 
       and AT.db.profile.manager.parentMapping[classID][specID] then
        return AT.db.profile.manager.parentMapping[classID][specID][customName]
    end
    return nil
end

function Manager:GetCustomLoadouts()
    local spec = GetSpecialization()
    if not spec then return {} end
    local specID = GetSpecializationInfo(spec)
    local classID = select(3, UnitClass("player"))
    
    if AT.db.profile.manager.customLoadouts[classID] and AT.db.profile.manager.customLoadouts[classID][specID] then
        return AT.db.profile.manager.customLoadouts[classID][specID]
    end
    return {}
end

function Manager:SaveCustomLoadout(name, importString, levelingOrder)
    local spec = GetSpecialization()
    if not spec then return false end
    local specID = GetSpecializationInfo(spec)
    local classID = select(3, UnitClass("player"))
    
    AT.db.profile.manager.customLoadouts[classID] = AT.db.profile.manager.customLoadouts[classID] or {}
    AT.db.profile.manager.customLoadouts[classID][specID] = AT.db.profile.manager.customLoadouts[classID][specID] or {}
    AT.db.profile.manager.customLoadouts[classID][specID][name] = {
        importString = importString,
        levelingOrder = levelingOrder
    }
    
    AT:Printf("Imported loadout '|cffffd200%s|r' saved.", name)
    return true
end

function Manager:SaveCurrentAsCustom(name)
    local spec = GetSpecialization()
    if not spec then return false, "No specialization active" end
    local specID = GetSpecializationInfo(spec)
    local classID = select(3, UnitClass("player"))
    
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return false, "Could not find active config" end
    
    local importString = C_Traits.GenerateImportString(configID)
    if not importString or importString == "" then 
        return false, "Failed to generate import string" 
    end
    
    AT.db.profile.manager.customLoadouts[classID] = AT.db.profile.manager.customLoadouts[classID] or {}
    AT.db.profile.manager.customLoadouts[classID][specID] = AT.db.profile.manager.customLoadouts[classID][specID] or {}
    AT.db.profile.manager.customLoadouts[classID][specID][name] = {
        importString = importString,
        levelingOrder = nil -- Saving current doesn't have leveling order by default
    }
    
    -- Automatically set the current blizzard slot as parent
    self:SetParent(name, configID)
    
    AT:Printf("Custom loadout '|cffffd200%s|r' saved (linked to Blizzard slot: %s).", name, (C_Traits.GetConfigInfo(configID).name))
    return true
end

function Manager:ApplyCustomLoadout(name)
    local spec = GetSpecialization()
    if not spec then return false end
    local specID = GetSpecializationInfo(spec)
    local classID = select(3, UnitClass("player"))
    
    local data = AT.db.profile.manager.customLoadouts[classID] 
                        and AT.db.profile.manager.customLoadouts[classID][specID] 
                        and AT.db.profile.manager.customLoadouts[classID][specID][name]
    
    if not data then return false end
    
    local importString = type(data) == "table" and data.importString or data
    
    local parentConfigID = self:GetParent(name)
    local activeConfigID = C_ClassTalents.GetActiveConfigID()
    
    if InCombatLockdown() then
        AT:Printf("Cannot change talents in combat.")
        return false
    end

    -- If we are not on the parent slot, switch to it first
    if parentConfigID and activeConfigID ~= parentConfigID then
        AT:Printf("Switching to parent slot: %s...", (C_Traits.GetConfigInfo(parentConfigID).name))
        C_ClassTalents.LoadConfig(parentConfigID, true)
        
        -- We defer the actual import until the slot switch is done (via event or timer)
        C_Timer.After(0.5, function() self:ApplyCustomLoadout(name) end)
        return true
    end
    
    -- Once on the correct slot (or if no parent assigned), import the traits
    local success = C_Traits.ImportLoadout(activeConfigID, importString)
    if success then
        if C_Traits.CommitConfig(activeConfigID) then
            AT:Printf("Applied custom loadout '|cffffd200%s|r'.", name)
            
            -- If this build has a leveling order, activate the leveling guide
            if type(data) == "table" and data.levelingOrder and AT.Modules.Leveling then
                AT.Modules.Leveling:SetActiveBuild(name, data.levelingOrder)
            end
            
            return true
        end
    end
    
    AT:Printf("Failed to apply custom loadout.")
    return false
end

function Manager:DeleteCustomLoadout(name)
    local spec = GetSpecialization()
    if not spec then return end
    local specID = GetSpecializationInfo(spec)
    local classID = select(3, UnitClass("player"))
    
    if AT.db.profile.manager.customLoadouts[classID] and AT.db.profile.manager.customLoadouts[classID][specID] then
        AT.db.profile.manager.customLoadouts[classID][specID][name] = nil
        AT:Printf("Deleted custom loadout '%s'.", name)
    end
end

function Manager:GetMassExportString()
    local classID = select(3, UnitClass("player"))
    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)
    if not specID then return "No active spec" end
    
    local data = AT.db.profile.manager.customLoadouts[classID] and AT.db.profile.manager.customLoadouts[classID][specID]
    if not data then return "No builds to export" end
    
    local serializer = LibStub("AceSerializer-3.0")
    return serializer:Serialize(data)
end

function Manager:MassImport(input)
    local serializer = LibStub("AceSerializer-3.0")
    local success, data = serializer:Deserialize(input)
    if not success then return false, "Invalid format" end
    
    local classID = select(3, UnitClass("player"))
    local spec = GetSpecialization()
    local specID = spec and GetSpecializationInfo(spec)
    if not specID then return false, "No active spec" end

    AT.db.profile.manager.customLoadouts[classID] = AT.db.profile.manager.customLoadouts[classID] or {}
    AT.db.profile.manager.customLoadouts[classID][specID] = AT.db.profile.manager.customLoadouts[classID][specID] or {}
    
    local count = 0
    for name, buildData in pairs(data) do
        AT.db.profile.manager.customLoadouts[classID][specID][name] = buildData
        count = count + 1
    end
    
    return true, count
end
