GravvyBuildPlannerUIHelpers = {
    nextControlId = 0,
    virtualControls = {},
}

local Helpers = GravvyBuildPlannerUIHelpers

function Helpers:CreateFromVirtual(parent, template, purpose)
    local name
    repeat
        self.nextControlId = self.nextControlId + 1
        name = string.format(
            "GravvyBuildPlanner_%s_%d",
            purpose or "VirtualControl",
            self.nextControlId
        )
    until _G[name] == nil

    local control = WINDOW_MANAGER:CreateControlFromVirtual(name, parent, template)
    self.virtualControls[#self.virtualControls + 1] = {
        name = name,
        template = template,
        control = control,
    }
    return control
end

function Helpers:AuditVirtualControls()
    local missing = {}
    local seen = {}
    for _, entry in ipairs(self.virtualControls) do
        if seen[entry.name] or _G[entry.name] ~= entry.control then
            missing[#missing + 1] = entry.name
        end
        seen[entry.name] = true
    end
    return {
        checked = #self.virtualControls,
        failed = #missing,
        names = missing,
    }
end
