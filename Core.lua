local addonName, ns = ...
local AscensionTalentManager = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")
_G.AscensionTalentManager = AscensionTalentManager
ns.AT = AscensionTalentManager

AscensionTalentManager.Modules = {}

function AscensionTalentManager:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("AscensionTalentManagerDB", {
        profile = {
            reminder = {
                enabled = true,
                autoSwap = false,
                popupOnMismatch = true,
                minimap = {
                    hide = false,
                },
                perSpec = {}, -- [specID] = { [context] = loadoutName }
            },
            manager = {
                customLoadouts = {}, -- [classID][specID][loadoutName] = serializedData
            },
            leveling = {
                autoApply = true,
            },
        }
    }, true)
    
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
    
    self:Printf("Initialized")
    
    self:RegisterChatCommand("asct", "ChatCommand")
    self:RegisterChatCommand("asctalents", "ChatCommand")
    self:RegisterChatCommand("ascto", "OpenSettings")
    self:RegisterChatCommand("asto", "OpenSettings")
    self:RegisterChatCommand("atm", "OpenManager")
end

function AscensionTalentManager:OpenSettings()
    if self.Modules.Options then
        self.Modules.Options:ToggleSettings()
    end
end

function AscensionTalentManager:RefreshConfig()
    -- This is called when the profile changes
    if self.Modules.UI then
        self.Modules.UI:RefreshList()
    end
end

function AscensionTalentManager:OpenManager()
    if self.Modules.UI then
        self.Modules.UI:ToggleFloatingManager()
    end
end

function AscensionTalentManager:ChatCommand(input)
    if not input or input:trim() == "" then
        -- Open settings? For now just print help
        self:PrintHelp()
        return
    end
    
    local command, nextedittime = self:GetArgs(input, 2)
    
    if command == "save" then
        if not nextedittime then self:Printf("Usage: /asct save <name>") return end
        self.Modules.Manager:SaveCurrentAsCustom(nextedittime)
    elseif command == "load" then
        if not nextedittime then self:Printf("Usage: /asct load <name>") return end
        self.Modules.Manager:ApplyCustomLoadout(nextedittime)
    elseif command == "list" then
        local list = self.Modules.Manager:GetCustomLoadouts()
        self:Printf("Custom Loadouts:")
        for name in pairs(list) do
            print("- " .. name)
        end
    elseif command == "setparent" then
        local customName, parentID = self:GetArgs(input, 3)
        if not customName or not parentID then self:Printf("Usage: /asct setparent <customName> <blizzardConfigID>") return end
        self.Modules.Manager:SetParent(customName, tonumber(parentID))
        self:Printf("Parent for %s set to %s", customName, parentID)
    elseif command == "delete" then
        if not nextedittime then self:Printf("Usage: /asct delete <name>") return end
        self.Modules.Manager:DeleteCustomLoadout(nextedittime)
    elseif command == "import" then
        local name, text = self:GetArgs(input, 3)
        if not name or not text then self:Printf("Usage: /asct import <name> <url/string>") return end
        
        local blizzardString, levelingOrder, err = self.Modules.Importer:ImportFromText(text)
        if blizzardString then
            self.Modules.Manager:SaveCustomLoadout(name, blizzardString, levelingOrder)
        else
            self:Printf("Import failed: %s", err)
        end
    elseif command == "config" or command == "options" or command == "settings" then
        self:OpenSettings()
    else
        self:PrintHelp()
    end
end

function AscensionTalentManager:PrintHelp()
    self:Printf("Commands:")
    print("  /asct save <name> - Save current talents as custom loadout")
    print("  /asct load <name> - Load a custom loadout (handles slot switching)")
    print("  /asct list        - List custom loadouts")
    print("  /asct setparent <name> <id> - Link custom loadout to a Blizzard slot ID")
    print("  /asct import <name> <url/string> - Import a build from IcyVeins or Blizzard string")
    print("  /asct delete <name> - Delete a custom loadout")
    print("  /asct config      - Open the advanced settings window")
    print("  /atm              - Open the floating manager window")
    print("  /ascto            - Quick shortcut to settings")
end

function AscensionTalentManager:GetModule(name)
    return self.Modules[name]
end

function AscensionTalentManager:RegisterModule(name, module)
    self.Modules[name] = module
end
