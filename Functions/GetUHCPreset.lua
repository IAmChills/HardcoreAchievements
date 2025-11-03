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

    local isSelfFound = IsSelfFound()
    if isSelfFound then
        for _, row in ipairs(AchievementPanel.achievements) do
            if row.id and not row.completed then
                -- Do not apply self-found bonus to secret achievements only
                if not row.isSecretAchievement then
                    row.points = row.points + HCA_SELF_FOUND_BONUS
                    row.Points:SetText(tostring(row.points) .. " pts")
                end
            end
        end
    end

    -- SSF toggle is now purely visual - show what points would be earned in solo mode
    -- Actual solo validation happens at kill/quest time and points are stored then
    -- Solo preview only shows if player is self-found
    local isSoloMode = _G.HardcoreAchievements_IsSoloModeEnabled and _G.HardcoreAchievements_IsSoloModeEnabled() or false
    if isSoloMode and isSelfFound then
        for _, row in ipairs(AchievementPanel.achievements) do
            if row.id and not row.completed then
                -- Visual doubling: show what points would be in solo mode (excluding static points, if achievement allows it)
                -- This is just a preview - actual points are determined at kill/quest time
                if not row.staticPoints and row.allowSoloDouble then
                    -- Check if we already have stored points from a previous kill/quest
                    local progress = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(row.id)
                    if not (progress and progress.pointsAtKill) then
                        -- No stored points yet, show doubled points as preview
                        local currentPoints = tonumber(row.points) or 0
                        row.points = currentPoints * 2
                        row.Points:SetText(tostring(row.points) .. " pts")
                    end
                end
                
                -- Update Sub text - show "pending solo" if we have stored solo status, or preview "Solo" if solo mode toggle is on
                -- Only update Sub text for incomplete achievements to preserve completed achievement solo indicators
                if not row.completed and row.allowSoloDouble and row.Sub and row.maxLevel and row.maxLevel > 0 then
                    local levelText = LEVEL .. " " .. row.maxLevel
                    local progress = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(row.id)
                    local hasSoloStatus = progress and (progress.soloKill or progress.soloQuest)
                    
                    -- If we have stored pointsAtKill (solo kill/quest), use those points
                    -- pointsAtKill doesn't include self-found bonus, so add it if applicable
                    if progress and progress.pointsAtKill then
                        local storedPoints = tonumber(progress.pointsAtKill) or row.points
                        -- Add self-found bonus if applicable (pointsAtKill doesn't include it)
                        if isSelfFound and not row.isSecretAchievement then
                            storedPoints = storedPoints + HCA_SELF_FOUND_BONUS
                        end
                        row.points = storedPoints
                        if row.Points then
                            row.Points:SetText(tostring(storedPoints) .. " pts")
                        end
                    end
                    
                    -- Show "pending solo" if we have stored solo status, or preview "Solo" if solo mode toggle is on
                    -- Solo indicators only show if player is self-found
                    if hasSoloStatus and isSelfFound then
                        row.Sub:SetText(levelText .. "\n|cFF9D3AFFPending solo|r")
                    elseif isSoloMode and not hasSoloStatus and isSelfFound then
                        row.Sub:SetText(levelText .. "\n|cFF9D3AFFSolo|r")
                    else
                        row.Sub:SetText(levelText)
                    end
                end
            end
        end
    else
        -- When solo mode toggle is disabled, only show "pending solo" if we have stored solo status from previous kills/quests
        local isSelfFound = IsSelfFound()
        for _, row in ipairs(AchievementPanel.achievements) do
            if row.id and not row.completed and row.Sub and row.maxLevel and row.maxLevel > 0 then
                local levelText = LEVEL .. " " .. row.maxLevel
                local progress = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(row.id)
                local hasSoloStatus = progress and (progress.soloKill or progress.soloQuest)
                
                -- If we have stored pointsAtKill (solo kill/quest), use those points
                -- pointsAtKill doesn't include self-found bonus, so add it if applicable
                if progress and progress.pointsAtKill then
                    local storedPoints = tonumber(progress.pointsAtKill) or row.points
                    -- Check if self-found bonus should be added
                    if isSelfFound and not row.isSecretAchievement then
                        storedPoints = storedPoints + HCA_SELF_FOUND_BONUS
                    end
                    row.points = storedPoints
                    if row.Points then
                        row.Points:SetText(tostring(storedPoints) .. " pts")
                    end
                end
                
                -- Solo indicators only show if player is self-found
                if hasSoloStatus and isSelfFound then
                    row.Sub:SetText(levelText .. "\n|cFF9D3AFFPending solo|r")
                else
                    row.Sub:SetText(levelText)
                end
            end
        end
    end
    
    -- Update total points
    if HCA_UpdateTotalPoints then
        HCA_UpdateTotalPoints()
    end
end

-- Export function to refresh all achievement points from scratch
function HCA_RefreshAllAchievementPoints()
    if not AchievementPanel or not AchievementPanel.achievements then return end
    
    local preset = GetPlayerPresetFromSettings()
    local isSelfFound = IsSelfFound()
    local isSoloMode = _G.HardcoreAchievements_IsSoloModeEnabled and _G.HardcoreAchievements_IsSoloModeEnabled() or false
    
    for _, row in ipairs(AchievementPanel.achievements) do
        if row.id and not row.completed then
            -- Start from original points
            local originalPoints = row.originalPoints or row.points or 0
            local staticPoints = row.staticPoints or false
            local finalPoints = originalPoints
            
            if not staticPoints then
                -- Apply preset multiplier
                local multiplier = GetPresetMultiplier(preset)
                finalPoints = math.floor(originalPoints * multiplier + 0.5)
                
                -- Visual preview: if solo mode toggle is on and no stored points, show doubled points
                -- This is just a preview - actual points are determined at kill/quest time
                -- Solo preview only applies if player is self-found
                local progress = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(row.id)
                if isSoloMode and row.allowSoloDouble and isSelfFound and not (progress and progress.pointsAtKill) then
                    finalPoints = finalPoints * 2
                end
            end
            
            -- Apply self-found bonus (always, except for secret achievements)
            if isSelfFound and not row.isSecretAchievement then
                finalPoints = finalPoints + HCA_SELF_FOUND_BONUS
            end
            
            row.points = finalPoints
            if row.Points then
                row.Points:SetText(tostring(finalPoints) .. " pts")
            end
            
            -- Update Sub text - check if we have stored solo status from previous kills/quests
            -- Only update Sub text for incomplete achievements to preserve completed achievement solo indicators
            if not row.completed and row.Sub and row.maxLevel and row.maxLevel > 0 then
                local levelText = LEVEL .. " " .. row.maxLevel
                -- Check progress for solo status
                local progress = HardcoreAchievements_GetProgress and HardcoreAchievements_GetProgress(row.id)
                local hasSoloStatus = progress and (progress.soloKill or progress.soloQuest)
                
                -- If we have stored pointsAtKill (solo kill/quest), use those points
                -- pointsAtKill doesn't include self-found bonus, so add it if applicable
                if progress and progress.pointsAtKill then
                    finalPoints = tonumber(progress.pointsAtKill) or finalPoints
                    -- Add self-found bonus if applicable (pointsAtKill doesn't include it)
                    if isSelfFound and not row.isSecretAchievement then
                        finalPoints = finalPoints + HCA_SELF_FOUND_BONUS
                    end
                    row.points = finalPoints
                    if row.Points then
                        row.Points:SetText(tostring(finalPoints) .. " pts")
                    end
                end
                
                -- Solo indicators only show if player is self-found
                if hasSoloStatus and isSelfFound then
                    row.Sub:SetText(levelText .. "\n|cFF9D3AFFPending solo|r")
                else
                    row.Sub:SetText(levelText)
                end
            end
        end
    end
    
    -- Update total points
    if HCA_UpdateTotalPoints then
        HCA_UpdateTotalPoints()
    end
    
    -- Update multiplier text if it exists
    if AchievementPanel and AchievementPanel.MultiplierText then
        local labelText = ""
        if preset or isSelfFound or isSoloMode then
            -- Build array of modifiers (preset goes last)
            local modifiers = {}
            if isSelfFound and not isSoloMode then
                table.insert(modifiers, "Self Found")
            end
            if isSoloMode and not isSelfFound then
                table.insert(modifiers, "Solo")
            end
            if isSoloMode and isSelfFound then
                table.insert(modifiers, "Solo Self Found")
            end
            if preset then
                table.insert(modifiers, preset)
            end
            
            labelText = "Point Multiplier (" .. table.concat(modifiers, ", ") .. ")"
        end
        
        AchievementPanel.MultiplierText:SetText(labelText)
        AchievementPanel.MultiplierText:SetTextColor(0.8, 0.8, 0.8)
    end
    
    -- Sync character panel checkbox state if it exists
    if AchievementPanel and AchievementPanel.SoloModeCheckbox then
        AchievementPanel.SoloModeCheckbox:SetChecked(isSoloMode)
    end
end

-- Event frame for ADDON_LOADED
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "UltraHardcore" then
        -- UltraHardcore has loaded, trigger multiplier text update
        C_Timer.After(3, function()
            -- Update multiplier text in embedded UI if it exists
            if DEST and DEST.MultiplierText then
                local preset = GetPlayerPresetFromSettings()
                local isSelfFound = IsSelfFound()
                local isSoloMode = _G.HardcoreAchievements_IsSoloModeEnabled and _G.HardcoreAchievements_IsSoloModeEnabled() or false
                
                local labelText = ""
                if preset or isSelfFound or isSoloMode then
                    -- Build array of modifiers (preset goes last)
                    local modifiers = {}
                    if isSelfFound and not isSoloMode then
                        table.insert(modifiers, "Self Found")
                    end
                    if isSoloMode and not isSelfFound then
                        table.insert(modifiers, "Solo")
                    end
                    if isSoloMode and isSelfFound then
                        table.insert(modifiers, "Solo Self Found")
                    end
                    if preset then
                        table.insert(modifiers, preset)
                    end
                    
                    labelText = "Point Multiplier (" .. table.concat(modifiers, ", ") .. ")"
                end
                
                DEST.MultiplierText:SetText(labelText)
                DEST.MultiplierText:SetTextColor(0.8, 0.8, 0.8)
            end
        end)
    elseif addonName == "HardcoreAchievements" then        
        C_Timer.After(3, function()
            -- Update multiplier text in standalone UI if it exists
            if AchievementPanel and AchievementPanel.MultiplierText then
                local preset = GetPlayerPresetFromSettings()
                local isSelfFound = IsSelfFound()
                local isSoloMode = _G.HardcoreAchievements_IsSoloModeEnabled and _G.HardcoreAchievements_IsSoloModeEnabled() or false
                
                local labelText = ""
                if preset or isSelfFound or isSoloMode then
                    -- Build array of modifiers (preset goes last)
                    local modifiers = {}
                    if isSelfFound and not isSoloMode then
                        table.insert(modifiers, "Self Found")
                    end
                    if isSoloMode and not isSelfFound then
                        table.insert(modifiers, "Solo")
                    end
                    if isSoloMode and isSelfFound then
                        table.insert(modifiers, "Solo Self Found")
                    end
                    if preset then
                        table.insert(modifiers, preset)
                    end
                    
                    labelText = "Point Multiplier (" .. table.concat(modifiers, ", ") .. ")"
                end
                
                AchievementPanel.MultiplierText:SetText(labelText)
                AchievementPanel.MultiplierText:SetTextColor(0.8, 0.8, 0.8)

                -- Update all achievement points with new multiplier and bonus
                UpdateAllAchievementPoints()
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



