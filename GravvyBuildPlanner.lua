GravvyBuildPlanner = {
    name = "GravvyBuildPlanner",
}

local addon = GravvyBuildPlanner

function addon:Initialize()
    self.data = GravvyBuildPlannerData:New()
end

local function onAddOnLoaded(_, name)
    if name ~= addon.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent("GravvyBuildPlanner_Loaded", EVENT_ADD_ON_LOADED)
    addon:Initialize()
end

EVENT_MANAGER:RegisterForEvent(
    "GravvyBuildPlanner_Loaded",
    EVENT_ADD_ON_LOADED,
    onAddOnLoaded
)
