GravvyBuildPlanner = {
    name = "GravvyBuildPlanner",
}

local addon = GravvyBuildPlanner

function addon:GetBuildVersion()
    if not GetAddOnManager then return 0 end
    local manager = GetAddOnManager()
    for index = 1, manager:GetNumAddOns() do
        local name = manager:GetAddOnInfo(index)
        if name == self.name then
            return manager:GetAddOnVersion(index)
        end
    end
    return 0
end

function addon:Initialize()
    self.data = GravvyBuildPlannerData:New()
    if self.data.startupMessage and d then
        d(self.data.startupMessage)
    end
    self.skillCatalog = GravvyBuildPlannerSkillCatalog:New()
    self.skillCatalog:Refresh()
    self.championCatalog = GravvyBuildPlannerChampionCatalog:New()
    self.championCatalog:Refresh()
    self.checklistDetection = GravvyBuildPlannerChecklistDetection:New(self)
    self.consumableCatalog = GravvyBuildPlannerConsumableCatalog:New(self.data)
    self.consumableCatalog:Refresh()
    self.setCatalog = GravvyBuildPlannerSetCatalog:New(self.data)
    self.itemResolver = GravvyBuildPlannerItemResolver:New()
    self.statImpact = GravvyBuildPlannerStatImpact:New(self)
    self.buildValidation = GravvyBuildPlannerBuildValidation:New(self)
    self.acquisition = GravvyBuildPlannerAcquisition:New(self.itemResolver)
    self.inventory = GravvyBuildPlannerInventory:New(self)
    self.shopping = GravvyBuildPlannerShoppingIntegration:New(self)
    self.readiness = GravvyBuildPlannerReadiness:New(self)
    self.walkthrough = GravvyBuildPlannerWalkthrough:New(self)
    self.capture = GravvyBuildPlannerCharacterCapture:New(self)
    self.accessibility = GravvyBuildPlannerAccessibility
    self.accessibility:Initialize(self)
    self.ui = GravvyBuildPlannerUI:New(self)
    self.ui:Initialize()
    self.share = GravvyBuildPlannerShare:New(self)
    self.share:Initialize()
    self.gamepad = GravvyBuildPlannerGamepad:New(self)
    self.gamepad:Initialize()
    self.runtimeAudit = GravvyBuildPlannerRuntimeAudit:New(self)
    self.checklistDetection:Initialize()
    self.inventory:Initialize()
    GravvyBuildPlannerSettings:Initialize(self)
    GravvyBuildPlannerMainMenu:Initialize(self)

    SLASH_COMMANDS["/buildplanner"] = function() self:ToggleWindow() end
    SLASH_COMMANDS["/gbp"] = function() self:ToggleWindow() end
    SLASH_COMMANDS["/buildplannerhelp"] = function()
        if IsInGamepadPreferredMode and IsInGamepadPreferredMode() then
            self.gamepad:ShowHelpDialog()
        else
            self.ui:ShowHelp()
        end
    end
    SLASH_COMMANDS["/gbpaudit"] = function() self.runtimeAudit:Run() end
end

function addon:ToggleWindow()
    if IsInGamepadPreferredMode and IsInGamepadPreferredMode() then
        self.ui:Hide()
        self.gamepad:Toggle()
    else
        self.gamepad:Hide()
        self.ui:Toggle()
    end
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
