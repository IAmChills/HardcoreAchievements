-- HCA_SharedUtils.lua
-- Shared utility functions used across multiple files in the Hardcore Achievements addon
-- This reduces code duplication and centralizes common logic

HCA_SharedUtils = {}

-- =========================================================
-- Settings Helpers
-- =========================================================

-- Get a setting value from character database
function HCA_SharedUtils.GetSetting(settingName, defaultValue)
    if type(HardcoreAchievements_GetCharDB) == "function" then
        local _, cdb = HardcoreAchievements_GetCharDB()
        if cdb and cdb.settings then
            local value = cdb.settings[settingName]
            if value ~= nil then
                return value
            end
        end
    end
    return defaultValue
end

-- Set a setting value in character database
function HCA_SharedUtils.SetSetting(settingName, value)
    if type(HardcoreAchievements_GetCharDB) == "function" then
        local _, cdb = HardcoreAchievements_GetCharDB()
        if cdb then
            cdb.settings = cdb.settings or {}
            cdb.settings[settingName] = value
        end
    end
end

-- =========================================================
-- Class Color Helper
-- =========================================================

-- Cache the class color string (player's class doesn't change during session)
local cachedClassColor = nil

-- Initialize class color cache
local function InitializeClassColor()
    if not cachedClassColor then
        -- Use the same method as the original implementation for compatibility
        cachedClassColor = "|c" .. select(4, GetClassColor(select(2, UnitClass("player"))))
    end
    return cachedClassColor
end

function HCA_SharedUtils.GetClassColor()
    -- Return cached value, initializing if needed
    if not cachedClassColor then
        InitializeClassColor()
    end
    return cachedClassColor
end

-- Initialize on PLAYER_LOGIN event
local classColorFrame = CreateFrame("Frame")
classColorFrame:RegisterEvent("PLAYER_LOGIN")
classColorFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        InitializeClassColor()
        self:UnregisterAllEvents()
    end
end)

-- =========================================================
-- Character Panel Tab Management
-- =========================================================

-- Get the Character Frame achievement tab
function HCA_SharedUtils.GetAchievementTab()
    return _G["CharacterFrameTab" .. (CharacterFrame.numTabs + 1)]
end

-- Check if tab is the achievement tab
function HCA_SharedUtils.IsAchievementTab(tab)
    if not tab or not tab.GetText then return false end
    local tabText = tab:GetText()
    if not tabText then return false end
    return tabText:find("Achievement") ~= nil or (_G.ACHIEVEMENTS and tabText:find(_G.ACHIEVEMENTS))
end

-- Show or hide the Character Panel achievement tab based on useCharacterPanel setting
function HCA_SharedUtils.UpdateCharacterPanelTabVisibility()
    -- Get the actual Tab frame directly (more reliable than searching by name)
    local tab = nil
    if type(_G.HardcoreAchievements_GetTab) == "function" then
        tab = _G.HardcoreAchievements_GetTab()
    end
    
    -- Fallback to finding by name if getter not available
    if not tab then
        tab = HCA_SharedUtils.GetAchievementTab()
        if not tab or not HCA_SharedUtils.IsAchievementTab(tab) then 
            -- Tab not found, but still call LoadTabPosition which will handle it
            if type(_G.HardcoreAchievements_LoadTabPosition) == "function" then
                _G.HardcoreAchievements_LoadTabPosition()
            end
            return 
        end
    end
    
    local useCharacterPanel = HCA_SharedUtils.GetSetting("useCharacterPanel", true)
    
    if useCharacterPanel then
        -- Show custom tab (Character Panel mode) - LoadTabPosition will handle the actual showing
        -- Also restore vertical tab if it was in vertical mode
        if type(_G.HardcoreAchievements_LoadTabPosition) == "function" then
            _G.HardcoreAchievements_LoadTabPosition()
        end
    else
        -- Hide custom tab (Dashboard mode) - hide immediately
        if tab then
            tab:Hide()
            -- Also hide square frame if it exists
            if tab.squareFrame then
                tab.squareFrame:Hide()
                tab.squareFrame:EnableMouse(false)
            end
        end
        -- Also hide vertical tab immediately
        if type(_G.HardcoreAchievements_HideVerticalTab) == "function" then
            _G.HardcoreAchievements_HideVerticalTab()
        end
    end
end

-- Set useCharacterPanel setting and update tab visibility
function HCA_SharedUtils.SetUseCharacterPanel(enabled)
    HCA_SharedUtils.SetSetting("useCharacterPanel", enabled)
    
    -- Sync showCustomTab with useCharacterPanel to keep them in sync
    if type(HardcoreAchievements_GetCharDB) == "function" then
        local _, cdb = HardcoreAchievements_GetCharDB()
        if cdb then
            cdb.settings = cdb.settings or {}
            cdb.settings.showCustomTab = enabled
        end
    end
    
    HCA_SharedUtils.UpdateCharacterPanelTabVisibility()
    
    -- Reload tab position only when enabling (positioning). When disabling, we already hid it directly.
    if enabled and type(_G.HardcoreAchievements_LoadTabPosition) == "function" then
        _G.HardcoreAchievements_LoadTabPosition()
    end
end

-- =========================================================
-- Achievement Definition Registration
-- =========================================================

-- Unified function to register achievement definitions to HCA_AchievementDefs
-- This ensures all achievement types (quest, dungeon, raid, meta, etc.) use the same structure
-- Parameters:
--   def: The achievement definition table (from Catalog files)
--   overrides: Optional table of field overrides (e.g., { level = nil } for raids)
function HCA_SharedUtils.RegisterAchievementDef(def, overrides)
    if not def or not def.achId then
        return
    end
    
    _G.HCA_AchievementDefs = _G.HCA_AchievementDefs or {}
    
    -- Build the definition entry with all common fields
    local achDef = {
        achId = def.achId,
        title = def.title,
        tooltip = def.tooltip,
        icon = def.icon,
        points = def.points or 0,
        level = def.level,
        -- Quest-specific fields
        targetNpcId = def.targetNpcId,
        requiredKills = def.requiredKills,
        requiredQuestId = def.requiredQuestId,
        -- Dungeon/Raid-specific fields
        mapID = def.requiredMapId or def.mapID,
        mapName = def.mapName or def.title,
        bossOrder = def.bossOrder,
        -- Meta-specific fields
        requiredAchievements = def.requiredAchievements,
        achievementOrder = def.achievementOrder,
        -- Common fields
        faction = def.faction,
        race = def.race,
        class = def.class,
        zone = def.zone,
        -- Type flags
        isQuest = def.isQuest or false,
        isRaid = def.isRaid or false,
        isHeroicDungeon = def.isHeroicDungeon or false,
        isMetaAchievement = def.isMetaAchievement or false,
        isVariation = def.isVariation or false,
        baseAchId = def.baseAchId,
    }
    
    -- Apply any overrides (e.g., raids might set level = nil)
    if overrides then
        for key, value in pairs(overrides) do
            achDef[key] = value
        end
    end
    
    _G.HCA_AchievementDefs[tostring(def.achId)] = achDef
end
