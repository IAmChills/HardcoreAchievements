-- Functions/NPCTooltip.lua
-- Adds achievement requirement information to NPC tooltips

local table_insert = table.insert

local function GetNPCIdFromGUID(guid)
    if not guid then return nil end
    local npcId = select(6, strsplit("-", guid))
    return npcId and tonumber(npcId) or nil
end

-- Helper function to find achievements that require a specific NPC ID
local function GetAchievementsForNPC(npcId)
    if not npcId then return {} end
    
    local achievements = {}
    
    -- Check HCA_AchievementDefs (all achievement types: quest, dungeon, raid)
    if _G.HCA_AchievementDefs then
        for achId, achDef in pairs(_G.HCA_AchievementDefs) do
            -- Skip variations (Solo, Duo, Trio) - only show base achievements
            if not achDef.isVariation then
                local found = false
                
                -- Check targetNpcId (single ID or array)
                if achDef.targetNpcId then
                    if type(achDef.targetNpcId) == "table" then
                        for _, id in pairs(achDef.targetNpcId) do
                            if tonumber(id) == npcId then
                                found = true
                                break
                            end
                        end
                    else
                        if tonumber(achDef.targetNpcId) == npcId then
                            found = true
                        end
                    end
                end
                
                -- Check requiredKills (supports both single IDs and arrays)
                if not found and achDef.requiredKills then
                    for killNpcId, need in pairs(achDef.requiredKills) do
                        if type(need) == "table" then
                            -- Array of NPC IDs
                            for _, id in pairs(need) do
                                if tonumber(id) == npcId then
                                    found = true
                                    break
                                end
                            end
                        else
                            -- Single NPC ID
                            if tonumber(killNpcId) == npcId then
                                found = true
                            end
                        end
                        if found then break end
                    end
                end
                
                if found then
                    table_insert(achievements, {
                        achId = achId,
                        title = achDef.title or achDef.mapName or tostring(achId)
                    })
                end
            end
        end
    end
    
    return achievements
end

-- Hook GameTooltip to add achievement information
local function HookNPCTooltip()
    if GameTooltip then
        GameTooltip:HookScript("OnTooltipSetUnit", function(self)
            local unit = select(2, self:GetUnit())
            if not unit then return end
            
            local guid = UnitGUID(unit)
            if not guid then return end
            
            -- Only process NPCs (not players, pets, etc.)
            local npcId = GetNPCIdFromGUID(guid)
            if not npcId then return end
            
            -- Find achievements that require this NPC
            local achievements = GetAchievementsForNPC(npcId)
            if #achievements > 0 then
                GameTooltip:AddLine(" ")  -- Add spacing
                for _, ach in ipairs(achievements) do
                    -- Prefix achievement title with logo icon
                    local iconPath = "Interface\\AddOns\\HardcoreAchievements\\Images\\HardcoreAchievementsButton.png"
                    local iconSize = 16  -- Size of the icon in pixels
                    local iconString = "|T" .. iconPath .. ":" .. iconSize .. ":" .. iconSize .. "|t "
                    GameTooltip:AddLine(iconString .. ach.title)
                end
                --GameTooltip:AddLine(" ")  -- Add spacing
            end
        end)
    end
end

-- Initialize on addon load
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "HardcoreAchievements" then
        -- Hook after a short delay to ensure GameTooltip is ready
        C_Timer.After(0.5, function()
            HookNPCTooltip()
        end)
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
