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
    { id = 19, name = "First Person Camera", dbSettingsValueName = "setFirstPersonCamera"}
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
    { -- Ultra
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
      ultra           = 1.70,
      ultraplus       = 1.80,
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

-- Function to update all achievement row points when UHC loads
local function UpdateAllAchievementPoints()
    if not AchievementPanel or not AchievementPanel.achievements then return end
    
    local preset = GetPlayerPresetFromSettings()
    for _, row in ipairs(AchievementPanel.achievements) do
        if row.id and not row.completed then
            -- Get the original points from the achievement definition
            local originalPoints = nil
            local staticPoints = false

            -- Try to get original points from row storage or use current points as fallback
            originalPoints = row.originalPoints or row.points
            staticPoints = row.staticPoints or false
            --print("Row ID:", row.id, "Original Points:", originalPoints, "Static:", staticPoints)
            if originalPoints then
                if not staticPoints then
                    -- Calculate the multiplier difference and add it to existing points
                    local multiplier = GetPresetMultiplier(preset)
                    local multiplierPoints = math.floor((originalPoints or 0) * (multiplier - 1) + 0.5)
                    row.points = row.points + multiplierPoints
                end
                
                -- Update the display text
                if row.Points then
                    row.Points:SetText(tostring(row.points) .. " pts")
                end
            end
        end
    end
    
    -- Update total points
    if UpdateTotalPoints then
        UpdateTotalPoints()
    end
end

-- Event frame for ADDON_LOADED
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "UltraHardcore" then
        -- UltraHardcore has loaded, trigger multiplier text update
        C_Timer.After(0.1, function()
            -- Update multiplier text in embedded UI if it exists
            if DEST and DEST.MultiplierText then
                local preset = GetPlayerPresetFromSettings()
                local isSelfFound = IsSelfFound()
                
                local labelText = ""
                if preset or isSelfFound then
                    labelText = "Point Multiplier ("
                    if preset then
                        labelText = labelText .. preset
                    end
                    if isSelfFound then
                        labelText = labelText .. ", Self Found"
                    end
                    labelText = labelText .. ")"
                end
                
                DEST.MultiplierText:SetText(labelText)
                DEST.MultiplierText:SetTextColor(0.8, 0.8, 0.8)
            end
            
            -- Update multiplier text in standalone UI if it exists
            if AchievementPanel and AchievementPanel.MultiplierText then
                local preset = GetPlayerPresetFromSettings()
                local isSelfFound = IsSelfFound()
                
                local labelText = ""
                if preset or isSelfFound then
                    labelText = "Point Multiplier ("
                    if preset then
                        labelText = labelText .. preset
                    end
                    if isSelfFound then
                        labelText = labelText .. ", Self Found"
                    end
                    labelText = labelText .. ")"
                end
                
                AchievementPanel.MultiplierText:SetText(labelText)
                AchievementPanel.MultiplierText:SetTextColor(0.8, 0.8, 0.8)
            end
            
            -- Update all achievement points with new multiplier
            UpdateAllAchievementPoints()
        end)
    end
end)

function GetPlayerPresetFromSettings()
    -- Return early if UltraHardcoreDB doesn't exist
    if not UltraHardcoreDB then
        return "1"
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
        return "2"
    end

    -- Tier sets (cumulative)
    local L = trueKeys(presets[1])            -- Lite
    local R = trueKeys(presets[2])            -- Recommended (includes Lite)
    local U = trueKeys(presets[3])            -- Ultra (includes Recommended)
    local E = trueKeys(presets[4])            -- Experimental (includes Ultra)

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
        return hasAny(player, E_only) and "Ultra +" or "Ultra"
    elseif hasAll(player, R) then
        return hasAny(player, U_only) and "Recommended +" or "Recommended"
    elseif hasAll(player, L) then
        return (hasAny(player, R_only) or hasAny(player, U_only) or hasAny(player, E_only)) and "Lite +" or "Lite"
    else
        return "Custom"
    end
end



