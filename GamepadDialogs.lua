local Gamepad = GravvyBuildPlannerGamepad
local Slots = GravvyBuildPlannerSlots
local Enchantments = GravvyBuildPlannerEnchantments

local EDIT_DIALOG = "GRAVVY_BUILD_PLANNER_GAMEPAD_EDIT"
local MANAGE_DIALOG = "GRAVVY_BUILD_PLANNER_GAMEPAD_MANAGE"
local NAME_DIALOG = "GRAVVY_BUILD_PLANNER_GAMEPAD_NAME"
local CONFIRM_DIALOG = "GRAVVY_BUILD_PLANNER_GAMEPAD_CONFIRM"
local EXPORT_DIALOG = "GRAVVY_BUILD_PLANNER_GAMEPAD_EXPORT"
local CODE_DIALOG = "GRAVVY_BUILD_PLANNER_GAMEPAD_CODE"
local HELP_DIALOG = "GRAVVY_BUILD_PLANNER_GAMEPAD_HELP"
local TRANSFER_DIALOG = "GRAVVY_BUILD_PLANNER_GAMEPAD_TRANSFER"
local SHARE_DIALOG = "GRAVVY_BUILD_PLANNER_GAMEPAD_SHARE"
local SKILL_DIALOG = "GRAVVY_BUILD_PLANNER_GAMEPAD_SKILL"
local CHARACTER_DIALOG = "GRAVVY_BUILD_PLANNER_GAMEPAD_CHARACTER"
local CHAMPION_DIALOG = "GRAVVY_BUILD_PLANNER_GAMEPAD_CHAMPION"
local SUPPLY_DIALOG = "GRAVVY_BUILD_PLANNER_GAMEPAD_SUPPLY"
local CHECKLIST_DIALOG = "GRAVVY_BUILD_PLANNER_GAMEPAD_CHECKLIST"
local REVISION_DIALOG = "GRAVVY_BUILD_PLANNER_GAMEPAD_REVISION"
local STAT_IMPACT_DIALOG = "GRAVVY_BUILD_PLANNER_GAMEPAD_STAT_IMPACT"
local DEFAULT_VALUE = -1

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

local function slotName(slotKey)
    return GetString(slotStringIds[slotKey])
end

local function showError(message)
    ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, message)
end

local function releaseAndOpen(dialogName, callback)
    ZO_Dialogs_ReleaseDialogOnButtonPress(dialogName)
    zo_callLater(callback, 10)
end

local function setupTextField(control, data, selected, options)
    local edit = control.editBoxControl
    control.highlight:SetHidden(not selected)
    edit:SetDefaultText(options.defaultText or "")
    edit:SetMaxInputChars(options.maxChars)
    edit:SetNewLineEnabled(options.multiline == true)
    edit:SetSelectAllOnFocus(true)
    edit:SetTextType(options.numeric and TEXT_TYPE_NUMERIC or TEXT_TYPE_ALL)
    edit:SetText(options.value() or "")
    edit.textChangedCallback = function(editBox)
        options.changed(editBox:GetText())
    end
    data.control = control
end

local function focusTextField(dialog)
    local data = dialog.entryList:GetTargetData()
    if data and data.control then
        data.control.editBoxControl:TakeFocus()
    end
end

local function textFieldEntry(header, options)
    return {
        template = options.multiline
            and "ZO_Gamepad_GenericDialog_TextFieldItem_Multiline_Large"
            or "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",
        header = header,
        templateData = {
            setup = function(control, data, selected)
                setupTextField(control, data, selected, options)
            end,
            callback = focusTextField,
            narrationText = ZO_GetDefaultParametricListEditBoxNarrationText,
        },
    }
end

local function dropdownEntry(header, choices, value, changed)
    local label = GetString(header)
    return {
        template = "ZO_GamepadDropdownItem",
        header = header,
        text = label,
        templateData = {
            setup = function(control, data, selected)
                local dropdown = control.dropdown
                dropdown:SetName(label)
                dropdown:SetSortsItems(false)
                dropdown:SetSelectedItemTextColor(selected)
                dropdown:ClearItems()
                local available = type(choices) == "function" and choices() or choices
                local selectedValue = value()
                local firstEntry
                local selectedEntry
                for _, choice in ipairs(available) do
                    local choiceValue = choice.value
                    local entry = dropdown:CreateItemEntry(choice.label, function()
                        changed(choiceValue)
                    end)
                    dropdown:AddItem(entry, ZO_COMBOBOX_SUPPRESS_UPDATE)
                    firstEntry = firstEntry or entry
                    if choiceValue == selectedValue then
                        selectedEntry = entry
                    end
                end
                dropdown:UpdateItems()
                dropdown:SelectItem(selectedEntry or firstEntry, true)
                SCREEN_NARRATION_MANAGER:RegisterDialogDropdown(data.dialog, dropdown)
            end,
            callback = function(dialog)
                local control = dialog.entryList:GetTargetControl()
                if control then
                    control.dropdown:Activate()
                end
            end,
            narrationText = function(_, control)
                return control.dropdown:GetNarrationText()
            end,
        },
    }
end

local function actionEntry(stringId, callback, enabled)
    return {
        template = "ZO_GamepadMenuEntryTemplate",
        text = stringId,
        templateData = {
            setup = ZO_SharedGamepadEntry_OnSetup,
            callback = callback,
            enabled = enabled,
        },
    }
end

local function selectDialogEntry(dialog)
    local data = dialog.entryList:GetTargetData()
    if data and data.callback then
        data.callback(dialog)
    end
end

local function cancelDialog(dialogName)
    return function()
        ZO_Dialogs_ReleaseDialogOnButtonPress(dialogName)
    end
end

local function addEnumChoice(choices, stringTable, value, prefix)
    if value == nil then
        return
    end
    local label = GetString(stringTable, value)
    if label and label ~= "" then
        choices[#choices + 1] = {
            label = prefix and (prefix .. ": " .. label) or label,
            value = value,
        }
    end
end

local function typeChoices(slotKey)
    local definition = Slots:Get(slotKey)
    local choices = {
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_ANY_TYPE), value = 0 },
    }
    if definition.family == "armor" then
        addEnumChoice(choices, "SI_ARMORTYPE", ARMORTYPE_LIGHT)
        addEnumChoice(choices, "SI_ARMORTYPE", ARMORTYPE_MEDIUM)
        addEnumChoice(choices, "SI_ARMORTYPE", ARMORTYPE_HEAVY)
    elseif definition.family == "weapon" then
        for _, weaponType in ipairs({
            WEAPONTYPE_AXE,
            WEAPONTYPE_HAMMER,
            WEAPONTYPE_SWORD,
            WEAPONTYPE_DAGGER,
            WEAPONTYPE_SHIELD,
            WEAPONTYPE_TWO_HANDED_AXE,
            WEAPONTYPE_TWO_HANDED_HAMMER,
            WEAPONTYPE_TWO_HANDED_SWORD,
            WEAPONTYPE_BOW,
            WEAPONTYPE_FIRE_STAFF,
            WEAPONTYPE_FROST_STAFF,
            WEAPONTYPE_LIGHTNING_STAFF,
            WEAPONTYPE_HEALING_STAFF,
        }) do
            if Slots:IsRequirementCompatible(slotKey, { weaponType = weaponType }) then
                addEnumChoice(choices, "SI_WEAPONTYPE", weaponType)
            end
        end
    end
    return choices
end

local function traitChoices(slotKey)
    local definition = Slots:Get(slotKey)
    local families = definition.family == "weapon"
        and { "weapon", "armor" }
        or { definition.family }
    local choices = {
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_ANY_TRAIT), value = ITEM_TRAIT_TYPE_NONE },
    }
    local seen = {}
    for _, family in ipairs(families) do
        local category = family == "armor" and ITEM_TRAIT_TYPE_CATEGORY_ARMOR
            or family == "weapon" and ITEM_TRAIT_TYPE_CATEGORY_WEAPON
            or ITEM_TRAIT_TYPE_CATEGORY_JEWELRY
        local prefix = #families > 1 and GetString(family == "armor"
            and SI_GRAVVY_BUILD_PLANNER_GAMEPAD_ARMOR
            or SI_GRAVVY_BUILD_PLANNER_GAMEPAD_WEAPON)
        for traitType = ITEM_TRAIT_TYPE_ITERATION_BEGIN or 1,
            ITEM_TRAIT_TYPE_ITERATION_END or 64 do
            if traitType ~= ITEM_TRAIT_TYPE_NONE
                and not seen[traitType]
                and GetItemTraitTypeCategory(traitType) == category then
                addEnumChoice(choices, "SI_ITEMTRAITTYPE", traitType, prefix)
                seen[traitType] = true
            end
        end
    end
    table.sort(choices, function(left, right)
        if left.value == ITEM_TRAIT_TYPE_NONE then
            return true
        elseif right.value == ITEM_TRAIT_TYPE_NONE then
            return false
        end
        return left.label < right.label
    end)
    return choices
end

local function enchantmentChoices(slotKey, customName)
    local definition = Slots:Get(slotKey)
    local families = definition.family == "weapon"
        and { "weapon", "armor" }
        or { definition.family }
    local choices = {}
    local seen = {}
    for _, family in ipairs(families) do
        local prefix = #families > 1 and GetString(family == "armor"
            and SI_GRAVVY_BUILD_PLANNER_GAMEPAD_ARMOR
            or SI_GRAVVY_BUILD_PLANNER_GAMEPAD_WEAPON)
        for _, choice in ipairs(Enchantments:GetChoices(family, customName)) do
            if not seen[choice.value] then
                choices[#choices + 1] = {
                    label = prefix and choice.value >= 0
                        and (prefix .. ": " .. choice.label)
                        or choice.label,
                    value = choice.value,
                }
                seen[choice.value] = true
            end
        end
    end
    return choices
end

local function qualityChoices()
    local choices = {
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_DEFAULT), value = DEFAULT_VALUE },
    }
    for _, quality in ipairs({
        ITEM_QUALITY_NORMAL,
        ITEM_QUALITY_MAGIC,
        ITEM_QUALITY_ARCANE,
        ITEM_QUALITY_ARTIFACT,
        ITEM_QUALITY_LEGENDARY,
    }) do
        addEnumChoice(choices, "SI_ITEMQUALITY", quality)
    end
    return choices
end

local function raceChoices()
    local choices = {
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_NOT_PLANNED), value = 0 },
    }
    if GetRaceName then
        for raceId = 1, 10 do
            local name = GetRaceName(GENDER_MALE or 1, raceId)
            if name and name ~= "" then
                choices[#choices + 1] = { label = name, value = raceId }
            end
        end
    end
    return choices
end

local function mundusChoices()
    local choices = {
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_NOT_PLANNED), value = 0 },
    }
    for mundus = 1, 13 do
        local name = GetString("SI_MUNDUSSTONE", mundus)
        if name and name ~= "" then
            choices[#choices + 1] = { label = name, value = mundus }
        end
    end
    return choices
end

local function curseChoices()
    return {
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_CURSE_NONE), value = 0 },
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_CURSE_VAMPIRE), value = 1 },
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_CURSE_WEREWOLF), value = 2 },
    }
end

local function supplyCategoryChoices()
    return {
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_SUPPLY_FOOD), value = "food" },
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_SUPPLY_DRINK), value = "drink" },
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_SUPPLY_POTION), value = "potion" },
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_SUPPLY_POISON), value = "poison" },
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_SUPPLY_OTHER), value = "other" },
    }
end

local function checklistCategoryChoices()
    return {
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_PASSIVE), value = "passive" },
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_SKILL_LINE), value = "skillLine" },
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_UNLOCK), value = "unlock" },
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_OTHER), value = "other" },
    }
end

local function checklistStatusChoices()
    return {
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_INCOMPLETE), value = false },
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_COMPLETE), value = true },
    }
end

local function familyForPending(slotKey, pending)
    local family = Slots:Get(slotKey).family
    if family == "weapon" and pending.weaponType == WEAPONTYPE_SHIELD then
        return "armor"
    end
    return family
end

local function valueIsInChoices(value, choices)
    for _, choice in ipairs(choices) do
        if choice.value == value then
            return true
        end
    end
    return false
end

function Gamepad:InitializeDialogs()
    self:InitializeEditDialog()
    self:InitializeManageDialog()
    self:InitializeStatImpactDialog()
    self:InitializeRevisionDialog()
    self:InitializeNameDialog()
    self:InitializeConfirmDialog()
    self:InitializeExportDialog()
    self:InitializeCodeDialog()
    self:InitializeHelpDialog()
    self:InitializeTransferDialog()
    self:InitializeShareDialog()
    self:InitializeSkillDialog()
    self:InitializeCharacterDialog()
    self:InitializeChampionDialog()
    self:InitializeSupplyDialog()
    self:InitializeChecklistDialog()
end

function Gamepad:InitializeEditDialog()
    ZO_Dialogs_RegisterCustomDialog(EDIT_DIALOG, {
        blockDialogReleaseOnPress = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        setup = function(dialog)
            self.editDialog = dialog
            if not self.pendingSlot then
                self:LoadPendingRequirement(self.pendingAlternativeIndex)
            end
            dialog:setupFunc()
        end,
        title = { text = SI_GRAVVY_BUILD_PLANNER_GAMEPAD_EDIT_TITLE },
        parametricList = {
            dropdownEntry(
                SI_GRAVVY_BUILD_PLANNER_REQUIREMENT,
                function() return self:GetPendingAlternativeChoices() end,
                function() return self.pendingAlternativeIndex or 0 end,
                function(value) self:SelectPendingAlternative(value) end
            ),
            textFieldEntry(SI_GRAVVY_BUILD_PLANNER_SET, {
                value = function() return self.pendingRequirement.setName end,
                changed = function(value) self.pendingRequirement.setName = value end,
                defaultText = GetString(SI_GRAVVY_BUILD_PLANNER_SET),
                maxChars = 100,
            }),
            dropdownEntry(
                SI_GRAVVY_BUILD_PLANNER_TYPE,
                function() return typeChoices(self.pendingSlot) end,
                function()
                    return self.pendingRequirement.armorType
                        or self.pendingRequirement.weaponType
                        or 0
                end,
                function(value)
                    local family = Slots:Get(self.pendingSlot).family
                    self.pendingRequirement.armorType = family == "armor" and value or nil
                    self.pendingRequirement.weaponType = family == "weapon" and value or nil
                end
            ),
            dropdownEntry(
                SI_GRAVVY_BUILD_PLANNER_TRAIT,
                function() return traitChoices(self.pendingSlot) end,
                function() return self.pendingRequirement.traitType or ITEM_TRAIT_TYPE_NONE end,
                function(value) self.pendingRequirement.traitType = value end
            ),
            dropdownEntry(
                SI_GRAVVY_BUILD_PLANNER_ENCHANTMENT,
                function()
                    return enchantmentChoices(
                        self.pendingSlot,
                        self.pendingRequirement.legacyEnchantmentName
                    )
                end,
                function()
                    return self.pendingRequirement.enchantmentCategory
                        or (self.pendingRequirement.legacyEnchantmentName
                            and Enchantments.CUSTOM)
                        or Enchantments.DEFAULT
                end,
                function(value) self.pendingRequirement.enchantmentCategory = value end
            ),
            dropdownEntry(
                SI_GRAVVY_BUILD_PLANNER_QUALITY,
                qualityChoices(),
                function() return self.pendingRequirement.quality or DEFAULT_VALUE end,
                function(value) self.pendingRequirement.quality = value end
            ),
            textFieldEntry(SI_GRAVVY_BUILD_PLANNER_LEVEL, {
                value = function() return self.pendingRequirement.level end,
                changed = function(value) self.pendingRequirement.level = value end,
                defaultText = GetString(SI_GRAVVY_BUILD_PLANNER_LEVEL),
                maxChars = 3,
                numeric = true,
            }),
            textFieldEntry(SI_GRAVVY_BUILD_PLANNER_CHAMPION_POINTS, {
                value = function() return self.pendingRequirement.championPoints end,
                changed = function(value) self.pendingRequirement.championPoints = value end,
                defaultText = GetString(SI_GRAVVY_BUILD_PLANNER_CHAMPION_POINTS),
                maxChars = 4,
                numeric = true,
            }),
            textFieldEntry(SI_GRAVVY_BUILD_PLANNER_NOTES, {
                value = function() return self.pendingRequirement.note end,
                changed = function(value) self.pendingRequirement.note = value end,
                defaultText = GetString(SI_GRAVVY_BUILD_PLANNER_NOTES),
                maxChars = 4000,
                multiline = true,
            }),
            actionEntry(
                SI_GRAVVY_BUILD_PLANNER_COPY_MOVE,
                function()
                    releaseAndOpen(EDIT_DIALOG, function()
                        self:ShowTransferDialog()
                    end)
                end,
                function()
                    local setup = self.owner.data:GetCurrentSetup()
                    return setup.equipment[self.pendingSlot] ~= nil
                        and self.pendingAlternativeIndex == nil
                end
            ),
            actionEntry(
                SI_GRAVVY_BUILD_PLANNER_SET_WIDE,
                function() self:ApplyPendingSetAlternative() end,
                function()
                    local setup = self.owner.data:GetCurrentSetup()
                    return self.pendingAlternativeIndex ~= nil
                        and self.owner.data:GetAlternatives(
                            setup,
                            self.pendingSlot
                        )[self.pendingAlternativeIndex] ~= nil
                end
            ),
            actionEntry(
                SI_GRAVVY_BUILD_PLANNER_REMOVE_ALTERNATIVE,
                function() self:RemovePendingAlternative() end,
                function()
                    local setup = self.owner.data:GetCurrentSetup()
                    return self.pendingAlternativeIndex ~= nil
                        and self.owner.data:GetAlternatives(
                            setup,
                            self.pendingSlot
                        )[self.pendingAlternativeIndex] ~= nil
                end
            ),
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = selectDialogEntry,
            },
            {
                keybind = "DIALOG_SECONDARY",
                text = SI_GRAVVY_BUILD_PLANNER_SAVE,
                callback = function()
                    local ok, message = self:SavePendingRequirement()
                    if not ok then
                        showError(message)
                        return
                    end
                    ZO_Dialogs_ReleaseDialogOnButtonPress(EDIT_DIALOG)
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback = cancelDialog(EDIT_DIALOG),
            },
        },
    })
end

function Gamepad:GetPendingAlternativeChoices()
    local setup = self.owner.data:GetCurrentSetup()
    local alternatives = self.owner.data:GetAlternatives(setup, self.pendingSlot)
    local choices = {
        { label = GetString(SI_GRAVVY_BUILD_PLANNER_PRIMARY), value = 0 },
    }
    for index = 1, #alternatives do
        choices[#choices + 1] = {
            label = zo_strformat(SI_GRAVVY_BUILD_PLANNER_ALTERNATIVE, index),
            value = index,
        }
    end
    if setup.equipment[self.pendingSlot] and #alternatives < 8 then
        choices[#choices + 1] = {
            label = GetString(SI_GRAVVY_BUILD_PLANNER_NEW_ALTERNATIVE),
            value = #alternatives + 1,
        }
    end
    return choices
end

function Gamepad:SelectPendingAlternative(value)
    self:LoadPendingRequirement(value ~= 0 and value or nil)
    if self.editDialog then
        self.editDialog:setupFunc()
    end
end

function Gamepad:LoadPendingRequirement(alternativeIndex)
    self.pendingSlot = self.pendingSlot or self:GetTargetSlot()
    local setup = self.owner.data:GetCurrentSetup()
    local alternatives = self.owner.data:GetAlternatives(setup, self.pendingSlot)
    self.pendingAlternativeIndex = alternativeIndex
    local saved = alternativeIndex
        and (alternatives[alternativeIndex] or setup.equipment[self.pendingSlot])
        or setup.equipment[self.pendingSlot]
        or {}
    self.pendingRequirement = {
        setName = saved.setName or "",
        setId = saved.setId,
        armorType = saved.armorType,
        weaponType = saved.weaponType,
        traitType = saved.traitType or ITEM_TRAIT_TYPE_NONE,
        enchantmentCategory = saved.enchantmentCategory,
        legacyEnchantmentName = not saved.enchantmentCategory and saved.enchantmentName or nil,
        quality = saved.quality,
        level = saved.level and tostring(saved.level) or "",
        championPoints = saved.championPoints and tostring(saved.championPoints) or "",
        note = saved.note or "",
    }
end

function Gamepad:SavePendingRequirement()
    local pending = self.pendingRequirement
    local setup, build = self.owner.data:GetCurrentSetup()
    local setName = zo_strtrim(pending.setName or "")
    local requirement = {
        setName = setName,
        note = pending.note or "",
    }
    local exactSet = self.owner.setCatalog:FindExact(setName)
    if exactSet then
        requirement.setId = exactSet.setId
        requirement.setName = exactSet.name
    end

    local definition = Slots:Get(self.pendingSlot)
    if definition.family == "armor" and pending.armorType and pending.armorType ~= 0 then
        requirement.armorType = pending.armorType
        if requirement.setId then
            local available = self.owner.itemResolver:GetAvailableArmorTypes(
                self.pendingSlot,
                requirement.setId
            )
            if #available == 1 then
                requirement.armorType = available[1]
            elseif #available > 1 and not valueIsInChoices(
                requirement.armorType,
                (function()
                    local choices = {}
                    for _, armorType in ipairs(available) do
                        choices[#choices + 1] = { value = armorType }
                    end
                    return choices
                end)()
            ) then
                requirement.armorType = available[1]
            end
        end
    elseif definition.family == "weapon"
        and pending.weaponType and pending.weaponType ~= 0 then
        requirement.weaponType = pending.weaponType
    end

    local editorFamily = familyForPending(self.pendingSlot, requirement)
    local wantedTraitCategory = editorFamily == "armor" and ITEM_TRAIT_TYPE_CATEGORY_ARMOR
        or editorFamily == "weapon" and ITEM_TRAIT_TYPE_CATEGORY_WEAPON
        or ITEM_TRAIT_TYPE_CATEGORY_JEWELRY
    if pending.traitType
        and pending.traitType ~= ITEM_TRAIT_TYPE_NONE
        and GetItemTraitTypeCategory(pending.traitType) == wantedTraitCategory then
        requirement.traitType = pending.traitType
    end

    local enchantment = pending.enchantmentCategory
    if enchantment == Enchantments.CUSTOM then
        requirement.enchantmentName = pending.legacyEnchantmentName
    elseif enchantment and enchantment ~= Enchantments.DEFAULT
        and valueIsInChoices(enchantment, Enchantments:GetChoices(editorFamily)) then
        requirement.enchantmentCategory = enchantment
        requirement.enchantmentName = Enchantments:GetName(enchantment)
    end
    if pending.quality and pending.quality ~= DEFAULT_VALUE then
        requirement.quality = pending.quality
    end
    if zo_strtrim(pending.level or "") ~= "" then
        requirement.level = zo_clamp(math.floor(tonumber(pending.level) or 1), 1, 50)
    end
    if zo_strtrim(pending.championPoints or "") ~= "" then
        local gearCap = GetChampionPointsPlayerProgressionCap
            and GetChampionPointsPlayerProgressionCap()
            or 160
        requirement.championPoints = zo_clamp(
            math.floor((tonumber(pending.championPoints) or 0) / 10) * 10,
            0,
            gearCap
        )
    end

    local resolved = self.owner.itemResolver:Resolve(self.pendingSlot, requirement, setup)
    if resolved then
        requirement.itemLink = resolved.itemLink
        requirement.itemId = resolved.itemId
        requirement.itemName = resolved.itemName
        if resolved.enchantmentMatches and requirement.enchantmentCategory then
            requirement.enchantmentId = resolved.enchantmentId
        end
    end
    local ok, result
    if self.pendingAlternativeIndex then
        ok, result = self.owner.data:SetAlternative(
            build.id,
            setup.id,
            self.pendingSlot,
            self.pendingAlternativeIndex,
            requirement
        )
    else
        ok, result = self.owner.data:SetEquipment(
            build.id,
            setup.id,
            self.pendingSlot,
            requirement
        )
    end
    if not ok then
        return false, result
    end
    self.owner.setCatalog:Refresh()
    self.owner.inventory:Refresh()
    self:SetStatus(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_SLOT_SAVED,
        slotName(self.pendingSlot)
    ))
    self:Refresh(true)
    return true
end

function Gamepad:ShowEditDialog()
    if self.activeView == "skills" then
        self:ShowSkillDialog()
        return
    elseif self.activeView == "character" then
        ZO_Dialogs_ShowGamepadDialog(CHARACTER_DIALOG)
        return
    elseif self.activeView == "champion" then
        ZO_Dialogs_ShowGamepadDialog(CHAMPION_DIALOG)
        return
    elseif self.activeView == "supplies" then
        ZO_Dialogs_ShowGamepadDialog(SUPPLY_DIALOG)
        return
    elseif self.activeView == "checklist" then
        ZO_Dialogs_ShowGamepadDialog(CHECKLIST_DIALOG)
        return
    elseif self.activeView == "comparison" then
        return
    end
    if self:IsTargetEditable() then
        self.pendingSlot = nil
        self.pendingAlternativeIndex = nil
        ZO_Dialogs_ShowGamepadDialog(EDIT_DIALOG)
    end
end

function Gamepad:InitializeChecklistDialog()
    ZO_Dialogs_RegisterCustomDialog(CHECKLIST_DIALOG, {
        blockDialogReleaseOnPress = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        setup = function(dialog)
            local data = self:GetTargetData()
            local setup = self.owner.data:GetCurrentSetup()
            local item = data and data.checklistIndex and setup.checklist[data.checklistIndex]
            self.pendingChecklist = {
                index = data and data.checklistIndex,
                category = item and item.category or "passive",
                name = item and item.name or "",
                targetRank = item and item.targetRank and tostring(item.targetRank) or "",
                completed = item and item.completed or false,
                note = item and item.note or "",
            }
            dialog:setupFunc()
        end,
        title = { text = SI_GRAVVY_BUILD_PLANNER_CHECKLIST },
        parametricList = {
            dropdownEntry(
                SI_GRAVVY_BUILD_PLANNER_CHECKLIST_CATEGORY,
                checklistCategoryChoices,
                function() return self.pendingChecklist.category end,
                function(value) self.pendingChecklist.category = value end
            ),
            textFieldEntry(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_NAME, {
                value = function() return self.pendingChecklist.name end,
                changed = function(value) self.pendingChecklist.name = value end,
                defaultText = GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_NAME),
                maxChars = 100,
            }),
            textFieldEntry(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_TARGET_RANK, {
                value = function() return self.pendingChecklist.targetRank end,
                changed = function(value) self.pendingChecklist.targetRank = value end,
                defaultText = GetString(SI_GRAVVY_BUILD_PLANNER_CHECKLIST_TARGET_RANK),
                maxChars = 2,
                numeric = true,
            }),
            dropdownEntry(
                SI_GRAVVY_BUILD_PLANNER_CHECKLIST_STATUS,
                checklistStatusChoices,
                function() return self.pendingChecklist.completed end,
                function(value) self.pendingChecklist.completed = value end
            ),
            textFieldEntry(SI_GRAVVY_BUILD_PLANNER_NOTES, {
                value = function() return self.pendingChecklist.note end,
                changed = function(value) self.pendingChecklist.note = value end,
                defaultText = GetString(SI_GRAVVY_BUILD_PLANNER_NOTES),
                maxChars = 4000,
                multiline = true,
            }),
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = selectDialogEntry,
            },
            {
                keybind = "DIALOG_SECONDARY",
                text = SI_GRAVVY_BUILD_PLANNER_CHECKLIST_SAVE,
                callback = function()
                    local ok, message = self:SavePendingChecklist()
                    if not ok then
                        showError(message)
                        return
                    end
                    ZO_Dialogs_ReleaseDialogOnButtonPress(CHECKLIST_DIALOG)
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback = cancelDialog(CHECKLIST_DIALOG),
            },
        },
    })
end

function Gamepad:SavePendingChecklist()
    local pending = self.pendingChecklist
    local name = zo_strtrim(pending.name or "")
    local rankText = zo_strtrim(pending.targetRank or "")
    local rank = rankText ~= "" and tonumber(rankText) or nil
    local passive = pending.category == "passive"
        and self.owner.skillCatalog:FindPassiveExact(name)
        or nil
    if name == "" or (rankText ~= "" and (not rank or rank ~= math.floor(rank)
        or rank < 1 or rank > 50)) or (passive and rank and rank > passive.maxRank) then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CHECKLIST)
    end
    local progression = passive and rank
        and self.owner.skillCatalog:GetPassiveProgression(passive, rank)
        or nil
    local setup, build = self.owner.data:GetCurrentSetup()
    local ok, result = self.owner.data:SetChecklistEntry(
        build.id,
        setup.id,
        pending.index,
        {
            category = pending.category,
            name = passive and passive.name or name,
            targetRank = rank,
            completed = pending.completed == true,
            abilityId = progression and progression.abilityId
                or passive and passive.abilityId,
            icon = progression and progression.icon or passive and passive.icon or "",
            note = pending.note or "",
        }
    )
    if not ok then
        return false, result
    end
    self:SetStatus(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_CHECKLIST_SAVED,
        passive and passive.name or name
    ))
    self:Refresh(true)
    return true
end

function Gamepad:InitializeSupplyDialog()
    ZO_Dialogs_RegisterCustomDialog(SUPPLY_DIALOG, {
        blockDialogReleaseOnPress = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        setup = function(dialog)
            local data = self:GetTargetData()
            local setup = self.owner.data:GetCurrentSetup()
            local supply = data and data.supplyIndex and setup.consumables[data.supplyIndex]
            self.pendingSupply = {
                index = data and data.supplyIndex,
                category = supply and supply.category or "food",
                name = supply and supply.name or "",
                quantity = supply and tostring(supply.quantity) or "1",
                note = supply and supply.note or "",
            }
            dialog:setupFunc()
        end,
        title = { text = SI_GRAVVY_BUILD_PLANNER_SUPPLIES },
        parametricList = {
            dropdownEntry(
                SI_GRAVVY_BUILD_PLANNER_SUPPLY_CATEGORY,
                supplyCategoryChoices,
                function() return self.pendingSupply.category end,
                function(value) self.pendingSupply.category = value end
            ),
            textFieldEntry(SI_GRAVVY_BUILD_PLANNER_SUPPLY_NAME, {
                value = function() return self.pendingSupply.name end,
                changed = function(value) self.pendingSupply.name = value end,
                defaultText = GetString(SI_GRAVVY_BUILD_PLANNER_SUPPLY_NAME),
                maxChars = 2048,
            }),
            textFieldEntry(SI_GRAVVY_BUILD_PLANNER_SUPPLY_QUANTITY, {
                value = function() return self.pendingSupply.quantity end,
                changed = function(value) self.pendingSupply.quantity = value end,
                defaultText = "1",
                maxChars = 4,
                numeric = true,
            }),
            textFieldEntry(SI_GRAVVY_BUILD_PLANNER_NOTES, {
                value = function() return self.pendingSupply.note end,
                changed = function(value) self.pendingSupply.note = value end,
                defaultText = GetString(SI_GRAVVY_BUILD_PLANNER_NOTES),
                maxChars = 4000,
                multiline = true,
            }),
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = selectDialogEntry,
            },
            {
                keybind = "DIALOG_SECONDARY",
                text = SI_GRAVVY_BUILD_PLANNER_SUPPLY_SAVE,
                callback = function()
                    local ok, message = self:SavePendingSupply()
                    if not ok then
                        showError(message)
                        return
                    end
                    ZO_Dialogs_ReleaseDialogOnButtonPress(SUPPLY_DIALOG)
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback = cancelDialog(SUPPLY_DIALOG),
            },
        },
    })
end

function Gamepad:SavePendingSupply()
    local pending = self.pendingSupply
    local typedName = zo_strtrim(pending.name or "")
    local quantity = tonumber(pending.quantity)
    if typedName == "" or not quantity or quantity ~= math.floor(quantity)
        or quantity < 1 or quantity > 9999 then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CONSUMABLE)
    end
    local catalogEntry = self.owner.consumableCatalog:FindExact(typedName, pending.category)
    local category = pending.category
    if string.find(typedName, "|H", 1, true) == 1 and GetItemLinkName then
        local itemLink = typedName
        local itemName = GetItemLinkName(itemLink)
        if itemName and itemName ~= "" then
            category = self.owner.consumableCatalog:GetCategory(itemLink) or category
            catalogEntry = {
                name = itemName,
                itemId = GetItemLinkItemId and GetItemLinkItemId(itemLink),
                itemLink = itemLink,
                icon = GetItemLinkIcon and GetItemLinkIcon(itemLink) or "",
            }
            typedName = itemName
        end
    end
    local setup, build = self.owner.data:GetCurrentSetup()
    local ok, result = self.owner.data:SetConsumable(
        build.id,
        setup.id,
        pending.index,
        {
            category = category,
            name = catalogEntry and catalogEntry.name or typedName,
            itemId = catalogEntry and catalogEntry.itemId,
            itemLink = catalogEntry and catalogEntry.itemLink,
            icon = catalogEntry and catalogEntry.icon or "",
            quantity = quantity,
            note = pending.note or "",
        }
    )
    if not ok then
        return false, result
    end
    self.owner.consumableCatalog:Refresh()
    self:SetStatus(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_SUPPLY_SAVED,
        catalogEntry and catalogEntry.name or typedName
    ))
    self:Refresh(true)
    return true
end

function Gamepad:InitializeChampionDialog()
    ZO_Dialogs_RegisterCustomDialog(CHAMPION_DIALOG, {
        blockDialogReleaseOnPress = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        setup = function(dialog)
            local data = self:GetTargetData()
            local setup = self.owner.data:GetCurrentSetup()
            local disciplineKey = data and data.championDiscipline or "warfare"
            local discipline = setup.champion[disciplineKey]
            local allocation
            for _, entry in ipairs(discipline.allocations) do
                if entry.skillId == (data and data.championSkillId) then
                    allocation = entry
                    break
                end
            end
            local slotIndex = 0
            if allocation then
                for index = 1, 4 do
                    if discipline.slottables[index] == allocation.skillId then
                        slotIndex = index
                        break
                    end
                end
            end
            self.pendingChampion = {
                discipline = disciplineKey,
                skillId = allocation and allocation.skillId,
                originalSkillId = allocation and allocation.skillId,
                points = allocation and tostring(allocation.points) or "",
                slotIndex = slotIndex,
            }
            dialog:setupFunc()
        end,
        title = { text = SI_GRAVVY_BUILD_PLANNER_CHAMPION },
        parametricList = {
            dropdownEntry(
                SI_GRAVVY_BUILD_PLANNER_CHAMPION_STAR,
                function()
                    local choices = {}
                    for _, entry in ipairs(
                        self.owner.championCatalog.byDiscipline[self.pendingChampion.discipline] or {}
                    ) do
                        choices[#choices + 1] = { label = entry.name, value = entry.skillId }
                    end
                    return choices
                end,
                function() return self.pendingChampion.skillId end,
                function(value)
                    self.pendingChampion.skillId = value
                    local entry = self.owner.championCatalog:FindById(value)
                    if entry and self.pendingChampion.points == "" then
                        self.pendingChampion.points = tostring(entry.maxPoints)
                    end
                    if entry and not entry.isSlottable then
                        self.pendingChampion.slotIndex = 0
                    end
                end
            ),
            textFieldEntry(SI_GRAVVY_BUILD_PLANNER_CHAMPION_POINTS, {
                value = function() return self.pendingChampion.points end,
                changed = function(value) self.pendingChampion.points = value end,
                defaultText = GetString(SI_GRAVVY_BUILD_PLANNER_CHAMPION_POINTS),
                maxChars = 4,
                numeric = true,
            }),
            dropdownEntry(
                SI_GRAVVY_BUILD_PLANNER_CHAMPION_SLOT,
                {
                    { label = GetString(SI_GRAVVY_BUILD_PLANNER_CHAMPION_NOT_SLOTTED), value = 0 },
                    { label = zo_strformat(SI_GRAVVY_BUILD_PLANNER_CHAMPION_SLOT_NUMBER, 1), value = 1 },
                    { label = zo_strformat(SI_GRAVVY_BUILD_PLANNER_CHAMPION_SLOT_NUMBER, 2), value = 2 },
                    { label = zo_strformat(SI_GRAVVY_BUILD_PLANNER_CHAMPION_SLOT_NUMBER, 3), value = 3 },
                    { label = zo_strformat(SI_GRAVVY_BUILD_PLANNER_CHAMPION_SLOT_NUMBER, 4), value = 4 },
                },
                function() return self.pendingChampion.slotIndex end,
                function(value) self.pendingChampion.slotIndex = value end
            ),
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = selectDialogEntry,
            },
            {
                keybind = "DIALOG_SECONDARY",
                text = SI_GRAVVY_BUILD_PLANNER_CHAMPION_SAVE,
                callback = function()
                    local ok, message = self:SavePendingChampion()
                    if not ok then
                        showError(message)
                        return
                    end
                    ZO_Dialogs_ReleaseDialogOnButtonPress(CHAMPION_DIALOG)
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback = cancelDialog(CHAMPION_DIALOG),
            },
        },
    })
end

function Gamepad:SavePendingChampion()
    local pending = self.pendingChampion
    local entry = self.owner.championCatalog:FindById(pending.skillId)
    local points = tonumber(pending.points)
    if not entry or entry.discipline ~= pending.discipline
        or not points or points ~= math.floor(points)
        or points < 1 or points > entry.maxPoints then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CHAMPION)
    end
    local setup, build = self.owner.data:GetCurrentSetup()
    local ok, message = self.owner.data:SetChampionAllocation(
        build.id,
        setup.id,
        pending.discipline,
        {
            skillId = entry.skillId,
            name = entry.name,
            icon = entry.icon,
            points = points,
            isSlottable = entry.isSlottable,
        }
    )
    if not ok then
        return false, message
    end
    if pending.originalSkillId and pending.originalSkillId ~= entry.skillId then
        self.owner.data:SetChampionAllocation(
            build.id,
            setup.id,
            pending.discipline,
            { skillId = pending.originalSkillId, remove = true }
        )
    end
    local discipline = setup.champion[pending.discipline]
    for slotIndex = 1, 4 do
        if discipline.slottables[slotIndex] == entry.skillId
            and slotIndex ~= pending.slotIndex then
            self.owner.data:SetChampionSlottable(
                build.id,
                setup.id,
                pending.discipline,
                slotIndex,
                nil
            )
        end
    end
    if entry.isSlottable and pending.slotIndex > 0 then
        ok, message = self.owner.data:SetChampionSlottable(
            build.id,
            setup.id,
            pending.discipline,
            pending.slotIndex,
            entry.skillId
        )
        if not ok then
            return false, message
        end
    end
    self:SetStatus(zo_strformat(SI_GRAVVY_BUILD_PLANNER_CHAMPION_SAVED, entry.name))
    self:Refresh(true)
    return true
end

function Gamepad:InitializeCharacterDialog()
    ZO_Dialogs_RegisterCustomDialog(CHARACTER_DIALOG, {
        blockDialogReleaseOnPress = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        setup = function(dialog)
            local setup = self.owner.data:GetCurrentSetup()
            local character = setup.character or {}
            local attributes = character.attributes or {}
            self.pendingCharacter = {
                health = tostring(attributes.health or 0),
                magicka = tostring(attributes.magicka or 0),
                stamina = tostring(attributes.stamina or 0),
                raceId = character.raceId or 0,
                mundus = character.mundus or 0,
                curse = character.curse or 0,
                subclassLines = {
                    character.subclassLines and character.subclassLines[1] or "",
                    character.subclassLines and character.subclassLines[2] or "",
                    character.subclassLines and character.subclassLines[3] or "",
                },
            }
            dialog:setupFunc()
        end,
        title = { text = SI_GRAVVY_BUILD_PLANNER_CHARACTER },
        parametricList = {
            textFieldEntry(SI_GRAVVY_BUILD_PLANNER_HEALTH, {
                value = function() return self.pendingCharacter.health end,
                changed = function(value) self.pendingCharacter.health = value end,
                defaultText = "0",
                maxChars = 2,
                numeric = true,
            }),
            textFieldEntry(SI_GRAVVY_BUILD_PLANNER_MAGICKA, {
                value = function() return self.pendingCharacter.magicka end,
                changed = function(value) self.pendingCharacter.magicka = value end,
                defaultText = "0",
                maxChars = 2,
                numeric = true,
            }),
            textFieldEntry(SI_GRAVVY_BUILD_PLANNER_STAMINA, {
                value = function() return self.pendingCharacter.stamina end,
                changed = function(value) self.pendingCharacter.stamina = value end,
                defaultText = "0",
                maxChars = 2,
                numeric = true,
            }),
            dropdownEntry(
                SI_GRAVVY_BUILD_PLANNER_RACE,
                raceChoices,
                function() return self.pendingCharacter.raceId end,
                function(value) self.pendingCharacter.raceId = value end
            ),
            dropdownEntry(
                SI_GRAVVY_BUILD_PLANNER_MUNDUS,
                mundusChoices,
                function() return self.pendingCharacter.mundus end,
                function(value) self.pendingCharacter.mundus = value end
            ),
            dropdownEntry(
                SI_GRAVVY_BUILD_PLANNER_CURSE,
                curseChoices,
                function() return self.pendingCharacter.curse end,
                function(value) self.pendingCharacter.curse = value end
            ),
            textFieldEntry(zo_strformat(SI_GRAVVY_BUILD_PLANNER_SUBCLASS_LINE, 1), {
                value = function() return self.pendingCharacter.subclassLines[1] end,
                changed = function(value) self.pendingCharacter.subclassLines[1] = value end,
                defaultText = zo_strformat(SI_GRAVVY_BUILD_PLANNER_SUBCLASS_LINE, 1),
                maxChars = 100,
            }),
            textFieldEntry(zo_strformat(SI_GRAVVY_BUILD_PLANNER_SUBCLASS_LINE, 2), {
                value = function() return self.pendingCharacter.subclassLines[2] end,
                changed = function(value) self.pendingCharacter.subclassLines[2] = value end,
                defaultText = zo_strformat(SI_GRAVVY_BUILD_PLANNER_SUBCLASS_LINE, 2),
                maxChars = 100,
            }),
            textFieldEntry(zo_strformat(SI_GRAVVY_BUILD_PLANNER_SUBCLASS_LINE, 3), {
                value = function() return self.pendingCharacter.subclassLines[3] end,
                changed = function(value) self.pendingCharacter.subclassLines[3] = value end,
                defaultText = zo_strformat(SI_GRAVVY_BUILD_PLANNER_SUBCLASS_LINE, 3),
                maxChars = 100,
            }),
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = selectDialogEntry,
            },
            {
                keybind = "DIALOG_SECONDARY",
                text = SI_GRAVVY_BUILD_PLANNER_SAVE_CHARACTER,
                callback = function()
                    local ok, message = self:SavePendingCharacter()
                    if not ok then
                        showError(message)
                        return
                    end
                    ZO_Dialogs_ReleaseDialogOnButtonPress(CHARACTER_DIALOG)
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback = cancelDialog(CHARACTER_DIALOG),
            },
        },
    })
end

function Gamepad:SavePendingCharacter()
    local pending = self.pendingCharacter
    local setup, build = self.owner.data:GetCurrentSetup()
    local ok, message = self.owner.data:UpdateCharacter(build.id, setup.id, {
        attributes = {
            health = tonumber(pending.health) or 0,
            magicka = tonumber(pending.magicka) or 0,
            stamina = tonumber(pending.stamina) or 0,
        },
        raceId = pending.raceId,
        mundus = pending.mundus,
        curse = pending.curse,
        subclassLines = pending.subclassLines,
    })
    if not ok then
        return false, message
    end
    self:SetStatus(GetString(SI_GRAVVY_BUILD_PLANNER_CHARACTER_SAVED))
    self:Refresh(true)
    return true
end

function Gamepad:InitializeSkillDialog()
    ZO_Dialogs_RegisterCustomDialog(SKILL_DIALOG, {
        blockDialogReleaseOnPress = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        setup = function(dialog)
            local data = self:GetTargetData()
            local setup = self.owner.data:GetCurrentSetup()
            local skill = data and setup.skillBars and setup.skillBars[data.skillBar]
                and setup.skillBars[data.skillBar][data.skillSlot]
            self.pendingSkillBar = data and data.skillBar
            self.pendingSkillSlot = data and data.skillSlot
            self.pendingAbilityId = skill and skill.abilityId
            dialog:setupFunc()
        end,
        title = { text = SI_GRAVVY_BUILD_PLANNER_SKILLS },
        parametricList = {
            dropdownEntry(
                SI_GRAVVY_BUILD_PLANNER_ABILITY,
                function()
                    local choices = {}
                    local ultimate = self.pendingSkillSlot == 6
                    for _, entry in ipairs(self.owner.skillCatalog.entries) do
                        if entry.isUltimate == ultimate then
                            choices[#choices + 1] = {
                                label = entry.name,
                                value = entry.abilityId,
                            }
                        end
                    end
                    return choices
                end,
                function() return self.pendingAbilityId end,
                function(value) self.pendingAbilityId = value end
            ),
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = selectDialogEntry,
            },
            {
                keybind = "DIALOG_SECONDARY",
                text = SI_GRAVVY_BUILD_PLANNER_SAVE_SKILL,
                callback = function()
                    local ok, message = self:SavePendingSkill()
                    if not ok then
                        showError(message)
                        return
                    end
                    ZO_Dialogs_ReleaseDialogOnButtonPress(SKILL_DIALOG)
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback = cancelDialog(SKILL_DIALOG),
            },
        },
    })
end

function Gamepad:ShowSkillDialog()
    ZO_Dialogs_ShowGamepadDialog(SKILL_DIALOG)
end

function Gamepad:SavePendingSkill()
    local skill = self.owner.skillCatalog:FindById(self.pendingAbilityId)
    if not skill then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SKILL)
    end
    local setup, build = self.owner.data:GetCurrentSetup()
    local ok, message = self.owner.data:SetSkill(
        build.id,
        setup.id,
        self.pendingSkillBar,
        self.pendingSkillSlot,
        skill
    )
    if not ok then
        return false, message
    end
    self:SetStatus(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_SKILL_SAVED,
        skill.name
    ))
    self:Refresh(true)
    return true
end

function Gamepad:RemovePendingAlternative()
    local setup, build = self.owner.data:GetCurrentSetup()
    local ok, message = self.owner.data:SetAlternative(
        build.id,
        setup.id,
        self.pendingSlot,
        self.pendingAlternativeIndex,
        nil
    )
    if not ok then
        showError(message)
        return
    end
    self.pendingAlternativeIndex = nil
    self.owner.inventory:Refresh()
    self:SetStatus(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_ALTERNATIVE_REMOVED,
        slotName(self.pendingSlot)
    ))
    ZO_Dialogs_ReleaseDialogOnButtonPress(EDIT_DIALOG)
end

function Gamepad:ApplyPendingSetAlternative()
    local ok, message = self:SavePendingRequirement()
    if not ok then
        showError(message)
        return
    end
    local setup, build = self.owner.data:GetCurrentSetup()
    ok, message = self.owner.data:ApplySetAlternative(
        build.id,
        setup.id,
        self.pendingSlot,
        self.pendingAlternativeIndex
    )
    if not ok then
        showError(message)
        return
    end
    self.owner.inventory:Refresh()
    self:SetStatus(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_SET_ALTERNATIVE_APPLIED,
        message
    ))
    ZO_Dialogs_ReleaseDialogOnButtonPress(EDIT_DIALOG)
end

function Gamepad:InitializeManageDialog()
    ZO_Dialogs_RegisterCustomDialog(MANAGE_DIALOG, {
        blockDialogReleaseOnPress = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        title = { text = SI_GRAVVY_BUILD_PLANNER_GAMEPAD_MANAGE_TITLE },
        mainText = { text = SI_GRAVVY_BUILD_PLANNER_GAMEPAD_MANAGE_HELP },
        parametricList = {
            actionEntry(SI_GRAVVY_BUILD_PLANNER_GAMEPAD_NEW_BUILD, function()
                self:OpenNameFromManage("newBuild")
            end),
            actionEntry(SI_GRAVVY_BUILD_PLANNER_CAPTURE, function()
                self:OpenCaptureFromManage()
            end),
            actionEntry(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT, function()
                releaseAndOpen(MANAGE_DIALOG, function() self:ShowStatImpactDialog() end)
            end),
            actionEntry(SI_GRAVVY_BUILD_PLANNER_REVISIONS, function()
                self:OpenRevisionsFromManage()
            end),
            actionEntry(SI_GRAVVY_BUILD_PLANNER_GAMEPAD_RENAME_BUILD, function()
                self:OpenNameFromManage("renameBuild")
            end),
            actionEntry(SI_GRAVVY_BUILD_PLANNER_GAMEPAD_DUPLICATE_BUILD, function()
                self:OpenNameFromManage("duplicateBuild")
            end),
            actionEntry(
                SI_GRAVVY_BUILD_PLANNER_GAMEPAD_DELETE_BUILD,
                function() self:OpenDeleteFromManage("build") end,
                function() return #self.owner.data:GetBuilds() > 1 end
            ),
            actionEntry(SI_GRAVVY_BUILD_PLANNER_GAMEPAD_NEW_SETUP, function()
                self:OpenNameFromManage("newSetup")
            end),
            actionEntry(SI_GRAVVY_BUILD_PLANNER_GAMEPAD_RENAME_SETUP, function()
                self:OpenNameFromManage("renameSetup")
            end),
            actionEntry(SI_GRAVVY_BUILD_PLANNER_GAMEPAD_DUPLICATE_SETUP, function()
                self:OpenNameFromManage("duplicateSetup")
            end),
            actionEntry(SI_GRAVVY_BUILD_PLANNER_GAMEPAD_MOVE_SETUP_UP, function()
                self:MoveSetupFromManage(-1)
            end, function()
                local setup, build = self.owner.data:GetCurrentSetup()
                local _, index = self.owner.data:FindSetup(build, setup.id)
                return index and index > 1
            end),
            actionEntry(SI_GRAVVY_BUILD_PLANNER_GAMEPAD_MOVE_SETUP_DOWN, function()
                self:MoveSetupFromManage(1)
            end, function()
                local setup, build = self.owner.data:GetCurrentSetup()
                local _, index = self.owner.data:FindSetup(build, setup.id)
                return index and index < #build.setups
            end),
            actionEntry(
                SI_GRAVVY_BUILD_PLANNER_GAMEPAD_DELETE_SETUP,
                function() self:OpenDeleteFromManage("setup") end,
                function()
                    local _, build = self.owner.data:GetCurrentSetup()
                    return #build.setups > 1
                end
            ),
            actionEntry(
                SI_GRAVVY_BUILD_PLANNER_UNDO,
                function() self:UndoFromManage() end,
                function() return self.owner.data:CanUndoDeletion() end
            ),
            actionEntry(SI_GRAVVY_BUILD_PLANNER_EXPORT, function()
                releaseAndOpen(MANAGE_DIALOG, function() self:ShowExportDialog() end)
            end),
            actionEntry(SI_GRAVVY_BUILD_PLANNER_SHARE, function()
                releaseAndOpen(MANAGE_DIALOG, function() self:ShowShareDialog() end)
            end),
            actionEntry(SI_GRAVVY_BUILD_PLANNER_HELP_TITLE, function()
                releaseAndOpen(MANAGE_DIALOG, function() self:ShowHelpDialog() end)
            end),
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = selectDialogEntry,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CLOSE,
                callback = cancelDialog(MANAGE_DIALOG),
            },
        },
    })
end

function Gamepad:ShowManageDialog()
    ZO_Dialogs_ShowGamepadDialog(MANAGE_DIALOG)
end

function Gamepad:OpenCaptureFromManage()
    self.pendingConfirmTitle = GetString(SI_GRAVVY_BUILD_PLANNER_CAPTURE)
    self.pendingConfirmText = GetString(SI_GRAVVY_BUILD_PLANNER_CONFIRM_CAPTURE)
    self.pendingConfirm = function()
        return self.owner.capture:Capture()
    end
    releaseAndOpen(MANAGE_DIALOG, function()
        ZO_Dialogs_ShowGamepadDialog(CONFIRM_DIALOG)
    end)
end

function Gamepad:GetStatImpactSetup()
    local build = self.owner.data:GetCurrentBuild()
    local setup = self.statImpactSetupId
        and self.owner.data:FindSetup(build, self.statImpactSetupId)
    if not setup then
        setup = self.owner.data:GetCurrentSetup()
        self.statImpactSetupId = setup.id
    end
    return setup, build
end

function Gamepad:GetStatImpactText()
    local setup = self:GetStatImpactSetup()
    local bar = self.statImpactBar == "back" and "back" or "front"
    local report = self.owner.statImpact:BuildReport(setup, bar)
    local snapshotValues = report.snapshot and report.snapshot.values or {}
    local comparable = not report.liveBar or report.liveBar == report.bar
    local lines = {
        GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_HELP),
        "",
        setup.name .. " · " .. GetString(bar == "back"
            and SI_GRAVVY_BUILD_PLANNER_BACK_BAR
            or SI_GRAVVY_BUILD_PLANNER_FRONT_BAR),
        "",
        GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_EXACT_TITLE),
    }
    for _, row in ipairs(self.owner.statImpact:GetStatRows()) do
        local liveValue = report.live[row.key]
        local snapshotValue = snapshotValues[row.key]
        lines[#lines + 1] = GetString(row.label)
            .. ": " .. self.owner.statImpact:FormatValue(row, liveValue)
            .. " → " .. self.owner.statImpact:FormatValue(row, snapshotValue)
            .. " (" .. (comparable
                and self.owner.statImpact:FormatChange(row, liveValue, snapshotValue)
                or "—") .. ")"
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_EFFECTS_TITLE)
    lines[#lines + 1] = zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_COVERAGE,
        report.resolved,
        report.planned,
        GetString(bar == "back"
            and SI_GRAVVY_BUILD_PLANNER_BACK_BAR
            or SI_GRAVVY_BUILD_PLANNER_FRONT_BAR)
    )
    for index = 1, math.min(6, #report.effects) do
        local effect = report.effects[index]
        lines[#lines + 1] = effect.label .. ": " .. effect.description
    end
    if #report.effects > 6 then
        lines[#lines + 1] = zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_MORE_EFFECTS,
            #report.effects - 6
        )
    elseif #report.effects == 0 then
        lines[#lines + 1] = GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_NO_EFFECTS)
    end
    return table.concat(lines, "\n")
end

function Gamepad:ShowStatImpactDialog(setupId)
    local build = self.owner.data:GetCurrentBuild()
    local setup = setupId and self.owner.data:FindSetup(build, setupId)
    if not setup and self.activeView == "comparison" then
        setup = self.comparisonSetupId
            and self.owner.data:FindSetup(build, self.comparisonSetupId)
    end
    setup = setup or self.owner.data:GetCurrentSetup()
    self.statImpactSetupId = setup.id
    self.statImpactBar = self.statImpactBar == "back" and "back" or "front"
    ZO_Dialogs_ShowGamepadDialog(STAT_IMPACT_DIALOG)
end

function Gamepad:ReopenStatImpactDialog()
    releaseAndOpen(STAT_IMPACT_DIALOG, function()
        ZO_Dialogs_ShowGamepadDialog(STAT_IMPACT_DIALOG)
    end)
end

function Gamepad:OpenStatImpactCapture()
    local setup, build = self:GetStatImpactSetup()
    local bar = self.statImpactBar
    local liveBar = self.owner.statImpact:GetLiveBar()
    if liveBar and liveBar ~= bar then
        showError(zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_SWITCH_TO_BAR,
            GetString(bar == "back"
                and SI_GRAVVY_BUILD_PLANNER_BACK_BAR
                or SI_GRAVVY_BUILD_PLANNER_FRONT_BAR)
        ))
        return
    end
    self.pendingConfirmTitle = GetString(SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CAPTURE_ACTION)
    self.pendingConfirmText = zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CONFIRM_CAPTURE,
        setup.name
    )
    self.pendingConfirm = function()
        local ok, message = self.owner.data:SetStatSnapshot(
            build.id,
            setup.id,
            bar,
            self.owner.statImpact:MakeSnapshot()
        )
        return ok, ok and zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CAPTURED,
            setup.name
        ) or message
    end
    releaseAndOpen(STAT_IMPACT_DIALOG, function()
        ZO_Dialogs_ShowGamepadDialog(CONFIRM_DIALOG)
    end)
end

function Gamepad:InitializeStatImpactDialog()
    ZO_Dialogs_RegisterCustomDialog(STAT_IMPACT_DIALOG, {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title = { text = SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_TITLE },
        mainText = { text = function() return self:GetStatImpactText() end },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_SWITCH_BAR,
                callback = function()
                    self.statImpactBar = self.statImpactBar == "back" and "front" or "back"
                    self:ReopenStatImpactDialog()
                end,
            },
            {
                keybind = "DIALOG_SECONDARY",
                text = SI_GRAVVY_BUILD_PLANNER_STAT_IMPACT_CAPTURE_ACTION,
                callback = function() self:OpenStatImpactCapture() end,
            },
            { keybind = "DIALOG_NEGATIVE", text = SI_DIALOG_CLOSE },
        },
    })
end

function Gamepad:GetRevisionChoices()
    local build = self.owner.data:GetCurrentBuild()
    local choices = {}
    for _, revision in ipairs(self.owner.data:GetRevisions(build.id)) do
        local patch = revision.patch ~= "" and (" - " .. revision.patch) or ""
        choices[#choices + 1] = {
            label = revision.name .. patch,
            value = revision.id,
        }
    end
    if #choices == 0 then
        choices[1] = {
            label = GetString(SI_GRAVVY_BUILD_PLANNER_REVISION_EMPTY),
            value = 0,
        }
    end
    return choices
end

function Gamepad:GetSelectedRevision()
    local build = self.owner.data:GetCurrentBuild()
    return self.owner.data:FindRevision(build, self.selectedRevisionId)
end

function Gamepad:InitializeRevisionDialog()
    ZO_Dialogs_RegisterCustomDialog(REVISION_DIALOG, {
        blockDialogReleaseOnPress = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        setup = function(dialog)
            local build = self.owner.data:GetCurrentBuild()
            local revisions = self.owner.data:GetRevisions(build.id)
            if not self.owner.data:FindRevision(build, self.selectedRevisionId) then
                self.selectedRevisionId = revisions[1] and revisions[1].id or 0
            end
            dialog:setupFunc()
        end,
        title = { text = SI_GRAVVY_BUILD_PLANNER_REVISION_TITLE },
        mainText = {
            text = function()
                local revision = self:GetSelectedRevision()
                if not revision then
                    return GetString(SI_GRAVVY_BUILD_PLANNER_REVISION_HELP)
                end
                return zo_strformat(
                    SI_GRAVVY_BUILD_PLANNER_REVISION_GAMEPAD_DETAIL,
                    revision.name,
                    revision.patch ~= "" and revision.patch
                        or GetString(SI_GRAVVY_BUILD_PLANNER_NOT_PLANNED),
                    #revision.snapshot.setups
                )
            end,
        },
        parametricList = {
            dropdownEntry(
                SI_GRAVVY_BUILD_PLANNER_REVISION_SELECT,
                function() return self:GetRevisionChoices() end,
                function() return self.selectedRevisionId end,
                function(value) self.selectedRevisionId = value end
            ),
            actionEntry(SI_GRAVVY_BUILD_PLANNER_REVISION_SAVE, function()
                self.pendingNameAction = "createRevision"
                self.pendingName = ""
                releaseAndOpen(REVISION_DIALOG, function()
                    ZO_Dialogs_ShowGamepadDialog(NAME_DIALOG)
                end)
            end),
            actionEntry(
                SI_GRAVVY_BUILD_PLANNER_REVISION_RESTORE,
                function() self:ConfirmGamepadRevisionRestore() end,
                function() return self:GetSelectedRevision() ~= nil end
            ),
            actionEntry(
                SI_GRAVVY_BUILD_PLANNER_REVISION_DELETE,
                function() self:ConfirmGamepadRevisionDelete() end,
                function() return self:GetSelectedRevision() ~= nil end
            ),
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = selectDialogEntry,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CLOSE,
                callback = cancelDialog(REVISION_DIALOG),
            },
        },
    })
end

function Gamepad:OpenRevisionsFromManage()
    releaseAndOpen(MANAGE_DIALOG, function()
        ZO_Dialogs_ShowGamepadDialog(REVISION_DIALOG)
    end)
end

function Gamepad:ConfirmGamepadRevisionRestore()
    local revision = self:GetSelectedRevision()
    if not revision then
        return
    end
    local build = self.owner.data:GetCurrentBuild()
    self.pendingConfirmTitle = GetString(SI_GRAVVY_BUILD_PLANNER_REVISION_RESTORE)
    self.pendingConfirmText = zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_CONFIRM_RESTORE_REVISION,
        revision.name
    )
    self.pendingConfirm = function()
        return self.owner.data:RestoreRevision(build.id, revision.id)
    end
    releaseAndOpen(REVISION_DIALOG, function()
        ZO_Dialogs_ShowGamepadDialog(CONFIRM_DIALOG)
    end)
end

function Gamepad:ConfirmGamepadRevisionDelete()
    local revision = self:GetSelectedRevision()
    if not revision then
        return
    end
    local build = self.owner.data:GetCurrentBuild()
    self.pendingConfirmTitle = GetString(SI_GRAVVY_BUILD_PLANNER_REVISION_DELETE)
    self.pendingConfirmText = zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_CONFIRM_DELETE_REVISION,
        revision.name
    )
    self.pendingConfirm = function()
        return self.owner.data:DeleteRevision(build.id, revision.id)
    end
    releaseAndOpen(REVISION_DIALOG, function()
        ZO_Dialogs_ShowGamepadDialog(CONFIRM_DIALOG)
    end)
end

function Gamepad:InitializeNameDialog()
    ZO_Dialogs_RegisterCustomDialog(NAME_DIALOG, {
        blockDialogReleaseOnPress = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        setup = function(dialog) dialog:setupFunc() end,
        title = {
            text = function()
                return GetString(self.pendingNameAction == "createRevision"
                    and SI_GRAVVY_BUILD_PLANNER_REVISION_NAME
                    or SI_GRAVVY_BUILD_PLANNER_ENTER_NAME)
            end,
        },
        parametricList = {
            textFieldEntry(SI_GRAVVY_BUILD_PLANNER_ENTER_NAME, {
                value = function() return self.pendingName end,
                changed = function(value) self.pendingName = value end,
                defaultText = GetString(SI_GRAVVY_BUILD_PLANNER_ENTER_NAME),
                maxChars = 100,
            }),
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = selectDialogEntry,
            },
            {
                keybind = "DIALOG_SECONDARY",
                text = SI_GRAVVY_BUILD_PLANNER_SAVE_NAME,
                callback = function()
                    local ok, message = self:AcceptPendingName()
                    if not ok then
                        showError(message)
                        return
                    end
                    ZO_Dialogs_ReleaseDialogOnButtonPress(NAME_DIALOG)
                end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback = cancelDialog(NAME_DIALOG),
            },
        },
    })
end

function Gamepad:OpenNameFromManage(action)
    local setup, build = self.owner.data:GetCurrentSetup()
    self.pendingNameAction = action
    self.pendingName = action == "renameBuild" and build.name
        or action == "renameSetup" and setup.name
        or ""
    releaseAndOpen(MANAGE_DIALOG, function()
        ZO_Dialogs_ShowGamepadDialog(NAME_DIALOG)
    end)
end

function Gamepad:AcceptPendingName()
    local setup, build = self.owner.data:GetCurrentSetup()
    local action = self.pendingNameAction
    local result, message
    if action == "newBuild" then
        result, message = self.owner.data:CreateBuild(self.pendingName)
    elseif action == "renameBuild" then
        result, message = self.owner.data:RenameBuild(build.id, self.pendingName)
    elseif action == "duplicateBuild" then
        result, message = self.owner.data:DuplicateBuild(build.id, self.pendingName)
    elseif action == "newSetup" then
        result, message = self.owner.data:CreateSetup(build.id, self.pendingName)
    elseif action == "renameSetup" then
        result, message = self.owner.data:RenameSetup(build.id, setup.id, self.pendingName)
    elseif action == "duplicateSetup" then
        result, message = self.owner.data:DuplicateSetup(build.id, setup.id, self.pendingName)
    elseif action == "createRevision" then
        result, message = self.owner.data:CreateRevision(build.id, self.pendingName)
    end
    if not result then
        return false, message
    end
    self.owner.setCatalog:Refresh()
    self.owner.inventory:Refresh()
    self:SetStatus(type(message) == "string" and message
        or GetString(SI_GRAVVY_BUILD_PLANNER_GAMEPAD_SAVED))
    self:Refresh(true)
    return true
end

function Gamepad:MoveSetupFromManage(direction)
    local setup, build = self.owner.data:GetCurrentSetup()
    self.owner.data:MoveSetup(build.id, setup.id, direction)
    ZO_Dialogs_ReleaseDialogOnButtonPress(MANAGE_DIALOG)
    self:Refresh(true)
end

function Gamepad:UndoFromManage()
    local ok, message = self.owner.data:UndoLastDeletion()
    if not ok then
        showError(message)
        return
    end
    ZO_Dialogs_ReleaseDialogOnButtonPress(MANAGE_DIALOG)
    self.owner.setCatalog:Refresh()
    self.owner.inventory:Refresh()
    self:SetStatus(GetString(SI_GRAVVY_BUILD_PLANNER_RESTORED))
    self:Refresh(true)
end

function Gamepad:InitializeConfirmDialog()
    ZO_Dialogs_RegisterCustomDialog(CONFIRM_DIALOG, {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title = { text = function() return self.pendingConfirmTitle end },
        mainText = { text = function() return self.pendingConfirmText end },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_DIALOG_CONFIRM,
                callback = function()
                    local ok, message = self.pendingConfirm()
                    if not ok then
                        self:SetStatus(message, true)
                        return
                    end
                    self.owner.setCatalog:Refresh()
                    if self.owner.consumableCatalog then
                        self.owner.consumableCatalog:Refresh()
                    end
                    self.owner.inventory:Refresh()
                    if message then
                        self:SetStatus(message)
                    end
                    self:Refresh(true)
                end,
            },
            { keybind = "DIALOG_NEGATIVE", text = SI_DIALOG_CANCEL },
        },
    })
end

function Gamepad:OpenDeleteFromManage(kind)
    local setup, build = self.owner.data:GetCurrentSetup()
    self.pendingConfirmTitle = GetString(SI_GRAVVY_BUILD_PLANNER_DELETE)
    if kind == "build" then
        self.pendingConfirmText = zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_CONFIRM_DELETE_BUILD,
            build.name
        )
        self.pendingConfirm = function()
            return self.owner.data:DeleteBuild(build.id)
        end
    else
        self.pendingConfirmText = zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_CONFIRM_DELETE_SETUP,
            setup.name
        )
        self.pendingConfirm = function()
            return self.owner.data:DeleteSetup(build.id, setup.id)
        end
    end
    releaseAndOpen(MANAGE_DIALOG, function()
        ZO_Dialogs_ShowGamepadDialog(CONFIRM_DIALOG)
    end)
end

function Gamepad:InitializeExportDialog()
    ZO_Dialogs_RegisterCustomDialog(EXPORT_DIALOG, {
        blockDialogReleaseOnPress = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        setup = function(dialog)
            self.exportIncludeOwned = false
            self.exportIncludeGlyphs = false
            self:RefreshExportReview()
            dialog:setupFunc()
        end,
        title = { text = SI_GRAVVY_BUILD_PLANNER_EXPORT_TITLE },
        mainText = {
            text = function()
                local review = self.exportReview
                return zo_strformat(
                    SI_GRAVVY_BUILD_PLANNER_EXPORT_SUMMARY,
                    review.included,
                    review.glyphs,
                    review.excluded,
                    review.owned
                )
            end,
        },
        parametricList = {
            dropdownEntry(
                SI_GRAVVY_BUILD_PLANNER_EXPORT_OWNED,
                {
                    { label = GetString(SI_GRAVVY_BUILD_PLANNER_EXPORT_EXCLUDE), value = false },
                    { label = GetString(SI_GRAVVY_BUILD_PLANNER_EXPORT_INCLUDE), value = true },
                },
                function() return self.exportIncludeOwned end,
                function(value)
                    self.exportIncludeOwned = value
                    self:RefreshExportReview()
                end
            ),
            dropdownEntry(
                SI_GRAVVY_BUILD_PLANNER_EXPORT_GLYPHS,
                {
                    { label = GetString(SI_GRAVVY_BUILD_PLANNER_EXPORT_NO_GLYPHS), value = false },
                    { label = GetString(SI_GRAVVY_BUILD_PLANNER_EXPORT_ADD_GLYPHS), value = true },
                },
                function() return self.exportIncludeGlyphs end,
                function(value)
                    self.exportIncludeGlyphs = value
                    self:RefreshExportReview()
                end
            ),
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = selectDialogEntry,
            },
            {
                keybind = "DIALOG_SECONDARY",
                text = SI_GRAVVY_BUILD_PLANNER_EXPORT_CREATE,
                callback = function() self:ExecuteGamepadExport() end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback = cancelDialog(EXPORT_DIALOG),
            },
        },
    })
end


function Gamepad:OpenAddonPage()
    if RequestOpenUnsafeURL then
        RequestOpenUnsafeURL(self.owner.shopping:GetAddonURL())
    else
        showError(GetString(SI_GRAVVY_BUILD_PLANNER_URL_UNAVAILABLE))
    end
end

function Gamepad:RefreshExportReview()
    self.exportReview = self.owner.shopping:BuildReview(
        self.exportIncludeOwned,
        self.exportIncludeGlyphs
    )
end

function Gamepad:ShowExportDialog()
    ZO_Dialogs_ShowGamepadDialog(EXPORT_DIALOG)
end

function Gamepad:ExecuteGamepadExport()
    local review = self.exportReview
    if not review or #review.items == 0 then
        showError(GetString(SI_GRAVVY_BUILD_PLANNER_EXPORT_NOTHING))
        return
    end
    local api = self.owner.shopping:GetAPI()
    if api then
        local ok, result, itemIndex = self.owner.shopping:CreateList(review)
        if ok then
            ZO_Dialogs_ReleaseDialogOnButtonPress(EXPORT_DIALOG)
            self:SetStatus(zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_EXPORT_CREATED,
                result.name,
                #review.items
            ))
            return
        elseif result ~= "NOT_READY" then
            showError(zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_EXPORT_FAILED,
                itemIndex and (tostring(result) .. " #" .. tostring(itemIndex))
                    or tostring(result)
            ))
            return
        end
    end
    self.pendingCode = self.owner.shopping:Encode(review)
    if not self.pendingCode then
        showError(GetString(SI_GRAVVY_BUILD_PLANNER_EXPORT_CODE_FAILED))
        return
    end
    releaseAndOpen(EXPORT_DIALOG, function()
        ZO_Dialogs_ShowGamepadDialog(CODE_DIALOG)
    end)
end

function Gamepad:InitializeCodeDialog()
    ZO_Dialogs_RegisterCustomDialog(CODE_DIALOG, {
        blockDialogReleaseOnPress = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        title = { text = SI_GRAVVY_BUILD_PLANNER_CODE_TITLE },
        mainText = { text = SI_GRAVVY_BUILD_PLANNER_CODE_HELP },
        parametricList = {
            textFieldEntry(SI_GRAVVY_BUILD_PLANNER_CODE_TITLE, {
                value = function() return self.pendingCode or "" end,
                changed = function(value) self.pendingCode = value end,
                defaultText = "SL2:",
                maxChars = 20000,
                multiline = true,
            }),
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = selectDialogEntry,
            },
            {
                keybind = "DIALOG_SECONDARY",
                text = SI_GRAVVY_BUILD_PLANNER_OPEN_ADDON_PAGE,
                callback = function() self:OpenAddonPage() end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CLOSE,
                callback = cancelDialog(CODE_DIALOG),
            },
        },
    })
end

function Gamepad:InitializeHelpDialog()
    ZO_Dialogs_RegisterCustomDialog(HELP_DIALOG, {
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title = { text = SI_GRAVVY_BUILD_PLANNER_HELP_TITLE },
        mainText = { text = function()
            return GetString(SI_GRAVVY_BUILD_PLANNER_HELP_CONTENT)
                .. GetString(SI_GRAVVY_BUILD_PLANNER_HELP_ALTERNATIVES)
                .. GetString(SI_GRAVVY_BUILD_PLANNER_HELP_SKILLS)
                .. GetString(SI_GRAVVY_BUILD_PLANNER_HELP_CHARACTER)
                .. GetString(SI_GRAVVY_BUILD_PLANNER_HELP_CHAMPION)
                .. GetString(SI_GRAVVY_BUILD_PLANNER_HELP_SUPPLIES)
                .. GetString(SI_GRAVVY_BUILD_PLANNER_HELP_CHECKLIST)
                .. GetString(SI_GRAVVY_BUILD_PLANNER_HELP_COMPARE)
                .. GetString(SI_GRAVVY_BUILD_PLANNER_HELP_STAT_IMPACT)
                .. GetString(SI_GRAVVY_BUILD_PLANNER_HELP_CAPTURE)
                .. GetString(SI_GRAVVY_BUILD_PLANNER_HELP_REVISIONS)
        end },
        buttons = {
            { keybind = "DIALOG_NEGATIVE", text = SI_DIALOG_CLOSE },
        },
    })
end

function Gamepad:InitializeShareDialog()
    ZO_Dialogs_RegisterCustomDialog(SHARE_DIALOG, {
        blockDialogReleaseOnPress = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        setup = function(dialog)
            local code, message = GravvyBuildPlannerShare.EncodeBuild(
                self.owner.data:GetCurrentBuild()
            )
            self.pendingShareCode = code or ""
            self.pendingShareError = message
            dialog:setupFunc()
        end,
        title = { text = SI_GRAVVY_BUILD_PLANNER_SHARE_TITLE },
        mainText = {
            text = function()
                return self.pendingShareError or GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_HELP)
            end,
        },
        parametricList = {
            textFieldEntry(SI_GRAVVY_BUILD_PLANNER_SHARE_TITLE, {
                value = function() return self.pendingShareCode end,
                changed = function(value) self.pendingShareCode = value end,
                defaultText = GravvyBuildPlannerShare.PREFIX,
                maxChars = GravvyBuildPlannerShare.MAX_CODE_LENGTH,
                multiline = true,
            }),
            actionEntry(SI_GRAVVY_BUILD_PLANNER_SHARE_IMPORT, function()
                self:ImportSharedBuild()
            end),
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = selectDialogEntry,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CLOSE,
                callback = cancelDialog(SHARE_DIALOG),
            },
        },
    })
end

function Gamepad:ShowShareDialog()
    ZO_Dialogs_ShowGamepadDialog(SHARE_DIALOG)
end

function Gamepad:ImportSharedBuild()
    local decoded, message = GravvyBuildPlannerShare.DecodeCode(self.pendingShareCode)
    if not decoded then
        showError(message)
        return
    end
    local build, importMessage = self.owner.data:ImportBuild(decoded)
    if not build then
        showError(importMessage)
        return
    end
    self.owner.setCatalog:Refresh()
    self.owner.inventory:QueueRefresh(0)
    ZO_Dialogs_ReleaseDialogOnButtonPress(SHARE_DIALOG)
    self:Refresh(true)
    self.owner.ui:Refresh()
    self:SetStatus(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_SHARE_IMPORTED,
        build.name,
        #build.setups
    ))
end

function Gamepad:ShowHelpDialog()
    ZO_Dialogs_ShowGamepadDialog(HELP_DIALOG)
end

function Gamepad:GetTransferTargets(sourceSlot, requirement)
    local setup = self.owner.data:GetCurrentSetup()
    local choices = {}
    for _, slotKey in ipairs(Slots.ORDER) do
        local mainHand = Slots:GetMainHand(slotKey)
        local mainRequirement = mainHand and setup.equipment[mainHand]
        if Slots:IsTransferCompatible(sourceSlot, slotKey, requirement)
            and not (mainRequirement and mainRequirement.occupiesOffHand) then
            choices[#choices + 1] = {
                label = slotName(slotKey),
                value = slotKey,
            }
        end
    end
    return choices
end

function Gamepad:InitializeTransferDialog()
    ZO_Dialogs_RegisterCustomDialog(TRANSFER_DIALOG, {
        blockDialogReleaseOnPress = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        setup = function(dialog)
            local setup = self.owner.data:GetCurrentSetup()
            self.pendingTransferSlot = self:GetTargetSlot()
            self.pendingTransferRequirement = setup.equipment[self.pendingTransferSlot]
            local targets = self:GetTransferTargets(
                self.pendingTransferSlot,
                self.pendingTransferRequirement
            )
            self.pendingTransferTarget = targets[1] and targets[1].value
            self.pendingTransferMove = false
            dialog:setupFunc()
        end,
        title = { text = SI_GRAVVY_BUILD_PLANNER_COPY_MOVE_TITLE },
        parametricList = {
            dropdownEntry(
                SI_GRAVVY_BUILD_PLANNER_DESTINATION,
                function()
                    return self:GetTransferTargets(
                        self.pendingTransferSlot,
                        self.pendingTransferRequirement
                    )
                end,
                function() return self.pendingTransferTarget end,
                function(value) self.pendingTransferTarget = value end
            ),
            dropdownEntry(
                SI_GRAVVY_BUILD_PLANNER_COPY_MOVE,
                {
                    { label = GetString(SI_GRAVVY_BUILD_PLANNER_COPY), value = false },
                    { label = GetString(SI_GRAVVY_BUILD_PLANNER_MOVE), value = true },
                },
                function() return self.pendingTransferMove end,
                function(value) self.pendingTransferMove = value end
            ),
        },
        buttons = {
            {
                keybind = "DIALOG_PRIMARY",
                text = SI_GAMEPAD_SELECT_OPTION,
                callback = selectDialogEntry,
            },
            {
                keybind = "DIALOG_SECONDARY",
                text = SI_GRAVVY_BUILD_PLANNER_COPY_MOVE,
                callback = function() self:ExecuteTransfer() end,
            },
            {
                keybind = "DIALOG_NEGATIVE",
                text = SI_DIALOG_CANCEL,
                callback = cancelDialog(TRANSFER_DIALOG),
            },
        },
    })
end

function Gamepad:ShowTransferDialog()
    local sourceSlot = self:GetTargetSlot()
    local setup = self.owner.data:GetCurrentSetup()
    local requirement = sourceSlot and setup.equipment[sourceSlot]
    if not requirement then
        showError(GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SOURCE_SLOT_EMPTY))
        return
    end
    if #self:GetTransferTargets(sourceSlot, requirement) == 0 then
        showError(GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_NO_TRANSFER_SLOT))
        return
    end
    ZO_Dialogs_ShowGamepadDialog(TRANSFER_DIALOG)
end

function Gamepad:FinishTransfer()
    local setup, build = self.owner.data:GetCurrentSetup()
    local sourceSlot = self.pendingTransferSlot
    local targetSlot = self.pendingTransferTarget
    local ok, message
    if self.pendingTransferMove then
        ok, message = self.owner.data:MoveEquipment(
            build.id,
            setup.id,
            sourceSlot,
            targetSlot
        )
    else
        ok, message = self.owner.data:CopyEquipment(
            build.id,
            setup.id,
            sourceSlot,
            targetSlot
        )
    end
    if not ok then
        return false, message
    end

    ZO_Dialogs_ReleaseDialogOnButtonPress(TRANSFER_DIALOG)
    self.owner.inventory:Refresh()
    self:SetStatus(zo_strformat(
        self.pendingTransferMove
            and SI_GRAVVY_BUILD_PLANNER_SLOT_MOVED
            or SI_GRAVVY_BUILD_PLANNER_SLOT_COPIED,
        slotName(sourceSlot),
        slotName(targetSlot)
    ))
    self:Refresh(true)
    for index, slotKey in ipairs(Slots.ORDER) do
        if slotKey == targetSlot then
            self.list:SetSelectedIndex(index)
            break
        end
    end
    return true
end

function Gamepad:ExecuteTransfer()
    local setup = self.owner.data:GetCurrentSetup()
    local sourceSlot = self.pendingTransferSlot
    local targetSlot = self.pendingTransferTarget
    local requirement = setup.equipment[sourceSlot]
    if not requirement or not targetSlot then
        showError(GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SOURCE_SLOT_EMPTY))
        return
    end

    local targetOffHand = Slots:GetOccupiedOffHand(targetSlot, requirement.weaponType)
    local replacesTarget = setup.equipment[targetSlot] ~= nil
    local clearsOffHand = targetOffHand and setup.equipment[targetOffHand] ~= nil
    if replacesTarget or clearsOffHand then
        self.pendingConfirmTitle = GetString(SI_GRAVVY_BUILD_PLANNER_COPY_MOVE_TITLE)
        self.pendingConfirmText = clearsOffHand and zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_CONFIRM_TRANSFER_TWO_HAND,
            slotName(targetSlot),
            slotName(targetOffHand)
        ) or zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_CONFIRM_REPLACE_SLOT,
            slotName(targetSlot)
        )
        self.pendingConfirm = function() return self:FinishTransfer() end
        releaseAndOpen(TRANSFER_DIALOG, function()
            ZO_Dialogs_ShowGamepadDialog(CONFIRM_DIALOG)
        end)
        return
    end

    local ok, message = self:FinishTransfer()
    if not ok then
        showError(message)
    end
end
