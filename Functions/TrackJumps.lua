local jumpTrackingFrame = CreateFrame("Frame")
jumpTrackingFrame:RegisterEvent("ADDON_LOADED")

local initialized = false

jumpTrackingFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "HardcoreAchievements" then
        -- HardcoreAchievements has loaded, wait 3 seconds for UltraHardcoreDB to potentially load
        C_Timer.After(3, function()
            -- Only initialize once
            if initialized then
                return
            end

            -- Wait for player to be logged in
            if not UnitGUID("player") then
                return
            end

            -- Wait for GetCharDB to be available
            if not _G.HardcoreAchievements_GetCharDB then
                return
            end

            -- Get character database
            local _, cdb = _G.HardcoreAchievements_GetCharDB()
            if not cdb then
                return
            end

            -- Mark as initialized to prevent multiple initializations
            initialized = true

            -- Initialize stats table if it doesn't exist
            cdb.stats = cdb.stats or {}

            -- Try to get jump count from our database first
            local jumpCount = cdb.stats.playerJumps

            -- If not found in our database (nil), try to migrate from UltraHardcoreDB
            if jumpCount == nil and UltraHardcoreDB then
                -- Check if CharacterStats exists and has the playerJumps stat
                if _G.CharacterStats and type(_G.CharacterStats.GetStat) == "function" then
                    local migratedCount = _G.CharacterStats:GetStat('playerJumps')
                    -- Migrate if we got a valid number (including 0)
                    if migratedCount ~= nil and type(migratedCount) == "number" then
                        jumpCount = migratedCount
                        cdb.stats.playerJumps = jumpCount
                        -- Migration successful, data is now in our database
                    end
                end
            end

            -- If playerJumps is nil (first load), check if player is already max level
            -- If so, set a flag to prevent awarding "The Disciplined One" achievement
            -- (can't verify they had 0 jumps when they reached 60)
            if jumpCount == nil then
                local playerLevel = UnitLevel("player") or 0
                if playerLevel >= 60 then
                    -- Player is already max level on first load - mark achievement as failed
                    cdb.achievements = cdb.achievements or {}
                    local achId = "Secret93"
                    if _G.HCA_EnsureFailureTimestamp then
                        _G.HCA_EnsureFailureTimestamp(achId)
                    end
                end
            end

            -- Set default to 0 if still nil
            local JumpCounter = {}
            JumpCounter.count = jumpCount or 0
            JumpCounter.lastJump = 0
            JumpCounter.debounce = 0.75  -- seconds between counted jumps
            cdb.stats.playerJumps = JumpCounter.count

            -- Check for achievement completion on initial load (in case player already has 100k jumps)
            C_Timer.After(0.5, function()
                if _G.EvaluateCustomCompletions then
                    _G.EvaluateCustomCompletions()
                end
            end)

            -- Function to call when a jump is detected
            function JumpCounter:OnJump()
                self.count = self.count + 1
                self.lastJump = GetTime()
                
                -- Update our database
                local _, cdb = _G.HardcoreAchievements_GetCharDB()
                if cdb then
                    cdb.stats = cdb.stats or {}
                    cdb.stats.playerJumps = self.count
                end
                
                -- Check for custom achievement completions (e.g., Jump Master at 100k jumps)
                if _G.EvaluateCustomCompletions then
                    _G.EvaluateCustomCompletions()
                end
            end

            -- Hook AscendStop to detect player jumps
            hooksecurefunc("AscendStop", function()
                if not IsFalling() then
                    return  -- ignore if the player is on the ground
                end

                local now = GetTime()
                if not JumpCounter.lastJump or (now - JumpCounter.lastJump > JumpCounter.debounce) then
                    JumpCounter:OnJump()
                end
            end)
        end)
    end
end)