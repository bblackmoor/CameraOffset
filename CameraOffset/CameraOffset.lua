local DEFAULT_NAME = "Default"
local MIN_OFFSET, MAX_OFFSET = -20, 20
local db, cameraPanel, cameraHost, profilesPanel, category
local leftEdit, rightEdit, targetText, offsetSlider, offsetValue
local keepCheck, reduceCheck, enableCheck, profileDropdown
local renameButton, deleteButton
local refreshing = false

local function GameDefault(name, fallback)
    local value = C_CVar.GetCVarDefault(name)
    return value ~= nil and value or fallback
end

local function DefaultProfile()
    return {
        keepCentered = GameDefault("CameraKeepCharacterCentered", C_CVar.GetCVar("CameraKeepCharacterCentered") or "0"),
        reduceMovement = GameDefault("CameraReduceUnexpectedMovement", C_CVar.GetCVar("CameraReduceUnexpectedMovement") or "0"),
        offset = tonumber(GameDefault("test_cameraOverShoulder", C_CVar.GetCVar("test_cameraOverShoulder") or "0")) or 0,
        leftWidth = 0, rightWidth = 0, enabled = false,
    }
end

local function CopyProfile(source)
    return {
        keepCentered = source.keepCentered, reduceMovement = source.reduceMovement,
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
    if saved.keepCentered == "0" or saved.keepCentered == "1" then result.keepCentered = saved.keepCentered end
    if saved.reduceMovement == "0" or saved.reduceMovement == "1" then result.reduceMovement = saved.reduceMovement end
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
            keepCentered = "0", reduceMovement = "0", offset = saved.offset,
            leftWidth = saved.leftWidth, rightWidth = saved.rightWidth, enabled = true,
        })
        db.profileKeys[CharacterKey()] = "Previous Camera Offset"
        db.fallbackProfile = "Previous Camera Offset"
        db.legacyDefaults = {
            keepCentered = GameDefault("CameraKeepCharacterCentered", "0"),
            reduceMovement = GameDefault("CameraReduceUnexpectedMovement", "0"),
            offset = GameDefault("test_cameraOverShoulder", "0"),
        }
        db.originalsByCharacter = { [CharacterKey()] = CopyProfile(db.legacyDefaults) }
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
        return
    end
    local character = CharacterKey()
    if not db.originalsByCharacter[character] then
        local originals = {}
        for key, cvar in pairs(CVARS) do
            originals[key] = db.legacyDefaults and db.legacyDefaults[key] or C_CVar.GetCVar(cvar)
        end
        db.originalsByCharacter[character] = originals
    end
    C_CVar.SetCVar("CameraKeepCharacterCentered", profile.keepCentered)
    C_CVar.SetCVar("CameraReduceUnexpectedMovement", profile.reduceMovement)
    C_CVar.SetCVar("test_cameraOverShoulder", tostring(profile.offset))
end

local function AddLabel(parent, content, x, y, width, font)
    local label = parent:CreateFontString(nil, "ARTWORK", font or "GameFontNormal")
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    label:SetText(content)
    return label
end

local function UpdateTarget()
    local profile = Profile()
    if profile.leftWidth > 0 and profile.rightWidth > 0 then
        targetText:SetText(string.format("Left monitor center: %.1f%% across the full window",
            50 * profile.leftWidth / (profile.leftWidth + profile.rightWidth)))
    else
        targetText:SetText("Enter both monitor widths to estimate a starting offset.")
    end
end

local function RefreshCamera()
    refreshing = true
    local profile = Profile()
    leftEdit:SetText(profile.leftWidth > 0 and tostring(profile.leftWidth) or "")
    rightEdit:SetText(profile.rightWidth > 0 and tostring(profile.rightWidth) or "")
    keepCheck:SetChecked(profile.keepCentered == "1")
    reduceCheck:SetChecked(profile.reduceMovement == "1")
    enableCheck:SetChecked(profile.enabled)
    offsetSlider:SetValue(profile.offset)
    offsetValue:SetText(string.format("%.1f", profile.offset))
    UpdateTarget()
    refreshing = false
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
end

local function AddButton(parent, label, x, y, width, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(label)
    button:SetScript("OnClick", callback)
    return button
end

local function CreateProfilesPanel()
    profilesPanel = CreateFrame("Frame", nil, UIParent)
    AddLabel(profilesPanel, "Profiles", 20, -20, 420, "GameFontNormalLarge")
    local info = AddLabel(profilesPanel,
        "Profiles contain every camera setting, including both monitor widths. They are shared account-wide; each character remembers its selected profile.",
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
    local function NameDialog(action, initial)
        StaticPopup_Show("CAMERAOFFSET_PROFILE_NAME", nil, nil, { action = action, initial = initial })
    end
    AddButton(profilesPanel, "Create", 20, -215, 88, function() NameDialog("create", "") end)
    AddButton(profilesPanel, "Copy", 115, -215, 88, function() NameDialog("copy", ProfileName() .. " Copy") end)
    renameButton = AddButton(profilesPanel, "Rename", 210, -215, 88,
        function() NameDialog("rename", ProfileName()) end)
    deleteButton = AddButton(profilesPanel, "Delete", 305, -215, 88,
        function() StaticPopup_Show("CAMERAOFFSET_DELETE_PROFILE", ProfileName()) end)
    AddButton(profilesPanel, "Restore Default", 20, -260, 145,
        function() StaticPopup_Show("CAMERAOFFSET_RESTORE_DEFAULT") end)
    AddLabel(profilesPanel, "Default can be edited and restored, but cannot be renamed or deleted. New profiles start with WoW's defaults; Copy starts with the currently selected settings.",
        20, -310, 510, "GameFontHighlightSmall"):SetHeight(55)
    profilesPanel:SetScript("OnShow", RefreshProfiles)
    RefreshProfiles()
end

local function SaveWidths()
    local left, right = tonumber(leftEdit:GetText()), tonumber(rightEdit:GetText())
    if not left or not right or left ~= math.floor(left) or right ~= math.floor(right)
        or left < 320 or right < 320 or left > 16384 or right > 16384 then
        print("|cffffaa00Camera Offset:|r Enter whole-number widths from 320 to 16384 pixels.")
        return false
    end
    local profile = Profile()
    profile.leftWidth, profile.rightWidth = left, right
    leftEdit:ClearFocus()
    rightEdit:ClearFocus()
    UpdateTarget()
    return true
end

local function AddWidthBox(label, x)
    AddLabel(cameraPanel, label, x, -262, 185)
    local edit = CreateFrame("EditBox", nil, cameraPanel, "InputBoxTemplate")
    edit:SetSize(125, 24)
    edit:SetPoint("TOPLEFT", x + 5, -287)
    edit:SetAutoFocus(false)
    edit:SetNumeric(true)
    edit:SetMaxLetters(5)
    edit:SetScript("OnEnterPressed", SaveWidths)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return edit
end

local function AddCVarCheck(label, y, key)
    local check = CreateFrame("CheckButton", nil, cameraPanel, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", 20, y)
    local text = AddLabel(cameraPanel, label, 50, y - 5, 460, "GameFontHighlight")
    text:SetHeight(25)
    check:SetScript("OnClick", function(self)
        Profile()[key] = self:GetChecked() and "1" or "0"
        ApplyProfile()
    end)
    return check
end

local function CreateCameraPanel()
    cameraHost = CreateFrame("Frame", nil, UIParent)
    local scroll = CreateFrame("ScrollFrame", nil, cameraHost, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", -28, 0)
    cameraPanel = CreateFrame("Frame", nil, scroll)
    cameraPanel:SetSize(640, 620)
    scroll:SetScrollChild(cameraPanel)
    scroll:SetScript("OnSizeChanged", function(self, width, height)
        cameraPanel:SetWidth(math.max(width - 4, 1))
        cameraPanel:SetHeight(math.max(620, height or 1))
    end)
    AddLabel(cameraPanel, "Camera settings", 20, -20, 420, "GameFontNormalLarge")
    local intro = AddLabel(cameraPanel,
        "A new install leaves WoW's camera settings alone. Enable a profile to apply its settings now and at login. Disabling restores your previous camera values without a UI reload.",
        20, -52, 510, "GameFontHighlight")
    intro:SetHeight(42)
    enableCheck = CreateFrame("CheckButton", nil, cameraPanel, "UICheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", 20, -101)
    AddLabel(cameraPanel, "Enable Camera Offset", 50, -106, 460, "GameFontHighlight")
    enableCheck:SetScript("OnClick", function(self)
        Profile().enabled = self:GetChecked() == true
        ApplyProfile()
    end)
    keepCheck = AddCVarCheck("Keep character centered (WoW camera setting)", -140, "keepCentered")
    reduceCheck = AddCVarCheck("Reduce unexpected camera movement (WoW camera setting)", -176, "reduceMovement")
    leftEdit = AddWidthBox("Left monitor width (px)", 20)
    rightEdit = AddWidthBox("Right monitor width (px)", 230)
    AddButton(cameraPanel, "Save widths", 20, -325, 120, SaveWidths)
    targetText = AddLabel(cameraPanel, "", 20, -365, 510, "GameFontHighlightSmall")
    AddButton(cameraPanel, "Try estimated offset", 20, -401, 176, function()
        if SaveWidths() then
            local profile = Profile()
            offsetSlider:SetValue(6 * profile.rightWidth / (profile.leftWidth + profile.rightWidth))
        end
    end)
    AddLabel(cameraPanel, "Camera shoulder offset", 20, -454, 300)
    offsetSlider = CreateFrame("Slider", "CameraOffsetSlider", cameraPanel, "OptionsSliderTemplate")
    offsetSlider:SetPoint("TOPLEFT", 26, -490)
    offsetSlider:SetWidth(360)
    offsetSlider:SetMinMaxValues(MIN_OFFSET, MAX_OFFSET)
    offsetSlider:SetValueStep(0.1)
    offsetSlider:SetObeyStepOnDrag(true)
    _G[offsetSlider:GetName() .. "Low"]:SetText(tostring(MIN_OFFSET))
    _G[offsetSlider:GetName() .. "High"]:SetText(tostring(MAX_OFFSET))
    _G[offsetSlider:GetName() .. "Text"]:SetText("")
    offsetValue = AddLabel(cameraPanel, "", 400, -490, 100)
    offsetSlider:SetScript("OnValueChanged", function(_, value)
        if refreshing then return end
        local rounded = math.floor(value * 10 + 0.5) / 10
        Profile().offset = rounded
        offsetValue:SetText(string.format("%.1f", rounded))
        ApplyProfile()
    end)
    AddLabel(cameraPanel,
        "The width estimate is only a starting point. Adjust the slider by eye; zoom and mounts can change the apparent alignment.",
        20, -550, 510, "GameFontHighlightSmall"):SetHeight(55)
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
    category = Settings.RegisterCanvasLayoutCategory(cameraHost, "Camera Offset")
    Settings.RegisterAddOnCategory(category)
    Settings.RegisterCanvasLayoutSubcategory(category, profilesPanel, "Profiles")
    SLASH_CAMERAOFFSET1 = "/cameraoffset"
    SlashCmdList.CAMERAOFFSET = function() Settings.OpenToCategory(category:GetID()) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", Initialize)
