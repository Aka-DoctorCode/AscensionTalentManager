local addonName, ns = ...
local AT = ns.AT
local Options = AT:NewModule("Options")
AT.Modules.Options = Options

function Options:OnInitialize()
    self:RegisterOptions()
end

function Options:ToggleSettings()
    if LibStub("AceConfigDialog-3.0").OpenFrames[addonName] then
        LibStub("AceConfigDialog-3.0"):Close(addonName)
    else
        LibStub("AceConfigDialog-3.0"):Open(addonName)
    end
end

function Options:GetOptions()
    local classID = select(3, UnitClass("player"))
    local _, classTag = GetClassInfo(classID)
    local classColor = RAID_CLASS_COLORS[classTag].colorStr

    local options = {
        name = "|c" .. classColor .. "Ascension Talent Manager|r - Configuration",
        handler = AT,
        type = "group",
        args = {
            intro = {
                type = "description",
                name = "Manage your talent builds, reminders, and leveling guides with a premium experience.",
                order = 0,
            },
            general = {
                name = "Core Systems",
                desc = "Main addon functionality and automation.",
                type = "group",
                order = 1,
                inline = true,
                args = {
                    reminderEnabled = {
                        name = "Enable Reminders",
                        desc = "Enable or disable talent set reminders when entering instances.",
                        type = "toggle",
                        order = 1,
                        get = function() return AT.db.profile.reminder.enabled end,
                        set = function(_, val) AT.db.profile.reminder.enabled = val end,
                    },
                    popupOnMismatch = {
                        name = "Smart Notifications",
                        desc = "Show a popup when you are not in the correct talent set for the current activity.",
                        type = "toggle",
                        order = 2,
                        get = function() return AT.db.profile.reminder.popupOnMismatch end,
                        set = function(_, val) AT.db.profile.reminder.popupOnMismatch = val end,
                    },
                    autoSwap = {
                        name = "Auto-Swap (Beta)",
                        desc = "Automatically change your talents when entering a context (Raid/Dungeon) while out of combat.",
                        type = "toggle",
                        order = 3,
                        get = function() return AT.db.profile.reminder.autoSwap end,
                        set = function(_, val) AT.db.profile.reminder.autoSwap = val end,
                    },
                    autoLevelUp = {
                        name = "Auto Level-Up",
                        desc = "Automatically spend talent points according to your leveling guide when you level up.",
                        type = "toggle",
                        order = 4,
                        get = function() return AT.db.profile.leveling.autoApply end,
                        set = function(_, val) AT.db.profile.leveling.autoApply = val end,
                    },
                },
            },
            importGroup = {
                name = "Import New Build",
                type = "group",
                order = 2,
                inline = true,
                args = {
                    importName = {
                        name = "Build Name",
                        desc = "Give your imported build a recognizable name.",
                        type = "input",
                        order = 1,
                        get = function() return Options.tempImportName or "" end,
                        set = function(_, val) Options.tempImportName = val end,
                    },
                    importString = {
                        name = "URL or Blizzard String",
                        desc = "Paste an Icy Veins URL or a Blizzard Export String (starts with CU...).",
                        type = "input",
                        width = "full",
                        order = 2,
                        get = function() return Options.tempImportString or "" end,
                        set = function(_, val) Options.tempImportString = val end,
                    },
                    doImport = {
                        name = "Import Now",
                        type = "execute",
                        order = 3,
                        func = function()
                            local name = Options.tempImportName
                            local text = Options.tempImportString
                            if not name or name == "" or not text or text == "" then
                                AT:Printf("|cffff0000Error:|r Please enter both a name and a string/URL.")
                                return
                            end
                            local bStr, lOrder, err = AT.Modules.Importer:ImportFromText(text)
                            if bStr then
                                AT.Modules.Manager:SaveCustomLoadout(name, bStr, lOrder)
                                Options.tempImportName = ""
                                Options.tempImportString = ""
                                AT.Modules.UI:RefreshList()
                                AT:Printf("Successfully imported |cffffd200%s|r.", name)
                            else
                                AT:Printf("Import failed: %s", err)
                            end
                        end,
                    },
                }
            },
            massActions = {
                name = "Mass Actions",
                type = "group",
                order = 3,
                inline = true,
                args = {
                    exportAll = {
                        name = "Export All (Clipboard)",
                        desc = "Copy all your custom builds for this specialization to share or backup.",
                        type = "execute",
                        order = 1,
                        func = function()
                            local data = AT.Modules.Manager:GetMassExportString()
                            StaticPopup_Show("ASCENSION_TALENTS_MASS_EXPORT", nil, nil, data)
                        end,
                    },
                    massImport = {
                        name = "Mass Import",
                        desc = "Paste a mass export string to import multiple builds at once.",
                        type = "execute",
                        order = 2,
                        func = function()
                            StaticPopup_Show("ASCENSION_TALENTS_MASS_IMPORT")
                        end,
                    },
                }
            },
            reminders = {
                name = "Context-Aware Reminders",
                desc = "Assign specific builds to different game activities.",
                type = "group",
                order = 3,
                childGroups = "tab",
                args = {}, 
            },
            profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(AT.db),
        },
    }
    options.args.profiles.order = 3

    -- Populate reminders per spec and context with enhanced UI/UX
    for i = 1, GetNumSpecializationsForClassID(classID) do
        local id, name, _, icon = GetSpecializationInfoForClassID(classID, i)
        if id then
            options.args.reminders.args["spec" .. id] = {
                name = "|T" .. icon .. ":18:18:0:0|t " .. name,
                type = "group",
                order = i,
                args = {
                    header = {
                        type = "header",
                        name = "Auto-Switch Rules for " .. name,
                        order = 1,
                    },
                },
            }
            
            local contexts = AT.Modules.Reminder.Contexts
            for j, context in ipairs(contexts) do
                 local label = context:gsub("^%l", string.upper)
                 if context == "farming" then label = "Farming/Legacy" end
                 
                 options.args.reminders.args["spec" .. id].args[context] = {
                    name = "|cffffd200" .. label .. "|r",
                    desc = "Which loadout should be active in " .. context .. "?",
                    type = "select",
                    order = j + 1,
                    width = "normal",
                    values = function()
                        local list = { ["-"] = "|cff888888None/Disabled|r" }
                        -- Add blizzard configs
                        local configs = C_ClassTalents.GetConfigIDsBySpecID(id)
                        for _, configID in ipairs(configs) do
                            local info = C_Traits.GetConfigInfo(configID)
                            if info then
                                list[info.name] = info.name
                            end
                        end
                        -- Add custom loadouts
                        local custom = AT.db.profile.manager.customLoadouts[classID]
                                       and AT.db.profile.manager.customLoadouts[classID][id]
                        if custom then
                            for cName in pairs(custom) do
                                list[cName] = "|cff00ff00(Custom)|r " .. cName
                            end
                        end
                        return list
                    end,
                    get = function() 
                        return AT.db.profile.reminder.perSpec[id] and AT.db.profile.reminder.perSpec[id][context] or "-"
                    end,
                    set = function(_, val)
                        AT.db.profile.reminder.perSpec[id] = AT.db.profile.reminder.perSpec[id] or {}
                        AT.db.profile.reminder.perSpec[id][context] = val
                    end,
                }
            end
        end
    end

    return options
end

function Options:RegisterOptions()
    LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, self:GetOptions())
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, "Ascension Talent Manager")
end
