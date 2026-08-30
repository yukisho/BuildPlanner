GravvyBuildPlannerSwapPackages = {}

local Packages = GravvyBuildPlannerSwapPackages

Packages.PRESETS = {
    { key = "boss", stringId = SI_GRAVVY_BUILD_PLANNER_SWAP_BOSS },
    { key = "trash", stringId = SI_GRAVVY_BUILD_PLANNER_SWAP_TRASH },
    { key = "solo", stringId = SI_GRAVVY_BUILD_PLANNER_SWAP_SOLO },
    { key = "parse", stringId = SI_GRAVVY_BUILD_PLANNER_SWAP_PARSE },
    { key = "noTrial", stringId = SI_GRAVVY_BUILD_PLANNER_SWAP_NO_TRIAL },
}

local includedSections = {
    gear = true,
    skills = true,
    champion = true,
    supplies = true,
}

function Packages:GetPreset(key)
    for _, preset in ipairs(self.PRESETS) do
        if preset.key == key then return preset end
    end
end

function Packages:GetPresetName(key)
    local preset = self:GetPreset(key)
    return preset and GetString(preset.stringId) or ""
end

function Packages:Build(source, target)
    local package = {
        name = source and target and zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_SWAP_NAME,
            source.name,
            target.name
        ) or "",
        source = source,
        target = target,
        rows = {},
        counts = { gear = 0, skills = 0, champion = 0, supplies = 0 },
    }
    for _, row in ipairs(GravvyBuildPlannerComparison:Build(source, target)) do
        if includedSections[row.sectionKey] then
            package.rows[#package.rows + 1] = row
            package.counts[row.sectionKey] = package.counts[row.sectionKey] + 1
        end
    end
    return package
end

function Packages:CreateVariation(data, buildId, sourceSetupId, presetKey)
    local build = data:FindBuild(buildId)
    local source = data:FindSetup(build, sourceSetupId)
    local name = self:GetPresetName(presetKey)
    if not build or not source or name == "" then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_MISSING)
    end
    local setup, message = data:DuplicateSetup(build.id, source.id, name)
    if not setup then return nil, message end
    return setup, zo_strformat(SI_GRAVVY_BUILD_PLANNER_SWAP_CREATED, setup.name)
end
