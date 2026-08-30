GravvyBuildPlannerHelp = {}

local Help = GravvyBuildPlannerHelp
local PAGE_STRING_IDS = {
    {
        SI_GRAVVY_BUILD_PLANNER_HELP_CONTENT,
    },
    {
        SI_GRAVVY_BUILD_PLANNER_HELP_ALTERNATIVES,
        SI_GRAVVY_BUILD_PLANNER_HELP_SKILLS,
        SI_GRAVVY_BUILD_PLANNER_HELP_CHARACTER,
        SI_GRAVVY_BUILD_PLANNER_HELP_CHAMPION,
    },
    {
        SI_GRAVVY_BUILD_PLANNER_HELP_SUPPLIES,
        SI_GRAVVY_BUILD_PLANNER_HELP_CHECKLIST,
        SI_GRAVVY_BUILD_PLANNER_HELP_COMPARE,
    },
    {
        SI_GRAVVY_BUILD_PLANNER_HELP_CAPTURE,
        SI_GRAVVY_BUILD_PLANNER_HELP_REVISIONS,
        SI_GRAVVY_BUILD_PLANNER_HELP_STAT_IMPACT,
        SI_GRAVVY_BUILD_PLANNER_HELP_VALIDATION,
        SI_GRAVVY_BUILD_PLANNER_HELP_READINESS,
    },
    {
        SI_GRAVVY_BUILD_PLANNER_HELP_ASSUMPTIONS,
        SI_GRAVVY_BUILD_PLANNER_HELP_CROSS_CHARACTER,
        SI_GRAVVY_BUILD_PLANNER_HELP_WALKTHROUGH,
    },
}

local function pageText(stringIds)
    local parts = {}
    for _, stringId in ipairs(stringIds) do
        parts[#parts + 1] = GetString(stringId)
    end
    return (table.concat(parts):gsub("^%s+", ""))
end

function Help:GetPages()
    local pages = {}
    for _, stringIds in ipairs(PAGE_STRING_IDS) do
        pages[#pages + 1] = pageText(stringIds)
    end
    return pages
end

function Help:GetCombinedContent()
    return table.concat(self:GetPages(), "\n\n")
end
