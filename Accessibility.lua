GravvyBuildPlannerAccessibility = {
    fonts = setmetatable({}, { __mode = "k" }),
    backdrops = setmetatable({}, { __mode = "k" }),
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
    for backdrop, colors in pairs(self.backdrops) do
        self:ApplyBackdrop(backdrop, colors)
    end
    if self.owner.ui then
        self.owner.ui:Refresh()
    end
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
