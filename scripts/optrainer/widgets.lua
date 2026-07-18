local Widgets = {}

local palette = {
    bg = { 0.045, 0.050, 0.065, 1.0 },
    line = { 0.20, 0.24, 0.30, 1.0 },
    text = { 0.90, 0.92, 0.96, 1.0 },
    muted = { 0.56, 0.62, 0.70, 1.0 },
    accent = { 0.38, 0.55, 0.72, 1.0 },
    primary = { 0.18, 0.45, 0.72, 1.0 },
    primaryHover = { 0.23, 0.55, 0.86, 1.0 },
    primaryActive = { 0.13, 0.34, 0.56, 1.0 },
    danger = { 0.74, 0.19, 0.25, 1.0 },
    dangerHover = { 0.90, 0.26, 0.34, 1.0 },
    success = { 0.16, 0.61, 0.38, 1.0 },
    successHover = { 0.22, 0.74, 0.48, 1.0 },
    warning = { 0.84, 0.55, 0.18, 1.0 },
    warningHover = { 0.95, 0.66, 0.28, 1.0 },
    frame = { 0.085, 0.095, 0.125, 1.0 },
    frameHover = { 0.12, 0.15, 0.20, 1.0 },
}

local function safe(fn, ...)
    if not fn then return false end
    local args = { ... }
    return pcall(function() return fn(table.unpack(args)) end)
end

local function color(id, colorType, values)
    if ImGui and ImGui.SetColor and colorType then
        safe(ImGui.SetColor, id, colorType, values[1], values[2], values[3], values[4])
    end
end

local function textColor(id, values)
    if ImGui and ImGui.SetTextColor then
        safe(ImGui.SetTextColor, id, values[1], values[2], values[3], values[4])
    end
end

local function size(id, width, height)
    if ImGui and ImGui.SetSize then
        safe(ImGui.SetSize, id, width or 0, height or 0)
    end
end

local function buttonColors(id, mode)
    if not ImGuiColor then return end
    if mode == "danger" then
        color(id, ImGuiColor.Button, palette.danger)
        color(id, ImGuiColor.ButtonHovered, palette.dangerHover)
        color(id, ImGuiColor.ButtonActive, { 0.55, 0.12, 0.17, 1.0 })
    elseif mode == "success" then
        color(id, ImGuiColor.Button, palette.success)
        color(id, ImGuiColor.ButtonHovered, palette.successHover)
        color(id, ImGuiColor.ButtonActive, { 0.11, 0.45, 0.28, 1.0 })
    elseif mode == "warning" then
        color(id, ImGuiColor.Button, palette.warning)
        color(id, ImGuiColor.ButtonHovered, palette.warningHover)
        color(id, ImGuiColor.ButtonActive, { 0.66, 0.40, 0.10, 1.0 })
    else
        color(id, ImGuiColor.Button, palette.primary)
        color(id, ImGuiColor.ButtonHovered, palette.primaryHover)
        color(id, ImGuiColor.ButtonActive, palette.primaryActive)
    end
end

function Widgets.ApplyWindowStyle(windowId, opacity)
    if not ImGuiColor then return end
    color(windowId, ImGuiColor.WindowBg, palette.bg)
    color(windowId, ImGuiColor.Border, palette.line)
    color(windowId, ImGuiColor.TitleBg, { 0.06, 0.07, 0.09, 1.0 })
    color(windowId, ImGuiColor.TitleBgActive, { 0.08, 0.10, 0.13, 1.0 })
    color(windowId, ImGuiColor.FrameBg, palette.frame)
    color(windowId, ImGuiColor.FrameBgHovered, palette.frameHover)
    color(windowId, ImGuiColor.FrameBgActive, { 0.14, 0.19, 0.25, 1.0 })
    color(windowId, ImGuiColor.Button, palette.primary)
    color(windowId, ImGuiColor.ButtonHovered, palette.primaryHover)
    color(windowId, ImGuiColor.ButtonActive, palette.primaryActive)
    color(windowId, ImGuiColor.CheckMark, palette.success)
    color(windowId, ImGuiColor.Tab, { 0.07, 0.08, 0.10, 1.0 })
    color(windowId, ImGuiColor.TabHovered, { 0.17, 0.35, 0.52, 1.0 })
    color(windowId, ImGuiColor.TabActive, palette.primary)
    color(windowId, ImGuiColor.Separator, palette.accent)
    color(windowId, ImGuiColor.ScrollbarGrab, { 0.18, 0.22, 0.28, 1.0 })
    color(windowId, ImGuiColor.ScrollbarGrabHovered, { 0.24, 0.30, 0.38, 1.0 })
end

function Widgets.Separator(parent, id, label)
    ImGui.AddElement(parent, id, ImGuiElement.SeparatorText, label or "")
    textColor(id, palette.accent)
end

function Widgets.Text(parent, id, label, muted, wrap)
    ImGui.AddText(parent, label or "", wrap == true, id)
    textColor(id, muted and palette.muted or palette.text)
end

function Widgets.Button(parent, id, label, callback, mode, width)
    ImGui.AddButton(parent, id, label or "", callback or function() end, false)
    size(id, width or 0, 0)
    buttonColors(id, mode)
end

function Widgets.SmallButton(parent, id, label, callback, mode, width)
    ImGui.AddButton(parent, id, label or "", callback or function() end, true)
    size(id, width or 0, 0)
    buttonColors(id, mode)
end

function Widgets.Toggle(parent, id, label, value, callback)
    ImGui.AddCheckbox(parent, id, label or "", function(checked)
        callback(checked == true)
    end, value == true)
    if ImGuiColor then
        color(id, ImGuiColor.FrameBg, palette.frame)
        color(id, ImGuiColor.FrameBgHovered, palette.frameHover)
        color(id, ImGuiColor.CheckMark, value and palette.success or palette.warning)
    end
end

function Widgets.SliderFloat(parent, id, label, value, min, max, callback, format)
    ImGui.AddSliderFloat(parent, id, label, function(newValue) callback(newValue) end, value, min, max, format or "%.2f")
    size(id, 0, 0)
end

function Widgets.SliderInt(parent, id, label, value, min, max, callback)
    ImGui.AddSliderInteger(parent, id, label, function(newValue) callback(newValue) end, value, min, max, "%d")
    size(id, 0, 0)
end

function Widgets.InputInt(parent, id, label, value, callback)
    ImGui.AddInputInteger(parent, id, label, function(newValue) callback(newValue) end, value or 0, 1, 10)
    size(id, 0, 0)
end

function Widgets.Input(parent, id, label, value, hint, callback, width)
    ImGui.AddInputText(parent, id, label, function(text) callback(text or "") end, value or "", hint or "")
    size(id, width or 0, 0)
end

function Widgets.Multiline(parent, id, label, value, lines, callback, width)
    local height = math.max(64, (lines or 5) * 18)
    ImGui.AddInputTextMultiline(parent, id, label, function(text) callback(text or "") end, value or "", lines or 5)
    size(id, width or 0, height)
end

function Widgets.Combo(parent, id, label, options, selected, callback, width)
    local selectedIndex = 0
    if type(selected) == "number" and selected > 0 then
        selectedIndex = selected - 1
    end
    ImGui.AddCombobox(parent, id, label, function(index, value) callback(index + 1, value) end, options, selectedIndex, false)
    size(id, width or 0, 0)
end

function Widgets.SameLine(parent, id)
    ImGui.AddElement(parent, id, ImGuiElement.SameLine, "")
end

function Widgets.Tooltip(id, text)
    if ImGui and ImGui.SetTooltip then safe(ImGui.SetTooltip, id, text or "") end
end

function Widgets.UpdateText(id, label)
    if ImGui and ImGui.ElementExists and ImGui.ElementExists(id) then safe(ImGui.UpdateText, id, label or "") end
end

function Widgets.UpdateValue(id, value)
    if ImGui and ImGui.ElementExists and ImGui.ElementExists(id) and ImGuiData then safe(ImGui.UpdateData, id, ImGuiData.Value, value) end
end

function Widgets.UpdateVisible(id, visible)
    if ImGui and ImGui.ElementExists and ImGui.ElementExists(id) and ImGui.SetVisible then safe(ImGui.SetVisible, id, visible == true) end
end

return Widgets