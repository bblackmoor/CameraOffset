local addonName = ...
local DEFAULT_NAME = "Default"
local SOURCE_URL = "https://github.com/bblackmoor/CameraOffset"
local MIN_OFFSET, MAX_OFFSET = -20, 20
local db, cameraPanel, cameraHost, profilesPanel, category, cameraCategory, profilesCategory
local leftEdit, rightEdit, targetText, offsetSlider, offsetValue
local enableCheck, profileDropdown
local renameButton, deleteButton
local refreshing = false

local function GameDefault(name, fallback)
    local value = C_CVar.GetCVarDefault(name)
    return value ~= nil and value or fallback
end

local function DefaultProfile()
    return {
        offset = tonumber(GameDefault("test_cameraOverShoulder", C_CVar.GetCVar("test_cameraOverShoulder") or "0")) or 0,
        leftWidth = 0, rightWidth = 0, enabled = false,
    }
end

local function CopyProfile(source)
    return {
        offset = source.offset, leftWidth = source.leftWidth, rightWidth = source.rightWidth,
        enabled = source.enabled,
    }
end

local function CharacterKey()
    local guid = UnitGUID("player")
    if guid and guid ~= "" then return guid end
    local name, realm = UnitFullName("player")
    return (name or "Unknown") .. "-" .. (realm or GetRealmName() or "Unknown")
end

local function ProfileName()
    local name = db.profileKeys[CharacterKey()]
    if db.profiles[name] then return name end
    return db.profiles[db.fallbackProfile] and db.fallbackProfile or DEFAULT_NAME
end

local function Profile()
    return db.profiles[ProfileName()]
end

local function ValidateProfile(saved)
    local result = DefaultProfile()
    if type(saved) ~= "table" then return result end
    result.enabled = saved.enabled == true
    if type(saved.offset) == "number" and saved.offset == saved.offset then
        result.offset = math.max(MIN_OFFSET, math.min(MAX_OFFSET, saved.offset))
    end
    for _, key in ipairs({ "leftWidth", "rightWidth" }) do
        local width = saved[key]
        if type(width) == "number" and width == math.floor(width) and width >= 320 and width <= 16384 then
            result[key] = width
        end
    end
    return result
end

local function LoadDB()
    local saved = CameraOffsetDB
    db = {
        schemaVersion = 2, profiles = { [DEFAULT_NAME] = DefaultProfile() },
        profileKeys = {}, fallbackProfile = DEFAULT_NAME,
    }
    if type(saved) == "table" and saved.schemaVersion == 2 then
        db.originalsByCharacter = type(saved.originalsByCharacter) == "table"
            and saved.originalsByCharacter or {}
        if type(saved.originals) == "table" then
            db.originalsByCharacter[CharacterKey()] = saved.originals
        end
        if type(saved.legacyDefaults) == "table" then db.legacyDefaults = saved.legacyDefaults end
        if type(saved.profiles) == "table" then
            for name, profile in pairs(saved.profiles) do
                if type(name) == "string" and name ~= "" and #name <= 64 then
                    db.profiles[name] = ValidateProfile(profile)
                end
            end
        end
        if type(saved.profileKeys) == "table" then
            for key, name in pairs(saved.profileKeys) do
                if type(key) == "string" and db.profiles[name] then db.profileKeys[key] = name end
            end
        end
        if db.profiles[saved.fallbackProfile] then db.fallbackProfile = saved.fallbackProfile end
    elseif type(saved) == "table" and type(saved.offset) == "number" then
        -- Preserve the settings applied by the original version without altering Default.
        db.profiles["Previous Camera Offset"] = ValidateProfile({
            offset = saved.offset, leftWidth = saved.leftWidth,
            rightWidth = saved.rightWidth, enabled = true,
        })
        db.profileKeys[CharacterKey()] = "Previous Camera Offset"
        db.fallbackProfile = "Previous Camera Offset"
        db.legacyDefaults = {
            keepCentered = GameDefault("CameraKeepCharacterCentered", "0"),
            reduceMovement = GameDefault("CameraReduceUnexpectedMovement", "0"),
            offset = GameDefault("test_cameraOverShoulder", "0"),
        }
        db.originalsByCharacter = { [CharacterKey()] = {
            keepCentered = db.legacyDefaults.keepCentered,
            reduceMovement = db.legacyDefaults.reduceMovement,
            offset = db.legacyDefaults.offset,
        } }
    end
    db.originalsByCharacter = db.originalsByCharacter or {}
    CameraOffsetDB = db
end

local CVARS = {
    keepCentered = "CameraKeepCharacterCentered",
    reduceMovement = "CameraReduceUnexpectedMovement",
    offset = "test_cameraOverShoulder",
}

local function RestoreCamera()
    local key = CharacterKey()
    local originals = db.originalsByCharacter[key]
    if not originals then return end
    for key, cvar in pairs(CVARS) do
        if originals[key] then C_CVar.SetCVar(cvar, originals[key]) end
    end
    db.originalsByCharacter[key] = nil
end

local function ApplyProfile()
    local profile = Profile()
    if not profile.enabled then
        RestoreCamera()
        return false
    end
    local character = CharacterKey()
    if not db.originalsByCharacter[character] then
        local originals = {}
        for key, cvar in pairs(CVARS) do
            originals[key] = db.legacyDefaults and db.legacyDefaults[key] or C_CVar.GetCVar(cvar)
        end
        db.originalsByCharacter[character] = originals
    end
    C_CVar.SetCVar("CameraKeepCharacterCentered", "0")
    C_CVar.SetCVar("CameraReduceUnexpectedMovement", "0")
    C_CVar.SetCVar("test_cameraOverShoulder", tostring(profile.offset))
    local applied = tonumber(C_CVar.GetCVar("test_cameraOverShoulder"))
    return applied and math.abs(applied - profile.offset) < 0.051
end

local function AddLabel(parent, content, x, y, width, font)
    local label = parent:CreateFontString(nil, "ARTWORK", font or "GameFontNormal")
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    label:SetText(content)
    return label
end

local function AddSwitch(parent, label, y, onChanged)
    local switch = CreateFrame("Button", nil, parent)
    switch:SetSize(44, 20)
    switch:SetPoint("TOPLEFT", 170, y - 3)
    switch:SetHitRectInsets(-150, 0, -3, -3)

    local track = switch:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0.25, 0.25, 0.26, 1)
    local thumb = switch:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(18, 16)
    thumb:SetColorTexture(0.72, 0.72, 0.73, 1)
    local caption = switch:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    caption:SetPoint("RIGHT", switch, "LEFT", -12, 0)
    caption:SetWidth(138)
    caption:SetJustifyH("LEFT")
    caption:SetText(label)

    function switch:SetChecked(checked)
        self.checked = checked == true
        thumb:ClearAllPoints()
        if self.checked then
            track:SetColorTexture(0.19, 0.42, 0.31, 1)
            thumb:SetPoint("RIGHT", self, "RIGHT", -2, 0)
        else
            track:SetColorTexture(0.25, 0.25, 0.26, 1)
            thumb:SetPoint("LEFT", self, "LEFT", 2, 0)
        end
    end
    function switch:GetChecked() return self.checked end
    switch:SetScript("OnClick", function(self)
        self:SetChecked(not self:GetChecked())
        onChanged(self:GetChecked())
    end)
    switch:SetChecked(false)
    return switch
end

local function CreateAboutPanel()
    local panel = CreateFrame("Frame", nil, UIParent)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -28, 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(640, 350)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, width, height)
        content:SetWidth(math.max(width - 4, 1))
        content:SetHeight(math.max(350, height or 1))
    end)

    local version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "Unknown"
    AddLabel(content, "Camera Offset — About", 20, -20, 510, "GameFontNormalLarge")
    AddLabel(content,
        "Shift your character toward the center of one monitor when the game window spans two monitors. Save camera settings in profiles that each character can select.",
        20, -56, 510, "GameFontHighlight"):SetHeight(50)
    AddLabel(content,
        "Version " .. version .. "\nAuthor    Brandon Blackmoor\nCategory  Camera",
        20, -126, 510, "GameFontHighlightSmall"):SetHeight(48)

    StaticPopupDialogs["CAMERAOFFSET_COPY_SOURCE"] = {
        text = "Press Ctrl+C to copy the source URL.",
        button1 = CLOSE or "Close", hasEditBox = true, maxLetters = 255, editBoxWidth = 340,
        OnShow = function(self)
            local edit = self.GetEditBox and self:GetEditBox() or self.editBox
            edit:SetText(SOURCE_URL)
            edit:SetFocus()
            edit:HighlightText()
        end,
        EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    local sourceLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sourceLabel:SetPoint("TOPLEFT", 20, -181)
    sourceLabel:SetText("Source    ")
    local sourceLink = CreateFrame("Button", nil, content)
    sourceLink:SetPoint("LEFT", sourceLabel, "RIGHT")
    local sourceText = sourceLink:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sourceText:SetPoint("LEFT")
    sourceText:SetText(SOURCE_URL)
    sourceText:SetTextColor(0.35, 0.7, 1, 1)
    sourceLink:SetSize(sourceText:GetStringWidth(), 16)
    sourceLink:SetScript("OnEnter", function() sourceText:SetTextColor(0.65, 0.85, 1, 1) end)
    sourceLink:SetScript("OnLeave", function() sourceText:SetTextColor(0.35, 0.7, 1, 1) end)
    sourceLink:SetScript("OnClick", function() StaticPopup_Show("CAMERAOFFSET_COPY_SOURCE") end)

    AddLabel(content,
        "License   GPL-3.0\n\nSlash commands\n" ..
        "    /cameraoffset — Open this About page.\n" ..
        "    /cameraoffset camera — Open Camera settings.\n" ..
        "    /cameraoffset profiles — Open Profiles.\n" ..
        "    /cameraoffset about — Open this About page.",
        20, -208, 510, "GameFontHighlightSmall"):SetHeight(130)
    return panel
end

local function UpdateTarget(message)
    local profile = Profile()
    local detail
    if profile.leftWidth > 0 and profile.rightWidth > 0 then
        detail = string.format("Left monitor center: %.1f%% across the full window",
            50 * profile.leftWidth / (profile.leftWidth + profile.rightWidth))
    else
        detail = "Enter both monitor widths to estimate a starting offset."
    end
    targetText:SetText(message and (message .. "\n" .. detail) or detail)
end

local function RefreshCamera()
    refreshing = true
    local profile = Profile()
    leftEdit:SetText(profile.leftWidth > 0 and tostring(profile.leftWidth) or "")
    rightEdit:SetText(profile.rightWidth > 0 and tostring(profile.rightWidth) or "")
    enableCheck:SetChecked(profile.enabled)
    offsetSlider:SetValue(profile.offset)
    offsetValue:SetText(string.format("%.1f", profile.offset))
    UpdateTarget()
    refreshing = false
end

local function ResetCameraDefaults()
    local defaults = {}
    for key, cvar in pairs(CVARS) do
        defaults[key] = C_CVar.GetCVarDefault(cvar)
        if defaults[key] == nil then
            print("|cffffaa00Camera Offset:|r WoW did not provide a default for " .. cvar .. ".")
            return
        end
    end
    local profile = Profile()
    profile.enabled = false
    profile.offset = tonumber(defaults.offset) or 0
    db.originalsByCharacter[CharacterKey()] = nil
    for key, cvar in pairs(CVARS) do C_CVar.SetCVar(cvar, defaults[key]) end
    RefreshCamera()
    UpdateTarget("Camera restored to WoW defaults; Camera Offset disabled.")
end

local function ProfileNames()
    local names = {}
    for name in pairs(db.profiles) do names[#names + 1] = name end
    table.sort(names, function(a, b)
        if a == DEFAULT_NAME then return true end
        if b == DEFAULT_NAME then return false end
        return a:lower() < b:lower()
    end)
    return names
end

local function RefreshProfiles()
    local name = ProfileName()
    UIDropDownMenu_SetSelectedValue(profileDropdown, name)
    UIDropDownMenu_SetText(profileDropdown, name)
    renameButton:SetEnabled(name ~= DEFAULT_NAME)
    deleteButton:SetEnabled(name ~= DEFAULT_NAME)
    RefreshCamera()
end

local function SelectProfile(name)
    db.profileKeys[CharacterKey()] = name
    ApplyProfile()
    RefreshProfiles()
end

local function CheckName(name, current)
    name = type(name) == "string" and strtrim(name) or ""
    if name == "" then return nil, "Enter a profile name." end
    if #name > 64 then return nil, "Profile names may contain at most 64 characters." end
    for existing in pairs(db.profiles) do
        if existing:lower() == name:lower() and existing ~= current then
            return nil, "That profile name is already in use."
        end
    end
    return name
end

local function ChangeProfile(action, proposed)
    local current = ProfileName()
    local name, errorMessage = CheckName(proposed, action == "rename" and current or nil)
    if not name then print("|cffffaa00Camera Offset:|r " .. errorMessage); return end
    if action == "rename" then
        if current == DEFAULT_NAME then return end
        db.profiles[name], db.profiles[current] = db.profiles[current], nil
        if db.fallbackProfile == current then db.fallbackProfile = name end
        for character, selected in pairs(db.profileKeys) do
            if selected == current then db.profileKeys[character] = name end
        end
        RefreshProfiles()
    else
        db.profiles[name] = action == "copy" and CopyProfile(Profile()) or DefaultProfile()
        SelectProfile(name)
    end
end

local function RegisterDialogs()
    StaticPopupDialogs["CAMERAOFFSET_PROFILE_NAME"] = {
        text = "Enter a profile name.", button1 = ACCEPT or "Accept", button2 = CANCEL or "Cancel",
        hasEditBox = true, maxLetters = 64, editBoxWidth = 260,
        OnShow = function(self, data)
            local edit = self.GetEditBox and self:GetEditBox() or self.editBox
            edit:SetText(data.initial)
            edit:SetFocus()
            edit:HighlightText()
        end,
        OnAccept = function(self, data)
            local edit = self.GetEditBox and self:GetEditBox() or self.editBox
            ChangeProfile(data.action, edit:GetText())
        end,
        EditBoxOnEnterPressed = function(self)
            local dialog = self:GetParent()
            if dialog.button1 then dialog.button1:Click() end
        end,
        EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs["CAMERAOFFSET_DELETE_PROFILE"] = {
        text = "Delete the profile |cffffffff%s|r? Characters using it will switch to Default.",
        button1 = DELETE or "Delete", button2 = CANCEL or "Cancel",
        OnAccept = function()
            local name = ProfileName()
            if name == DEFAULT_NAME then return end
            db.profiles[name] = nil
            if db.fallbackProfile == name then db.fallbackProfile = DEFAULT_NAME end
            for character, selected in pairs(db.profileKeys) do
                if selected == name then db.profileKeys[character] = DEFAULT_NAME end
            end
            ApplyProfile()
            RefreshProfiles()
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs["CAMERAOFFSET_RESTORE_DEFAULT"] = {
        text = "Restore the Default profile to World of Warcraft's camera defaults?",
        button1 = "Restore", button2 = CANCEL or "Cancel",
        OnAccept = function()
            db.profiles[DEFAULT_NAME] = DefaultProfile()
            if ProfileName() == DEFAULT_NAME then ApplyProfile() end
            RefreshProfiles()
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs["CAMERAOFFSET_ENABLE_INFO"] = {
        text = "When enabled, Camera Offset turns off 'Keep character centered' and 'Reduce unexpected camera movement' so the saved shoulder offset can take effect. When disabled, it restores all three camera values saved before activation for this character. No UI reload is needed.",
        button1 = OKAY or "Okay", timeout = 0, whileDead = true,
        hideOnEscape = true, preferredIndex = 3,
    }
end

local function AddButton(parent, label, x, y, width, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(label)
    button:SetScript("OnClick", callback)
    return button
end

local function AddInfoLink(parent, anchor, dialog)
    local link = CreateFrame("Frame", nil, parent)
    link:SetPoint("LEFT", anchor, "RIGHT", 12, 0)
    local circle = link:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    circle:SetPoint("CENTER")
    circle:SetText("O")
    local letter = link:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    letter:SetPoint("CENTER")
    letter:SetText("i")
    link:SetSize(math.ceil(math.max(circle:GetStringWidth(), letter:GetStringWidth()) + 6),
        math.ceil(math.max(circle:GetStringHeight(), letter:GetStringHeight()) + 4))
    link:EnableMouse(true)
    link:SetScript("OnMouseUp", function(_, mouseButton)
        if mouseButton == "LeftButton" then StaticPopup_Show(dialog) end
    end)
    return link
end

local function CreateProfilesPanel()
    profilesPanel = CreateFrame("Frame", nil, UIParent)
    AddLabel(profilesPanel, "Profiles", 20, -20, 420, "GameFontNormalLarge")
    local info = AddLabel(profilesPanel,
        "Profiles contain the enable switch, shoulder offset, and both monitor widths. They are shared account-wide; each character remembers its selected profile.",
        20, -55, 510, "GameFontHighlight")
    info:SetHeight(55)
    AddLabel(profilesPanel, "Selected profile", 20, -127, 250)
    profileDropdown = CreateFrame("Frame", nil, profilesPanel, "UIDropDownMenuTemplate")
    profileDropdown:SetPoint("TOPLEFT", 6, -153)
    UIDropDownMenu_SetWidth(profileDropdown, 250)
    UIDropDownMenu_Initialize(profileDropdown, function(_, level)
        for _, name in ipairs(ProfileNames()) do
            local selected = name
            local item = UIDropDownMenu_CreateInfo()
            item.text, item.value = selected, selected
            item.checked = ProfileName() == selected
            item.func = function() SelectProfile(selected) end
            UIDropDownMenu_AddButton(item, level)
        end
    end)
    AddButton(profilesPanel, "Restore Default", 316, -159, 145,
        function() StaticPopup_Show("CAMERAOFFSET_RESTORE_DEFAULT") end)
    AddLabel(profilesPanel, "Default can be edited and restored, but cannot be renamed or deleted. New profiles start with WoW's defaults; Copy starts with the currently selected settings.",
        20, -194, 510, "GameFontHighlightSmall"):SetHeight(48)
    local function NameDialog(action, initial)
        StaticPopup_Show("CAMERAOFFSET_PROFILE_NAME", nil, nil, { action = action, initial = initial })
    end
    AddButton(profilesPanel, "Create", 20, -253, 88, function() NameDialog("create", "") end)
    AddButton(profilesPanel, "Copy", 115, -253, 88, function() NameDialog("copy", ProfileName() .. " Copy") end)
    renameButton = AddButton(profilesPanel, "Rename", 210, -253, 88,
        function() NameDialog("rename", ProfileName()) end)
    deleteButton = AddButton(profilesPanel, "Delete", 305, -253, 88,
        function() StaticPopup_Show("CAMERAOFFSET_DELETE_PROFILE", ProfileName()) end)
    profilesPanel:SetScript("OnShow", RefreshProfiles)
    RefreshProfiles()
end

local function SaveWidths()
    local left, right = tonumber(leftEdit:GetText()), tonumber(rightEdit:GetText())
    if not left or not right or left ~= math.floor(left) or right ~= math.floor(right)
        or left < 320 or right < 320 or left > 16384 or right > 16384 then
        UpdateTarget("Enter both widths as whole numbers from 320 to 16384 px.")
        return false
    end
    local profile = Profile()
    profile.leftWidth, profile.rightWidth = left, right
    UpdateTarget(string.format("Saved widths: %d x %d px.", left, right))
    return true
end

local function SaveWidth(edit, key, label)
    local text = edit:GetText()
    local value = tonumber(text)
    if text ~= "" and (not value or value ~= math.floor(value) or value < 320 or value > 16384) then
        UpdateTarget(label .. " must be a whole number from 320 to 16384 px.")
        return
    end
    Profile()[key] = value or 0
    UpdateTarget(label .. (value and string.format(" saved: %d px.", value) or " cleared."))
end

local function AddWidthBox(label, x, key)
    AddLabel(cameraPanel, label, x, -157, 185)
    local edit = CreateFrame("EditBox", nil, cameraPanel, "InputBoxTemplate")
    edit:SetSize(125, 24)
    edit:SetPoint("TOPLEFT", x, -180)
    edit:SetAutoFocus(false)
    edit:SetNumeric(true)
    edit:SetMaxLetters(5)
    edit:SetScript("OnEditFocusLost", function(self) SaveWidth(self, key, label) end)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEscapePressed", function(self)
        local saved = Profile()[key]
        self:SetText(saved > 0 and tostring(saved) or "")
        self:ClearFocus()
    end)
    return edit
end

local function CreateCameraPanel()
    cameraHost = CreateFrame("Frame", nil, UIParent)
    local scroll = CreateFrame("ScrollFrame", nil, cameraHost, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -28, 0)
    cameraPanel = CreateFrame("Frame", nil, scroll)
    cameraPanel:SetSize(640, 510)
    scroll:SetScrollChild(cameraPanel)
    scroll:SetScript("OnSizeChanged", function(self, width, height)
        cameraPanel:SetWidth(math.max(width - 4, 1))
        cameraPanel:SetHeight(math.max(510, height or 1))
    end)
    AddLabel(cameraPanel, "Camera settings", 20, -20, 420, "GameFontNormalLarge")
    local intro = AddLabel(cameraPanel,
        "A new install leaves WoW's camera settings alone. Enabling turns centering and reduced movement off, then applies this profile. Disabling restores your previous camera values without a UI reload.",
        20, -52, 510, "GameFontHighlight")
    intro:SetHeight(42)
    enableCheck = AddSwitch(cameraPanel, "Enable Camera Offset", -101, function(checked)
        Profile().enabled = checked
        local applied = ApplyProfile()
        UpdateTarget(checked and (applied and "Camera Offset enabled and applied to WoW."
            or "Camera Offset enabled, but WoW did not accept the offset.")
            or "Camera Offset disabled; previous camera values restored.")
    end)
    local resetButton = AddButton(cameraPanel, "Reset camera defaults", 226, -104, 178,
        ResetCameraDefaults)
    AddInfoLink(cameraPanel, resetButton, "CAMERAOFFSET_ENABLE_INFO")
    leftEdit = AddWidthBox("Left monitor width (px)", 20, "leftWidth")
    rightEdit = AddWidthBox("Right monitor width (px)", 230, "rightWidth")
    targetText = AddLabel(cameraPanel, "", 20, -216, 510, "GameFontHighlightSmall")
    targetText:SetHeight(42)
    AddButton(cameraPanel, "Try estimated offset", 20, -268, 176, function()
        if SaveWidths() then
            local profile = Profile()
            local estimate = 6 * profile.rightWidth / (profile.leftWidth + profile.rightWidth)
            profile.offset = math.floor(estimate * 10 + 0.5) / 10
            offsetSlider:SetValue(profile.offset)
            offsetValue:SetText(string.format("%.1f", profile.offset))
            local applied = ApplyProfile()
            UpdateTarget(string.format("Estimated offset %.1f %s", profile.offset,
                not profile.enabled and "saved; enable Camera Offset to apply it."
                or applied and "applied to WoW." or "saved, but WoW did not accept the offset."))
        end
    end)
    AddLabel(cameraPanel, "Camera shoulder offset", 20, -318, 300)
    offsetSlider = CreateFrame("Slider", "CameraOffsetSlider", cameraPanel, "OptionsSliderTemplate")
    offsetSlider:SetPoint("TOPLEFT", 26, -353)
    offsetSlider:SetWidth(360)
    offsetSlider:SetMinMaxValues(MIN_OFFSET, MAX_OFFSET)
    offsetSlider:SetValueStep(0.1)
    offsetSlider:SetObeyStepOnDrag(true)
    _G[offsetSlider:GetName() .. "Low"]:SetText(tostring(MIN_OFFSET))
    _G[offsetSlider:GetName() .. "High"]:SetText(tostring(MAX_OFFSET))
    _G[offsetSlider:GetName() .. "Text"]:SetText("")
    offsetValue = AddLabel(cameraPanel, "", 400, -353, 100)
    offsetSlider:SetScript("OnValueChanged", function(_, value)
        if refreshing then return end
        local rounded = math.floor(value * 10 + 0.5) / 10
        Profile().offset = rounded
        offsetValue:SetText(string.format("%.1f", rounded))
        local applied = ApplyProfile()
        UpdateTarget(string.format("Offset %.1f %s", rounded,
            not Profile().enabled and "saved; enable Camera Offset to apply it."
            or applied and "applied to WoW." or "saved, but WoW did not accept the offset."))
    end)
    AddLabel(cameraPanel,
        "The width estimate is only a starting point. Adjust the slider by eye; zoom and mounts can change the apparent alignment.",
        20, -413, 510, "GameFontHighlightSmall"):SetHeight(55)
    cameraPanel:SetScript("OnShow", RefreshCamera)
    RefreshCamera()
end

local function Initialize()
    LoadDB()
    -- A disabled profile never touches CVars on a fresh install.
    ApplyProfile()
    RegisterDialogs()
    CreateCameraPanel()
    CreateProfilesPanel()
    category = Settings.RegisterCanvasLayoutCategory(CreateAboutPanel(), "Camera Offset")
    Settings.RegisterAddOnCategory(category)
    cameraCategory = Settings.RegisterCanvasLayoutSubcategory(category, cameraHost, "Camera")
    profilesCategory = Settings.RegisterCanvasLayoutSubcategory(category, profilesPanel, "Profiles")
    SLASH_CAMERAOFFSET1 = "/cameraoffset"
    SlashCmdList.CAMERAOFFSET = function(message)
        local command = strtrim(message or ""):lower()
        local destination = command == "camera" and cameraCategory
            or command == "profiles" and profilesCategory or category
        Settings.OpenToCategory(destination:GetID())
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", Initialize)
