-- Embed Dashboard into Ultra Hardcore's UI if available
-- This file attempts to integrate the Hardcore Achievements Dashboard
-- into Ultra Hardcore's character tab if the addon supports it.

local ADDON_NAME = ...

-- Helper: get the Achievements tab frame in both old and new UHC builds
local function GetAchievementsContainer()
  -- Check for new TabManager API
  if TabManager and TabManager.getTabContent then
    local f = TabManager.getTabContent(3)  -- Achievements tab is typically tab 3
    if f then return f end
  end
  -- Check for old tabContents structure
  if _G.tabContents and _G.tabContents[3] then
    return _G.tabContents[3]
  end
  return nil
end

-- Attempt to embed the Dashboard into Ultra Hardcore's UI
local function TryEmbedDashboard()
  -- Wait for both addons to be loaded
  if not HardcoreAchievements_Dashboard then
    return false
  end
  
  local container = GetAchievementsContainer()
  if not container then
    return false
  end
  
  local DASHBOARD = HardcoreAchievements_Dashboard
  if not DASHBOARD or not DASHBOARD.BuildEmbedFrame then
    return false
  end
  
  -- Embed the dashboard into the container
  -- This would need to be implemented based on Ultra Hardcore's current API
  -- For now, we'll just return false since the achievements tab was removed
    return false
end

-- Initialize embedding after both addons are loaded
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event, addonName)
  if event == "ADDON_LOADED" then
    -- Check if Ultra Hardcore is loaded
    if addonName == "UltraHardcore" or addonName == "UltraHardcoreAchievements" then
      -- Try to embed after a short delay to ensure everything is initialized
      C_Timer.After(0.5, function()
        TryEmbedDashboard()
      end)
    end
  elseif event == "PLAYER_LOGIN" then
    -- Try embedding one more time after login
    C_Timer.After(1.0, function()
      TryEmbedDashboard()
    end)
  end
end)
