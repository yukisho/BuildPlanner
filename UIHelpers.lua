GravvyBuildPlannerUIHelpers = {
    nextControlId = 0,
}

local Helpers = GravvyBuildPlannerUIHelpers

function Helpers:CreateFromVirtual(parent, template, purpose)
    self.nextControlId = self.nextControlId + 1
    local name = string.format(
        "GravvyBuildPlanner_%s_%d",
        purpose or "VirtualControl",
        self.nextControlId
    )
    return WINDOW_MANAGER:CreateControlFromVirtual(name, parent, template)
end
