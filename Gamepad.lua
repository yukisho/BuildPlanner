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
    return setmetatable({ owner = owner, dirty = true, activeView = "gear" }, { __index = self })
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
    return data and self.activeView ~= "comparison"
        and (self.activeView ~= "gear" or not data.occupied)
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
            name = function()
                if self.activeView == "skills" then
                    return GetString(SI_GRAVVY_BUILD_PLANNER_EDIT_SKILL)
                elseif self.activeView == "character" then
                    return GetString(SI_GRAVVY_BUILD_PLANNER_SAVE_CHARACTER)
                elseif self.activeView == "champion" then
                    return GetString(SI_GRAVVY_BUILD_PLANNER_CHAMPION_SAVE)
                elseif self.activeView == "supplies" then
                    return GetString(SI_GRAVVY_BUILD_PLANNER_SUPPLY_SAVE)
                elseif self.activeView == "checklist" then
                    return GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_SAVE)
                end
                return GetString(SI_GRAVVY_BUILD_PLANNER_GAMEPAD_EDIT)
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            enabled = function() return self:IsTargetEditable() end,
            callback = function() self:ShowEditDialog() end,
        },
        {
            name = function()
                if self.activeView == "checklist" then
                    local data = self:GetTargetData()
                    return GetString(data and data.completed
                        and SI_GRAVVY_BUILD_PLANNER_CHECKLIST_MARK_INCOMPLETE
                        or SI_GRAVVY_BUILD_PLANNER_CHECKLIST_MARK_COMPLETE)
                elseif self.activeView == "comparison" then
                    return GetString(SI_GRAVVY_BUILD_PLANNER_COMPARE_NEXT_SETUP)
                end
                return GetString(SI_GRAVVY_BUILD_PLANNER_ROUTE)
            end,
            keybind = "UI_SHORTCUT_SECONDARY",
            visible = function()
                if self.activeView == "checklist" then
                    local data = self:GetTargetData()
                    return data and data.checklistIndex ~= nil
                elseif self.activeView == "comparison" then
                    local _, build = self.owner.data:GetCurrentSetup()
                    return #build.setups > 2
                end
                return self:GetTargetRequirement() ~= nil and #self:GetTargetRoutes() > 1
            end,
            callback = function()
                if self.activeView == "checklist" then
                    self:ToggleTargetChecklist()
                elseif self.activeView == "comparison" then
                    self:CycleComparisonTarget()
                else
                    self:CycleTargetRoute()
                end
            end,
        },
        {
            name = function()
                if self.activeView == "skills" then
                    return GetString(SI_GRAVVY_BUILD_PLANNER_CLEAR_SKILL)
                elseif self.activeView == "champion" then
                    return GetString(SI_GRAVVY_BUILD_PLANNER_CHAMPION_REMOVE)
                elseif self.activeView == "supplies" then
                    return GetString(SI_GRAVVY_BUILD_PLANNER_SUPPLY_REMOVE)
                elseif self.activeView == "checklist" then
                    return GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_REMOVE)
                end
                return GetString(SI_GRAVVY_BUILD_PLANNER_CLEAR)
            end,
            keybind = "UI_SHORTCUT_TERTIARY",
            visible = function()
                return self.activeView ~= "character" and self.activeView ~= "comparison"
            end,
            enabled = function()
                if self.activeView == "skills" then
                    local data = self:GetTargetData()
                    local setup = self.owner.data:GetCurrentSetup()
                    return data and setup.skillBars and setup.skillBars[data.skillBar]
                        and setup.skillBars[data.skillBar][data.skillSlot] ~= nil
                elseif self.activeView == "champion" then
                    local data = self:GetTargetData()
                    return data and data.championSkillId ~= nil
                elseif self.activeView == "supplies" then
                    local data = self:GetTargetData()
                    return data and data.supplyIndex ~= nil
                elseif self.activeView == "checklist" then
                    local data = self:GetTargetData()
                    return data and data.checklistIndex ~= nil
                end
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
        {
            name = function()
                if self.activeView == "gear" then
                    return GetString(SI_GRAVVY_BUILD_PLANNER_SKILLS)
                elseif self.activeView == "skills" then
                    return GetString(SI_GRAVVY_BUILD_PLANNER_CHARACTER)
                elseif self.activeView == "character" then
                    return GetString(SI_GRAVVY_BUILD_PLANNER_CHAMPION)
                elseif self.activeView == "champion" then
                    return GetString(SI_GRAVVY_BUILD_PLANNER_SUPPLIES)
                elseif self.activeView == "supplies" then
                    return GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST)
                elseif self.activeView == "checklist" then
                    return GetString(SI_GRAVVY_BUILD_PLANNER_COMPARE)
                end
                return GetString(SI_GRAVVY_BUILD_PLANNER_GEAR)
            end,
            keybind = "UI_SHORTCUT_LEFT_STICK",
            callback = function() self:TogglePlannerView() end,
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
    local selectedData = self:GetTargetData()
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
    if self.activeView == "skills" then
        local entryIndex = 0
        for _, barKey in ipairs({ "front", "back" }) do
            local bar = setup.skillBars and setup.skillBars[barKey] or {}
            for slotIndex = 1, 6 do
                entryIndex = entryIndex + 1
                local label = zo_strformat(
                    SI_GRAVVY_BUILD_PLANNER_SKILL_SLOT_TITLE,
                    GetString(barKey == "front"
                        and SI_GRAVVY_BUILD_PLANNER_FRONT_BAR
                        or SI_GRAVVY_BUILD_PLANNER_BACK_BAR),
                    slotIndex == 6
                        and GetString(SI_GRAVVY_BUILD_PLANNER_ULTIMATE)
                        or tostring(slotIndex)
                )
                local entry = ZO_GamepadEntryData:New(label)
                entry.skillBar = barKey
                entry.skillSlot = slotIndex
                entry:SetFontScaleOnSelection(false)
                entry:SetShowUnselectedSublabels(true)
                entry:AddSubLabel(bar[slotIndex] and bar[slotIndex].name
                    or GetString(SI_GRAVVY_BUILD_PLANNER_NOT_PLANNED))
                self.list:AddEntry("ZO_GamepadMenuEntryTemplate", entry)
                if selectedData and selectedData.skillBar == barKey
                    and selectedData.skillSlot == slotIndex then
                    selectedIndex = entryIndex
                end
            end
        end
        self.list:Commit()
        self.list:SetSelectedIndex(selectedIndex or 1)
        self.dirty = false
        self:RefreshPreview()
        self:RefreshKeybinds()
        return
    end
    if self.activeView == "character" then
        local character = setup.character or {}
        local attributes = character.attributes or {}
        local curseNames = {
            [0] = SI_GRAVVY_BUILD_PLANNER_CURSE_NONE,
            [1] = SI_GRAVVY_BUILD_PLANNER_CURSE_VAMPIRE,
            [2] = SI_GRAVVY_BUILD_PLANNER_CURSE_WEREWOLF,
        }
        local raceName = character.raceId and character.raceId > 0 and GetRaceName
            and GetRaceName(GENDER_MALE or 1, character.raceId)
            or GetString(SI_GRAVVY_BUILD_PLANNER_NOT_PLANNED)
        local mundusName = character.mundus and character.mundus > 0
            and GetString("SI_MUNDUSSTONE", character.mundus)
            or GetString(SI_GRAVVY_BUILD_PLANNER_NOT_PLANNED)
        local fields = {
            { "health", SI_GRAVVY_BUILD_PLANNER_HEALTH, tostring(attributes.health or 0) },
            { "magicka", SI_GRAVVY_BUILD_PLANNER_MAGICKA, tostring(attributes.magicka or 0) },
            { "stamina", SI_GRAVVY_BUILD_PLANNER_STAMINA, tostring(attributes.stamina or 0) },
            { "race", SI_GRAVVY_BUILD_PLANNER_RACE, raceName },
            { "mundus", SI_GRAVVY_BUILD_PLANNER_MUNDUS, mundusName },
            {
                "curse",
                SI_GRAVVY_BUILD_PLANNER_CURSE,
                GetString(curseNames[character.curse or 0] or SI_GRAVVY_BUILD_PLANNER_CURSE_NONE),
            },
        }
        for index = 1, 3 do
            fields[#fields + 1] = {
                "subclass" .. tostring(index),
                SI_GRAVVY_BUILD_PLANNER_SUBCLASS_LINE,
                character.subclassLines and character.subclassLines[index] ~= ""
                    and character.subclassLines[index]
                    or GetString(SI_GRAVVY_BUILD_PLANNER_NOT_PLANNED),
                index,
            }
        end
        for index, field in ipairs(fields) do
            local label = field[4]
                and zo_strformat(field[2], field[4])
                or GetString(field[2])
            local entry = ZO_GamepadEntryData:New(label)
            entry.characterField = field[1]
            entry:SetFontScaleOnSelection(false)
            entry:SetShowUnselectedSublabels(true)
            entry:AddSubLabel(field[3])
            self.list:AddEntry("ZO_GamepadMenuEntryTemplate", entry)
            if selectedData and selectedData.characterField == field[1] then
                selectedIndex = index
            end
        end
        self.list:Commit()
        self.list:SetSelectedIndex(selectedIndex or 1)
        self.dirty = false
        self:RefreshPreview()
        self:RefreshKeybinds()
        return
    end
    if self.activeView == "champion" then
        local selectedDiscipline = selectedData and selectedData.championDiscipline
        local selectedSkillId = selectedData and selectedData.championSkillId
        local entryIndex = 0
        for _, disciplineKey in ipairs({ "craft", "warfare", "fitness" }) do
            local discipline = setup.champion[disciplineKey]
            entryIndex = entryIndex + 1
            local addEntry = ZO_GamepadEntryData:New(zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_CHAMPION_ADD_DISCIPLINE,
                GetString(disciplineKey == "craft"
                    and SI_GRAVVY_BUILD_PLANNER_CHAMPION_CRAFT
                    or disciplineKey == "warfare"
                        and SI_GRAVVY_BUILD_PLANNER_CHAMPION_WARFARE
                        or SI_GRAVVY_BUILD_PLANNER_CHAMPION_FITNESS)
            ))
            addEntry.championDiscipline = disciplineKey
            addEntry:SetFontScaleOnSelection(false)
            self.list:AddEntry("ZO_GamepadMenuEntryTemplate", addEntry)
            if selectedDiscipline == disciplineKey and not selectedSkillId then
                selectedIndex = entryIndex
            end
            for _, allocation in ipairs(discipline.allocations) do
                entryIndex = entryIndex + 1
                local catalogEntry = self.owner.championCatalog:FindById(allocation.skillId)
                local entry = ZO_GamepadEntryData:New(
                    catalogEntry and catalogEntry.name or allocation.name
                )
                entry.championDiscipline = disciplineKey
                entry.championSkillId = allocation.skillId
                entry:SetFontScaleOnSelection(false)
                entry:SetShowUnselectedSublabels(true)
                entry:AddSubLabel(zo_strformat(
                    SI_GRAVVY_BUILD_PLANNER_CHAMPION_POINTS_ASSIGNED,
                    allocation.points
                ))
                for slotIndex = 1, 4 do
                    if discipline.slottables[slotIndex] == allocation.skillId then
                        entry:AddSubLabel(zo_strformat(
                            SI_GRAVVY_BUILD_PLANNER_CHAMPION_SLOT_NUMBER,
                            slotIndex
                        ))
                        break
                    end
                end
                self.list:AddEntry("ZO_GamepadMenuEntryTemplate", entry)
                if selectedDiscipline == disciplineKey
                    and selectedSkillId == allocation.skillId then
                    selectedIndex = entryIndex
                end
            end
        end
        self.list:Commit()
        self.list:SetSelectedIndex(selectedIndex or 1)
        self.dirty = false
        self:RefreshPreview()
        self:RefreshKeybinds()
        return
    end
    if self.activeView == "supplies" then
        local selectedSupplyIndex = selectedData and selectedData.supplyIndex
        local addEntry = ZO_GamepadEntryData:New(GetString(SI_GRAVVY_BUILD_PLANNER_SUPPLY_ADD))
        addEntry:SetFontScaleOnSelection(false)
        self.list:AddEntry("ZO_GamepadMenuEntryTemplate", addEntry)
        for index, supply in ipairs(setup.consumables) do
            local entry = ZO_GamepadEntryData:New(supply.name)
            entry.supplyIndex = index
            entry.itemLink = supply.itemLink
            entry:SetFontScaleOnSelection(false)
            entry:SetShowUnselectedSublabels(true)
            entry:AddSubLabel(zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_SUPPLY_GAMEPAD_DETAIL,
                GetString(supply.category == "food"
                    and SI_GRAVVY_BUILD_PLANNER_SUPPLY_FOOD
                    or supply.category == "drink"
                        and SI_GRAVVY_BUILD_PLANNER_SUPPLY_DRINK
                        or supply.category == "potion"
                            and SI_GRAVVY_BUILD_PLANNER_SUPPLY_POTION
                            or supply.category == "poison"
                                and SI_GRAVVY_BUILD_PLANNER_SUPPLY_POISON
                                or SI_GRAVVY_BUILD_PLANNER_SUPPLY_OTHER),
                supply.quantity
            ))
            if supply.note ~= "" then
                entry:AddSubLabel(supply.note)
            end
            self.list:AddEntry("ZO_GamepadMenuEntryTemplate", entry)
            if selectedSupplyIndex == index then
                selectedIndex = index + 1
            end
        end
        self.list:Commit()
        self.list:SetSelectedIndex(selectedIndex or 1)
        self.dirty = false
        self:RefreshPreview()
        self:RefreshKeybinds()
        return
    end
    if self.activeView == "checklist" then
        local selectedChecklistIndex = selectedData and selectedData.checklistIndex
        local addEntry = ZO_GamepadEntryData:New(GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_ADD))
        addEntry:SetFontScaleOnSelection(false)
        self.list:AddEntry("ZO_GamepadMenuEntryTemplate", addEntry)
        for index, item in ipairs(setup.checklist) do
            local marker = item.completed and "✓ " or "○ "
            local entry = ZO_GamepadEntryData:New(marker .. item.name)
            entry.checklistIndex = index
            entry.abilityId = item.abilityId
            entry.targetRank = item.targetRank
            entry.completed = item.completed
            entry:SetFontScaleOnSelection(false)
            entry:SetShowUnselectedSublabels(true)
            local categoryId = item.category == "passive"
                and SI_GRAVVY_BUILD_PLANNER_CHECKLIST_PASSIVE
                or item.category == "skillLine"
                    and SI_GRAVVY_BUILD_PLANNER_CHECKLIST_SKILL_LINE
                    or item.category == "unlock"
                        and SI_GRAVVY_BUILD_PLANNER_CHECKLIST_UNLOCK
                        or SI_GRAVVY_BUILD_PLANNER_CHECKLIST_OTHER
            local detail = GetString(categoryId)
            if item.targetRank then
                detail = detail .. " · " .. zo_strformat(
                    SI_GRAVVY_BUILD_PLANNER_CHECKLIST_RANK_VALUE,
                    item.targetRank
                )
            end
            entry:AddSubLabel(detail)
            if item.note ~= "" then
                entry:AddSubLabel(item.note)
            end
            self.list:AddEntry("ZO_GamepadMenuEntryTemplate", entry)
            if selectedChecklistIndex == index then
                selectedIndex = index + 1
            end
        end
        self.list:Commit()
        self.list:SetSelectedIndex(selectedIndex or 1)
        self.dirty = false
        self:RefreshPreview()
        self:RefreshKeybinds()
        return
    end
    if self.activeView == "comparison" then
        local target = self.comparisonSetupId
            and self.owner.data:FindSetup(build, self.comparisonSetupId)
        if not target or target.id == setup.id then
            target = GravvyBuildPlannerComparison:GetDefaultTarget(build, setup.id)
            self.comparisonSetupId = target and target.id
        end
        self.setupName:SetText(target and (setup.name .. " ↔ " .. target.name) or setup.name)
        local differences = GravvyBuildPlannerComparison:Build(setup, target)
        if #differences == 0 then
            local message = target
                and GetString(SI_GRAVVY_BUILD_PLANNER_COMPARE_NONE)
                or GetString(SI_GRAVVY_BUILD_PLANNER_COMPARE_NEEDS_SETUP)
            local entry = ZO_GamepadEntryData:New(message)
            entry:SetFontScaleOnSelection(false)
            self.list:AddEntry("ZO_GamepadMenuEntryTemplate", entry)
        else
            for _, difference in ipairs(differences) do
                local entry = ZO_GamepadEntryData:New(
                    difference.section .. " · " .. difference.label
                )
                entry:SetFontScaleOnSelection(false)
                entry:SetShowUnselectedSublabels(true)
                entry:AddSubLabel(setup.name .. ": " .. difference.left)
                entry:AddSubLabel(target.name .. ": " .. difference.right)
                self.list:AddEntry("ZO_GamepadMenuEntryTemplate", entry)
            end
        end
        self.list:Commit()
        self.list:SetSelectedIndex(1)
        self.dirty = false
        self:ClearPreview()
        self:RefreshKeybinds()
        return
    end
    local selectedSlot = selectedData and selectedData.slotKey
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

function Gamepad:TogglePlannerView()
    if self.activeView == "gear" then
        self.activeView = "skills"
    elseif self.activeView == "skills" then
        self.activeView = "character"
    elseif self.activeView == "character" then
        self.activeView = "champion"
    elseif self.activeView == "champion" then
        self.activeView = "supplies"
    elseif self.activeView == "supplies" then
        self.activeView = "checklist"
    elseif self.activeView == "checklist" then
        self.activeView = "comparison"
    else
        self.activeView = "gear"
    end
    self:SetStatus("")
    self:Refresh(true)
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

function Gamepad:ToggleTargetChecklist()
    local data = self:GetTargetData()
    if not data or not data.checklistIndex then
        return
    end
    local setup, build = self.owner.data:GetCurrentSetup()
    local ok, message = self.owner.data:SetChecklistCompleted(
        build.id,
        setup.id,
        data.checklistIndex,
        not data.completed
    )
    if not ok then
        self:SetStatus(message, true)
        return
    end
    self:Refresh(true)
end

function Gamepad:CycleComparisonTarget()
    local current, build = self.owner.data:GetCurrentSetup()
    local candidates = {}
    local selectedIndex = 0
    for _, setup in ipairs(build.setups) do
        if setup.id ~= current.id then
            candidates[#candidates + 1] = setup
            if setup.id == self.comparisonSetupId then
                selectedIndex = #candidates
            end
        end
    end
    if #candidates == 0 then
        return
    end
    selectedIndex = (selectedIndex % #candidates) + 1
    self.comparisonSetupId = candidates[selectedIndex].id
    self:Refresh(true)
end

function Gamepad:ClearTargetSlot()
    if self.activeView == "skills" then
        local data = self:GetTargetData()
        local setup, build = self.owner.data:GetCurrentSetup()
        self.owner.data:SetSkill(build.id, setup.id, data.skillBar, data.skillSlot, nil)
        self:SetStatus(GetString(SI_GRAVVY_BUILD_PLANNER_SKILL_CLEARED))
        self:Refresh(true)
        return
    end
    if self.activeView == "champion" then
        local data = self:GetTargetData()
        if data and data.championSkillId then
            local setup, build = self.owner.data:GetCurrentSetup()
            self.owner.data:SetChampionAllocation(
                build.id,
                setup.id,
                data.championDiscipline,
                { skillId = data.championSkillId, remove = true }
            )
            self:SetStatus(GetString(SI_GRAVVY_BUILD_PLANNER_CHAMPION_REMOVED))
            self:Refresh(true)
        end
        return
    end
    if self.activeView == "supplies" then
        local data = self:GetTargetData()
        if data and data.supplyIndex then
            local setup, build = self.owner.data:GetCurrentSetup()
            self.owner.data:SetConsumable(build.id, setup.id, data.supplyIndex, nil)
            self.owner.consumableCatalog:Refresh()
            self:SetStatus(GetString(SI_GRAVVY_BUILD_PLANNER_SUPPLY_REMOVED))
            self:Refresh(true)
        end
        return
    end
    if self.activeView == "checklist" then
        local data = self:GetTargetData()
        if data and data.checklistIndex then
            local setup, build = self.owner.data:GetCurrentSetup()
            local ok, message = self.owner.data:SetChecklistEntry(
                build.id,
                setup.id,
                data.checklistIndex,
                nil
            )
            self:SetStatus(ok
                and GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_REMOVED)
                or message, not ok)
            self:Refresh(true)
        end
        return
    end
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
    if self.activeView == "skills" then
        local data = self:GetTargetData()
        local setup = self.owner.data:GetCurrentSetup()
        local skill = data and setup.skillBars and setup.skillBars[data.skillBar]
            and setup.skillBars[data.skillBar][data.skillSlot]
        if skill and GAMEPAD_TOOLTIPS and GAMEPAD_TOOLTIPS.LayoutSimpleAbility then
            GAMEPAD_TOOLTIPS:LayoutSimpleAbility(GAMEPAD_LEFT_TOOLTIP, skill.abilityId)
        end
        return
    end
    if self.activeView == "character" then
        return
    end
    if self.activeView == "champion" then
        local data = self:GetTargetData()
        local entry = data and data.championSkillId
            and self.owner.championCatalog:FindById(data.championSkillId)
        if entry and entry.skillData and GAMEPAD_TOOLTIPS.LayoutChampionSkill then
            GAMEPAD_TOOLTIPS:LayoutChampionSkill(GAMEPAD_LEFT_TOOLTIP, entry.skillData)
        end
        return
    end
    if self.activeView == "supplies" then
        local data = self:GetTargetData()
        if data and data.itemLink and GAMEPAD_TOOLTIPS then
            GAMEPAD_TOOLTIPS:LayoutItemLink(GAMEPAD_LEFT_TOOLTIP, data.itemLink)
        end
        return
    end
    if self.activeView == "checklist" then
        local data = self:GetTargetData()
        if data and data.abilityId and GAMEPAD_TOOLTIPS then
            GAMEPAD_TOOLTIPS:LayoutSimpleAbility(GAMEPAD_LEFT_TOOLTIP, data.abilityId)
        end
        return
    end
    if self.activeView == "comparison" then
        return
    end
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
