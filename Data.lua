GravvyBuildPlannerData = {}

local Data = GravvyBuildPlannerData
local SCHEMA_VERSION = 4
local MAX_DELETED_ACTIONS = 20
local MAX_NOTE_LENGTH = 4000
local MAX_ALTERNATIVES = 8
local DEFAULT_QUALITY = ITEM_QUALITY_LEGENDARY or 5
local validAcquisitionRoutes = {
    buy = true,
    craft = true,
    farm = true,
    reconstruct = true,
    transmute = true,
    unknown = true,
}

local defaults = {
    schemaVersion = SCHEMA_VERSION,
    nextBuildId = 1,
    nextSetupId = 1,
    selectedBuildId = nil,
    deletedActions = {},
    builds = {},
    settings = {
        window = {},
        fontScale = 1,
        highContrast = false,
        nonColorIndicators = false,
    },
}

local stringFields = {
    "setName",
    "itemName",
    "itemLink",
    "enchantmentName",
    "note",
}

local numberFields = {
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

local function trim(value)
    return zo_strtrim(type(value) == "string" and value or "")
end

local function normalizeNote(value)
    value = tostring(value or "")
    if #value > MAX_NOTE_LENGTH then
        value = string.sub(value, 1, MAX_NOTE_LENGTH)
    end
    return value
end

local function now()
    return GetTimeStamp and GetTimeStamp() or 0
end

local function deepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end
    local copy = {}
    seen[value] = copy
    for key, entry in pairs(value) do
        copy[deepCopy(key, seen)] = deepCopy(entry, seen)
    end
    return copy
end

local function sameName(left, right)
    return zo_strlower(trim(left)) == zo_strlower(trim(right))
end

local function makeUniqueName(seen, baseName)
    local name = baseName
    local suffix = 2
    while seen[zo_strlower(name)] do
        name = baseName .. " " .. tostring(suffix)
        suffix = suffix + 1
    end
    seen[zo_strlower(name)] = true
    return name
end

local function copyRequirement(source)
    if type(source) ~= "table" then
        return nil
    end

    local copy = {}
    for _, key in ipairs(stringFields) do
        local value = source[key]
        if value ~= nil then
            if type(value) ~= "string" then
                return nil
            end
            if key == "note" then
                copy[key] = normalizeNote(value)
            elseif key == "itemLink" then
                copy[key] = value
            else
                copy[key] = trim(value)
            end
        end
    end
    for _, key in ipairs(numberFields) do
        local value = source[key]
        if value ~= nil then
            value = tonumber(value)
            if not value or value ~= math.floor(value) or value < 0 then
                return nil
            end
            copy[key] = value
        end
    end
    return copy
end

local function sameSet(left, right)
    if left.setId and right.setId then
        return left.setId == right.setId
    end
    local leftName = zo_strlower(trim(left.setName))
    local rightName = zo_strlower(trim(right.setName))
    return leftName ~= "" and leftName == rightName
end

local function normalizeAlternative(slotKey, source, primary)
    local requirement = copyRequirement(source)
    if not requirement
        or not GravvyBuildPlannerSlots:IsRequirementCompatible(slotKey, requirement) then
        return nil
    end
    local occupiedOffHand = GravvyBuildPlannerSlots:GetOccupiedOffHand(
        slotKey,
        requirement.weaponType
    )
    requirement.occupiesOffHand = occupiedOffHand ~= nil
    if primary and requirement.occupiesOffHand ~= (primary.occupiesOffHand == true) then
        return nil
    end
    return requirement
end

local function copySkill(source, slotIndex)
    if type(source) ~= "table" then
        return nil
    end
    local abilityId = tonumber(source.abilityId)
    if not abilityId or abilityId ~= math.floor(abilityId) or abilityId < 1
        or type(source.name) ~= "string" or type(source.icon) ~= "string"
        or source.isUltimate ~= (slotIndex == 6) then
        return nil
    end
    return {
        abilityId = abilityId,
        name = trim(source.name),
        icon = source.icon,
        isUltimate = source.isUltimate,
    }
end

local function copySkillBars(source, strict)
    local bars = { front = {}, back = {} }
    source = type(source) == "table" and source or {}
    for _, barKey in ipairs({ "front", "back" }) do
        local bar = source[barKey]
        if bar ~= nil and type(bar) ~= "table" then
            return strict and nil or bars
        end
        for slotIndex, entry in pairs(bar or {}) do
            slotIndex = tonumber(slotIndex)
            local skill = slotIndex and copySkill(entry, slotIndex)
            if skill and slotIndex >= 1 and slotIndex <= 6 then
                bars[barKey][slotIndex] = skill
            elseif strict then
                return nil
            end
        end
    end
    return bars
end

local function readWholeNumber(value, minimum)
    value = tonumber(value)
    if not value or value ~= math.floor(value) or value < minimum then
        return nil
    end
    return value
end

local function copyBuildChanges(values)
    if type(values) ~= "table" then
        return nil
    end

    local changes = {}
    if values.classId ~= nil then
        changes.classId = readWholeNumber(values.classId, 0)
        if not changes.classId then
            return nil
        end
    end
    for _, key in ipairs({ "role", "patch", "author", "sourceUrl" }) do
        if values[key] ~= nil then
            if type(values[key]) ~= "string" then
                return nil
            end
            changes[key] = trim(values[key])
        end
    end
    if values.notes ~= nil then
        if type(values.notes) ~= "string" then
            return nil
        end
        changes.notes = normalizeNote(values.notes)
    end
    return changes
end

local function copySetupChanges(values)
    if type(values) ~= "table" then
        return nil
    end

    local changes = {}
    if values.note ~= nil then
        if type(values.note) ~= "string" then
            return nil
        end
        changes.note = normalizeNote(values.note)
    end
    for _, entry in ipairs({
        { "defaultQuality", 0 },
        { "defaultLevel", 1 },
        { "defaultChampionPoints", 0 },
    }) do
        local key, minimum = entry[1], entry[2]
        if values[key] ~= nil then
            changes[key] = readWholeNumber(values[key], minimum)
            if not changes[key] then
                return nil
            end
        end
    end
    return changes
end

local function setupNameExists(build, name, exceptId)
    for _, setup in ipairs(build.setups) do
        if setup.id ~= exceptId and sameName(setup.name, name) then
            return true
        end
    end
    return false
end

local function uniqueSetupName(build, baseName, exceptId)
    local name = baseName
    local suffix = 2
    while setupNameExists(build, name, exceptId) do
        name = baseName .. " " .. tostring(suffix)
        suffix = suffix + 1
    end
    return name
end

function Data:New()
    local data = setmetatable({}, { __index = self })
    data.saved = ZO_SavedVars:NewAccountWide(
        "GravvyBuildPlanner_Data",
        1,
        nil,
        defaults,
        GetWorldName()
    )
    data:Migrate()
    return data
end

function Data:Migrate()
    local saved = self.saved
    saved.builds = type(saved.builds) == "table" and saved.builds or {}
    saved.deletedActions = type(saved.deletedActions) == "table" and saved.deletedActions or {}
    saved.settings = type(saved.settings) == "table" and saved.settings or {}
    saved.settings.window = type(saved.settings.window) == "table" and saved.settings.window or {}
    saved.settings.fontScale = zo_clamp(
        tonumber(saved.settings.fontScale) or 1,
        0.9,
        1.4
    )
    saved.settings.highContrast = saved.settings.highContrast == true
    saved.settings.nonColorIndicators = saved.settings.nonColorIndicators == true
    local window = saved.settings.window
    window.left = tonumber(window.left)
    window.top = tonumber(window.top)
    while #saved.deletedActions > MAX_DELETED_ACTIONS do
        table.remove(saved.deletedActions, 1)
    end

    local builds = {}
    for _, build in ipairs(saved.builds) do
        if type(build) == "table" then
            builds[#builds + 1] = build
        end
    end
    saved.builds = builds

    local highestBuildId = 0
    local highestSetupId = 0
    local usedBuildIds = {}
    local usedSetupIds = {}
    local usedBuildNames = {}
    for _, build in ipairs(saved.builds) do
        local buildId = readWholeNumber(build.id, 1)
        if not buildId or usedBuildIds[buildId] then
            buildId = highestBuildId + 1
        end
        build.id = buildId
        usedBuildIds[buildId] = true
        highestBuildId = math.max(highestBuildId, build.id)
        build.name = trim(build.name)
        if build.name == "" then
            build.name = GetString(SI_GRAVVY_BUILD_PLANNER_DEFAULT_BUILD)
        end
        build.name = makeUniqueName(usedBuildNames, build.name)
        build.classId = readWholeNumber(build.classId, 0)
        build.role = trim(build.role)
        build.patch = trim(build.patch)
        build.author = trim(build.author)
        build.sourceUrl = trim(build.sourceUrl)
        build.notes = normalizeNote(build.notes)
        build.createdAt = readWholeNumber(build.createdAt, 0) or now()
        build.updatedAt = readWholeNumber(build.updatedAt, 0) or build.createdAt
        local setups = {}
        if type(build.setups) == "table" then
            for _, setup in ipairs(build.setups) do
                if type(setup) == "table" then
                    setups[#setups + 1] = setup
                end
            end
        end
        build.setups = setups

        local usedSetupNames = {}
        for _, setup in ipairs(build.setups) do
            local setupId = readWholeNumber(setup.id, 1)
            if not setupId or usedSetupIds[setupId] then
                setupId = highestSetupId + 1
            end
            setup.id = setupId
            usedSetupIds[setupId] = true
            highestSetupId = math.max(highestSetupId, setup.id)
            setup.name = trim(setup.name)
            if setup.name == "" then
                setup.name = GetString(SI_GRAVVY_BUILD_PLANNER_DEFAULT_SETUP)
            end
            setup.name = makeUniqueName(usedSetupNames, setup.name)
            setup.note = normalizeNote(setup.note)
            setup.defaultQuality = math.max(0, math.floor(tonumber(setup.defaultQuality) or DEFAULT_QUALITY))
            setup.defaultLevel = math.max(1, math.floor(tonumber(setup.defaultLevel) or 50))
            setup.defaultChampionPoints = math.max(0, math.floor(tonumber(setup.defaultChampionPoints) or 160))
            setup.equipment = type(setup.equipment) == "table" and setup.equipment or {}
            setup.alternatives = type(setup.alternatives) == "table"
                and setup.alternatives
                or {}
            setup.alternativeGroups = nil
            setup.skillBars = copySkillBars(setup.skillBars, false)
            setup.acquisition = type(setup.acquisition) == "table" and setup.acquisition or {}
            setup.slotStates = nil
            setup.createdAt = readWholeNumber(setup.createdAt, 0) or now()
            setup.updatedAt = readWholeNumber(setup.updatedAt, 0) or setup.createdAt

            for slotKey, requirement in pairs(setup.equipment) do
                if not GravvyBuildPlannerSlots:IsValid(slotKey) then
                    setup.equipment[slotKey] = nil
                else
                    requirement = copyRequirement(requirement)
                    if requirement and GravvyBuildPlannerSlots:IsRequirementCompatible(slotKey, requirement) then
                        setup.equipment[slotKey] = requirement
                    else
                        setup.equipment[slotKey] = nil
                    end
                end
            end
            for slotKey, state in pairs(setup.acquisition) do
                if not GravvyBuildPlannerSlots:IsValid(slotKey) or type(state) ~= "table" then
                    setup.acquisition[slotKey] = nil
                elseif not setup.equipment[slotKey]
                    or not validAcquisitionRoutes[state.preferredRoute] then
                    setup.acquisition[slotKey] = nil
                else
                    setup.acquisition[slotKey] = {
                        preferredRoute = state.preferredRoute,
                    }
                end
            end
            for _, mainHand in ipairs({ "frontMain", "backMain" }) do
                local requirement = setup.equipment[mainHand]
                local offHand = requirement and GravvyBuildPlannerSlots:GetOccupiedOffHand(
                    mainHand,
                    requirement.weaponType
                )
                if offHand then
                    requirement.occupiesOffHand = true
                    setup.equipment[offHand] = nil
                end
            end
            for slotKey, entries in pairs(setup.alternatives) do
                local primary = setup.equipment[slotKey]
                if not primary or type(entries) ~= "table" then
                    setup.alternatives[slotKey] = nil
                else
                    local alternatives = {}
                    for _, entry in ipairs(entries) do
                        local requirement = normalizeAlternative(slotKey, entry, primary)
                        if requirement and #alternatives < MAX_ALTERNATIVES then
                            alternatives[#alternatives + 1] = requirement
                        end
                    end
                    setup.alternatives[slotKey] = #alternatives > 0 and alternatives or nil
                end
            end
        end
    end

    saved.nextBuildId = math.max(
        math.floor(tonumber(saved.nextBuildId) or 1),
        highestBuildId + 1
    )
    saved.nextSetupId = math.max(
        math.floor(tonumber(saved.nextSetupId) or 1),
        highestSetupId + 1
    )
    saved.schemaVersion = SCHEMA_VERSION

    if #saved.builds == 0 then
        self:CreateBuild(GetString(SI_GRAVVY_BUILD_PLANNER_DEFAULT_BUILD))
        return
    end

    for _, build in ipairs(saved.builds) do
        if #build.setups == 0 then
            self:CreateSetup(build.id, GetString(SI_GRAVVY_BUILD_PLANNER_DEFAULT_SETUP))
        elseif not self:FindSetup(build, build.selectedSetupId) then
            build.selectedSetupId = build.setups[1].id
        end
    end
    if not self:FindBuild(saved.selectedBuildId) then
        saved.selectedBuildId = saved.builds[1].id
    end
end

function Data:GetBuilds()
    return self.saved.builds
end

function Data:GetSettings()
    return self.saved.settings
end

function Data:FindBuild(id)
    for index, build in ipairs(self.saved.builds) do
        if build.id == id then
            return build, index
        end
    end
end

function Data:FindSetup(build, id)
    if not build then
        return nil
    end
    for index, setup in ipairs(build.setups) do
        if setup.id == id then
            return setup, index
        end
    end
end

function Data:GetCurrentBuild()
    local build = self:FindBuild(self.saved.selectedBuildId)
    if not build then
        build = self.saved.builds[1]
        self.saved.selectedBuildId = build.id
    end
    return build
end

function Data:GetCurrentSetup()
    local build = self:GetCurrentBuild()
    local setup = self:FindSetup(build, build.selectedSetupId)
    if not setup then
        setup = build.setups[1]
        build.selectedSetupId = setup.id
    end
    return setup, build
end

function Data:BuildNameExists(name, exceptId)
    for _, build in ipairs(self.saved.builds) do
        if build.id ~= exceptId and sameName(build.name, name) then
            return true
        end
    end
    return false
end

function Data:GetUniqueBuildName(baseName, exceptId)
    local name = baseName
    local suffix = 2
    while self:BuildNameExists(name, exceptId) do
        name = baseName .. " " .. tostring(suffix)
        suffix = suffix + 1
    end
    return name
end

function Data:CreateBuild(name, values)
    name = trim(name)
    if name == "" then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_NAME)
    end
    if self:BuildNameExists(name) then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_EXISTS)
    end
    local changes = copyBuildChanges(values or {})
    if not changes then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_REQUIREMENT)
    end

    local build = {
        id = self.saved.nextBuildId,
        name = name,
        classId = changes.classId,
        role = changes.role or "",
        patch = changes.patch or "",
        author = changes.author or "",
        sourceUrl = changes.sourceUrl or "",
        notes = changes.notes or "",
        setups = {},
        createdAt = now(),
        updatedAt = now(),
    }
    self.saved.nextBuildId = self.saved.nextBuildId + 1
    self.saved.builds[#self.saved.builds + 1] = build
    self.saved.selectedBuildId = build.id

    local setup = self:CreateSetup(build.id, GetString(SI_GRAVVY_BUILD_PLANNER_DEFAULT_SETUP))
    build.selectedSetupId = setup.id
    return build
end

function Data:UpdateBuild(id, values)
    local build = self:FindBuild(id)
    if not build then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_MISSING)
    end
    local changes = copyBuildChanges(values)
    if not changes then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_REQUIREMENT)
    end
    if values.name ~= nil then
        local name = trim(values.name)
        if name == "" then
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_NAME)
        end
        if self:BuildNameExists(name, build.id) then
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_EXISTS)
        end
        build.name = name
    end

    for key, value in pairs(changes) do
        build[key] = value
    end
    build.updatedAt = now()
    return true, build
end

function Data:RenameBuild(id, name)
    return self:UpdateBuild(id, { name = name })
end

function Data:DuplicateBuild(id, name)
    local source = self:FindBuild(id)
    if not source then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_MISSING)
    end

    if name ~= nil and type(name) ~= "string" then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_NAME)
    end
    name = trim(name)
    if name == "" then
        name = self:GetUniqueBuildName(zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_COPIED_BUILD_NAME,
            source.name
        ))
    end
    if self:BuildNameExists(name) then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_EXISTS)
    end

    local timestamp = now()
    local build = {
        id = self.saved.nextBuildId,
        name = name,
        classId = source.classId,
        role = source.role,
        patch = source.patch,
        author = source.author,
        sourceUrl = source.sourceUrl,
        notes = source.notes,
        setups = {},
        createdAt = timestamp,
        updatedAt = timestamp,
    }
    self.saved.nextBuildId = self.saved.nextBuildId + 1

    for _, sourceSetup in ipairs(source.setups) do
        local setup = {
            id = self.saved.nextSetupId,
            name = sourceSetup.name,
            note = sourceSetup.note,
            defaultQuality = sourceSetup.defaultQuality,
            defaultLevel = sourceSetup.defaultLevel,
            defaultChampionPoints = sourceSetup.defaultChampionPoints,
            equipment = deepCopy(sourceSetup.equipment),
            alternatives = deepCopy(sourceSetup.alternatives),
            skillBars = deepCopy(sourceSetup.skillBars) or { front = {}, back = {} },
            acquisition = {},
            createdAt = timestamp,
            updatedAt = timestamp,
        }
        self.saved.nextSetupId = self.saved.nextSetupId + 1
        build.setups[#build.setups + 1] = setup
        if sourceSetup.id == source.selectedSetupId then
            build.selectedSetupId = setup.id
        end
    end
    build.selectedSetupId = build.selectedSetupId or build.setups[1].id

    self.saved.builds[#self.saved.builds + 1] = build
    self.saved.selectedBuildId = build.id
    return build
end

function Data:ImportBuild(source)
    if type(source) ~= "table" or type(source.setups) ~= "table" or #source.setups == 0 then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
    end

    local name = trim(source.name)
    local changes = copyBuildChanges(source)
    if name == "" or not changes then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
    end

    local timestamp = now()
    local build = {
        id = self.saved.nextBuildId,
        name = self:GetUniqueBuildName(name),
        classId = changes.classId,
        role = changes.role or "",
        patch = changes.patch or "",
        author = changes.author or "",
        sourceUrl = changes.sourceUrl or "",
        notes = changes.notes or "",
        setups = {},
        createdAt = timestamp,
        updatedAt = timestamp,
    }

    local usedNames = {}
    for _, sourceSetup in ipairs(source.setups) do
        if type(sourceSetup) ~= "table" or type(sourceSetup.equipment) ~= "table" then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end
        local setupName = trim(sourceSetup.name)
        local setupChanges = copySetupChanges(sourceSetup)
        if setupName == "" or not setupChanges then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end
        setupName = makeUniqueName(usedNames, setupName)

        local equipment = {}
        for slotKey, sourceRequirement in pairs(sourceSetup.equipment) do
            local requirement = copyRequirement(sourceRequirement)
            if not GravvyBuildPlannerSlots:IsValid(slotKey)
                or not requirement
                or not GravvyBuildPlannerSlots:IsRequirementCompatible(slotKey, requirement) then
                return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
            end
            equipment[slotKey] = requirement
        end
        for _, mainHand in ipairs({ "frontMain", "backMain" }) do
            local requirement = equipment[mainHand]
            local offHand = requirement and GravvyBuildPlannerSlots:GetOccupiedOffHand(
                mainHand,
                requirement.weaponType
            )
            if offHand then
                if equipment[offHand] then
                    return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                end
                requirement.occupiesOffHand = true
            end
        end

        local acquisition = {}
        if sourceSetup.acquisition ~= nil and type(sourceSetup.acquisition) ~= "table" then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end
        for slotKey, state in pairs(sourceSetup.acquisition or {}) do
            if equipment[slotKey]
                and type(state) == "table"
                and validAcquisitionRoutes[state.preferredRoute] then
                acquisition[slotKey] = { preferredRoute = state.preferredRoute }
            else
                return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
            end
        end

        local alternatives = {}
        if sourceSetup.alternatives ~= nil and type(sourceSetup.alternatives) ~= "table" then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end
        for slotKey, entries in pairs(sourceSetup.alternatives or {}) do
            local primary = equipment[slotKey]
            if not primary or type(entries) ~= "table" or #entries > MAX_ALTERNATIVES then
                return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
            end
            alternatives[slotKey] = {}
            for _, entry in ipairs(entries) do
                local requirement = normalizeAlternative(slotKey, entry, primary)
                if not requirement then
                    return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
                end
                alternatives[slotKey][#alternatives[slotKey] + 1] = requirement
            end
        end
        local skillBars = copySkillBars(sourceSetup.skillBars, true)
        if not skillBars then
            return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
        end

        build.setups[#build.setups + 1] = {
            id = self.saved.nextSetupId + #build.setups,
            name = setupName,
            note = setupChanges.note or "",
            defaultQuality = setupChanges.defaultQuality or DEFAULT_QUALITY,
            defaultLevel = setupChanges.defaultLevel or 50,
            defaultChampionPoints = setupChanges.defaultChampionPoints or 160,
            equipment = equipment,
            alternatives = alternatives,
            skillBars = skillBars,
            acquisition = acquisition,
            createdAt = timestamp,
            updatedAt = timestamp,
        }
    end

    local selectedIndex = source.selectedSetupIndex == nil
        and 1
        or readWholeNumber(source.selectedSetupIndex, 1)
    if not selectedIndex or selectedIndex > #build.setups then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_SHARE_ERROR_DATA)
    end
    build.selectedSetupId = build.setups[selectedIndex].id
    self.saved.nextBuildId = self.saved.nextBuildId + 1
    self.saved.nextSetupId = self.saved.nextSetupId + #build.setups
    self.saved.builds[#self.saved.builds + 1] = build
    self.saved.selectedBuildId = build.id
    return build
end

function Data:SelectBuild(id)
    local build = self:FindBuild(id)
    if not build then
        return false
    end
    self.saved.selectedBuildId = build.id
    return true
end

function Data:MoveBuild(id, direction)
    direction = tonumber(direction)
    if not direction or direction == 0 then
        return false
    end
    direction = direction < 0 and -1 or 1
    local _, index = self:FindBuild(id)
    local target = index and zo_clamp(index + direction, 1, #self.saved.builds)
    if not target or target == index then
        return false
    end
    local builds = self.saved.builds
    builds[index], builds[target] = builds[target], builds[index]
    return true
end

function Data:CreateSetup(buildId, name, source)
    local build = self:FindBuild(buildId)
    if not build then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_MISSING)
    end
    name = trim(name)
    if name == "" then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_NAME)
    end
    if setupNameExists(build, name) then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_EXISTS)
    end
    if source ~= nil and type(source) ~= "table" then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_REQUIREMENT)
    end

    local setup = {
        id = self.saved.nextSetupId,
        name = name,
        note = source and normalizeNote(source.note) or "",
        defaultQuality = source and source.defaultQuality or DEFAULT_QUALITY,
        defaultLevel = source and source.defaultLevel or 50,
        defaultChampionPoints = source and source.defaultChampionPoints or 160,
        equipment = source and deepCopy(source.equipment) or {},
        alternatives = source and deepCopy(source.alternatives) or {},
        skillBars = source and deepCopy(source.skillBars) or { front = {}, back = {} },
        acquisition = {},
        createdAt = now(),
        updatedAt = now(),
    }
    self.saved.nextSetupId = self.saved.nextSetupId + 1
    build.setups[#build.setups + 1] = setup
    build.selectedSetupId = setup.id
    build.updatedAt = now()
    return setup
end

function Data:DuplicateSetup(buildId, setupId, name)
    local build = self:FindBuild(buildId)
    if not build then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_MISSING)
    end
    local setup = self:FindSetup(build, setupId)
    if not setup then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_MISSING)
    end
    if name ~= nil and type(name) ~= "string" then
        return nil, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_NAME)
    end
    name = trim(name)
    if name == "" then
        name = uniqueSetupName(build, zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_COPIED_SETUP_NAME,
            setup.name
        ))
    end
    return self:CreateSetup(build.id, name, setup)
end

function Data:RenameSetup(buildId, setupId, name)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    if not setup then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_MISSING)
    end
    name = trim(name)
    if name == "" then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_NAME)
    end
    if setupNameExists(build, name, setup.id) then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_EXISTS)
    end
    setup.name = name
    setup.updatedAt = now()
    return true, setup
end

function Data:UpdateSetup(buildId, setupId, values)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    if not setup then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_MISSING)
    end
    local changes = copySetupChanges(values)
    if not changes then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_REQUIREMENT)
    end
    for key, value in pairs(changes) do
        setup[key] = value
    end
    setup.updatedAt = now()
    build.updatedAt = setup.updatedAt
    return true, setup
end

function Data:SelectSetup(buildId, setupId)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    if not setup then
        return false
    end
    self.saved.selectedBuildId = build.id
    build.selectedSetupId = setup.id
    return true
end

function Data:MoveSetup(buildId, setupId, direction)
    local build = self:FindBuild(buildId)
    direction = tonumber(direction)
    if not build or not direction or direction == 0 then
        return false
    end
    direction = direction < 0 and -1 or 1
    local _, index = self:FindSetup(build, setupId)
    local target = index and zo_clamp(index + direction, 1, #build.setups)
    if not target or target == index then
        return false
    end
    build.setups[index], build.setups[target] = build.setups[target], build.setups[index]
    build.updatedAt = now()
    return true
end

function Data:SetEquipment(buildId, setupId, slotKey, values)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    if not setup then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_MISSING)
    end
    if not GravvyBuildPlannerSlots:IsValid(slotKey) then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SLOT)
    end
    if values == nil then
        setup.equipment[slotKey] = nil
        setup.alternatives[slotKey] = nil
        setup.acquisition[slotKey] = nil
        setup.updatedAt = now()
        build.updatedAt = setup.updatedAt
        return true
    end

    local requirement = copyRequirement(values)
    if not requirement or not GravvyBuildPlannerSlots:IsRequirementCompatible(slotKey, requirement) then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_REQUIREMENT)
    end

    local mainHand = GravvyBuildPlannerSlots:GetMainHand(slotKey)
    if mainHand then
        local mainRequirement = setup.equipment[mainHand]
        if mainRequirement and mainRequirement.occupiesOffHand then
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SLOT_OCCUPIED)
        end
    end

    local clearedOffHand = GravvyBuildPlannerSlots:GetOccupiedOffHand(
        slotKey,
        requirement.weaponType
    )
    requirement.occupiesOffHand = clearedOffHand ~= nil
    setup.equipment[slotKey] = requirement
    local alternatives = setup.alternatives[slotKey]
    if alternatives then
        local compatible = {}
        for _, alternative in ipairs(alternatives) do
            alternative = normalizeAlternative(slotKey, alternative, requirement)
            if alternative then
                compatible[#compatible + 1] = alternative
            end
        end
        setup.alternatives[slotKey] = #compatible > 0 and compatible or nil
    end
    if clearedOffHand then
        setup.equipment[clearedOffHand] = nil
        setup.alternatives[clearedOffHand] = nil
        setup.acquisition[clearedOffHand] = nil
    end
    setup.updatedAt = now()
    build.updatedAt = setup.updatedAt
    return true, requirement, clearedOffHand
end

function Data:GetAlternatives(setup, slotKey)
    return setup and setup.alternatives and setup.alternatives[slotKey] or {}
end

function Data:SetSkill(buildId, setupId, barKey, slotIndex, values)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    slotIndex = tonumber(slotIndex)
    if not setup or (barKey ~= "front" and barKey ~= "back")
        or not slotIndex or slotIndex ~= math.floor(slotIndex)
        or slotIndex < 1 or slotIndex > 6 then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SKILL_SLOT)
    end
    setup.skillBars = setup.skillBars or { front = {}, back = {} }
    if values == nil then
        setup.skillBars[barKey][slotIndex] = nil
    else
        local skill = copySkill(values, slotIndex)
        if not skill then
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SKILL)
        end
        for otherSlot, otherSkill in pairs(setup.skillBars[barKey]) do
            if otherSlot ~= slotIndex and otherSkill.abilityId == skill.abilityId then
                return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SKILL_DUPLICATE)
            end
        end
        setup.skillBars[barKey][slotIndex] = skill
    end
    setup.updatedAt = now()
    build.updatedAt = setup.updatedAt
    return true
end

function Data:SetAlternative(buildId, setupId, slotKey, index, values)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    local primary = setup and setup.equipment[slotKey]
    if not primary then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SOURCE_SLOT_EMPTY)
    end

    local alternatives = setup.alternatives[slotKey] or {}
    index = tonumber(index) or (#alternatives + 1)
    if index ~= math.floor(index) or index < 1 or index > #alternatives + 1
        or index > MAX_ALTERNATIVES then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_ALTERNATIVE_LIMIT)
    end
    if values == nil then
        if not alternatives[index] then
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_REQUIREMENT)
        end
        table.remove(alternatives, index)
        setup.alternatives[slotKey] = #alternatives > 0 and alternatives or nil
    else
        local requirement = normalizeAlternative(slotKey, values, primary)
        if not requirement then
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_ALTERNATIVE)
        end
        alternatives[index] = requirement
        setup.alternatives[slotKey] = alternatives
    end
    setup.updatedAt = now()
    build.updatedAt = setup.updatedAt
    return true, values and alternatives[index] or nil
end

function Data:ApplySetAlternative(buildId, setupId, sourceSlot, alternativeIndex)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    local primary = setup and setup.equipment[sourceSlot]
    local source = primary and self:GetAlternatives(setup, sourceSlot)[alternativeIndex]
    if not source or trim(primary.setName) == "" or trim(source.setName) == "" then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_ALTERNATIVE)
    end

    local added = 0
    for _, slotKey in ipairs(GravvyBuildPlannerSlots.ORDER) do
        local planned = setup.equipment[slotKey]
        if planned and slotKey ~= sourceSlot and sameSet(planned, primary) then
            local replacement = copyRequirement(planned)
            replacement.setId = source.setId
            replacement.setName = source.setName
            replacement.itemLink = nil
            replacement.itemId = nil
            replacement.itemName = nil
            replacement.enchantmentId = nil
            local duplicate = false
            for _, existing in ipairs(self:GetAlternatives(setup, slotKey)) do
                if sameSet(existing, replacement) then
                    duplicate = true
                    break
                end
            end
            if not duplicate then
                local ok = self:SetAlternative(buildId, setupId, slotKey, nil, replacement)
                if ok then
                    added = added + 1
                end
            end
        end
    end
    return true, added
end

function Data:SetPreferredRoute(buildId, setupId, slotKey, route)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    if not setup or not setup.equipment[slotKey] then
        return false
    end
    if route ~= nil and not validAcquisitionRoutes[route] then
        return false
    end

    setup.acquisition[slotKey] = route and { preferredRoute = route } or nil
    setup.updatedAt = now()
    build.updatedAt = setup.updatedAt
    return true
end

local function transferEquipment(self, buildId, setupId, sourceSlot, targetSlot, move)
    local build = self:FindBuild(buildId)
    local setup = self:FindSetup(build, setupId)
    if not setup then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_MISSING)
    end

    local source = setup.equipment[sourceSlot]
    if not source then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SOURCE_SLOT_EMPTY)
    end
    if not GravvyBuildPlannerSlots:IsTransferCompatible(sourceSlot, targetSlot, source) then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_TRANSFER_SLOT)
    end

    local requirement = copyRequirement(source)
    requirement.itemLink = nil
    requirement.itemId = nil
    requirement.itemName = nil
    requirement.enchantmentId = nil

    local sourceAcquisition = setup.acquisition[sourceSlot]
    local targetAcquisition = setup.acquisition[targetSlot]
    local sourceAlternatives = deepCopy(setup.alternatives[sourceSlot] or {})
    local targetAlternatives = setup.alternatives[targetSlot]
    setup.acquisition[targetSlot] = nil
    setup.alternatives[targetSlot] = nil
    local ok, result, clearedOffHand = self:SetEquipment(
        buildId,
        setupId,
        targetSlot,
        requirement
    )
    if not ok then
        setup.acquisition[targetSlot] = targetAcquisition
        setup.alternatives[targetSlot] = targetAlternatives
        return false, result
    end
    for _, alternative in ipairs(sourceAlternatives) do
        alternative.itemLink = nil
        alternative.itemId = nil
        alternative.itemName = nil
        alternative.enchantmentId = nil
        self:SetAlternative(buildId, setupId, targetSlot, nil, alternative)
    end
    if move then
        setup.equipment[sourceSlot] = nil
        setup.alternatives[sourceSlot] = nil
        setup.acquisition[sourceSlot] = nil
        if sourceAcquisition and sourceAcquisition.preferredRoute then
            setup.acquisition[targetSlot] = {
                preferredRoute = sourceAcquisition.preferredRoute,
            }
        end
        setup.updatedAt = now()
        build.updatedAt = setup.updatedAt
    end
    return true, result, clearedOffHand
end

function Data:CopyEquipment(buildId, setupId, sourceSlot, targetSlot)
    return transferEquipment(self, buildId, setupId, sourceSlot, targetSlot, false)
end

function Data:MoveEquipment(buildId, setupId, sourceSlot, targetSlot)
    return transferEquipment(self, buildId, setupId, sourceSlot, targetSlot, true)
end

function Data:PushDeletedAction(action)
    action.deletedAt = now()
    local actions = self.saved.deletedActions
    actions[#actions + 1] = action
    while #actions > MAX_DELETED_ACTIONS do
        table.remove(actions, 1)
    end
end

function Data:DeleteBuild(id)
    local build, index = self:FindBuild(id)
    if not build then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_MISSING)
    end
    if #self.saved.builds == 1 then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_REQUIRED)
    end
    self:PushDeletedAction({ kind = "build", build = build, index = index })
    table.remove(self.saved.builds, index)
    self.saved.selectedBuildId = self.saved.builds[math.min(index, #self.saved.builds)].id
    return true, build
end

function Data:DeleteSetup(buildId, setupId)
    local build = self:FindBuild(buildId)
    if not build then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_MISSING)
    end
    local setup, index = self:FindSetup(build, setupId)
    if not setup then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_MISSING)
    end
    if #build.setups == 1 then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_SETUP_REQUIRED)
    end
    self:PushDeletedAction({
        kind = "setup",
        buildId = build.id,
        setup = setup,
        index = index,
    })
    table.remove(build.setups, index)
    build.selectedSetupId = build.setups[math.min(index, #build.setups)].id
    build.updatedAt = now()
    return true, setup
end

function Data:UndoLastDeletion()
    local actions = self.saved.deletedActions
    local action = actions[#actions]
    if not action then
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_NOTHING_TO_UNDO)
    end

    if action.kind == "build" and action.build then
        local build = action.build
        build.name = self:GetUniqueBuildName(build.name, build.id)
        local index = zo_clamp(action.index or (#self.saved.builds + 1), 1, #self.saved.builds + 1)
        table.insert(self.saved.builds, index, build)
        self.saved.selectedBuildId = build.id
    elseif action.kind == "setup" and action.setup then
        local build = self:FindBuild(action.buildId)
        if not build then
            return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_BUILD_MISSING)
        end
        local setup = action.setup
        setup.name = uniqueSetupName(build, setup.name, setup.id)
        local index = zo_clamp(action.index or (#build.setups + 1), 1, #build.setups + 1)
        table.insert(build.setups, index, setup)
        build.selectedSetupId = setup.id
        self.saved.selectedBuildId = build.id
    else
        return false, GetString(SI_GRAVVY_BUILD_PLANNER_ERROR_NOTHING_TO_UNDO)
    end

    table.remove(actions)
    return true, action
end

function Data:CanUndoDeletion()
    return #self.saved.deletedActions > 0
end
