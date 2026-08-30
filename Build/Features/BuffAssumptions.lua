GravvyBuildPlannerBuffAssumptions = {}

local Assumptions = GravvyBuildPlannerBuffAssumptions

function Assumptions:Split(value)
    local entries = {}
    local seen = {}
    value = tostring(value or ""):gsub("\r", "")
    for line in (value .. "\n"):gmatch("(.-)\n") do
        line = zo_strtrim(line)
        local key = zo_strlower(line)
        if line ~= "" and not seen[key] then
            seen[key] = true
            entries[#entries + 1] = line
        end
    end
    return entries
end

function Assumptions:Join(entries)
    return table.concat(entries or {}, "\n")
end

function Assumptions:HasAny(setup)
    local values = setup and setup.buffAssumptions or {}
    return (values.food or "") ~= ""
        or (values.potion or "") ~= ""
        or #(values.selfBuffs or {}) > 0
        or #(values.groupBuffs or {}) > 0
        or #(values.targetConditions or {}) > 0
end

function Assumptions:GetRows(setup)
    local values = setup and setup.buffAssumptions or {}
    return {
        { key = "food", label = GetString(SI_GRAVVY_BUILD_PLANNER_ASSUMPTIONS_FOOD), value = values.food or "" },
        { key = "potion", label = GetString(SI_GRAVVY_BUILD_PLANNER_ASSUMPTIONS_POTION), value = values.potion or "" },
        { key = "selfBuffs", label = GetString(SI_GRAVVY_BUILD_PLANNER_ASSUMPTIONS_SELF), value = table.concat(values.selfBuffs or {}, ", ") },
        { key = "groupBuffs", label = GetString(SI_GRAVVY_BUILD_PLANNER_ASSUMPTIONS_GROUP), value = table.concat(values.groupBuffs or {}, ", ") },
        { key = "targetConditions", label = GetString(SI_GRAVVY_BUILD_PLANNER_ASSUMPTIONS_TARGET), value = table.concat(values.targetConditions or {}, ", ") },
    }
end

function Assumptions:Format(setup)
    local lines = {}
    for _, row in ipairs(self:GetRows(setup)) do
        if row.value ~= "" then lines[#lines + 1] = row.label .. ": " .. row.value end
    end
    return #lines > 0 and table.concat(lines, "\n")
        or GetString(SI_GRAVVY_BUILD_PLANNER_ASSUMPTIONS_NONE)
end
