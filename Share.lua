GravvyBuildPlannerShare = {}

local Share = GravvyBuildPlannerShare
local Slots = GravvyBuildPlannerSlots
local PREFIX = "GBP1:"
local FORMAT_VERSION = 1
local MAX_CODE_LENGTH = 100000
local MAX_SETUPS = 100
local MAX_STRING = 512
local MAX_NOTE = 4000
local MAX_LINK = 2048
local MAX_U32 = 4294967295
local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local DECODE = {}

local buildStrings = {
    { key = "name", max = MAX_STRING, required = true },
    { key = "role", max = MAX_STRING },
    { key = "patch", max = MAX_STRING },
    { key = "author", max = MAX_STRING },
    { key = "sourceUrl", max = MAX_STRING },
    { key = "notes", max = MAX_NOTE },
}
local requirementStrings = {
    { key = "setName", max = MAX_STRING },
    { key = "itemName", max = MAX_STRING },
    { key = "itemLink", max = MAX_LINK },
    { key = "enchantmentName", max = MAX_STRING },
    { key = "note", max = MAX_NOTE },
}
local requirementNumbers = {
    "setId",
    "itemId",
    "armorType",
    "weaponType",
    "traitType",
    "enchantmentId",
    "enchantmentCategory",
    "quality",
    "level",
    "championPoints",
}
local routeValues = {
    buy = 1,
    craft = 2,
    farm = 3,
    reconstruct = 4,
    transmute = 5,
    unknown = 6,
}
local routeNames = {}
for name, value in pairs(routeValues) do
    routeNames[value] = name
end

Share.PREFIX = PREFIX
Share.MAX_CODE_LENGTH = MAX_CODE_LENGTH

for index = 1, #ALPHABET do
    DECODE[string.sub(ALPHABET, index, index)] = index - 1
end

local function trim(value)
    return string.match(value or "", "^%s*(.-)%s*$")
end

local function encodeBase64(value)
    local result = {}
    for position = 1, #value, 3 do
        local first = string.byte(value, position)
        local second = string.byte(value, position + 1)
        local third = string.byte(value, position + 2)
        local packed = (first * 65536) + ((second or 0) * 256) + (third or 0)
        result[#result + 1] = string.sub(ALPHABET, math.floor(packed / 262144) + 1, math.floor(packed / 262144) + 1)
        result[#result + 1] = string.sub(ALPHABET, (math.floor(packed / 4096) % 64) + 1, (math.floor(packed / 4096) % 64) + 1)
        if second then
            result[#result + 1] = string.sub(ALPHABET, (math.floor(packed / 64) % 64) + 1, (math.floor(packed / 64) % 64) + 1)
        end
        if third then
            result[#result + 1] = string.sub(ALPHABET, (packed % 64) + 1, (packed % 64) + 1)
        end
    end
    return table.concat(result)
end

local function decodeBase64(value)
    if value == "" or #value % 4 == 1 then
        return nil
    end
    local result = {}
    for position = 1, #value, 4 do
        local first = DECODE[string.sub(value, position, position)]
        local second = DECODE[string.sub(value, position + 1, position + 1)]
        local thirdCharacter = string.sub(value, position + 2, position + 2)
        local fourthCharacter = string.sub(value, position + 3, position + 3)
        local third = thirdCharacter ~= "" and DECODE[thirdCharacter] or nil
        local fourth = fourthCharacter ~= "" and DECODE[fourthCharacter] or nil
        if first == nil or second == nil
            or (thirdCharacter ~= "" and third == nil)
            or (fourthCharacter ~= "" and fourth == nil) then
            return nil
        end
        local packed = (first * 262144) + (second * 4096)
            + ((third or 0) * 64) + (fourth or 0)
        result[#result + 1] = string.char(math.floor(packed / 65536) % 256)
        if third ~= nil then
            result[#result + 1] = string.char(math.floor(packed / 256) % 256)
        end
        if fourth ~= nil then
            result[#result + 1] = string.char(packed % 256)
        end
    end
    return table.concat(result)
end

local function appendU16(parts, value)
    parts[#parts + 1] = string.char(math.floor(value / 256) % 256, value % 256)
end

local function appendU32(parts, value)
    parts[#parts + 1] = string.char(
        math.floor(value / 16777216) % 256,
        math.floor(value / 65536) % 256,
        math.floor(value / 256) % 256,
        value % 256
    )
end

local function appendString(parts, value)
    appendU16(parts, #value)
    parts[#parts + 1] = value
end

local function checksum(value)
    local first = 1
    local second = 0
    for index = 1, #value do
        first = (first + string.byte(value, index)) % 65521
        second = (second + first) % 65521
    end
    return (second * 65536) + first
end

local function wholeNumber(value, minimum, maximum)
    value = tonumber(value)
    if not value or value ~= math.floor(value) or value < minimum or value > maximum then
        return nil
    end
    return value
end

local function appendOptionalU32(parts, value)
    if value == nil then
        appendU32(parts, 0)
        return true
    end
    value = wholeNumber(value, 0, MAX_U32 - 1)
    if not value then
        return false
    end
    appendU32(parts, value + 1)
    return true
end

local function makeReader(payload)
    local position = 1
    local reader = {}
    function reader:Byte()
        local value = string.byte(payload, position)
        position = position + 1
        return value
    end
    function reader:U16()
        local first, second = self:Byte(), self:Byte()
        return first and second and ((first * 256) + second) or nil
    end
    function reader:U32()
        local first, second, third, fourth = self:Byte(), self:Byte(), self:Byte(), self:Byte()
        return first and second and third and fourth
            and ((first * 16777216) + (second * 65536) + (third * 256) + fourth)
            or nil
    end
    function reader:String(maxLength, required)
        local length = self:U16()
        if not length or length > maxLength or position + length - 1 > #payload then
            return nil
        end
        local value = string.sub(payload, position, position + length - 1)
        position = position + length
        if required and trim(value) == "" then
            return nil
        end
        return value
    end
    function reader:IsDone()
        return position == #payload + 1
    end
    return reader
end

local function readOptionalU32(reader)
    local value = reader:U32()
    if value == 0 then
        return nil, true
    end
    return value and value - 1 or nil, value ~= nil
end

function Share.EncodeBuild(build)
    if type(build) ~= "table" or type(build.setups) ~= "table"
        or #build.setups == 0 or #build.setups > MAX_SETUPS then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
    end

    local parts = { string.char(FORMAT_VERSION) }
    for _, field in ipairs(buildStrings) do
        local value = tostring(build[field.key] or "")
        if #value > field.max or (field.required and trim(value) == "") then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end
        appendString(parts, value)
    end
    if not appendOptionalU32(parts, build.classId) then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
    end
    appendU16(parts, #build.setups)
    local selectedSetupIndex = 1
    for index, setup in ipairs(build.setups) do
        if setup.id == build.selectedSetupId then
            selectedSetupIndex = index
            break
        end
    end
    appendU16(parts, selectedSetupIndex)

    for _, setup in ipairs(build.setups) do
        local setupName = tostring(setup.name or "")
        local setupNote = tostring(setup.note or "")
        local quality = wholeNumber(setup.defaultQuality, 0, 65535)
        local level = wholeNumber(setup.defaultLevel, 1, 65535)
        local championPoints = wholeNumber(setup.defaultChampionPoints, 0, MAX_U32)
        if trim(setupName) == "" or #setupName > MAX_STRING or #setupNote > MAX_NOTE
            or not quality or not level or not championPoints
            or type(setup.equipment) ~= "table" then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end
        appendString(parts, setupName)
        appendString(parts, setupNote)
        appendU16(parts, quality)
        appendU16(parts, level)
        appendU32(parts, championPoints)

        local count = 0
        for slotKey, requirement in pairs(setup.equipment) do
            if not Slots:IsValid(slotKey)
                or type(requirement) ~= "table"
                or not Slots:IsRequirementCompatible(slotKey, requirement) then
                return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
            end
        end
        for _, slotKey in ipairs(Slots.ORDER) do
            if setup.equipment[slotKey] then
                count = count + 1
            end
        end
        parts[#parts + 1] = string.char(count)
        for slotIndex, slotKey in ipairs(Slots.ORDER) do
            local requirement = setup.equipment[slotKey]
            if requirement then
                parts[#parts + 1] = string.char(slotIndex)
                for _, field in ipairs(requirementStrings) do
                    local value = tostring(requirement[field.key] or "")
                    if #value > field.max then
                        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                    end
                    appendString(parts, value)
                end
                for _, key in ipairs(requirementNumbers) do
                    if not appendOptionalU32(parts, requirement[key]) then
                        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                    end
                end
                local state = setup.acquisition and setup.acquisition[slotKey]
                local route = state and routeValues[state.preferredRoute] or 0
                if state and not route then
                    return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                end
                parts[#parts + 1] = string.char(route)
            end
        end
    end

    local body = table.concat(parts)
    local payload = { body }
    appendU32(payload, checksum(body))
    local code = PREFIX .. encodeBase64(table.concat(payload))
    if #code > MAX_CODE_LENGTH then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_LONG)
    end
    return code
end

function Share.DecodeCode(code)
    code = trim(code)
    if #code > MAX_CODE_LENGTH then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_LONG)
    end
    if string.sub(code, 1, #PREFIX) ~= PREFIX then
        return nil, zo_strformat(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_PREFIX, PREFIX)
    end
    local payload = decodeBase64(string.sub(code, #PREFIX + 1))
    if not payload or #payload < 5 then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_INVALID)
    end
    local body = string.sub(payload, 1, #payload - 4)
    local checksumReader = makeReader(string.sub(payload, #payload - 3))
    if checksumReader:U32() ~= checksum(body) then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_INVALID)
    end

    local reader = makeReader(body)
    if reader:Byte() ~= FORMAT_VERSION then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_VERSION)
    end
    local build = { setups = {} }
    for _, field in ipairs(buildStrings) do
        build[field.key] = reader:String(field.max, field.required)
        if build[field.key] == nil then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end
    end
    local classId, classOk = readOptionalU32(reader)
    local setupCount = reader:U16()
    local selectedSetupIndex = reader:U16()
    if not classOk or not setupCount or setupCount < 1 or setupCount > MAX_SETUPS then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
    end
    if not selectedSetupIndex or selectedSetupIndex < 1 or selectedSetupIndex > setupCount then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
    end
    build.classId = classId
    build.selectedSetupIndex = selectedSetupIndex

    for _ = 1, setupCount do
        local setup = {
            name = reader:String(MAX_STRING, true),
            note = reader:String(MAX_NOTE, false),
            defaultQuality = reader:U16(),
            defaultLevel = reader:U16(),
            defaultChampionPoints = reader:U32(),
            equipment = {},
            acquisition = {},
        }
        local equipmentCount = reader:Byte()
        if not setup.name or setup.note == nil or not setup.defaultQuality
            or not setup.defaultLevel or setup.defaultLevel < 1
            or not setup.defaultChampionPoints or not equipmentCount
            or equipmentCount > #Slots.ORDER then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end
        local seenSlots = {}
        for _ = 1, equipmentCount do
            local slotIndex = reader:Byte()
            local slotKey = slotIndex and Slots.ORDER[slotIndex]
            if not slotKey or seenSlots[slotKey] then
                return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
            end
            seenSlots[slotKey] = true
            local requirement = {}
            for _, field in ipairs(requirementStrings) do
                local value = reader:String(field.max, false)
                if value == nil then
                    return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                end
                if value ~= "" then
                    requirement[field.key] = value
                end
            end
            for _, key in ipairs(requirementNumbers) do
                local value, ok = readOptionalU32(reader)
                if not ok then
                    return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                end
                requirement[key] = value
            end
            local route = reader:Byte()
            if route == nil or (route ~= 0 and not routeNames[route]) then
                return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
            end
            if not Slots:IsRequirementCompatible(slotKey, requirement) then
                return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
            end
            setup.equipment[slotKey] = requirement
            if route ~= 0 then
                setup.acquisition[slotKey] = { preferredRoute = routeNames[route] }
            end
        end
        build.setups[#build.setups + 1] = setup
    end
    if not reader:IsDone() then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_INVALID)
    end
    return build
end

local function makeLabel(parent, text, x, y, width, font)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    GravvyBuildPlannerAccessibility:SetFont(label, font or "ZoFontGame")
    label:SetText(text or "")
    label:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    label:SetDimensions(width, 30)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    return label
end

local function makeButton(parent, text, width)
    local button = WINDOW_MANAGER:CreateControl(nil, parent, CT_BUTTON)
    button:SetDimensions(width, 28)
    GravvyBuildPlannerAccessibility:SetFont(button, "ZoFontGame")
    button:SetText(text)
    button:SetNormalFontColor(0.85, 0.78, 0.62, 1)
    button:SetMouseOverFontColor(1, 1, 1, 1)
    return button
end

function Share:New(owner)
    return setmetatable({ owner = owner }, { __index = self })
end

function Share:Initialize()
    local window = WINDOW_MANAGER:CreateTopLevelWindow("GravvyBuildPlannerShareWindow")
    window:SetDimensions(700, 390)
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetClampedToScreen(true)
    window:SetMouseEnabled(true)
    window:SetMovable(true)
    window:SetHidden(true)
    window:SetDrawTier(DT_HIGH)
    self.window = window

    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(nil, window, "ZO_DefaultBackdrop")
    backdrop:SetAnchorFill(window)
    GravvyBuildPlannerAccessibility:RegisterBackdrop(
        backdrop,
        { 0.035, 0.035, 0.045, 0.99 },
        { 0.5, 0.42, 0.28, 0.95 }
    )
    local title = makeLabel(
        window,
        GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_TITLE),
        18,
        10,
        664,
        "ZoFontWinH2"
    )
    title:SetMouseEnabled(true)
    title:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            window:StartMoving()
        end
    end)
    title:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            window:StopMovingOrResizing()
        end
    end)
    local help = makeLabel(window, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_HELP), 18, 48, 664)
    help:SetHeight(52)
    help:SetVerticalAlignment(TEXT_ALIGN_TOP)

    local editBackdrop = WINDOW_MANAGER:CreateControlFromVirtual(nil, window, "ZO_EditBackdrop")
    editBackdrop:SetAnchor(TOPLEFT, window, TOPLEFT, 18, 106)
    editBackdrop:SetDimensions(664, 190)
    local edit = WINDOW_MANAGER:CreateControlFromVirtual(nil, editBackdrop, "ZO_DefaultEditMultiLineForBackdrop")
    edit:ClearAnchors()
    edit:SetAnchor(TOPLEFT, editBackdrop, TOPLEFT, 5, 4)
    edit:SetAnchor(BOTTOMRIGHT, editBackdrop, BOTTOMRIGHT, -5, -4)
    GravvyBuildPlannerAccessibility:SetFont(edit, "ZoFontGame")
    edit:SetMaxInputChars(MAX_CODE_LENGTH)
    edit:SetNewLineEnabled(true)
    edit:SetSelectAllOnFocus(true)
    edit:SetHandler("OnEscape", function() self:Hide() end)
    self.codeEdit = edit

    self.status = makeLabel(window, "", 18, 302, 664, "ZoFontGameSmall")
    local export = makeButton(window, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_EXPORT), 120)
    export:SetAnchor(BOTTOMLEFT, window, BOTTOMLEFT, 18, -16)
    export:SetHandler("OnClicked", function() self:ExportCurrent() end)
    local selectCode = makeButton(window, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_SELECT), 100)
    selectCode:SetAnchor(LEFT, export, RIGHT, 8, 0)
    selectCode:SetHandler("OnClicked", function() self:SelectCode() end)
    local import = makeButton(window, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_IMPORT), 120)
    import:SetAnchor(LEFT, selectCode, RIGHT, 8, 0)
    import:SetHandler("OnClicked", function() self:ImportCode() end)
    local close = makeButton(window, GetString(SI_GRAVVY_BUILD_PLANNER_CLOSE), 80)
    close:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, -18, -16)
    close:SetHandler("OnClicked", function() self:Hide() end)
end

function Share:SetStatus(message, isError)
    if self.owner.accessibility then
        message = self.owner.accessibility:FormatStatus(message, isError)
    end
    self.status:SetText(message or "")
    self.status:SetColor(isError and 1 or 0.65, isError and 0.35 or 0.82, isError and 0.35 or 0.55, 1)
end

function Share:Open()
    self.window:SetHidden(false)
    self:ExportCurrent()
end

function Share:Hide()
    if self.codeEdit.LoseFocus then
        self.codeEdit:LoseFocus()
    end
    self.window:SetHidden(true)
end

function Share:SelectCode()
    self.codeEdit:TakeFocus()
    if self.codeEdit.SelectAll then
        self.codeEdit:SelectAll()
    end
    self:SetStatus(GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_COPY_HINT))
end

function Share:ExportCurrent()
    local code, message = Share.EncodeBuild(self.owner.data:GetCurrentBuild())
    if not code then
        self:SetStatus(message, true)
        return
    end
    self.codeEdit:SetText(code)
    self:SelectCode()
end

function Share:ImportCode()
    local decoded, message = Share.DecodeCode(self.codeEdit:GetText())
    if not decoded then
        self:SetStatus(message, true)
        return
    end
    local build, importMessage = self.owner.data:ImportBuild(decoded)
    if not build then
        self:SetStatus(importMessage, true)
        return
    end
    self.owner.setCatalog:Refresh()
    self.owner.inventory:QueueRefresh(0)
    self.owner.ui:Refresh()
    self.owner.gamepad:Refresh(true)
    self:Hide()
    self.owner.ui:SetStatus(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_SHARE_IMPORTED,
        build.name,
        #build.setups
    ))
end
