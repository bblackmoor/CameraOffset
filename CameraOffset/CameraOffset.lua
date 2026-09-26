local DEFAULT_OFFSET = 3
local MIN_OFFSET, MAX_OFFSET = -20, 20
local panel, offsetSlider, offsetValue, targetText
local leftEdit, rightEdit

local function SetCameraOffset(value)
    value = tonumber(value)
    if not value then return end
    value = math.max(MIN_OFFSET, math.min(MAX_OFFSET, math.floor(value * 10 + 0.5) / 10))
    CameraOffsetDB.offset = value
    C_CVar.SetCVar("test_cameraOverShoulder", tostring(value))
    if offsetSlider and offsetSlider:GetValue() ~= value then
        offsetSlider:SetValue(value)
    end
    if offsetValue then offsetValue:SetText(string.format("%.1f", value)) end
end

local function MonitorWidth(edit)
    local width = tonumber(edit:GetText())
    if width and width >= 320 and width <= 16384 and width == math.floor(width) then
        return width
    end
end

local function UpdateTarget()
    if not targetText then return end
    local left, right = CameraOffsetDB.leftWidth, CameraOffsetDB.rightWidth
    if left and right then
        targetText:SetText(string.format("Left monitor center: %.1f%% across the full window", 50 * left / (left + right)))
    else
        targetText:SetText("Enter both monitor widths to estimate a starting offset.")
    end
end

local function SaveWidths()
    local left, right = MonitorWidth(leftEdit), MonitorWidth(rightEdit)
    if not left or not right then
        print("|cffffaa00Camera Offset:|r Enter whole-number widths from 320 to 16384 pixels.")
        return false
    end
    CameraOffsetDB.leftWidth, CameraOffsetDB.rightWidth = left, right
    leftEdit:ClearFocus()
    rightEdit:ClearFocus()
    UpdateTarget()
    return true
end

local function AddLabel(parent, content, x, y, width)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    label:SetText(content)
    return label
end

local function AddWidthBox(label, x)
    AddLabel(panel, label, x, -128, 185)
    local edit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    edit:SetSize(125, 24)
    edit:SetPoint("TOPLEFT", x + 5, -153)
    edit:SetAutoFocus(false)
    edit:SetNumeric(true)
    edit:SetMaxLetters(5)
    edit:SetScript("OnEnterPressed", SaveWidths)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return edit
end

local function CreateSettings()
    panel = CreateFrame("Frame", nil, UIParent)
    panel.name = "Camera Offset"

    AddLabel(panel, "Camera Offset", 20, -20, 420):SetFontObject("GameFontNormalLarge")
    local intro = AddLabel(panel, "Keep the world drawn across both monitors while shifting your character toward the center of the left monitor. Changes to the slider apply immediately.", 20, -55, 510)
    intro:SetFontObject("GameFontHighlight")
    intro:SetHeight(55)

    leftEdit = AddWidthBox("Left monitor width (px)", 20)
    rightEdit = AddWidthBox("Right monitor width (px)", 230)
    leftEdit:SetText(CameraOffsetDB.leftWidth or "")
    rightEdit:SetText(CameraOffsetDB.rightWidth or "")

    local save = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    save:SetSize(120, 24)
    save:SetPoint("TOPLEFT", 20, -191)
    save:SetText("Save widths")
    save:SetScript("OnClick", SaveWidths)

    targetText = AddLabel(panel, "", 20, -230, 510)
    targetText:SetFontObject("GameFontHighlightSmall")
    UpdateTarget()

    local estimate = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    estimate:SetSize(176, 24)
    estimate:SetPoint("TOPLEFT", 20, -264)
    estimate:SetText("Try estimated offset")
    estimate:SetScript("OnClick", function()
        if SaveWidths() then
            -- Equal-width monitors start at 3. Widths cannot give an exact CVar.
            SetCameraOffset(6 * CameraOffsetDB.rightWidth / (CameraOffsetDB.leftWidth + CameraOffsetDB.rightWidth))
        end
    end)

    AddLabel(panel, "Camera shoulder offset", 20, -315, 300)
    offsetSlider = CreateFrame("Slider", "CameraOffsetSlider", panel, "OptionsSliderTemplate")
    offsetSlider:SetPoint("TOPLEFT", 26, -351)
    offsetSlider:SetWidth(360)
    offsetSlider:SetMinMaxValues(MIN_OFFSET, MAX_OFFSET)
    offsetSlider:SetValueStep(0.1)
    offsetSlider:SetObeyStepOnDrag(true)
    _G[offsetSlider:GetName() .. "Low"]:SetText(tostring(MIN_OFFSET))
    _G[offsetSlider:GetName() .. "High"]:SetText(tostring(MAX_OFFSET))
    _G[offsetSlider:GetName() .. "Text"]:SetText("")
    offsetValue = AddLabel(panel, "", 400, -351, 100)
    offsetSlider:SetScript("OnValueChanged", function(_, value) SetCameraOffset(value) end)
    offsetSlider:SetValue(CameraOffsetDB.offset)
    SetCameraOffset(CameraOffsetDB.offset)

    local note = AddLabel(panel, "The estimate is only a starting point. Adjust the slider until your character looks centered on the left monitor; the value is saved for later logins. Camera zoom and mounts can change the apparent alignment.", 20, -413, 510)
    note:SetFontObject("GameFontHighlightSmall")
    note:SetHeight(60)

    local category = Settings.RegisterCanvasLayoutCategory(panel, "Camera Offset")
    Settings.RegisterAddOnCategory(category)
    SLASH_CAMERAOFFSET1 = "/cameraoffset"
    SlashCmdList.CAMERAOFFSET = function() Settings.OpenToCategory(category:GetID()) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
    if type(CameraOffsetDB) ~= "table" then CameraOffsetDB = {} end
    if type(CameraOffsetDB.offset) ~= "number" then CameraOffsetDB.offset = DEFAULT_OFFSET end
    C_CVar.SetCVar("CameraKeepCharacterCentered", "0")
    C_CVar.SetCVar("CameraReduceUnexpectedMovement", "0")
    SetCameraOffset(CameraOffsetDB.offset)
    CreateSettings()
end)
