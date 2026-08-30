GravvyBuildPlannerReadiness = {}

local Readiness = GravvyBuildPlannerReadiness
local Slots = GravvyBuildPlannerSlots
local TRANSMUTE_COST = 50

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

local differenceIds = {
    trait = SI_GRAVVY_BUILD_PLANNER_VALIDATION_DETAIL_TRAIT,
    enchantment = SI_GRAVVY_BUILD_PLANNER_VALIDATION_DETAIL_ENCHANTMENT,
    quality = SI_GRAVVY_BUILD_PLANNER_NEEDS_QUALITY,
}

local function slotName(slotKey)
    return GetString(slotStringIds[slotKey])
end

local function locationName(location)
    return GetString(location == "equipped"
        and SI_GRAVVY_BUILD_PLANNER_OWNED_EQUIPPED
        or location == "backpack"
            and SI_GRAVVY_BUILD_PLANNER_OWNED_BACKPACK
            or location == "bank"
                and SI_GRAVVY_BUILD_PLANNER_OWNED_BANK
                or SI_GRAVVY_BUILD_PLANNER_READINESS_NO_LOCATION)
end

local function hasDifference(match, wanted)
    for _, difference in ipairs(match and match.differences or {}) do
        if difference == wanted then return true end
    end
    return false
end

function Readiness:New(owner)
    return setmetatable({ owner = owner }, { __index = self })
end

function Readiness:BuildReport(setup)
    self.owner.inventory:EnsureSetup(setup)
    local setupMatches = self.owner.inventory.matches[setup.id] or {}
    local assigned = {}
    for _, match in pairs(setupMatches) do
        local key = tostring(match.bagId) .. ":" .. tostring(match.slotIndex)
        assigned[key] = (assigned[key] or 0) + 1
    end
    local function contestedItem(slotKey, requirement)
        local candidates = { requirement }
        for _, alternative in ipairs(setup.alternatives and setup.alternatives[slotKey] or {}) do
            candidates[#candidates + 1] = alternative
        end
        for _, item in ipairs(self.owner.inventory.items or {}) do
            local key = tostring(item.bagId) .. ":" .. tostring(item.slotIndex)
            if (assigned[key] or 0) >= (tonumber(item.count) or 1) then
                for _, candidate in ipairs(candidates) do
                    if self.owner.acquisition:CompareItem(
                        slotKey,
                        candidate,
                        setup,
                        item.itemLink
                    ) then
                        return item
                    end
                end
            end
        end
    end
    local report = {
        setup = setup,
        entries = {},
        ready = 0,
        adjustable = 0,
        missing = 0,
        conflicting = 0,
        routes = {
            owned = 0, buy = 0, craft = 0, farm = 0,
            reconstruct = 0, transmute = 0, unknown = 0,
        },
        materials = {
            glyphs = 0,
            upgradePieces = 0,
            qualitySteps = 0,
            transmutePieces = 0,
            transmuteCrystals = 0,
        },
    }
    for _, slotKey in ipairs(Slots.ORDER) do
        local requirement = setup.equipment and setup.equipment[slotKey]
        if requirement then
            local mainHand = Slots:GetMainHand(slotKey)
            local main = mainHand and setup.equipment[mainHand]
            local conflict = main and (main.occupiesOffHand
                or Slots:IsTwoHanded(main.weaponType))
            local match = not conflict and setupMatches[slotKey]
                or nil
            local contested = not conflict and not match
                and contestedItem(slotKey, requirement) or nil
            conflict = conflict or contested ~= nil
            local matchedRequirement = match and self.owner.inventory:GetMatchedRequirement(
                setup.id,
                slotKey,
                setup
            ) or requirement
            local resolved = self.owner.itemResolver:Resolve(
                slotKey,
                matchedRequirement,
                setup
            )
            local state = self.owner.acquisition:Classify(
                slotKey,
                matchedRequirement,
                setup,
                resolved
            )
            local preferred = setup.acquisition and setup.acquisition[slotKey]
            local routes = self.owner.acquisition:GetAvailableRoutes(state, match)
            local route = conflict and "unknown" or self.owner.acquisition:ChooseRoute(
                routes,
                preferred and preferred.preferredRoute
            )
            local status
            if conflict then
                status = "conflicting"
                report.conflicting = report.conflicting + 1
            elseif match and match.exact then
                status = "ready"
                report.ready = report.ready + 1
            elseif match then
                status = "adjustable"
                report.adjustable = report.adjustable + 1
            else
                status = "missing"
                report.missing = report.missing + 1
            end
            report.routes[route] = (report.routes[route] or 0) + 1

            local work = {}
            for _, difference in ipairs(match and match.differences or {}) do
                work[#work + 1] = GetString(differenceIds[difference])
            end
            if conflict then
                work[1] = GetString(SI_GRAVVY_BUILD_PLANNER_READINESS_OFFHAND_CONFLICT)
                if contested then
                    work[1] = GetString(SI_GRAVVY_BUILD_PLANNER_READINESS_ITEM_CONFLICT)
                end
            elseif not match then
                local level, championPoints = self.owner.itemResolver:GetRequestedLevel(
                    matchedRequirement,
                    setup
                )
                work[1] = zo_strformat(
                    championPoints and championPoints > 0
                        and SI_GRAVVY_BUILD_PLANNER_READINESS_ACQUIRE_CP
                        or SI_GRAVVY_BUILD_PLANNER_READINESS_ACQUIRE_LEVEL,
                    championPoints and championPoints > 0 and championPoints or level
                )
            elseif #work == 0 then
                work[1] = GetString(SI_GRAVVY_BUILD_PLANNER_READINESS_NO_WORK)
            end

            if matchedRequirement.enchantmentCategory
                and (not match or hasDifference(match, "enchantment")) then
                report.materials.glyphs = report.materials.glyphs + 1
            end
            if match and hasDifference(match, "quality") then
                report.materials.upgradePieces = report.materials.upgradePieces + 1
                local currentQuality = GetItemLinkDisplayQuality
                    and GetItemLinkDisplayQuality(match.itemLink) or 0
                local targetQuality = matchedRequirement.quality or setup.defaultQuality or 0
                report.materials.qualitySteps = report.materials.qualitySteps
                    + math.max(0, targetQuality - currentQuality)
            end
            if match and hasDifference(match, "trait") then
                report.materials.transmutePieces = report.materials.transmutePieces + 1
                report.materials.transmuteCrystals = report.materials.transmuteCrystals
                    + TRANSMUTE_COST
            end
            report.entries[#report.entries + 1] = {
                slotKey = slotKey,
                slot = slotName(slotKey),
                status = status,
                route = route,
                location = match and locationName(match.location)
                    or contested and locationName(contested.location)
                    or GetString(SI_GRAVVY_BUILD_PLANNER_READINESS_NO_LOCATION),
                work = table.concat(work, ", "),
                differences = match and match.differences or {},
            }
        end
    end
    report.shopping = self.owner.shopping:BuildReview(false, true)
    return report
end

function Readiness:FormatRoutes(report)
    local labels = {}
    for _, route in ipairs({
        "buy", "craft", "reconstruct", "transmute", "farm", "owned", "unknown",
    }) do
        local count = report.routes[route] or 0
        if count > 0 then
            labels[#labels + 1] = self.owner.acquisition:GetRouteLabel(route)
                .. " " .. tostring(count)
        end
    end
    return table.concat(labels, " · ")
end

function Readiness:FormatMaterials(report)
    local materials = report.materials
    return zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_READINESS_MATERIALS,
        materials.glyphs,
        materials.upgradePieces,
        materials.qualitySteps,
        materials.transmutePieces,
        materials.transmuteCrystals
    )
end

function Readiness:FormatReport(report, limit)
    local lines = {
        zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_READINESS_SUMMARY,
            report.ready,
            report.adjustable,
            report.missing,
            report.conflicting
        ),
        self:FormatRoutes(report),
        self:FormatMaterials(report),
        zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_READINESS_BUYABLE,
            report.shopping.included,
            report.shopping.glyphs
        ),
        "",
    }
    local maximum = math.min(#report.entries, limit or #report.entries)
    for index = 1, maximum do
        local entry = report.entries[index]
        lines[#lines + 1] = entry.slot .. " — "
            .. GetString(({
                ready = SI_GRAVVY_BUILD_PLANNER_READINESS_READY,
                adjustable = SI_GRAVVY_BUILD_PLANNER_READINESS_ADJUSTABLE,
                missing = SI_GRAVVY_BUILD_PLANNER_READINESS_MISSING,
                conflicting = SI_GRAVVY_BUILD_PLANNER_READINESS_CONFLICTING,
            })[entry.status]) .. " · "
            .. self.owner.acquisition:GetRouteLabel(entry.route) .. " · "
            .. entry.location .. " · " .. entry.work
    end
    return table.concat(lines, "\n")
end
