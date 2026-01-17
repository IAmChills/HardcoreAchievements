local settingsCheckboxOptions = {
    { id = 1, name = "UHC Player Frame", dbSettingsValueName = "hidePlayerFrame" },
    { id = 2, name = "Hide Minimap", dbSettingsValueName = "hideMinimap" },
    { id = 4, name = "Hide Target Frame", dbSettingsValueName = "hideTargetFrame" },
    { id = 5, name = "Hide Target Tooltips", dbSettingsValueName = "hideTargetTooltip" },
    { id = 6, name = "Death Indicator (Tunnel Vision)", dbSettingsValueName = "showTunnelVision" },
    { id = 7, name = "Tunnel Vision Covers Everything", dbSettingsValueName = "tunnelVisionMaxStrata" },
    { id = 9, name = "Show Dazed Effect", dbSettingsValueName = "showDazedEffect" },
    { id = 10, name = "Show Crit Screen Shift Effect", dbSettingsValueName = "showCritScreenMoveEffect" },
    { id = 11, name = "Hide Action Bars when not resting", dbSettingsValueName = "hideActionBars" },
    { id = 12, name = "UHC Party Frames", dbSettingsValueName = "hideGroupHealth" },
    { id = 13, name = "Pets Die Permanently", dbSettingsValueName = "petsDiePermanently" },
    { id = 15, name = "Disable Nameplates", dbSettingsValueName = "disableNameplateHealth" },
    { id = 16, name = "Show Incoming Damage Effect", dbSettingsValueName = "showIncomingDamageEffect" },
    { id = 17, name = "Breath Indicator", dbSettingsValueName = "hideBreathIndicator" },
    { id = 18, name = "Show Incoming Healing Effect", dbSettingsValueName = "showHealingIndicator" },
    { id = 19, name = "First Person Camera", dbSettingsValueName = "setFirstPersonCamera"},
    --{ id = 20, name = "Reject buffs from others", dbSettingsValueName = "rejectBuffsFromOthers"},
    { id = 21, name = "Route Planner", dbSettingsValueName = "routePlanner"},
    { id = 22, name = "Hide Quest UI", dbSettingsValueName = "completelyRemovePlayerFrame"},
    { id = 23, name = "Hide Action Bars when not resting", dbSettingsValueName = "completelyRemoveTargetFrame"},
    { id = 24, name = "Hide Player Cast Bar", dbSettingsValueName = "hidePlayerCastBar"},
    { id = 25, name = "Open World Health Indicators", dbSettingsValueName = "showWildAllyHealthIndicator"},
}

local presets = {
    { -- Lite
        hidePlayerFrame = true,
        showTunnelVision = true,
    },
    { -- Recommended
        hidePlayerFrame = true,
        showTunnelVision = true,
        hideTargetFrame = true,
        hideTargetTooltip = true,
        disableNameplateHealth = true,
        showDazedEffect = true,
        hideGroupHealth = true,
        hideMinimap = true,
    },
    { -- Extreme
        hidePlayerFrame = true,
        showTunnelVision = true,
        hideTargetFrame = true,
        hideTargetTooltip = true,
        disableNameplateHealth = true,
        showDazedEffect = true,
        hideGroupHealth = true,
        hideMinimap = true,
        petsDiePermanently = true,
        hideActionBars = true,
        tunnelVisionMaxStrata = true,
        --rejectBuffsFromOthers = true,
        routePlanner = true,
    },
    { -- Experimental
        hidePlayerFrame = true,
        showTunnelVision = true,
        hideTargetFrame = true,
        hideTargetTooltip = true,
        disableNameplateHealth = true,
        showDazedEffect = true,
        hideGroupHealth = true,
        hideMinimap = true,
        petsDiePermanently = true,
        hideActionBars = true,
        tunnelVisionMaxStrata = true,
        hideBreathIndicator = true,
        showCritScreenMoveEffect = true,
        showIncomingDamageEffect = true,
        showHealingIndicator = true,
        setFirstPersonCamera = true,
        --rejectBuffsFromOthers = true,
        routePlanner = true,
        completelyRemovePlayerFrame = true,
        completelyRemoveTargetFrame = true,
        hidePlayerCastBar = true,
        showWildAllyHealthIndicator = true,
    }
}

-- Helper functions
local function trueKeys(t)
    local s = {}
    if t then for k, v in pairs(t) do if v == true then s[k] = true end end end
    return s
end

local function hasAll(have, need)
    for k in pairs(need) do if not have[k] then return false end end
    return true
end

local function hasAny(have, subset)
    for k in pairs(subset) do if have[k] then return true end end
    return false
end

function GetPresetMultiplier(preset)
    local POINT_MULTIPLIER = {
      lite            = 1.20,
      liteplus        = 1.30,
      recommended     = 1.50,
      recommendedplus = 1.60,
      extreme         = 1.70,
      extremeplus     = 1.80,
      experimental    = 2.00,
      custom          = 1.00,
    }
    
    if not preset or preset == "Custom" then
      return 1.00
    end
    
    local normalizedPreset = tostring(preset or ""):lower()
    normalizedPreset = normalizedPreset:gsub("%+","plus")
         :gsub("%s+","")
         :gsub("[^%w]","")
    
    return POINT_MULTIPLIER[normalizedPreset] or 1.00
end

-- Centralized function to update multiplier text for any frame
-- multiplierTextElement: FontString element to update (e.g., DashboardFrame.MultiplierText)
-- textColor: Optional color table {r, g, b} or nil for default (0.8, 0.8, 0.8)
function UpdateMultiplierText(multiplierTextElement, textColor)
    if not multiplierTextElement then
        return
    end
    
    local preset = GetPlayerPresetFromSettings()
    
    -- Check if hardcore is active (for Self Found detection)
    -- In TBC, this will be false, so Self Found will never be active
    local isHardcoreActive = C_GameRules and C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive() or false
    local isSelfFound = false
    if isHardcoreActive and IsSelfFound and IsSelfFound() then
        isSelfFound = true
    end
    
    -- Check solo mode from character database (works in both Hardcore and TBC)
    -- This checks the soloAchievements setting from character database
    local isSoloMode = _G.HardcoreAchievements_IsSoloModeEnabled and _G.HardcoreAchievements_IsSoloModeEnabled() or false
    
    local labelText = ""
    local modifiers = {}
    
    -- In TBC (non-hardcore), Self Found is never available, so we only check Solo
    -- Build array of modifiers (preset goes last)
    if isSoloMode and not isSelfFound then
        table.insert(modifiers, "Solo")
    elseif isSelfFound and not isSoloMode then
        table.insert(modifiers, "Self Found")
    elseif isSoloMode and isSelfFound then
        table.insert(modifiers, "Solo Self Found")
    end
    
    if preset then
        table.insert(modifiers, preset)
    end
    
    -- Show text if there are any modifiers (preset or solo/self-found)
    if #modifiers > 0 then
        labelText = "Point Multiplier (" .. table.concat(modifiers, ", ") .. ")"
    end
    
    multiplierTextElement:SetText(labelText)
    
    -- Use provided color or default
    if textColor then
        if type(textColor) == "table" then
            multiplierTextElement:SetTextColor(textColor[1] or textColor.r or 0.8, 
                                               textColor[2] or textColor.g or 0.8, 
                                               textColor[3] or textColor.b or 0.8)
        end
    else
        multiplierTextElement:SetTextColor(0.8, 0.8, 0.8)
    end
end

-- Export UpdateMultiplierText globally for use by other files
_G.UpdateMultiplierText = UpdateMultiplierText

-- Event frame for ADDON_LOADED
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "UltraHardcore" then
        -- UltraHardcore has loaded, trigger multiplier text update
        C_Timer.After(3, function()
            -- Update multiplier text in embedded UI if it exists
            if DEST and DEST.MultiplierText then
                UpdateMultiplierText(DEST.MultiplierText)
            end
            -- Update multiplier text in Dashboard if it exists
            if DashboardFrame and DashboardFrame.MultiplierText then
                UpdateMultiplierText(DashboardFrame.MultiplierText, {0.922, 0.871, 0.761})
            end
        end)
    elseif addonName == "HardcoreAchievements" then        
        C_Timer.After(3, function()
            -- Update multiplier text in Character Panel if it exists
            if AchievementPanel and AchievementPanel.MultiplierText then
                UpdateMultiplierText(AchievementPanel.MultiplierText)
            end
            -- Update multiplier text in Dashboard if it exists
            if DashboardFrame and DashboardFrame.MultiplierText then
                UpdateMultiplierText(DashboardFrame.MultiplierText, {0.922, 0.871, 0.761})
            end

            -- Update all achievement points with new multiplier and bonus
            if RefreshAllAchievementPoints then
                RefreshAllAchievementPoints()
            end
        end)
    end
end)

function GetPlayerPresetFromSettings()
    -- Return early if UltraHardcoreDB doesn't exist
    if not UltraHardcoreDB then
        return
    end

    -- Get player's settings from UltraHardcoreDB
    local settings = nil
    local guid = UnitGUID("player")
    if guid and UltraHardcoreDB.characterSettings and UltraHardcoreDB.characterSettings[guid] then
        settings = UltraHardcoreDB.characterSettings[guid]
    elseif UltraHardcoreDB.GLOBAL_SETTINGS then
        settings = UltraHardcoreDB.GLOBAL_SETTINGS
    end

    if not settings then
        return
    end

    -- Tier sets (cumulative)
    local L = trueKeys(presets[1])            -- Lite
    local R = trueKeys(presets[2])            -- Recommended (includes Lite)
    local U = trueKeys(presets[3])            -- Extreme (includes Recommended)
    local E = trueKeys(presets[4])            -- Experimental (includes Extreme)

    -- Exclusive deltas (new options introduced at each tier)
    local R_only = {}; for k in pairs(R) do if not L[k] then R_only[k] = true end end
    local U_only = {}; for k in pairs(U) do if not R[k] then U_only[k] = true end end
    local E_only = {}; for k in pairs(E) do if not U[k] then E_only[k] = true end end

    -- Player's enabled set (restricted to known tier keys)
    local player = {}
    for k in pairs(L) do if settings[k] == true then player[k] = true end end
    for k in pairs(R_only) do if settings[k] == true then player[k] = true end end
    for k in pairs(U_only) do if settings[k] == true then player[k] = true end end
    for k in pairs(E_only) do if settings[k] == true then player[k] = true end end

    -- Determine preset
    if hasAll(player, E) then
        return "Experimental"
    elseif hasAll(player, U) then
        return hasAny(player, E_only) and "Extreme +" or "Extreme"
    elseif hasAll(player, R) then
        return hasAny(player, U_only) and "Recommended +" or "Recommended"
    elseif hasAll(player, L) then
        return (hasAny(player, R_only) or hasAny(player, U_only) or hasAny(player, E_only)) and "Lite +" or "Lite"
    else
        return "Custom"
    end
end



