GravvyBuildPlannerShoppingIntegration = {}

local Shopping = GravvyBuildPlannerShoppingIntegration
local Slots = GravvyBuildPlannerSlots
local Validation = GravvyBuildPlannerValidation
local ADDON_URL = "https://www.esoui.com/downloads/info4775-ShoppingList.html"
local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

local function trim(value)
    return zo_strtrim(tostring(value or ""))
end

local function limit(value, maximum)
    value = tostring(value or "")
    if #value > maximum then
        return string.sub(value, 1, maximum)
    end
    return value
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
    value = tostring(value or "")
    appendU16(parts, #value)
    parts[#parts + 1] = value
end

local function optionalU16(value)
    return value == nil and 0 or value + 1
end

local function optionalU32(value)
    return value == nil and 0 or value + 1
end

local function checksum(value)
    local first, second = 1, 0
    for index = 1, #value do
        first = (first + string.byte(value, index)) % 65521
        second = (second + first) % 65521
    end
    return (second * 65536) + first
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

local qualityModeValues = { any = 0, minimum = 1, exact = 2 }
local levelModeValues = { any = 0, exact = 1 }

function Shopping:New(owner)
    return setmetatable({ owner = owner }, { __index = self })
end

function Shopping:GetAPI()
    local api = GravvyShoppingList and GravvyShoppingList.API
    if not api or type(api.GetVersion) ~= "function" then
        return nil, "missing"
    end
    local ok, version = pcall(function() return api:GetVersion() end)
    if not ok or type(version) ~= "number" or version < 2
        or type(api.CreateList) ~= "function" then
        return nil, "old"
    end
    return api, "ready"
end

function Shopping:GetAddonURL()
    return ADDON_URL
end

function Shopping:ValidateReview(review)
    if type(review) ~= "table" or type(review.items) ~= "table"
        or #review.items > 500 or type(review.name) ~= "string"
        or #review.name > Validation.MAX_STRING or type(review.note) ~= "string"
        or #review.note > 2000 then
        return false
    end
    for _, item in ipairs(review.items) do
        local match = type(item) == "table" and item.match or nil
        if type(item) ~= "table" or not Validation:IsItemLink(item.itemLink or "")
            or not Validation:WholeNumber(item.quantity or 1, 1, 1000000)
            or type(item.note or "") ~= "string" or #(item.note or "") > 2000
            or type(match) ~= "table" then
            return false
        end
        if match.quality ~= nil and not Validation:IsQuality(match.quality) then return false end
        if match.level ~= nil and not Validation:IsLevel(match.level) then return false end
        if match.championPoints ~= nil
            and not Validation:IsChampionPoints(match.championPoints) then return false end
        if match.traitType ~= nil
            and not Validation:WholeNumber(match.traitType, 0, 255) then return false end
        if match.setName ~= nil
            and not Validation:SanitizePlainText(match.setName, Validation.MAX_STRING, true) then
            return false
        end
    end
    return true
end

local function itemNote(slotKey, requirement, setup)
    local parts = { GetString(({
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
    })[slotKey]) }
    local quality = requirement.quality or setup.defaultQuality
    if quality then
        parts[#parts + 1] = zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_EXPORT_TARGET_QUALITY,
            GetString("SI_ITEMQUALITY", quality)
        )
    end
    if requirement.enchantmentName and requirement.enchantmentName ~= "" then
        parts[#parts + 1] = zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_EXPORT_TARGET_ENCHANTMENT,
            requirement.enchantmentName
        )
    end
    if requirement.note and requirement.note ~= "" then
        parts[#parts + 1] = requirement.note
    end
    return limit(table.concat(parts, " · "), 2000)
end

function Shopping:BuildReview(includeOwned, includeGlyphs)
    local setup, build = self.owner.data:GetCurrentSetup()
    local review = {
        name = build.name .. " - " .. setup.name,
        note = zo_strformat(SI_GRAVVY_BUILD_PLANNER_EXPORT_LIST_NOTE, setup.name),
        items = {},
        included = 0,
        glyphs = 0,
        excluded = 0,
        owned = 0,
        includeOwned = includeOwned == true,
        includeGlyphs = includeGlyphs == true,
    }
    if build.sourceUrl and build.sourceUrl ~= "" then
        review.note = review.note .. "\n" .. zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_EXPORT_SOURCE,
            build.sourceUrl
        )
    end
    review.name = limit(review.name, 512)
    review.note = limit(review.note, 2000)

    local glyphs = {}
    local glyphOrder = {}
    local function needsGlyph(match)
        if not match then
            return true
        end
        for _, difference in ipairs(match.differences or {}) do
            if difference == "enchantment" then
                return true
            end
        end
        return false
    end
    local function addGlyph(requirement)
        local level, championPoints = self.owner.itemResolver:GetRequestedLevel(
            requirement,
            setup
        )
        local quality = requirement.quality or setup.defaultQuality
        local glyphLink, glyphName = self.owner.itemResolver:CreateGlyphLink(
            requirement.enchantmentCategory,
            requirement,
            setup,
            quality
        )
        if not glyphLink then
            return
        end
        local entry = glyphs[glyphLink]
        if entry then
            entry.quantity = entry.quantity + 1
        else
            entry = {
                itemLink = glyphLink,
                quantity = 1,
                note = zo_strformat(
                    SI_GRAVVY_BUILD_PLANNER_EXPORT_GLYPH_NOTE,
                    glyphName
                ),
                match = {
                    qualityMode = "exact",
                    quality = quality,
                    levelMode = "exact",
                    level = level,
                    championPoints = championPoints,
                },
            }
            glyphs[glyphLink] = entry
            glyphOrder[#glyphOrder + 1] = glyphLink
        end
        review.glyphs = review.glyphs + 1
    end
    local function chooseRequirement(slotKey, owned)
        if owned then
            return self.owner.inventory:GetMatchedRequirement(setup.id, slotKey, setup)
        end
        local choices = { setup.equipment[slotKey] }
        for _, alternative in ipairs(self.owner.data:GetAlternatives(setup, slotKey)) do
            choices[#choices + 1] = alternative
        end
        for index, candidate in ipairs(choices) do
            local resolved = self.owner.itemResolver:Resolve(slotKey, candidate, setup)
            local state = self.owner.acquisition:Classify(
                slotKey,
                candidate,
                setup,
                resolved
            )
            local itemLink = resolved and resolved.itemLink or candidate.itemLink
            if state.tradeable and not state.bindOnPickup and itemLink and itemLink ~= "" then
                return candidate, index > 1 and index - 1 or nil, resolved
            end
        end
    end
    for _, slotKey in ipairs(Slots.ORDER) do
        local primary = setup.equipment[slotKey]
        if primary then
            local owned = self.owner.inventory:GetMatch(setup.id, slotKey)
            local requirement, alternativeIndex, resolved = chooseRequirement(slotKey, owned)
            if review.includeGlyphs
                and requirement
                and requirement.enchantmentCategory
                and needsGlyph(owned) then
                addGlyph(requirement)
            end
            if owned and not review.includeOwned then
                review.owned = review.owned + 1
            elseif not requirement then
                review.excluded = review.excluded + 1
            else
                resolved = resolved or self.owner.itemResolver:Resolve(
                    slotKey,
                    requirement,
                    setup
                )
                local state = self.owner.acquisition:Classify(
                    slotKey,
                    requirement,
                    setup,
                    resolved
                )
                local itemLink = resolved and resolved.itemLink or requirement.itemLink
                if state.tradeable and not state.bindOnPickup
                    and itemLink and itemLink ~= "" then
                    local level, championPoints = self.owner.itemResolver:GetRequestedLevel(
                        requirement,
                        setup
                    )
                    local note = itemNote(slotKey, requirement, setup)
                    if alternativeIndex then
                        note = zo_strformat(
                            SI_GRAVVY_BUILD_PLANNER_ALTERNATIVE_NOTE,
                            alternativeIndex,
                            note
                        )
                    end
                    review.items[#review.items + 1] = {
                        itemLink = itemLink,
                        quantity = 1,
                        note = note,
                        match = {
                            setName = requirement.setName,
                            traitType = requirement.traitType or ITEM_TRAIT_TYPE_NONE,
                            qualityMode = "any",
                            quality = requirement.quality or setup.defaultQuality,
                            levelMode = "exact",
                            level = level,
                            championPoints = championPoints,
                        },
                    }
                    review.included = review.included + 1
                else
                    review.excluded = review.excluded + 1
                end
            end
        end
    end
    for _, glyphLink in ipairs(glyphOrder) do
        review.items[#review.items + 1] = glyphs[glyphLink]
    end
    return review
end

function Shopping:CreateList(review)
    if not self:ValidateReview(review) then
        return false, "INVALID_DATA"
    end
    local api, state = self:GetAPI()
    if not api then
        return false, state
    end
    local ok, success, result, itemIndex = pcall(api.CreateList, api, {
        name = review.name,
        note = review.note,
        items = review.items,
        onNameConflict = "unique",
        select = true,
    })
    if not ok then
        return false, "API_ERROR"
    end
    return success, result, itemIndex
end

function Shopping:Encode(review)
    if not self:ValidateReview(review) then
        return nil
    end
    local parts = { string.char(2) }
    appendString(parts, review.name)
    appendString(parts, review.note)
    appendU16(parts, #review.items)

    for _, item in ipairs(review.items) do
        local itemLink = item.itemLink or ""
        local name = item.name or zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(itemLink) or "")
        local match = item.match or {}
        local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(itemLink, false)
        if not hasSet then
            setName, setId = "", 0
        end
        if match.setName and match.setName ~= "" then
            if trim(setName) ~= ""
                and zo_strlower(trim(setName)) ~= zo_strlower(trim(match.setName)) then
                setId = 0
            end
            setName = match.setName
        end
        appendString(parts, name)
        appendU32(parts, item.quantity or 1)
        appendString(parts, itemLink)
        appendString(parts, item.note)
        appendString(parts, setName)
        appendU32(parts, setId or 0)
        appendU16(parts, optionalU16(match.traitType))
        parts[#parts + 1] = string.char(qualityModeValues[match.qualityMode or "any"])
        appendU16(parts, optionalU16(match.quality))
        parts[#parts + 1] = string.char(levelModeValues[match.levelMode or "any"])
        appendU16(parts, optionalU16(match.level))
        appendU32(parts, optionalU32(match.championPoints))
        appendU32(parts, 0)
    end

    local body = table.concat(parts)
    local payload = { body }
    appendU32(payload, checksum(body))
    local code = "SL2:" .. encodeBase64(table.concat(payload))
    return #code <= 20000 and code or nil
end
