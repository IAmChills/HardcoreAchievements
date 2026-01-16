local ExplorationAchievements = {
{
    achId = "Precious",
    title = "The Precious",
    level = nil,
    tooltip = "Starting as a level 1 character, journey on foot to |cff0091e6Blackrock Mountain|r and destroy |cff0091e6The 1 Ring|r",
    icon = "Interface\\AddOns\\HardcoreAchievements\\Images\\Icons\\INV_DARKMOON_EYE.png",
    points = 0,
    customIsCompleted = function()
        -- This achievement is completed when the player deletes "The 1 Ring" (itemId 8350)
        -- while in Blackrock Mountain (mapId 1415). The event bridge in HardcoreAchievements.lua
        -- sets this flag only after a confirmed delete that results in 0 remaining.
        return _G.HCA_Precious_RingDeleted == true
    end,
    staticPoints = true,
},
}

-- Defer registration until PLAYER_LOGIN to prevent load timeouts
_G.HCA_RegistrationQueue = _G.HCA_RegistrationQueue or {}

-- Queue all exploration achievements for deferred registration
for _, def in ipairs(ExplorationAchievements) do
  -- Mark as exploration for filtering
  def.isExploration = true
  -- Queue achievement registration
  table.insert(_G.HCA_RegistrationQueue, function()
    if def.customIsCompleted then
      _G[def.achId .. "_IsCompleted"] = def.customIsCompleted
    end

    CreateAchievementRow(
      AchievementPanel,
      def.achId,
      def.title,
      def.tooltip,
      def.icon,
      def.level,
      def.points or 0,
      nil,
      nil,
      def.staticPoints,
      nil,
      def
    )
  end)
end
