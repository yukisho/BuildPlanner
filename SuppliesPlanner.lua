local UI = GravvyBuildPlannerUI
local ROW_COUNT = 10
local EMPTY_TEXTURE = "EsoUI/Art/Inventory/inventory_tabIcon_consumables_up.dds"

local categoryStringIds = {
    food = SI_GRAVVY_BUILD_PLANNER_SUPPLY_FOOD,
    drink = SI_GRAVVY_BUILD_PLANNER_SUPPLY_DRINK,
    potion = SI_GRAVVY_BUILD_PLANNER_SUPPLY_POTION,
    poison = SI_GRAVVY_BUILD_PLANNER_SUPPLY_POISON,
    other = SI_GRAVVY_BUILD_PLANNER_SUPPLY_OTHER,
}

local function makeLabel(parent, text, x, y, width, font)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    GravvyBuildPlannerAccessibility:SetFont(label, font or "ZoFontGame")
    label:SetColor(0.88, 0.86, 0.8, 1)
    label:SetText(text or "")
    label:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    label:SetDimensions(width or 120, 30)
    GravvyBuildPlannerAccessibility:RegisterTextGeometry(label, width or 120, 30)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return label
end

local function makeButton(parent, text, width)
    local button = WINDOW_MANAGER:CreateControl(nil, parent, CT_BUTTON)
    button:SetDimensions(width, 28)
    GravvyBuildPlannerAccessibility:RegisterTextGeometry(button, width, 28)
    GravvyBuildPlannerAccessibility:SetFont(button, "ZoFontGame")
    button:SetText(text)
    button:SetNormalFontColor(0.85, 0.78, 0.62, 1)
    button:SetMouseOverFontColor(1, 1, 1, 1)
    button:SetPressedFontColor(0.65, 0.55, 0.35, 1)
    return button
end

local function makeEdit(parent, name, x, y, width, numeric, maxChars)
    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(name .. "Backdrop", parent, "ZO_EditBackdrop")
    backdrop:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    backdrop:SetDimensions(width, 30)
    local edit = WINDOW_MANAGER:CreateControlFromVirtual(name, backdrop, "ZO_DefaultEditForBackdrop")
    edit:ClearAnchors()
    edit:SetAnchor(TOPLEFT, backdrop, TOPLEFT, 3, 2)
    edit:SetAnchor(BOTTOMRIGHT, backdrop, BOTTOMRIGHT, -3, -2)
    GravvyBuildPlannerAccessibility:SetFont(edit, "ZoFontGame")
    edit:SetMaxInputChars(maxChars or 100)
    edit:SetNewLineEnabled(false)
    edit:SetSelectAllOnFocus(true)
    if numeric then
        edit:SetTextType(TEXT_TYPE_NUMERIC)
    end
    return edit
end

local function makeNoteEdit(parent, name, x, y, width, height)
    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(name .. "Backdrop", parent, "ZO_EditBackdrop")
    backdrop:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    backdrop:SetDimensions(width, height)
    local edit = WINDOW_MANAGER:CreateControlFromVirtual(name, backdrop, "ZO_DefaultEditMultiLineForBackdrop")
    edit:ClearAnchors()
    edit:SetAnchor(TOPLEFT, backdrop, TOPLEFT, 5, 4)
    edit:SetAnchor(BOTTOMRIGHT, backdrop, BOTTOMRIGHT, -5, -4)
    GravvyBuildPlannerAccessibility:SetFont(edit, "ZoFontGame")
    edit:SetMaxInputChars(4000)
    edit:SetNewLineEnabled(true)
    return edit
end

local function makeCombo(parent, name, x, y, width)
    local container = WINDOW_MANAGER:CreateControlFromVirtual(name, parent, "ZO_ComboBox")
    container:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    container:SetDimensions(width, 30)
    local combo = ZO_ComboBox_ObjectFromContainer(container)
    combo:SetSortsItems(false)
    return combo
end

local function setCategoryChoices(combo, selectedValue, changed)
    combo:ClearItems()
    combo.selectedValue = selectedValue
    local selectedLabel
    for _, key in ipairs({ "food", "drink", "potion", "poison", "other" }) do
        local label = GetString(categoryStringIds[key])
        combo:AddItem(combo:CreateItemEntry(label, function()
            combo.selectedValue = key
            if changed then
                changed(key)
            end
        end))
        if key == selectedValue then
            selectedLabel = label
        end
    end
    combo:SetSelectedItem(selectedLabel or GetString(categoryStringIds.food))
end

function UI:CreateSuppliesPlanner()
    local panel = WINDOW_MANAGER:CreateControl("GravvyBuildPlannerSupplies", self.window, CT_CONTROL)
    panel:SetAnchor(TOPLEFT, self.window, TOPLEFT, 18, self.CONTENT_TOP)
    panel:SetDimensions(942, 530)
    panel:SetHidden(true)
    self.suppliesPanel = panel
    self.supplyOffset = 0

    local backdrop = GravvyBuildPlannerUIHelpers:CreateFromVirtual(
        panel,
        "ZO_DefaultBackdrop",
        "SuppliesBackdrop"
    )
    backdrop:SetAnchorFill(panel)
    GravvyBuildPlannerAccessibility:RegisterBackdrop(
        backdrop,
        { 0.018, 0.018, 0.026, 0.9 },
        { 0.28, 0.24, 0.18, 0.85 }
    )

    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_SUPPLY_REQUIREMENTS), 22, 18, 450, "ZoFontWinH3")
    local add = makeButton(panel, GetString(SI_GRAVVY_BUILD_PLANNER_SUPPLY_ADD), 155)
    add:SetAnchor(TOPLEFT, panel, TOPLEFT, 307, 20)
    add:SetHandler("OnClicked", function()
        self.selectedSupplyIndex = nil
        self:LoadSupplyEditor()
    end)
    self.supplyRows = {}
    for rowIndex = 1, ROW_COUNT do
        local row = makeButton(panel, "", 438)
        row:SetHeight(36)
        row:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        row:SetAnchor(TOPLEFT, panel, TOPLEFT, 24, 58 + ((rowIndex - 1) * 38))
        row:SetHandler("OnClicked", function() self:SelectSupplyRow(rowIndex) end)
        row:SetHandler("OnMouseEnter", function(control) self:ShowSupplyTooltip(control, control.itemLink) end)
        row:SetHandler("OnMouseExit", function() self:HideSupplyTooltip() end)
        self.supplyRows[rowIndex] = row
    end
    local previous = makeButton(panel, GetString(SI_GRAVVY_BUILD_PLANNER_PREVIOUS), 100)
    previous:SetAnchor(BOTTOMLEFT, panel, BOTTOMLEFT, 24, -14)
    previous:SetHandler("OnClicked", function() self:PageSupplies(-1) end)
    local nextPage = makeButton(panel, GetString(SI_GRAVVY_BUILD_PLANNER_NEXT), 100)
    nextPage:SetAnchor(LEFT, previous, RIGHT, 8, 0)
    nextPage:SetHandler("OnClicked", function() self:PageSupplies(1) end)
    self.supplyPageLabel = makeLabel(panel, "", 244, 486, 218, "ZoFontGameSmall")
    self.supplyPageLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    local divider = WINDOW_MANAGER:CreateControl(nil, panel, CT_TEXTURE)
    divider:SetAnchor(TOPLEFT, panel, TOPLEFT, 484, 18)
    divider:SetDimensions(1, 494)
    divider:SetColor(0.5, 0.42, 0.28, 0.7)

    self.supplyEditorTitle = makeLabel(panel, "", 514, 20, 395, "ZoFontWinH3")
    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_SUPPLY_CATEGORY), 514, 62, 110)
    self.supplyCategoryCombo = makeCombo(panel, "GravvyBuildPlannerSupplyCategory", 630, 62, 279)
    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_SUPPLY_NAME), 514, 104, 110)
    self.supplyNameEdit = makeEdit(panel, "GravvyBuildPlannerSupplyName", 514, 136, 395, false, 2048)
    self.supplyNameEdit:SetHandler("OnTextChanged", function() self:OnSupplyTextChanged() end)
    self.supplyNameEdit:SetHandler("OnKeyDown", function(_, key) self:OnSupplyKeyDown(key) end)
    self.supplyNameEdit:SetHandler("OnFocusLost", function() self:ResolveSupply() end)
    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_SUPPLY_QUANTITY), 514, 178, 110)
    self.supplyQuantityEdit = makeEdit(panel, "GravvyBuildPlannerSupplyQuantity", 630, 178, 90, true, 4)
    makeLabel(panel, GetString(SI_GRAVVY_BUILD_PLANNER_NOTES), 514, 220, 110)
    self.supplyNoteEdit = makeNoteEdit(panel, "GravvyBuildPlannerSupplyNote", 514, 252, 395, 100)
    self.supplyPreview = WINDOW_MANAGER:CreateControl(nil, panel, CT_TEXTURE)
    self.supplyPreview:SetDimensions(56, 56)
    self.supplyPreview:SetAnchor(TOPLEFT, panel, TOPLEFT, 514, 370)
    self.supplyPreview:SetMouseEnabled(true)
    self.supplyPreview:SetHandler("OnMouseEnter", function(control)
        local entry = self.selectedSupplyCatalogEntry or self.selectedSupplyEntry
        self:ShowSupplyTooltip(control, entry and entry.itemLink)
    end)
    self.supplyPreview:SetHandler("OnMouseExit", function() self:HideSupplyTooltip() end)
    self.supplyPreviewName = makeLabel(panel, "", 582, 380, 327, "ZoFontGame")

    local remove = makeButton(panel, GetString(SI_GRAVVY_BUILD_PLANNER_SUPPLY_REMOVE), 150)
    remove:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, -180, -20)
    remove:SetHandler("OnClicked", function() self:RemoveSupply() end)
    local save = makeButton(panel, GetString(SI_GRAVVY_BUILD_PLANNER_SUPPLY_SAVE), 150)
    save:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, -20, -20)
    save:SetHandler("OnClicked", function() self:SaveSupply() end)

    local suggestions = WINDOW_MANAGER:CreateControl(nil, panel, CT_CONTROL)
    suggestions:SetDimensions(395, 152)
    suggestions:SetAnchor(TOPLEFT, self.supplyNameEdit, BOTTOMLEFT, 0, 2)
    suggestions:SetHidden(true)
    suggestions:SetDrawTier(DT_HIGH)
    self.supplySuggestionPanel = suggestions
    local suggestionBackdrop = GravvyBuildPlannerUIHelpers:CreateFromVirtual(
        suggestions,
        "ZO_DefaultBackdrop",
        "SupplySuggestionsBackdrop"
    )
    suggestionBackdrop:SetAnchorFill(suggestions)
    self.supplySuggestionButtons = {}
    for index = 1, 6 do
        local button = makeButton(suggestions, "", 385)
        button:SetHeight(24)
        button:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        button:SetAnchor(TOPLEFT, suggestions, TOPLEFT, 5, 4 + ((index - 1) * 24))
        button:SetHandler("OnClicked", function() self:ChooseSupplySuggestion(index) end)
        self.supplySuggestionButtons[index] = button
    end
end

function UI:GetSupplies()
    local setup = self.owner.data:GetCurrentSetup()
    return setup.consumables
end

function UI:RefreshSuppliesPlanner()
    if not self.suppliesPanel then
        return
    end
    local supplies = self:GetSupplies()
    local lastOffset = #supplies > 0 and math.floor((#supplies - 1) / ROW_COUNT) * ROW_COUNT or 0
    self.supplyOffset = zo_clamp(self.supplyOffset, 0, lastOffset)
    for rowIndex = 1, ROW_COUNT do
        local row = self.supplyRows[rowIndex]
        local entry = supplies[self.supplyOffset + rowIndex]
        row.itemLink = entry and entry.itemLink
        row:SetHidden(not entry)
        row:SetText(entry and zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_SUPPLY_SUMMARY,
            GetString(categoryStringIds[entry.category]),
            entry.name,
            entry.quantity
        ) or "")
    end
    local first = #supplies == 0 and 0 or self.supplyOffset + 1
    local last = math.min(#supplies, self.supplyOffset + ROW_COUNT)
    self.supplyPageLabel:SetText(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_CHAMPION_PAGE,
        first,
        last,
        #supplies
    ))
    self:LoadSupplyEditor()
end

function UI:PageSupplies(direction)
    local supplies = self:GetSupplies()
    local lastOffset = #supplies > 0 and math.floor((#supplies - 1) / ROW_COUNT) * ROW_COUNT or 0
    self.supplyOffset = zo_clamp(
        self.supplyOffset + (direction * ROW_COUNT),
        0,
        lastOffset
    )
    self:RefreshSuppliesPlanner()
end

function UI:SelectSupplyRow(rowIndex)
    local index = self.supplyOffset + rowIndex
    self.selectedSupplyIndex = self:GetSupplies()[index] and index or nil
    self:LoadSupplyEditor()
end

function UI:LoadSupplyEditor()
    local entry = self.selectedSupplyIndex and self:GetSupplies()[self.selectedSupplyIndex]
    self.loadingSupply = true
    self.selectedSupplyEntry = entry
    self.selectedSupplyCatalogEntry = entry
    self.supplyEditorTitle:SetText(GetString(entry
        and SI_GRAVVY_BUILD_PLANNER_SUPPLY_EDIT
        or SI_GRAVVY_BUILD_PLANNER_SUPPLY_NEW))
    setCategoryChoices(self.supplyCategoryCombo, entry and entry.category or "food", function()
        self.selectedSupplyCatalogEntry = nil
        self:OnSupplyTextChanged()
    end)
    self.supplyNameEdit:SetText(entry and entry.name or "")
    self.supplyQuantityEdit:SetText(entry and tostring(entry.quantity) or "1")
    self.supplyNoteEdit:SetText(entry and entry.note or "")
    self.supplyPreview:SetTexture(entry and entry.icon ~= "" and entry.icon or EMPTY_TEXTURE)
    self.supplyPreviewName:SetText(entry and entry.name or GetString(SI_GRAVVY_BUILD_PLANNER_NOT_PLANNED))
    self.supplySuggestionPanel:SetHidden(true)
    self.loadingSupply = false
end

function UI:OnSupplyTextChanged()
    if self.loadingSupply then
        return
    end
    self.selectedSupplyCatalogEntry = nil
    local results = self.owner.consumableCatalog:Search(
        self.supplyNameEdit:GetText(),
        self.supplyCategoryCombo.selectedValue,
        6
    )
    self.supplySuggestionData = results
    self.supplySuggestionIndex = 1
    self.supplySuggestionPanel:SetHidden(#results == 0)
    for index, button in ipairs(self.supplySuggestionButtons) do
        button:SetHidden(not results[index])
        button:SetText(results[index] and results[index].name or "")
    end
end

function UI:ChooseSupplySuggestion(index)
    local entry = self.supplySuggestionData and self.supplySuggestionData[index]
    if not entry then
        return
    end
    self.selectedSupplyCatalogEntry = entry
    self.loadingSupply = true
    self.supplyNameEdit:SetText(entry.name)
    self.loadingSupply = false
    self.supplyPreview:SetTexture(entry.icon ~= "" and entry.icon or EMPTY_TEXTURE)
    self.supplyPreviewName:SetText(entry.name)
    self.supplySuggestionPanel:SetHidden(true)
end

function UI:ResolveSupply()
    if self.selectedSupplyCatalogEntry then
        return self.selectedSupplyCatalogEntry
    end
    self.selectedSupplyCatalogEntry = self.owner.consumableCatalog:FindExact(
        self.supplyNameEdit:GetText(),
        self.supplyCategoryCombo.selectedValue
    )
    local entry = self.selectedSupplyCatalogEntry
    if entry then
        self.supplyPreview:SetTexture(entry.icon ~= "" and entry.icon or EMPTY_TEXTURE)
        self.supplyPreviewName:SetText(entry.name)
    end
    return self.selectedSupplyCatalogEntry
end

function UI:OnSupplyKeyDown(key)
    if self.supplySuggestionPanel:IsHidden() then
        return
    end
    local count = math.min(6, #(self.supplySuggestionData or {}))
    if key == KEY_DOWN then
        self.supplySuggestionIndex = math.min(count, self.supplySuggestionIndex + 1)
    elseif key == KEY_UP then
        self.supplySuggestionIndex = math.max(1, self.supplySuggestionIndex - 1)
    elseif key == KEY_ENTER then
        self:ChooseSupplySuggestion(self.supplySuggestionIndex)
    elseif key == KEY_ESCAPE then
        self.supplySuggestionPanel:SetHidden(true)
    end
end

function UI:SaveSupply()
    local typedName = zo_strtrim(self.supplyNameEdit:GetText())
    local catalogEntry = self:ResolveSupply()
    local category = self.supplyCategoryCombo.selectedValue
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
    local quantity = tonumber(self.supplyQuantityEdit:GetText())
    if typedName == "" or not quantity or quantity ~= math.floor(quantity)
        or quantity < 1 or quantity > 9999 then
        self:SetStatus(GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_CONSUMABLE), true)
        return
    end
    local values = {
        category = category,
        name = catalogEntry and catalogEntry.name or typedName,
        itemId = catalogEntry and catalogEntry.itemId,
        itemLink = catalogEntry and catalogEntry.itemLink,
        icon = catalogEntry and catalogEntry.icon or "",
        quantity = quantity,
        note = self.supplyNoteEdit:GetText(),
    }
    local setup, build = self.owner.data:GetCurrentSetup()
    local ok, result = self.owner.data:SetConsumable(
        build.id,
        setup.id,
        self.selectedSupplyIndex,
        values
    )
    if not ok then
        self:SetStatus(result, true)
        return
    end
    self.selectedSupplyIndex = result
    self.owner.consumableCatalog:RefreshSaved()
    self:RefreshSuppliesPlanner()
    self:SetStatus(zo_strformat(SI_GRAVVY_BUILD_PLANNER_SUPPLY_SAVED, values.name))
end

function UI:RemoveSupply()
    if not self.selectedSupplyIndex then
        return
    end
    local setup, build = self.owner.data:GetCurrentSetup()
    local ok, message = self.owner.data:SetConsumable(
        build.id,
        setup.id,
        self.selectedSupplyIndex,
        nil
    )
    if not ok then
        self:SetStatus(message, true)
        return
    end
    self.selectedSupplyIndex = nil
    self.owner.consumableCatalog:RefreshSaved()
    self:RefreshSuppliesPlanner()
    self:SetStatus(GetString(SI_GRAVVY_BUILD_PLANNER_SUPPLY_REMOVED))
end

function UI:ShowSupplyTooltip(control, itemLink)
    if itemLink and itemLink ~= "" and ItemTooltip and InitializeTooltip then
        InitializeTooltip(ItemTooltip, control, LEFT, -8, 0, RIGHT)
        ItemTooltip:SetLink(itemLink)
    end
end

function UI:HideSupplyTooltip()
    if ItemTooltip and ClearTooltip then
        ClearTooltip(ItemTooltip)
    end
end
