GravvyBuildPlannerMainMenu = {}

function GravvyBuildPlannerMainMenu:Initialize(owner)
    if not LibMainMenu2 then
        return
    end

    LibMainMenu2:Init()
    LibMainMenu2:AddMenuItem("GravvyBuildPlannerMainMenu", {
        binding = "GRAVVY_BUILD_PLANNER_TOGGLE",
        categoryName = SI_GRAVVY_BUILD_PLANNER_TITLE,
        callback = function() owner:ToggleWindow() end,
        visible = function() return true end,
        normal = "EsoUI/Art/Journal/journal_quests_tabIcon_up.dds",
        pressed = "EsoUI/Art/Journal/journal_quests_tabIcon_down.dds",
        highlight = "EsoUI/Art/Journal/journal_quests_tabIcon_over.dds",
        disabled = "EsoUI/Art/Journal/journal_quests_tabIcon_disabled.dds",
    })
end
