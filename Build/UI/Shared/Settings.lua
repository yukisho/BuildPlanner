GravvyBuildPlannerSettings = {}

function GravvyBuildPlannerSettings:Initialize(owner)
    if not LibAddonMenu2 then
        return
    end

    local function saved()
        return owner.data:GetSettings()
    end
    local panelName = "GravvyBuildPlannerOptions"
    LibAddonMenu2:RegisterAddonPanel(panelName, {
        type = "panel",
        name = GetString(SI_GRAVVY_BUILD_PLANNER_TITLE),
        displayName = GetString(SI_GRAVVY_BUILD_PLANNER_TITLE),
        author = "Gravvy",
        registerForRefresh = true,
        registerForDefaults = true,
    })
    LibAddonMenu2:RegisterOptionControls(panelName, {
        {
            type = "header",
            name = GetString(SI_GRAVVY_BUILD_PLANNER_SETTINGS_ACCESSIBILITY),
        },
        {
            type = "dropdown",
            name = GetString(SI_GRAVVY_BUILD_PLANNER_SETTINGS_FONT_SCALE),
            choices = { "90%", "100%", "110%", "120%", "130%", "140%" },
            choicesValues = { 0.9, 1, 1.1, 1.2, 1.3, 1.4 },
            getFunc = function() return saved().fontScale end,
            setFunc = function(value)
                saved().fontScale = value
                owner.accessibility:Refresh()
            end,
            default = 1,
        },
        {
            type = "checkbox",
            name = GetString(SI_GRAVVY_BUILD_PLANNER_SETTINGS_HIGH_CONTRAST),
            tooltip = GetString(SI_GRAVVY_BUILD_PLANNER_SETTINGS_HIGH_CONTRAST_TOOLTIP),
            getFunc = function() return saved().highContrast end,
            setFunc = function(value)
                saved().highContrast = value
                owner.accessibility:Refresh()
            end,
            default = false,
        },
        {
            type = "checkbox",
            name = GetString(SI_GRAVVY_BUILD_PLANNER_SETTINGS_NON_COLOR),
            tooltip = GetString(SI_GRAVVY_BUILD_PLANNER_SETTINGS_NON_COLOR_TOOLTIP),
            getFunc = function() return saved().nonColorIndicators end,
            setFunc = function(value)
                saved().nonColorIndicators = value
                owner.accessibility:Refresh()
            end,
            default = false,
        },
    })
end
