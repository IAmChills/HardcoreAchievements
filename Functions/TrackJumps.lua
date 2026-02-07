---------------------------------------
-- Configuration
---------------------------------------
local INIT_DELAY_SEC = 3           -- Wait time for UltraHardcoreDB to load
local JUMP_DEBOUNCE_SEC = 0.75     -- Seconds between counted jumps
local EVAL_DELAY_SEC = 0.5         -- Delay before evaluating completions on load
local REFRESH_DELAY_SEC = 0.1      -- Delay before refreshing UI after failure

local NO_JUMP_ACHIEVEMENT_ID = "NoJumpChallenge"

local addonName, addon = ...
local UnitLevel = UnitLevel
local UnitGUID = UnitGUID
local GetExpansionLevel = GetExpansionLevel
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local GetTime = GetTime
local hooksecurefunc = hooksecurefunc
local IsFalling = IsFalling

---------------------------------------
-- Helper Functions
---------------------------------------

-- Fail NoJumpChallenge achievement if needed
local function FailNoJumpChallengeIfNeeded(cdb, refreshUI)
    if not cdb then return end
    
    cdb.achievements = cdb.achievements or {}
    local rec = cdb.achievements[NO_JUMP_ACHIEVEMENT_ID]
    
    -- Only fail if not already completed or failed
    if not rec or (not rec.completed and not rec.failed) then
        if addon and addon.EnsureFailureTimestamp then
            addon.EnsureFailureTimestamp(NO_JUMP_ACHIEVEMENT_ID)
            
            -- Refresh outleveled status to show the failure state
            if refreshUI and addon and addon.RefreshOutleveledAll then
                C_Timer.After(REFRESH_DELAY_SEC, function()
                    addon.RefreshOutleveledAll()
                end)
            end
        end
    end
end

-- Migrate jump count from UltraHardcoreDB if available
local function MigrateJumpCount(cdb)
    if not cdb then return nil end
    
    -- Try to get jump count from our database first
    local jumpCount = cdb.stats and cdb.stats.playerJumps
    
    -- If not found, try to migrate from UltraHardcoreDB
    if jumpCount == nil and UltraHardcoreDB then
        if _G.CharacterStats and type(_G.CharacterStats.GetStat) == "function" then
            local migratedCount = _G.CharacterStats:GetStat('playerJumps')
            -- Migrate if we got a valid number (including 0)
            if migratedCount ~= nil and type(migratedCount) == "number" then
                jumpCount = migratedCount
                cdb.stats = cdb.stats or {}
                cdb.stats.playerJumps = jumpCount
            end
        end
    end
    
    return jumpCount
end

-- Check if player is max level for their expansion
local function IsPlayerMaxLevel()
    local playerLevel = UnitLevel("player") or 0
    local expansionLevel = GetExpansionLevel()
    return (playerLevel >= 60 and expansionLevel == 0) or (playerLevel >= 70 and expansionLevel == 1)
end

---------------------------------------
-- Main Initialization
---------------------------------------

local jumpTrackingFrame = CreateFrame("Frame")
jumpTrackingFrame:RegisterEvent("ADDON_LOADED")

local initialized = false
local JumpCounter = nil

jumpTrackingFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "HardcoreAchievements" then
        -- HardcoreAchievements has loaded, wait for UltraHardcoreDB to potentially load
        C_Timer.After(INIT_DELAY_SEC, function()
            -- Only initialize once
            if initialized then
                return
            end

            -- Wait for prerequisites
            if not UnitGUID("player") or not (addon and addon.GetCharDB) then
                return
            end

            -- Get character database
            local _, cdb = addon.GetCharDB()
            if not cdb then
                return
            end

            -- Mark as initialized to prevent multiple initializations
            initialized = true

            -- Initialize stats table
            cdb.stats = cdb.stats or {}

            -- Migrate jump count from UltraHardcoreDB if needed
            local jumpCount = MigrateJumpCount(cdb)

            -- Fail "NoJumpChallenge" achievement if player already has jumps > 0 on load
            if jumpCount and jumpCount > 0 then
                FailNoJumpChallengeIfNeeded(cdb, false)
            -- If playerJumps is nil (first load), check if player is already max level
            -- If so, mark achievement as failed (can't verify they had 0 jumps when they reached max level)
            elseif jumpCount == nil and IsPlayerMaxLevel() then
                FailNoJumpChallengeIfNeeded(cdb, false)
            end

            -- Initialize jump counter
            JumpCounter = {
                count = jumpCount or 0,
                lastJump = 0,
                debounce = JUMP_DEBOUNCE_SEC
            }
            cdb.stats.playerJumps = JumpCounter.count

            -- Check for achievement completion on initial load (in case player already has 100k jumps)
            C_Timer.After(EVAL_DELAY_SEC, function()
                if addon and addon.EvaluateCustomCompletions then
                    addon.EvaluateCustomCompletions()
                end
            end)

            -- Function to call when a jump is detected
            function JumpCounter:OnJump()
                self.count = self.count + 1
                self.lastJump = GetTime()
                
                -- Update our database
                local _, cdb = addon.GetCharDB()
                if cdb then
                    cdb.stats = cdb.stats or {}
                    cdb.stats.playerJumps = self.count
                    
                    -- Fail "NoJumpChallenge" achievement if player jumps (jump count > 0)
                    if self.count > 0 then
                        FailNoJumpChallengeIfNeeded(cdb, true)
                    end
                end
                
                -- Check for custom achievement completions (e.g., Jump Master at 100k jumps)
                if addon and addon.EvaluateCustomCompletions then
                    addon.EvaluateCustomCompletions()
                end
            end

            -- Hook AscendStop to detect player jumps
            hooksecurefunc("AscendStop", function()
                if not IsFalling() then
                    return  -- ignore if the player is on the ground
                end

                if JumpCounter then
                    local now = GetTime()
                    if not JumpCounter.lastJump or (now - JumpCounter.lastJump > JumpCounter.debounce) then
                        JumpCounter:OnJump()
                    end
                end
            end)
        end)
    end
end)