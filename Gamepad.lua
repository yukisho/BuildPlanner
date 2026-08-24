GravvyBuildPlannerGamepad = {}

local Gamepad = GravvyBuildPlannerGamepad
local Slots = GravvyBuildPlannerSlots

local slotStringIds = {
    head = SI_GRAVVY_BUILD_PLANNER_SLOT_HEAD,
    shoulders = SI_GRAVVY_BUILD_PLANNER_SLOT_SHOULDERS,
    chest = SI_GRAVVY_BUILD_PLANNER_SLOT_CHEST,
    hands = SI_GRAVVY_BUILD_PLANNER_SLOT_HANDS,
    waist = SI_GRAVVY_BUILD_PLANNER_SLOT_WAIST,
    legs = SI_GRAVVY_BUILD_PLANNER_SLOT_LEGS,
    feet = SI_GRAVVY_BUILD_PLANNER_SLOT_FEET,
    neck = SI_GRAVVY_BUILD_PLANNER_SLOT_NECK,
    ring1 = SI_GRAVVY_BUILD_PLANNER_SLOT_RING1,
    ring2 = SI_GRAVVY_BUILD_PLANNER_SLOT_RING2,
    frontMain = SI_GRAVVY_BUILD_PLANNER_SLOT_FRONTMAIN,
    frontOff = SI_GRAVVY_BUILD_PLANNER_SLOT_FRONTOFF,
    backMain = SI_GRAVVY_BUILD_PLANNER_SLOT_BACKMAIN,
    backOff = SI_GRAVVY_BUILD_PLANNER_SLOT_BACKOFF,
}

function Gamepad:New(owner)
    return setmetatable({ owner = owner, dirty = true }, { __index = self })
end

function Gamepad:Initialize()
    self.control = GravvyBuildPlannerGamepadWindow
    self.title = self.control:GetNamedChild("Title")
    self.buildName = self.control:GetNamedChild("BuildName")
    self.setupName = self.control:GetNamedChild("SetupName")
    self.progress = self.control:GetNamedChild("Progress")
    self.status = self.control:GetNamedChild("Status")
    self.title:SetText(GetString(SI_GRAVVY_BUILD_PLANNER_TITLE))
    self.owner.accessibility:SetFont(self.title, "ZoFontGamepadBold48")
    self.owner.accessibility:SetFont(self.buildName, "ZoFontGamepadCondensed42")
    self.owner.accessibility:SetFont(self.setupName, "ZoFontGamepad34")
    self.owner.accessibility:SetFont(self.progress, "ZoFontGamepad27")
    self.owner.accessibility:SetFont(self.status, "ZoFontGamepad27")
    self.owner.accessibility:RegisterBackdrop(
        self.control:GetNamedChild("Backdrop"),
        { 0.035, 0.035, 0.045, 0.96 },
        { 0.5, 0.42, 0.28, 0.9 }
    )

    self.list = ZO_GamepadVerticalItemParametricScrollList:New(
        self.control:GetNamedChild("List")
    )
    self.list:AddDataTemplate(
        "ZO_GamepadMenuEntryTemplate",
        ZO_SharedGamepadEntry_OnSetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction
    )
    self.list:SetNoItemText(GetString(SI_GRAVVY_BUILD_PLANNER_GAMEPAD_EMPTY))
    self.list:SetOnTargetDataChangedCallback(function()
        self:RefreshPreview()
        self:RefreshKeybinds()
    end)

    self:InitializeKeybinds()
    self:InitializeDialogs()
    EVENT_MANAGER:RegisterForEvent(
        "GravvyBuildPlanner_GamepadModeChanged",
        EVENT_GAMEPAD_PREFERRED_MODE_CHANGED,
        function(_, gamepadPreferred)
            if gamepadPreferred then
                self.owner.ui:Hide()
            else
                self:Hide()
            end
        end
    )
end

function Gamepad:IsShowing()
    return self.control and not self.control:IsHidden()
end

function Gamepad:GetTargetData()
    return self.list and self.list:GetTargetData()
end

function Gamepad:GetTargetSlot()
    local data = self:GetTargetData()
    return data and data.slotKey
end

function Gamepad:GetTargetRequirement()
    local slotKey = self:GetTargetSlot()
    local setup = self.owner.data:GetCurrentSetup()
    return slotKey and setup.equipment[slotKey] or nil
end

function Gamepad:IsTargetEditable()
    local data = self:GetTargetData()
    return data and not data.occupied
end

function Gamepad:GetTargetRoutes()
    local slotKey = self:GetTargetSlot()
    local requirement = self:GetTargetRequirement()
    if not slotKey or not requirement then
        return {}
    end
    local setup = self.owner.data:GetCurrentSetup()
    local resolved = self.owner.itemResolver:Resolve(slotKey, requirement, setup)
    local state = self.owner.acquisition:Classify(slotKey, requirement, setup, resolved)
    local owned = self.owner.inventory:GetMatch(setup.id, slotKey)
    return self.owner.acquisition:GetAvailableRoutes(state, owned)
end

function Gamepad:InitializeKeybinds()
    self.keybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = GetString(SI_GRAVVY_BUILD_PLANNER_GAMEPAD_EDIT),
            keybind = "UI_SHORTCUT_PRIMARY",
            enabled = function() return self:IsTargetEditable() end,
            callback = function() self:ShowEditDialog() end,
        },
        {
            name = GetString(SI_GRAVVY_BUILD_PLANNER_ROUTE),
            keybind = "UI_SHORTCUT_SECONDARY",
            visible = function()
                return self:GetTargetRequirement() ~= nil
                    and #self:GetTargetRoutes() > 1
            end,
            callback = function() self:CycleTargetRoute() end,
        },
        {
            name = GetString(SI_GRAVVY_BUILD_PLANNER_CLEAR),
            keybind = "UI_SHORTCUT_TERTIARY",
            enabled = function()
                return self:IsTargetEditable() and self:GetTargetRequirement() ~= nil
            end,
            callback = function() self:ClearTargetSlot() end,
        },
        {
            name = GetString(SI_GRAVVY_BUILD_PLANNER_EXPORT),
            keybind = "UI_SHORTCUT_QUATERNARY",
            callback = function() self:ShowExportDialog() end,
        },
        {
            name = GetString(SI_GRAVVY_BUILD_PLANNER_GAMEPAD_PREVIOUS_SETUP),
            keybind = "UI_SHORTCUT_LEFT_SHOULDER",
            visible = function()
                local _, build = self.owner.data:GetCurrentSetup()
                return #build.setups > 1
            end,
            callback = function() self:SwitchSetup(-1) end,
        },
        {
            name = GetString(SI_GRAVVY_BUILD_PLANNER_GAMEPAD_NEXT_SETUP),
            keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
            visible = function()
                local _, build = self.owner.data:GetCurrentSetup()
                return #build.setups > 1
            end,
            callback = function() self:SwitchSetup(1) end,
        },
        {
            name = GetString(SI_GRAVVY_BUILD_PLANNER_GAMEPAD_PREVIOUS_BUILD),
            keybind = "UI_SHORTCUT_LEFT_TRIGGER",
            visible = function() return #self.owner.data:GetBuilds() > 1 end,
            callback = function() self:SwitchBuild(-1) end,
        },
        {
            name = GetString(SI_GRAVVY_BUILD_PLANNER_GAMEPAD_NEXT_BUILD),
            keybind = "UI_SHORTCUT_RIGHT_TRIGGER",
            visible = function() return #self.owner.data:GetBuilds() > 1 end,
            callback = function() self:SwitchBuild(1) end,
        },
        {
            name = GetString(SI_GRAVVY_BUILD_PLANNER_GAMEPAD_MANAGE),
            keybind = "UI_SHORTCUT_RIGHT_STICK",
            callback = function() self:ShowManageDialog() end,
        },
        KEYBIND_STRIP:GenerateGamepadBackButtonDescriptor(function() self:Hide() end),
    }
end

function Gamepad:Show()
    if not IsInGamepadPreferredMode() or self:IsShowing() then
        return
    end
    self.owner.ui:Hide()
    self.control:SetHidden(false)
    self.keybindState = KEYBIND_STRIP:PushKeybindGroupState()
    KEYBIND_STRIP:RemoveDefaultExit(self.keybindState)
    KEYBIND_STRIP:AddKeybindButtonGroup(self.keybinds, self.keybindState)
    self.list:Activate()
    self:Refresh(true)
    PlaySound(SOUNDS.GAMEPAD_OPEN_WINDOW)
end

function Gamepad:Hide()
    if not self:IsShowing() then
        return
    end
    self:ClearPreview()
    self.list:Deactivate()
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybinds, self.keybindState)
    KEYBIND_STRIP:RestoreDefaultExit(self.keybindState)
    KEYBIND_STRIP:PopKeybindGroupState()
    self.keybindState = nil
    self.control:SetHidden(true)
    PlaySound(SOUNDS.GAMEPAD_CLOSE_WINDOW)
end

function Gamepad:Toggle()
    if self:IsShowing() then
        self:Hide()
    else
        self:Show()
    end
end

function Gamepad:RefreshKeybinds()
    if self:IsShowing() then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybinds, self.keybindState)
    end
end

local function requirementSummary(requirement)
    if not requirement then
        return GetString(SI_GRAVVY_BUILD_PLANNER_NOT_PLANNED)
    end
    local name = requirement.itemName or requirement.setName
    if not name or name == "" then
        return GetString(SI_GRAVVY_BUILD_PLANNER_INCOMPLETE)
    end
    local details = {}
    if requirement.traitType and requirement.traitType ~= ITEM_TRAIT_TYPE_NONE then
        details[#details + 1] = GetString("SI_ITEMTRAITTYPE", requirement.traitType)
    end
    if requirement.enchantmentName and requirement.enchantmentName ~= "" then
        details[#details + 1] = requirement.enchantmentName
    end
    return #details > 0 and name .. " — " .. table.concat(details, ", ") or name
end

function Gamepad:GetAcquisitionStatus(slotKey, requirement, setup)
    if not requirement then
        return nil
    end
    local resolved = self.owner.itemResolver:Resolve(slotKey, requirement, setup)
    local state = self.owner.acquisition:Classify(slotKey, requirement, setup, resolved)
    local owned = self.owner.inventory:GetMatch(setup.id, slotKey, requirement, setup)
    local saved = setup.acquisition[slotKey]
    return self.owner.acquisition:GetStatus(
        state,
        owned,
        saved and saved.preferredRoute
    )
end

function Gamepad:Refresh(force)
    if not self:IsShowing() and not force then
        self.dirty = true
        return
    end
    local selectedSlot = self:GetTargetSlot()
    local setup, build = self.owner.data:GetCurrentSetup()
    self.buildName:SetText(build.name)
    self.setupName:SetText(setup.name)
    local progress = self.owner.inventory:GetProgress(setup.id)
    self.progress:SetText(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_SETUP_PROGRESS,
        progress.ready,
        progress.planned,
        progress.adjustable,
        progress.missing
    ))

    self.list:Clear()
    local selectedIndex
    for index, slotKey in ipairs(Slots.ORDER) do
        local mainHand = Slots:GetMainHand(slotKey)
        local mainRequirement = mainHand and setup.equipment[mainHand]
        local occupied = mainRequirement and mainRequirement.occupiesOffHand
        local requirement = setup.equipment[slotKey]
        local entry = ZO_GamepadEntryData:New(GetString(slotStringIds[slotKey]))
        entry.slotKey = slotKey
        entry.occupied = occupied == true
        entry:SetFontScaleOnSelection(false)
        entry:SetShowUnselectedSublabels(true)
        if occupied then
            entry:AddSubLabel(zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_OCCUPIED,
                GetString(slotStringIds[mainHand])
            ))
        else
            local summary = requirementSummary(requirement)
            local alternativeCount = #self.owner.data:GetAlternatives(setup, slotKey)
            if alternativeCount > 0 then
                summary = zo_strformat(
                    SI_GRAVVY_BUILD_PLANNER_SUMMARY_ALTERNATIVES,
                    summary,
                    alternativeCount
                )
            end
            entry:AddSubLabel(summary)
            local status = self:GetAcquisitionStatus(slotKey, requirement, setup)
            if status then
                entry:AddSubLabel(status)
            end
        end
        self.list:AddEntry("ZO_GamepadMenuEntryTemplate", entry)
        if slotKey == selectedSlot then
            selectedIndex = index
        end
    end
    self.list:Commit()
    if selectedIndex then
        self.list:SetSelectedIndex(selectedIndex)
    end
    self.dirty = false
    self:RefreshPreview()
    self:RefreshKeybinds()
end

function Gamepad:SwitchSetup(direction)
    local setup, build = self.owner.data:GetCurrentSetup()
    if #build.setups < 2 then
        return
    end
    local _, index = self.owner.data:FindSetup(build, setup.id)
    local target = ((index - 1 + direction) % #build.setups) + 1
    self.owner.data:SelectSetup(build.id, build.setups[target].id)
    self:SetStatus("")
    self:Refresh(true)
    PlaySound(direction < 0 and SOUNDS.GAMEPAD_PAGE_BACK or SOUNDS.GAMEPAD_PAGE_FORWARD)
end

function Gamepad:SwitchBuild(direction)
    local builds = self.owner.data:GetBuilds()
    if #builds < 2 then
        return
    end
    local current = self.owner.data:GetCurrentBuild()
    local _, index = self.owner.data:FindBuild(current.id)
    local target = ((index - 1 + direction) % #builds) + 1
    self.owner.data:SelectBuild(builds[target].id)
    self:SetStatus("")
    self:Refresh(true)
    PlaySound(direction < 0 and SOUNDS.GAMEPAD_PAGE_BACK or SOUNDS.GAMEPAD_PAGE_FORWARD)
end

function Gamepad:CycleTargetRoute()
    local routes = self:GetTargetRoutes()
    if #routes < 2 then
        return
    end
    local slotKey = self:GetTargetSlot()
    local setup, build = self.owner.data:GetCurrentSetup()
    local saved = setup.acquisition[slotKey]
    local current = saved and saved.preferredRoute
    local choices = { false }
    for _, route in ipairs(routes) do
        choices[#choices + 1] = route
    end
    local index = 1
    for choiceIndex, route in ipairs(choices) do
        if route == current then
            index = choiceIndex
            break
        end
    end
    local nextRoute = choices[(index % #choices) + 1]
    self.owner.data:SetPreferredRoute(
        build.id,
        setup.id,
        slotKey,
        nextRoute or nil
    )
    self:Refresh(true)
end

function Gamepad:ClearTargetSlot()
    local slotKey = self:GetTargetSlot()
    local setup, build = self.owner.data:GetCurrentSetup()
    local ok, message = self.owner.data:SetEquipment(build.id, setup.id, slotKey, nil)
    if not ok then
        self:SetStatus(message, true)
        return
    end
    self.owner.inventory:Refresh()
    self:SetStatus(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_SLOT_CLEARED,
        GetString(slotStringIds[slotKey])
    ))
    self:Refresh(true)
end

function Gamepad:RefreshPreview()
    self:ClearPreview()
    local slotKey = self:GetTargetSlot()
    local requirement = self:GetTargetRequirement()
    if not slotKey or not requirement or not GAMEPAD_TOOLTIPS then
        return
    end
    local setup = self.owner.data:GetCurrentSetup()
    local resolved = self.owner.itemResolver:Resolve(slotKey, requirement, setup)
    local itemLink = resolved and resolved.itemLink or requirement.itemLink
    if itemLink and itemLink ~= "" then
        GAMEPAD_TOOLTIPS:LayoutItemLink(GAMEPAD_LEFT_TOOLTIP, itemLink)
    end
end

function Gamepad:ClearPreview()
    if GAMEPAD_TOOLTIPS and GAMEPAD_LEFT_TOOLTIP then
        GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_LEFT_TOOLTIP)
    end
end

function Gamepad:SetStatus(message, isError)
    self.status:SetText(self.owner.accessibility:FormatStatus(message, isError))
    self.status:SetColor(
        isError and 1 or 0.65,
        isError and 0.35 or 0.82,
        isError and 0.35 or 0.55,
        1
    )
end
