local addonName, ns = ...
local AT = ns.AT
local Importer = AT:NewModule("Importer")
AT.Modules.Importer = Importer

local LibTT = LibStub("LibTalentTree-1.0")

-- Constants ported from TLM
local BIT_WIDTH_HEADER_VERSION = 8
local BIT_WIDTH_SPEC_ID = 16
local SERIALIZATION_VERSION = 2
local ICYVEINS_SPEC_ID_WIDTH = 12
local ICYVEINS_NODE_INDEX_WIDTH = 6

function Importer:OnInitialize()
    self.classAndSpecNodeCache = {}
end

function Importer:SafeMakeStream(text)
    if not text or text == "" then return nil end
    local success, stream = pcall(ExportUtil.MakeImportDataStream, text)
    return success and stream or nil
end

function Importer:SafeExtract(stream, bits)
    if not stream or not bits then return 0 end
    local success, value = pcall(stream.ExtractValue, stream, bits)
    if not success then
        stream.isBroken = true
        return 0
    end
    return value
end

function Importer:GetRemainingBits(stream)
    if not stream then return 0 end
    local success, total = pcall(stream.GetNumberOfBits, stream)
    if not success then return 0 end
    local current = stream.currentExtractedBits or 0
    return total - current
end

-- Check if input is a Blizzard export string (starts with CU and long enough)
function Importer:IsBlizzardString(text)
    return text:match("^CU") and #text > 50
end

-- Check if input is an Icy Veins URL
function Importer:IsIcyVeinsUrl(text)
    return text:match("icy%-veins%.com/wow/.*%-talent%-calculator#")
end

-- Check if input is a Wowhead URL
function Importer:IsWowheadUrl(text)
    return text:match("wowhead%.com/.*/talent%-calc/")
end

-- Main entry point for importing from text/URL
function Importer:ImportFromText(text)
    text = text:trim()
    
    if self:IsBlizzardString(text) then
        local mainString, levelingPart = text:match("^(.*)%-LVL%-(.*)$")
        if not mainString then
            return text, nil, nil -- Plain string
        end
        return mainString, self:ParseBlizzardLevelingData(mainString, levelingPart), nil
    end
    
    if self:IsIcyVeinsUrl(text) then
        return self:ImportFromIcyVeins(text)
    end
    
    if self:IsWowheadUrl(text) then
        local bPart = text:match("(CU%w+)")
        if bPart then
            return self:ImportFromText(bPart)
        end
        return nil, nil, "This Wowhead URL doesn't contain a Blizzard string. Please use the 'Export' button on Wowhead."
    end
    
    return nil, nil, "Unrecognized format. Please provide a Blizzard export string or an Icy Veins URL."
end

-------------------------------------------------------------------------------
-- Icy Veins Logic Port
-------------------------------------------------------------------------------

function Importer:ImportFromIcyVeins(url)
    local dataSection = url:match("#(.*)")
    if not dataSection then return nil, nil, "Invalid Icy Veins URL (no data section)" end
    
    dataSection = dataSection:gsub(":", "/") -- IcyVeins uses : instead of / for base64

    local segments = { string.split("-", dataSection) }
    local specIDString = segments[1]
    if not specIDString or specIDString == "" then return nil, nil, "Invalid Icy Veins URL (missing spec segment)" end

    local specID = tonumber(specIDString)
    if not specID then
        local importStream = self:SafeMakeStream(specIDString)
        if importStream then
            specID = tonumber(self:SafeExtract(importStream, ICYVEINS_SPEC_ID_WIDTH))
        end
    end

    if not specID then return nil, nil, "Could not extract SpecID from URL" end

    local classID = C_SpecializationInfo.GetClassIDFromSpecID(specID)
    if not classID then 
        -- If specID extraction was wrong (e.g. it was a ClassID), try to handle it
        classID = specID -- Fallback if the first segment was ClassID
    end

    local treeID = LibTT:GetClassTreeID(classID)
    if not treeID then return nil, nil, "Could not find talent tree for Spec/Class ID: " .. specID end

    -- Icy Veins segments: [1]SpecID/Class, [2]ClassTree, [3]SpecTree, [4]HeroTree
    local classString = segments[2]
    local specString = segments[3]
    local heroString = segments[4]

    -- Map selected nodes
    local classNodes, specNodes, heroNodesByTree = self:GetClassAndSpecNodeIDs(specID, treeID)
    
    -- Parse segments with safety
    local selectedNodes = {}
    local levelingOrder = {}
    
    if classString and classString ~= "" then
        self:ParseIcyVeinsSegment(classString, classNodes, selectedNodes, levelingOrder)
    end
    if specString and specString ~= "" then
        self:ParseIcyVeinsSegment(specString, specNodes, selectedNodes, levelingOrder)
    end
    
    -- Hero talents handling
    if heroString and heroString ~= "" then
        local heroStream = self:SafeMakeStream(heroString)
        if heroStream and self:GetRemainingBits(heroStream) > 0 then
            local heroTreeIndex = self:SafeExtract(heroStream, 1) + 1
            local subTreeIDs = LibTT:GetSubTreeIDsForSpecID(specID)
            local selectedSubTreeID = subTreeIDs[heroTreeIndex]
            if selectedSubTreeID and heroNodesByTree[selectedSubTreeID] then
                self:ParseIcyVeinsSegment(heroString, heroNodesByTree[selectedSubTreeID], selectedNodes, levelingOrder, 1)
            end
        end
    end

    -- Construct a Blizzard string from these nodes
    return self:CreateBlizzardStringFromNodes(specID, treeID, selectedNodes), levelingOrder, nil
end

function Importer:ParseIcyVeinsSegment(segmentString, nodes, results, levelingOrder, bitOffset)
    if not segmentString or segmentString == "" then return end
    local stream = self:SafeMakeStream(segmentString)
    if not stream then return end
    
    if bitOffset then self:SafeExtract(stream, bitOffset) end
    
    local rankByNodeID = {}
    local safetyCount = 0
    
    while self:GetRemainingBits(stream) > ICYVEINS_NODE_INDEX_WIDTH and not stream.isBroken and safetyCount < 500 do
        safetyCount = safetyCount + 1
        local nodeIndex = self:SafeExtract(stream, ICYVEINS_NODE_INDEX_WIDTH) + 1
        local nodeID = nodes[nodeIndex]
        
        if nodeID then
            local nodeInfo = LibTT:GetNodeInfo(nodeID)
            local entryID
            
            if nodeInfo.type == Enum.TraitNodeType.Selection or nodeInfo.type == Enum.TraitNodeType.SubTreeSelection then
                local choiceIndex = self:SafeExtract(stream, 1) + 1
                entryID = nodeInfo.entryIDs[choiceIndex]
            else
                entryID = nodeInfo.entryIDs[1]
            end
            
            rankByNodeID[nodeID] = (rankByNodeID[nodeID] or 0) + 1
            results[nodeID] = {
                nodeID = nodeID,
                entryID = entryID,
                rank = rankByNodeID[nodeID]
            }
            -- Add to leveling order
            table.insert(levelingOrder, {
                nodeID = nodeID,
                entryID = entryID,
                rank = rankByNodeID[nodeID]
            })
        else
            break
        end
    end
end

function Importer:GetClassAndSpecNodeIDs(specID, treeID)
    if self.classAndSpecNodeCache[specID] then
        return unpack(self.classAndSpecNodeCache[specID])
    end

    local nodes = C_Traits.GetTreeNodes(treeID)
    local classNodes, specNodes = {}, {}
    local heroNodesByTree = {}

    for _, nodeID in ipairs(nodes) do
        local nodeInfo = LibTT:GetNodeInfo(nodeID)
        if LibTT:IsNodeVisibleForSpec(specID, nodeID) and nodeInfo.maxRanks > 0 then
            if nodeInfo.isSubTreeSelection then
                -- skip selection node itself
            elseif nodeInfo.subTreeID then
                heroNodesByTree[nodeInfo.subTreeID] = heroNodesByTree[nodeInfo.subTreeID] or {}
                table.insert(heroNodesByTree[nodeInfo.subTreeID], nodeID)
            elseif nodeInfo.isClassNode then
                table.insert(classNodes, nodeID)
            else
                table.insert(specNodes, nodeID)
            end
        end
    end

    table.sort(classNodes)
    table.sort(specNodes)
    for _, t in pairs(heroNodesByTree) do table.sort(t) end

    self.classAndSpecNodeCache[specID] = { classNodes, specNodes, heroNodesByTree }
    return classNodes, specNodes, heroNodesByTree
end

-- Create a Blizzard-compatible string from a table of nodes
function Importer:CreateBlizzardStringFromNodes(specID, treeID, nodes)
    local exportStream = ExportUtil.MakeExportDataStream()
    
    -- Header
    exportStream:AddValue(BIT_WIDTH_HEADER_VERSION, SERIALIZATION_VERSION)
    exportStream:AddValue(BIT_WIDTH_SPEC_ID, specID)
    
    -- Hash (16 bytes of 0 to skip validation)
    for i = 1, 16 do exportStream:AddValue(8, 0) end
    
    -- Content
    local treeNodes = C_Traits.GetTreeNodes(treeID)
    for _, nodeID in ipairs(treeNodes) do
        local info = nodes[nodeID]
        local isNodeGranted = LibTT:IsNodeGrantedForSpec(specID, nodeID)
        
        -- Bit 1: Selected or Granted
        exportStream:AddValue(1, (info or isNodeGranted) and 1 or 0)
        
        if info or isNodeGranted then
            -- Bit 2: IsPurchased
            exportStream:AddValue(1, info and 1 or 0)
        end
        
        if info then
            local nodeInfo = LibTT:GetNodeInfo(nodeID)
            -- Bit 3: Partially Ranked?
            local isPartiallyRanked = nodeInfo.maxRanks ~= info.rank
            exportStream:AddValue(1, isPartiallyRanked and 1 or 0)
            if isPartiallyRanked then
                exportStream:AddValue(6, info.rank)
            end
            
            -- Bit 4: Is Choice Node?
            local isChoiceNode = nodeInfo.type == Enum.TraitNodeType.Selection or nodeInfo.type == Enum.TraitNodeType.SubTreeSelection
            exportStream:AddValue(1, isChoiceNode and 1 or 0)
            if isChoiceNode then
                local entryIndex = 0
                for i, eid in ipairs(nodeInfo.entryIDs) do
                    if eid == info.entryID then
                        entryIndex = i
                        break
                    end
                end
                exportStream:AddValue(2, entryIndex - 1)
            end
        end
    end
    
    return exportStream:GetExportString()
end
function Importer:ParseBlizzardLevelingData(mainString, levelingPart)
    local mainStream = self:SafeMakeStream(mainString)
    if not mainStream then return {} end

    self:SafeExtract(mainStream, BIT_WIDTH_HEADER_VERSION)
    local specID = self:SafeExtract(mainStream, BIT_WIDTH_SPEC_ID)
    for i = 1, 16 do self:SafeExtract(mainStream, 8) end -- skip hash

    local classID = C_SpecializationInfo.GetClassIDFromSpecID(specID)
    local treeID = LibTT:GetClassTreeID(classID)
    local treeNodes = C_Traits.GetTreeNodes(treeID)
    
    local levelingStream = self:SafeMakeStream(levelingPart)
    if not levelingStream then return {} end
    self:SafeExtract(levelingStream, 5) -- version

    -- We need to know which nodes were actually purchased in the main string
    -- to map them to the leveling ranks
    local purchased = {}
    for _, nodeID in ipairs(treeNodes) do
        if mainStream.isBroken then break end
        local isSelected = self:SafeExtract(mainStream, 1) == 1
        if isSelected then
            local isPurchased = self:SafeExtract(mainStream, 1) == 1
            if isPurchased then
                local nodeInfo = LibTT:GetNodeInfo(nodeID)
                local isPartiallyRanked = self:SafeExtract(mainStream, 1) == 1
                local ranks = isPartiallyRanked and self:SafeExtract(mainStream, 6) or nodeInfo.maxRanks
                local isChoice = self:SafeExtract(mainStream, 1) == 1
                local entryID = nodeInfo.entryIDs[1]
                if isChoice then
                    local choiceIdx = self:SafeExtract(mainStream, 2) + 1
                    entryID = nodeInfo.entryIDs[choiceIdx]
                end
                table.insert(purchased, {nodeID = nodeID, entryID = entryID, maxRanks = ranks})
            end
        end
    end

    local levelingOrder = {}
    for _, info in ipairs(purchased) do
        if levelingStream.isBroken then break end
        for rank = 1, info.maxRanks do
            local level = self:SafeExtract(levelingStream, 7)
            if level > 0 then
                table.insert(levelingOrder, {
                    nodeID = info.nodeID,
                    entryID = info.entryID,
                    rank = rank,
                    level = level
                })
            end
            if levelingStream.isBroken then break end
        end
    end
    
    -- Sort by level
    table.sort(levelingOrder, function(a, b) return a.level < b.level end)
    return levelingOrder
end
