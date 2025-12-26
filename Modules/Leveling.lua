local addonName, ns = ...
local AT = ns.AT
local Leveling = AT:NewModule("Leveling", "AceEvent-3.0", "AceHook-3.0")
AT.Modules.Leveling = Leveling

function Leveling:OnInitialize()
    self.activeLevelingBuild = nil
    self.activeBuildName = nil
end

function Leveling:OnEnable()
    self:RegisterEvent("TRAIT_CONFIG_UPDATED", "UpdateHighlights")
    self:RegisterEvent("TRAIT_NODE_CHANGED", "OnNodeSpent")
    self:RegisterEvent("PLAYER_LEVEL_UP", "OnLevelUp")
    
    if C_AddOns.IsAddOnLoaded("Blizzard_PlayerSpells") then
        self:SetupHooks()
    else
        self:RegisterEvent("ADDON_LOADED", function(_, addon)
            if addon == "Blizzard_PlayerSpells" then
                self:SetupHooks()
            end
        end)
    end
end

function Leveling:SetupHooks()
    if PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame then
        self:SecureHook(PlayerSpellsFrame.TalentsFrame, "OnShow", "UpdateHighlights")
    end
end

function Leveling:SetActiveBuild(name, levelingOrder)
    self.activeBuildName = name
    self.activeLevelingBuild = levelingOrder
    self:UpdateHighlights()
end

function Leveling:UpdateHighlights()
    if not self.activeLevelingBuild or not PlayerSpellsFrame or not PlayerSpellsFrame:IsShown() then 
        return 
    end
    
    local talentsFrame = PlayerSpellsFrame.TalentsFrame
    if not talentsFrame then return end

    -- Clear previous highlights
    if self.highlightFrames then
        for _, frame in pairs(self.highlightFrames) do
            frame:Hide()
        end
    end
    self.highlightFrames = self.highlightFrames or {}

    -- Find the next node to pick
    local nextNode = self:GetNextNodeToPick()
    if not nextNode then return end

    -- Highlight it
    if talentsFrame.GetNodeFrame then
        local button = talentsFrame:GetNodeFrame(nextNode.nodeID)
        if button then
            self:HighlightButton(button, nextNode.nodeID)
        end
    end
end

function Leveling:GetNextNodeToPick()
    if not self.activeLevelingBuild then return nil end
    
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return nil end

    for _, entry in ipairs(self.activeLevelingBuild) do
        local nodeInfo = C_Traits.GetNodeInfo(configID, entry.nodeID)
        if nodeInfo and nodeInfo.ranksPurchased < entry.rank then
            return entry
        end
    end
    return nil
end

function Leveling:HighlightButton(button, nodeID)
    local h = self.highlightFrames[nodeID]
    if not h then
        h = CreateFrame("Frame", nil, button, "BackdropTemplate")
        h:SetPoint("TOPLEFT", -5, 5)
        h:SetPoint("BOTTOMRIGHT", 5, -5)
        h:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
        })
        h:SetBackdropBorderColor(0, 1, 0, 1) -- Bright Green
        
        -- Add a pulsing animation
        local group = h:CreateAnimationGroup()
        local anim = group:CreateAnimation("Alpha")
        anim:SetFromAlpha(1)
        anim:SetToAlpha(0.3)
        anim:SetDuration(0.8)
        anim:SetOrder(1)
        anim:SetSmoothing("IN_OUT")
        group:SetLooping("BOUNCE")
        h.anim = group
        
        self.highlightFrames[nodeID] = h
    end
    
    h:SetParent(button)
    h:Show()
    h.anim:Play()
end
function Leveling:StartRecording(targetBuildName)
    self.recordingBuildName = targetBuildName
    self.recordedOrder = {}
    AT:Printf("Recording started for '|cffffd200%s|r'. Spend talent points to capture order.", targetBuildName)
end

function Leveling:StopRecording()
    if not self.recordingBuildName then return end
    
    local name = self.recordingBuildName
    local order = self.recordedOrder
    
    self.recordingBuildName = nil
    self.recordedOrder = nil
    
    local data = AT.Modules.Manager:GetCustomLoadouts()[name]
    if data and type(data) == "table" then
        data.levelingOrder = order
        AT:Printf("Recording saved to '|cffffd200%s|r'.", name)
    end
end

function Leveling:OnNodeSpent(event, nodeID)
    if not self.recordingBuildName then return end
    
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return end
    
    local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
    if nodeInfo and nodeInfo.ranksPurchased > 0 then
        -- Avoid duplicates if rank is already recorded
        local selectionID = nodeInfo.activeEntry and nodeInfo.activeEntry.entryID
        
        table.insert(self.recordedOrder, {
            nodeID = nodeID,
            entryID = selectionID,
            rank = nodeInfo.ranksPurchased
        })
    end
end

function Leveling:OnLevelUp(event, level)
    if level < 10 then return end
    if not AT.db.profile.leveling or not AT.db.profile.leveling.autoApply then return end
    
    -- Delay a bit to ensure currency/nodes are updated
    C_Timer.After(1, function()
        if not InCombatLockdown() then
            self:AutoApplyNextPoint()
        else
            self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
                self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                self:AutoApplyNextPoint()
            end)
        end
    end)
end

function Leveling:AutoApplyNextPoint()
    if not self.activeLevelingBuild then return end
    
    local nextNode = self:GetNextNodeToPick()
    if not nextNode then return end
    
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return end
    
    local nodeInfo = C_Traits.GetNodeInfo(configID, nextNode.nodeID)
    if not nodeInfo or not nodeInfo.canPurchase then return end

    -- Apply the point
    local success = C_Traits.PurchaseRank(configID, nextNode.nodeID)
    if success then
        C_Traits.CommitConfig(configID)
        local selectionID = nextNode.entryID
        local spellID = selectionID and C_Traits.GetEntryInfo(configID, selectionID).definitionID and C_Traits.GetDefinitionInfo(C_Traits.GetEntryInfo(configID, selectionID).definitionID).spellID
        local spellLink = spellID and C_Spell.GetSpellLink(spellID) or "Talent"
        
        AT:Printf("Auto Level-Up: Learned |cff00ff00%s|r (Rank %d).", spellLink, nextNode.rank)
        self:UpdateHighlights()
    end
end
