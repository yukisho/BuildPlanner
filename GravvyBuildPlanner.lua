GravvyBuildPlanner = {
    name = "GravvyBuildPlanner",
}

local addon = GravvyBuildPlanner

function addon:Initialize()
    self.data = GravvyBuildPlannerData:New()
    self.setCatalog = GravvyBuildPlannerSetCatalog:New(self.data)
    self.itemResolver = GravvyBuildPlannerItemResolver:New()
    self.acquisition = GravvyBuildPlannerAcquisition:New(self.itemResolver)
    self.inventory = GravvyBuildPlannerInventory:New(self)
    self.shopping = GravvyBuildPlannerShoppingIntegration:New(self)
    self.accessibility = GravvyBuildPlannerAccessibility
    self.accessibility:Initialize(self)
    self.ui = GravvyBuildPlannerUI:New(self)
    self.ui:Initialize()
    self.share = GravvyBuildPlannerShare:New(self)
    self.share:Initialize()
    self.gamepad = GravvyBuildPlannerGamepad:New(self)
    self.gamepad:Initialize()
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
