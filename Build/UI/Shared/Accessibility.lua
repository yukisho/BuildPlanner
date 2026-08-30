GravvyBuildPlannerAccessibility = {
    fonts = setmetatable({}, { __mode = "k" }),
    backdrops = setmetatable({}, { __mode = "k" }),
    textGeometry = setmetatable({}, { __mode = "k" }),
}

local Accessibility = GravvyBuildPlannerAccessibility

function Accessibility:Initialize(owner)
    self.owner = owner
end

function Accessibility:GetSettings()
    return self.owner and self.owner.data:GetSettings() or {}
end

function Accessibility:SetFont(control, fontName)
    self.fonts[control] = fontName
    self:ApplyFont(control, fontName)
end

function Accessibility:ApplyFont(control, fontName)
    local scale = tonumber(self:GetSettings().fontScale) or 1
    local fontObject = _G[fontName]
    if scale == 1 or not fontObject or not fontObject.GetFontInfo then
        control:SetFont(fontName)
        return
    end

    local face, size, style = fontObject:GetFontInfo()
    if not face or not size then
        control:SetFont(fontName)
        return
    end
    local descriptor = string.format("%s|%d", face, math.floor((size * scale) + 0.5))
    if style and style ~= "" then
        descriptor = descriptor .. "|" .. style
    end
    control:SetFont(descriptor)
end

function Accessibility:RegisterTextGeometry(control, width, height)
    self.textGeometry[control] = { width = width, height = height }
    self:ApplyTextGeometry(control, self.textGeometry[control])
end

function Accessibility:ApplyTextGeometry(control, geometry)
    local scale = tonumber(self:GetSettings().fontScale) or 1
    local scaledHeight = math.floor((geometry.height * math.min(scale, 1.2)) + 0.5)
    if control.SetDimensions then
        control:SetDimensions(geometry.width, scaledHeight)
    end
    if control.SetWrapMode and TEXT_WRAP_MODE_ELLIPSIS and geometry.height <= 32 then
        control:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end
end

function Accessibility:RegisterBackdrop(backdrop, center, edge)
    local colors = { center = center, edge = edge }
    self.backdrops[backdrop] = colors
    self:ApplyBackdrop(backdrop, colors)
end

function Accessibility:ApplyBackdrop(backdrop, colors)
    if self:GetSettings().highContrast then
        backdrop:SetCenterColor(0, 0, 0, 1)
        backdrop:SetEdgeColor(1, 0.82, 0.25, 1)
        return
    end
    backdrop:SetCenterColor(
        colors.center[1],
        colors.center[2],
        colors.center[3],
        colors.center[4]
    )
    backdrop:SetEdgeColor(
        colors.edge[1],
        colors.edge[2],
        colors.edge[3],
        colors.edge[4]
    )
end

function Accessibility:Refresh()
    for control, fontName in pairs(self.fonts) do
        self:ApplyFont(control, fontName)
    end
    for control, geometry in pairs(self.textGeometry) do
        self:ApplyTextGeometry(control, geometry)
    end
    for backdrop, colors in pairs(self.backdrops) do
        self:ApplyBackdrop(backdrop, colors)
    end
    if self.owner.ui then
        self.owner.ui:Refresh()
    end
    if self.owner.gamepad then
        self.owner.gamepad:Refresh()
    end
end

local function controlIsTruncated(control)
    if control.WasTruncated then
        local ok, truncated = pcall(control.WasTruncated, control)
        if ok then return truncated == true, true end
    end
    if control.GetTextWidth and control.GetWidth then
        local okWidth, textWidth = pcall(control.GetTextWidth, control)
        local okControl, controlWidth = pcall(control.GetWidth, control)
        if okWidth and okControl and textWidth and controlWidth then
            return textWidth > controlWidth + 1, true
        end
    end
    return false, false
end

function Accessibility:AuditTextGeometry(scales)
    local settings = self:GetSettings()
    local originalScale = settings.fontScale
    local report = { checked = 0, failed = 0, issues = {}, scales = scales }

    for _, scale in ipairs(scales or { 1, 1.2, 1.4 }) do
        settings.fontScale = scale
        for control, fontName in pairs(self.fonts) do
            self:ApplyFont(control, fontName)
        end
        for control, geometry in pairs(self.textGeometry) do
            self:ApplyTextGeometry(control, geometry)
        end
        for control in pairs(self.textGeometry) do
            local truncated, measurable = controlIsTruncated(control)
            if measurable then report.checked = report.checked + 1 end
            if truncated then
                report.failed = report.failed + 1
                if #report.issues < 12 then
                    local name = control.GetName and control:GetName() or nil
                    report.issues[#report.issues + 1] = {
                        scale = scale,
                        name = name and name ~= "" and name or tostring(control),
                    }
                end
            end
        end
    end

    settings.fontScale = originalScale
    for control, fontName in pairs(self.fonts) do
        self:ApplyFont(control, fontName)
    end
    for control, geometry in pairs(self.textGeometry) do
        self:ApplyTextGeometry(control, geometry)
    end
    return report
end

function Accessibility:FormatStatus(message, isError)
    message = message or ""
    if message == "" or not self:GetSettings().nonColorIndicators then
        return message
    end
    return zo_strformat(
        isError and SI_GRAVVY_BUILD_PLANNER_ERROR_PREFIX
            or SI_GRAVVY_BUILD_PLANNER_STATUS_PREFIX,
        message
    )
end
