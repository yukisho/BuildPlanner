GravvyBuildPlannerRuntimeAudit = {}

local RuntimeAudit = GravvyBuildPlannerRuntimeAudit
local Slots = GravvyBuildPlannerSlots
local MAX_BAG_READ_MS = 150
local MAX_SETUP_MATCH_MS = 600

local function addIssue(report, message)
    report.issues[#report.issues + 1] = message
end

local function isTruncated(control)
    if not control or not control.WasTruncated then return false, false end
    local ok, truncated = pcall(control.WasTruncated, control)
    return ok and truncated == true, ok
end

local function emit(message)
    if CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
        CHAT_SYSTEM:AddMessage(message)
    elseif d then
        d(message)
    end
end

function RuntimeAudit:New(owner)
    return setmetatable({ owner = owner }, { __index = self })
end

function RuntimeAudit:CollectLinkSamples()
    local samples = {}
    local found = {}
    for _, build in ipairs(self.owner.data:GetBuilds()) do
        for _, setup in ipairs(build.setups) do
            for _, slotKey in ipairs(Slots.ORDER) do
                local requirement = setup.equipment[slotKey]
                local definition = Slots:Get(slotKey)
                local family = definition and definition.family
                if requirement and requirement.setId and family and not found[family] then
                    samples[#samples + 1] = {
                        family = family,
                        slotKey = slotKey,
                        requirement = requirement,
                        setup = setup,
                    }
                    found[family] = true
                end
            end
        end
    end
    return samples, found
end

function RuntimeAudit:CheckLayout()
    local report = self.owner.accessibility:AuditTextGeometry({ 1, 1.2, 1.4 })
    local gamepad = self.owner.gamepad
    for _, control in ipairs({
        gamepad and gamepad.title,
        gamepad and gamepad.buildName,
        gamepad and gamepad.setupName,
        gamepad and gamepad.progress,
        gamepad and gamepad.status,
    }) do
        local truncated, measurable = isTruncated(control)
        if measurable then report.checked = report.checked + 1 end
        if truncated then
            report.failed = report.failed + 1
            if #report.issues < 12 then
                local name = control.GetName and control:GetName() or tostring(control)
                report.issues[#report.issues + 1] = { scale = "gamepad", name = name }
            end
        end
    end
    return report
end

function RuntimeAudit:Run()
    local controls = GravvyBuildPlannerUIHelpers:AuditVirtualControls()
    local layout = self:CheckLayout()
    local samples, families = self:CollectLinkSamples()
    local links = self.owner.itemResolver:AuditRepresentativeLinks(samples)
    local performance = self.owner.inventory:Benchmark()
    local apiVersion = GetAPIVersion and GetAPIVersion() or 0
    local report = {
        apiVersion = apiVersion,
        controls = controls,
        layout = layout,
        links = links,
        performance = performance,
        issues = {},
    }

    if apiVersion ~= self.owner.itemResolver.TESTED_API_VERSION then
        addIssue(report, zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_AUDIT_API_CHANGED,
            apiVersion,
            self.owner.itemResolver.TESTED_API_VERSION
        ))
    end
    for _, family in ipairs({ "armor", "jewelry", "weapon" }) do
        if not families[family] then
            addIssue(report, zo_strformat(
                SI_GRAVVY_BUILD_PLANNER_AUDIT_SAMPLE_MISSING,
                family
            ))
        end
    end
    for _, entry in ipairs(layout.issues) do
        addIssue(report, zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_AUDIT_LAYOUT_ISSUE,
            entry.name,
            entry.scale
        ))
    end
    for _, issue in ipairs(links.issues) do addIssue(report, issue) end
    for _, name in ipairs(controls.names) do addIssue(report, name) end

    local performancePassed = performance.readMs <= MAX_BAG_READ_MS
        and performance.matchMs <= MAX_SETUP_MATCH_MS
    if not performancePassed then
        addIssue(report, GetString(SI_GRAVVY_BUILD_PLANNER_AUDIT_PERFORMANCE_SLOW))
    end
    local samplesComplete = families.armor and families.jewelry and families.weapon
    report.passed = controls.failed == 0
        and layout.failed == 0
        and links.failed == 0
        and performancePassed
        and samplesComplete
        and apiVersion == self.owner.itemResolver.TESTED_API_VERSION
    self.lastReport = report
    self:Print(report)
    return report
end

function RuntimeAudit:Print(report)
    emit(GetString(SI_GRAVVY_BUILD_PLANNER_AUDIT_TITLE))
    emit(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_AUDIT_CONTROLS,
        report.controls.checked,
        report.controls.failed
    ))
    emit(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_AUDIT_LAYOUT,
        report.layout.checked,
        report.layout.failed
    ))
    emit(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_AUDIT_LINKS,
        report.links.checked,
        report.links.failed,
        report.apiVersion
    ))
    local performance = report.performance
    emit(zo_strformat(
        SI_GRAVVY_BUILD_PLANNER_AUDIT_PERFORMANCE,
        performance.items,
        performance.readMs,
        performance.setups,
        performance.requirements,
        performance.alternatives,
        performance.matchMs
    ))
    for index = 1, math.min(5, #report.issues) do
        emit(zo_strformat(SI_GRAVVY_BUILD_PLANNER_AUDIT_ISSUE, report.issues[index]))
    end
    if #report.issues > 5 then
        emit(zo_strformat(
            SI_GRAVVY_BUILD_PLANNER_AUDIT_MORE_ISSUES,
            #report.issues - 5
        ))
    end
    emit(GetString(report.passed
        and SI_GRAVVY_BUILD_PLANNER_AUDIT_PASSED
        or SI_GRAVVY_BUILD_PLANNER_AUDIT_FAILED))
end
