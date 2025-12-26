local addonName, ns = ...
local AT = ns.AT
local AntiTaint = AT:NewModule("AntiTaint", "AceEvent-3.0", "AceHook-3.0")
AT.Modules.AntiTaint = AntiTaint

function AntiTaint:OnInitialize()
    -- Cleanup unused registration
end

function AntiTaint:OnEnable()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_PlayerSpells", function()
        self:SetupHooks()
    end)
    self:HandleActionBarEventTaintSpread()
end

function AntiTaint:SetupHooks()
    local talentsTab = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
    if not talentsTab then return end

    -- Hook talent buttons to prevent highlights from tainting
    talentsTab:RegisterCallback(TalentFrameBaseMixin.Event.TalentButtonAcquired, self.OnTalentButtonAcquired, self)
    for talentButton in talentsTab:EnumerateAllTalentButtons() do
        self:OnTalentButtonAcquired(talentButton)
    end

    -- Securely hook panel shows
    self:SecureHook("ShowUIPanel", "OnShowUIPanel")
    self:SecureHook("HideUIPanel", "OnHideUIPanel")
end

function AntiTaint:OnTalentButtonAcquired(button)
    button.ShowActionBarHighlights = function(btn) self:SetActionBarHighlights(btn, true) end
    button.HideActionBarHighlights = function(btn) self:SetActionBarHighlights(btn, false) end
end

function AntiTaint:SetActionBarHighlights(talentButton, shown)
    local spellID = talentButton:GetSpellID()
    if not spellID then return end
    
    -- Optimized highlight refresh that avoids the guarded Blizzard paths
    for _, actionButton in pairs(ActionBarButtonEventsFrame.frames) do
        if actionButton.SpellHighlightTexture and actionButton.SpellHighlightAnim then
            local isMatch = (spellID == actionButton.spellID) -- Simplified check
            SharedActionButton_RefreshSpellHighlight(actionButton, shown and isMatch)
        end
    end
end

function AntiTaint:OnShowUIPanel(frame)
    if frame == PlayerSpellsFrame and not frame:IsShown() then
        frame:Show() -- Force show to bypass potential blocked actions
    end
end

function AntiTaint:OnHideUIPanel(frame)
    if frame == PlayerSpellsFrame and frame:IsShown() then
        frame:Hide()
    end
end

function AntiTaint:HandleActionBarEventTaintSpread()
    -- This logic prevents the talent UI from tainting the ActionBars
    -- by unregistering certain events from the main frame and handling them per-button
    local events = {
        ["PLAYER_ENTERING_WORLD"] = true,
        ["ACTIONBAR_SLOT_CHANGED"] = true,
        ["UPDATE_BINDINGS"] = true,
    }
    
    for _, actionButton in pairs(ActionBarButtonEventsFrame.frames) do
        for event in pairs(events) do
            actionButton:RegisterEvent(event)
        end
    end
    
    for event in pairs(events) do
        ActionBarButtonEventsFrame:UnregisterEvent(event)
    end
end
