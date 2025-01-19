--[[ 
Hardcore Death Alerts Addon v0.5
- Tracks and displays deaths in Hardcore realms.

Quick Setup:
1. Enable Hardcore Death Announcements and set them to ALL DEATHS. (Hardcore Death Alerts can be 'never' and it still works fine.)
2. Join the 'HardcoreDeaths' channel. You can hide this channel in your chat settings.
3. Use /hcalerts for commands.

Commands:
/hcalerts reset     - Clears the death log.
--]]

-- Localize frequently used globals for faster access
local CreateFrame = CreateFrame
local string = string
local table = table
local PlaySound = PlaySound
local UnitLevel = UnitLevel
local pairs = pairs
local tonumber = tonumber
local match = string.match
local format = string.format
local insert = table.insert
local remove = table.remove

-- Namespace with local cache
local HCA = {
    deathData = {},     -- Loaded from saved variables
    frameCache = {},    -- Filled up in initilization
    rowCounter = 0,     -- Keeps track of total rows added in the Death Tracker
    patterns = {
        --[[
        {"fell to their death", "Falling"},                 -- Falling
        {"died of fatigue", "Fatigue"},                     -- Fatigue
        {"drowned to death", "Drowned"},                    -- Drowned
        {"was burnt to a crisp by lava", "Burnt in Lava"},  -- Death by Lava
        {"has been slain by a (.+)", nil},                  -- Monster Death
        {"has been slain by (.+)", nil}                     -- Player / Duel Death
        --]]

        
        {"drowned to death", "Drowned"},             -- Drowing
        {"fell to their death", "Falling"},          -- Falling
        {"died of fatigue", "Fatigue"},              -- Fatigue
        {"was burnt to death by fire", "Fire"},      -- Fire
        {"was burnt to a crisp by lava", "Lava"},    -- Lava
        {"has died at level", "No Cause"},           -- No Cause
        {"was slimed to death", "Slimed"},           -- Slimed
        {"has been slain by a (.+)", nil},           -- Monster Death
        {"has been slain by (.+)", nil},             -- Player Death
        {"has been slain in a duel by (.+)", nil}   -- Duel Death
    }
}

-- Settings Menu
HardcoreAlerts_SavedVars = {}

local category = Settings.RegisterVerticalLayoutCategory("Hardcore Alerts")

local function OnSettingChanged(setting, value)
	-- This callback will be invoked whenever a setting is modified.
	--print("Setting changed:", setting:GetVariable(), value)
    if setting:GetVariable() == "HardcoreAlerts_Tracker_Toggle" then
        if value then
            HCA.frameCache.addonFrame:Show()
        else
            HCA.frameCache.addonFrame:Hide()
        end
    end

    -- Eventually I want to parse what class the person who died was and set the alert to the player's class. Until then, this will allow the player to set it to whatever / make it match ElvUI really easily!
    if setting:GetVariable() == "HardcoreAlerts_AlertStyle_Selection" then
        local textures = {
            "Interface/AddOns/HardcoreAlerts/Textures/lines_druid.png",
            "Interface/AddOns/HardcoreAlerts/Textures/lines_hunter.png",
            "Interface/AddOns/HardcoreAlerts/Textures/lines_mage.png",
            "Interface/AddOns/HardcoreAlerts/Textures/lines_paladin.png",
            "Interface/AddOns/HardcoreAlerts/Textures/lines_priest.png",
            "Interface/AddOns/HardcoreAlerts/Textures/lines_rogue.png",
            "Interface/AddOns/HardcoreAlerts/Textures/lines_shaman.png",
            "Interface/AddOns/HardcoreAlerts/Textures/lines_warlock.png",
            "Interface/AddOns/HardcoreAlerts/Textures/lines_warrior.png",
            "" -- No Background
        }
    
        local index = HardcoreAlerts_SavedVars.alertStyleIndex
        local texturePath = textures[index]
    
        if texturePath then
            HCA.frameCache.alertBackground:SetTexture(texturePath)
        else
            print("This shouldn't be selected!")
        end
    end

    if setting:GetVariable() == "HardcoreAlerts_AlertFont_Selection" then
        local fonts = {
            [1] = "Fonts\\MORPHEUS.TTF",
            [2] = "Fonts\\ARIALN.TTF",
            [3] = "Fonts\\FRIZQT__.TTF",
            [4] = "Fonts\\skurri.ttf"
        }
    
        local fontPath = fonts[HardcoreAlerts_SavedVars.alertFontIndex]
        if fontPath then
            HCA.frameCache.alertText:SetFont(fontPath, 28, "THICKOUTLINE")
        else
            print("This shouldn't be selected!")
        end
    end
end

local function InitilizeSettingsUI()
    -- Load menu items here
    do 
        local name = "Show Alerts"
        local variable = "HardcoreAlerts_Alerts_Toggle"
        local variableKey = "showAlerts"
        local variableTbl = HardcoreAlerts_SavedVars
        local defaultValue = true
    
        local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTbl, type(defaultValue), name, defaultValue)
        setting:SetValueChangedCallback(OnSettingChanged)
    
        local tooltip = "Show on-screen death alerts?"
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    do 
        local name = "Show Death Tracker"
        local variable = "HardcoreAlerts_Tracker_Toggle"
        local variableKey = "showTracker"
        local variableTbl = HardcoreAlerts_SavedVars
        local defaultValue = true
    
        local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTbl, type(defaultValue), name, defaultValue)
        setting:SetValueChangedCallback(OnSettingChanged)
    
        local tooltip = "Show the death tracker?"
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    do 
        local name = "Show In Chat"
        local variable = "HardcoreAlerts_Chat_Toggle"
        local variableKey = "showChatMessage"
        local variableTbl = HardcoreAlerts_SavedVars
        local defaultValue = false
    
        local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTbl, type(defaultValue), name, defaultValue)
        setting:SetValueChangedCallback(OnSettingChanged)
    
        local tooltip = "Display in chat?"
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    do 
        local name = "Always Show Guild Member Alert"
        local variable = "HardcoreAlerts_GuildMember_Toggle"
        local variableKey = "showGuildAlert"
        local variableTbl = HardcoreAlerts_SavedVars
        local defaultValue = true
    
        local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTbl, type(defaultValue), name, defaultValue)
        setting:SetValueChangedCallback(OnSettingChanged)
    
        local tooltip = "Always show guild member alerts?"
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    do
        -- RegisterProxySetting example. This will run the GetValue and SetValue
        -- callbacks whenever access to the setting is required.
    
        local name = "Minimum Level for Alerts"
        local variable = "HardcoreAlerts_Slider"
        local defaultValue = 10
        local minValue = 10
        local maxValue = 60
        local step = 1
    
        local function GetValue()
            return HardcoreAlerts_SavedVars.minAlertSlider or defaultValue
        end
    
        local function SetValue(value)
            HardcoreAlerts_SavedVars.minAlertSlider = value
        end
    
        local setting = Settings.RegisterProxySetting(category, variable, type(defaultValue), name, defaultValue, GetValue, SetValue)
        setting:SetValueChangedCallback(OnSettingChanged)
    
        local tooltip = "Set the minimum level shown for on screen alerts."
        local options = Settings.CreateSliderOptions(minValue, maxValue, step)
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right);
        Settings.CreateSlider(category, setting, options, tooltip)
    end

    do 
        local name = "Minimum Level is Player's Level"
        local variable = "HardcoreAlerts_PlayerMinLevel_Toggle"
        local variableKey = "isMinLevelPlayerLevel"
        local variableTbl = HardcoreAlerts_SavedVars
        local defaultValue = true
    
        local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTbl, type(defaultValue), name, defaultValue)
        setting:SetValueChangedCallback(OnSettingChanged)
    
        local tooltip = "Should the minimum level for alerts be the player's level?"
        Settings.CreateCheckbox(category, setting, tooltip)
    end

    do
        local name = "Alert Style"
        local variable = "HardcoreAlerts_AlertStyle_Selection"
        local defaultValue = 1 -- Corresponds to "Option 2" below.
        local variableKey = "alertStyleIndex"
        local variableTbl = HardcoreAlerts_SavedVars
        local tooltip = "This is a tooltip for the dropdown."
    
        local function GetOptions()
            local container = Settings.CreateControlTextContainer()
            container:Add(1, "Lines - Druid")
            container:Add(2, "Lines - Hunter")
            container:Add(3, "Lines - Mage")
            container:Add(4, "Lines - Paladin")
            container:Add(5, "Lines - Priest")
            container:Add(6, "Lines - Rogue")
            container:Add(7, "Lines - Shaman")
            container:Add(8, "Lines - Warlock")
            container:Add(9, "Lines - Warrior")
            container:Add(10, "No Background")
            return container:GetData()
        end
    
        local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTbl, type(defaultValue), name, defaultValue)
        setting:SetValueChangedCallback(OnSettingChanged)

        Settings.CreateDropdown(category, setting, GetOptions, tooltip)
    end

    do
        local name = "Alert Font"
        local variable = "HardcoreAlerts_AlertFont_Selection"
        local defaultValue = 1
        local variableKey = "alertFontIndex"
        local variableTbl = HardcoreAlerts_SavedVars
        local tooltip = "This is a tooltip for the dropdown."
    
        local function GetOptions()
            local container = Settings.CreateControlTextContainer()

            container:Add(1, "Morpheus")
            container:Add(2, "Arial Narrow")
            container:Add(3, "Friz Quadrata")
            container:Add(4, "Skurri")

            return container:GetData()
        end
    
        local setting = Settings.RegisterAddOnSetting(category, variable, variableKey, variableTbl, type(defaultValue), name, defaultValue)
        setting:SetValueChangedCallback(OnSettingChanged)

        Settings.CreateDropdown(category, setting, GetOptions, tooltip)
    end

    Settings.RegisterAddOnCategory(category)
end

-- Initialize saved variables
HardcoreAlertsDB = HardcoreAlertsDB or {}

-- Cache frequently used colors
local COLOR_CACHE = {
    [-6] = "|cff808080", -- gray
    [-5] = "|cff00ff00", -- green
    [-2] = "|cffffff00", -- yellow
    [0] = "|cffffff00",  -- yellow
    [3] = "|cffff7f00",  -- orange
    [5] = "|cffff0000"   -- red
}

-- Save death data to the saved variables
local function SaveDeathData()
    --if not HardcoreAlertsDB then HardcoreAlertsDB = {} end
    HardcoreAlertsDB.deaths = HCA.deathData
end

-- Optimized color calculation
local function GetLevelColor(deathLevel)
    local levelDiff = deathLevel - UnitLevel("player")
    local color
    
    if levelDiff >= 5 then
        color = COLOR_CACHE[5]
        return color--, true
    elseif levelDiff >= 3 then
        color = COLOR_CACHE[3]
        return color--, true
    elseif levelDiff >= 0 then
        color = COLOR_CACHE[0]
        return color--, true
    elseif levelDiff >= -2 then
        color = COLOR_CACHE[-2]
        return color--, false
    elseif levelDiff >= -5 then
        color = COLOR_CACHE[-5]
        return color--, false
    else
        color = COLOR_CACHE[-6]
        return color--, false
    end
end

-- Create UI elements
local function InitializeUI()
    -- Main frame
    local addonFrame = CreateFrame("Frame", "DeathTrackerFrame", UIParent, "BackdropTemplate")
    addonFrame:SetSize(360, 190)  -- widened to accommodate table columns
    addonFrame:SetPoint("CENTER")
    addonFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    addonFrame:SetBackdropColor(0, 0, 0, 0.8)
    addonFrame:EnableMouse(true)
    addonFrame:SetMovable(true)
    addonFrame:RegisterForDrag("LeftButton")
    addonFrame:SetScript("OnDragStart", addonFrame.StartMoving)
    addonFrame:SetScript("OnDragStop", addonFrame.StopMovingOrSizing)
    --addonFrame:SetResizable(true)
    --addonFrame:SetResizeBounds(400, 280, 400, 300)
    addonFrame:SetClipsChildren(true)

    -- Resize button
    --[[
    local resizeButton = CreateFrame("Button", nil, addonFrame)
    resizeButton:SetSize(16, 16)
    resizeButton:SetPoint("BOTTOMRIGHT")
    resizeButton:SetNormalTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
    resizeButton:SetHighlightTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Highlight")
    resizeButton:SetPushedTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Down")
    resizeButton:SetScript("OnMouseDown", function() addonFrame:StartSizing("BOTTOMRIGHT") end)
    resizeButton:SetScript("OnMouseUp", function() addonFrame:StopMovingOrSizing() end)
    --]]

    -- Title
    local title = addonFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -10)
    title:SetFont("Fonts\\MORPHEUS.TTF", 14, "OUTLINE")
    title:SetText("Death Tracker")

    -- Tooltip (for commands)
    title:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Reset Data: /hcalerts reset", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    title:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Scroll frame
    --[[
    local scrollFrame = CreateFrame("ScrollingMessageFrame", nil, addonFrame)
    scrollFrame:SetSize(180, 260)
    scrollFrame:SetPoint("BOTTOM", 0, 10)
    scrollFrame:SetFontObject(GameFontHighlight)
    scrollFrame:SetJustifyH("LEFT")
    scrollFrame:SetFading(false)
    scrollFrame:SetMaxLines(100)
    --]]

    -- Create a scroll frame to contain our table
    local content = CreateFrame("Frame", nil, addonFrame)
    content:SetSize(addonFrame:GetWidth() - 20, addonFrame:GetHeight() - 60)
    content:SetPoint("TOPLEFT", addonFrame, "TOPLEFT", 10, -30)

    -- Table Header
    local headerRow = CreateFrame("Frame", nil, addonFrame)
    headerRow:SetHeight(20)
    headerRow:SetWidth(content:GetWidth())
    headerRow:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)

    local headers = {"Lvl", "Name", "Cause", "Location"}
    local columnWidths = {20, 80, 100, 100} -- {40, 100, 100, 120}
    local runningWidth = 0

    for i, text in ipairs(headers) do
        local headerText = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        headerText:SetPoint("LEFT", headerRow, "LEFT", runningWidth, 0)
        headerText:SetWidth(columnWidths[i])
        headerText:SetText(text)
        runningWidth = runningWidth + columnWidths[i] + 10
    end

    -- Initialize variables for adding rows
    HCA.frameCache = HCA.frameCache or {}
    HCA.frameCache.addonFrame = addonFrame
    HCA.frameCache.scrollFrame = scrollFrame
    HCA.frameCache.content = content
    HCA.frameCache.headerRow = headerRow
    HCA.lastRow = nil  -- to track last added row for positioning

    -- Alert Frame
    local alertFrame = CreateFrame("Frame", "AlertFrame", UIParent)
    alertFrame:SetSize(400, 100)
    alertFrame:SetPoint("TOP")
    alertFrame:SetAlpha(0)

    -- Alert text
    local alertText = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    alertText:SetPoint("TOP", alertFrame, "TOP", 0, -100)
    alertText:SetTextColor(1, 1, 1, 1)
    -- Load the correct font from the saved variables
    --alertText:SetFont("Fonts\\MORPHEUS.TTF", 28, "THICKOUTLINE")
    HCA.frameCache.alertText = alertText

    local fonts = {
        [1] = "Fonts\\MORPHEUS.TTF",
        [2] = "Fonts\\ARIALN.TTF",
        [3] = "Fonts\\FRIZQT__.TTF",
        [4] = "Fonts\\skurri.ttf"
    }
    
    local fontPath = fonts[HardcoreAlerts_SavedVars.alertFontIndex]
    
    if fontPath then
        alertText:SetFont(fontPath, 28, "THICKOUTLINE")
    else
        print("This shouldn't be selected!")
    end

    -- Alert background
    local alertBackground = alertFrame:CreateTexture(nil, "BACKGROUND")
    alertBackground:SetPoint("CENTER", alertText, "CENTER", 0, 0)
    alertBackground:SetScale(0.75, 0.75)
    -- Load the correct texture from the saved variables
    --alertBackground:SetTexture("Interface/AddOns/HardcoreAlerts/Textures/alert_bg_red.png")
    HCA.frameCache.alertBackground = alertBackground

    local textures = {
        "Interface/AddOns/HardcoreAlerts/Textures/lines_druid.png",
        "Interface/AddOns/HardcoreAlerts/Textures/lines_hunter.png",
        "Interface/AddOns/HardcoreAlerts/Textures/lines_mage.png",
        "Interface/AddOns/HardcoreAlerts/Textures/lines_paladin.png",
        "Interface/AddOns/HardcoreAlerts/Textures/lines_priest.png",
        "Interface/AddOns/HardcoreAlerts/Textures/lines_rogue.png",
        "Interface/AddOns/HardcoreAlerts/Textures/lines_shaman.png",
        "Interface/AddOns/HardcoreAlerts/Textures/lines_warlock.png",
        "Interface/AddOns/HardcoreAlerts/Textures/lines_warrior.png",
        "" -- No Background
    }
    
    local index = HardcoreAlerts_SavedVars.alertStyleIndex
    local texturePath = textures[index]
    
    if texturePath then
        HCA.frameCache.alertBackground:SetTexture(texturePath)
    else
        print("This shouldn't be selected!")
    end

    -- Create animation group once
    local animGroup = alertFrame:CreateAnimationGroup()
    
    local fadeIn = animGroup:CreateAnimation("Alpha")
    fadeIn:SetOrder(1)
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.5)
    fadeIn:SetSmoothing("IN")

    local stay = animGroup:CreateAnimation("Alpha")
    stay:SetOrder(2)
    stay:SetFromAlpha(1)
    stay:SetToAlpha(1)
    stay:SetDuration(3)
    stay:SetSmoothing("NONE")

    local fadeOut = animGroup:CreateAnimation("Alpha")
    fadeOut:SetOrder(3)
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(5)
    fadeOut:SetSmoothing("OUT")

    animGroup:SetScript("OnPlay", function()
        alertText:Show()
        alertBackground:Show()
    end)

    animGroup:SetScript("OnFinished", function()
        alertBackground:Hide()
        alertText:Hide()
    end)

    HCA.frameCache.animGroup = animGroup

    -- Update scroll frame size function
    local function UpdateScrollFrame()
        --[[
        scrollFrame:ClearAllPoints()
        scrollFrame:SetPoint("TOPLEFT", addonFrame, "TOPLEFT", 10, -30)
        scrollFrame:SetPoint("BOTTOMRIGHT", addonFrame, "BOTTOMRIGHT", -10, 10)
        scrollFrame:SetSize(addonFrame:GetWidth() - 20, addonFrame:GetHeight() - 40)
        --]]

        local newWidth = addonFrame:GetWidth() - 40
        HCA.frameCache.content:SetWidth(newWidth)
        HCA.frameCache.headerRow:SetWidth(newWidth)

        content:SetSize(addonFrame:GetWidth() - 20, addonFrame:GetHeight() - 40)
    end

    addonFrame:SetScript("OnSizeChanged", UpdateScrollFrame)
    UpdateScrollFrame()

    return addonFrame, scrollFrame, alertText, alertBackground
end

-- Create a new row in the table for a death entry
local function AddDeathRow(death)
    local content = HCA.frameCache.content

    -- Increment the persistent row counter
    HCA.rowCounter = HCA.rowCounter + 1
    local rowIndex = HCA.rowCounter  -- Use the persistent counter

    -- Create a new row
    local row = CreateFrame("Frame", nil, content)
    row:SetHeight(20)
    row:SetWidth(content:GetWidth())

    -- Apply alternating colors
    local backgroundColor
    if rowIndex % 2 == 0 then
        -- Even row (light gray)
        backgroundColor = { r = 0.2, g = 0.2, b = 0.2, a = 0.6 }
    else
        -- Odd row (dark gray)
        backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.6 }
    end

    -- Add a background texture to the row
    local rowBackground = row:CreateTexture(nil, "BACKGROUND")
    rowBackground:SetAllPoints(row)
    rowBackground:SetColorTexture(backgroundColor.r, backgroundColor.g, backgroundColor.b, backgroundColor.a)

    local columns = { death.level, death.name, death.cause, death.location }
    local columnWidths = {20, 80, 100, 100}
    local runningWidth = 0

    for i, text in ipairs(columns) do
        local colText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        colText:SetPoint("LEFT", row, "LEFT", runningWidth, 0)
        colText:SetWidth(columnWidths[i])

        -- Apply level color
        if i == 1 then
            local levelColor = GetLevelColor(death.level) or "|cffffffff" -- Default to white
            colText:SetText(levelColor .. text .. "|r")
        else
            colText:SetText(text)
        end

        runningWidth = runningWidth + columnWidths[i] + 10
    end

    -- Add the new row at the bottom
    local numChildren = #content:GetChildren()
    if numChildren == 0 then
        row:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0)
    else
        local lastRow = select(numChildren, content:GetChildren())
        row:SetPoint("BOTTOMLEFT", lastRow, "TOPLEFT", 0, 2)
    end

    -- Remove excess rows
    local rows = { content:GetChildren() }
    if #rows > 6 then
        rows[1]:Hide()
        rows[1]:SetParent(nil)
    end

    -- Reposition rows after adding and/or removing
    local rows = { content:GetChildren() }
    local numRows = #rows

    -- Reposition rows starting from the bottom
    for i = numRows, 1, -1 do
        local row = rows[i]
        if i == numRows then
            row:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0)
        else
            row:SetPoint("BOTTOMLEFT", rows[i + 1], "TOPLEFT", 0, 2)
        end
    end
end

-- Alert display
local function ShowDeathAlert(message)
    local alertText = HCA.frameCache.alertText
    --local cleanedMessage = message:gsub("%[(.-)%]", "%1"):gsub("!", "!\n")
    
    alertText:SetText(message)
    
    HCA.frameCache.animGroup:Stop()
    HCA.frameCache.animGroup:Play()

    PlaySound(8959, "Master")
end

-- Check if the player is in the player's guild
local function IsPlayerInGuild(playerName)
    local numMembers = GetNumGuildMembers()
    for i = 1, numMembers do
        local name, _, rankIndex, _, level, class, zone, onlineStatus, isAway, notes, officierNote = GetGuildRosterInfo(i)

        name = strsplit("-", name)

        if name == playerName then
            return true
        end
    end
    return false
end

-- Check if the player is on the player's friend's list
local function IsPlayerInFriendList(playerName)
    -- Check if the player is in the friend list
    for i = 1, C_FriendList.GetNumFriends() do
        local name = C_FriendList.GetFriendInfoByIndex(i).name
        if name and name == playerName then
            return true
        end
    end
    return false
end

-- Message processing
local function ProcessDeathMessage(message)
    local name, cause, zone, level = match(message, "%[(.-)%](.-) in (.-)! They were level (%d+)")
    
    if not (name and level and cause and zone) then return end
    
    level = tonumber(level)
    local rewordedCause = ""
    
    for _, pattern in pairs(HCA.patterns) do
        local match = string.match(cause, pattern[1])
        if match then
            rewordedCause = pattern[2] or match
            break
        end
    end

    -- Self Check
    local isSelf = name == UnitName("player")
    if isSelf then
        name = "|cffff0000" .. name .. "|r" -- Turn the name red!
    end

    -- Guild Check
    local isInGuild = IsPlayerInGuild(name)
    if isInGuild then
        name = "|cff00ff00" .. name .. "|r" -- Turn the name green!
    end

    -- Check if the player is a friend
    local isFriend = IsPlayerInFriendList(name)
    if isFriend then
        name = "|cffffff00" .. name .. "|r" -- Turn the name yellow for friends
    end

    -- After parsing death info:
    local deathRecord = {
        level = level,
        name = name,
        cause = rewordedCause,
        location = zone
    }

    insert(HCA.deathData, deathRecord)
    if #HCA.deathData > 100 then
        remove(HCA.deathData, 1)
    end

    SaveDeathData()
    
    -- Add a new row to the table for this death
    AddDeathRow(deathRecord)

    -- Show Alerts or not                   HardcoreAlerts_SavedVars.showAlerts
    -- Show in chat or not                  HardcoreAlerts_SavedVars.showChatMessage
    -- Level is player's / level is set     HardcoreAlerts_SavedVars.isMinLevelPlayerLevel
    -- Make guildies always show            HardcoreAlerts_SavedVars.showGuildAlert

    -- Create the alert message
    local alertMessage

    if isSelf then
        alertMessage = name .. cause .. " in " .. zone .. "!\nYou were level " .. level
    else
        alertMessage = name .. cause .. " in " .. zone .. "!\nThey were level " .. level
    end

    if HardcoreAlerts_SavedVars.showAlerts then
        -- Always show myself
        if isSelf then
            ShowDeathAlert(alertMessage)
            return
        end

         -- Always show guildies (if the options is checked)
        if HardcoreAlerts_SavedVars.showGuildAlert and isInGuild then
            ShowDeathAlert(alertMessage)
            return
        end

        -- Check which level to check against when showing alerts
        local minLevel = 0
        if HardcoreAlerts_SavedVars.isMinLevelPlayerLevel then
            minLevel = UnitLevel("player")
        else
            minLevel = HardcoreAlerts_SavedVars.minAlertSlider
        end

        if level >= minLevel then
            ShowDeathAlert(alertMessage)
        end
    end

    if HardcoreAlerts_SavedVars.showChatMessage then
        print(alertMessage)
    end
end

-- Hook into the ADDON_LOADED event to initialize saved data -> Might need to throw this somewhere else and see what happens
local frame = CreateFrame("Frame") -- I'm not actually sure I need to create this frame again. I bet it can fit under the addonFrame one, but this works for now!
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == "HardcoreAlerts" then
        InitilizeSettingsUI()
        InitializeUI()

        if HardcoreAlerts_SavedVars.showTracker then
            HCA.frameCache.addonFrame:Show()
        else
            HCA.frameCache.addonFrame:Hide()
        end

        -- Initialize saved data if not present
        HCA.deathData = HardcoreAlertsDB.deaths or {}

        -- Populate the data
        for _, deathEntry in ipairs(HCA.deathData) do
            AddDeathRow(deathEntry)
        end
    end
end)

-- Event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CHAT_MSG_CHANNEL")

eventFrame:SetScript("OnEvent", function(_, _, message, _, _, channelName)
    local channel = match(channelName, "%d+%.%s*(.+)")
    if channel == "HardcoreDeaths" then
        ProcessDeathMessage(message)
    end
end)

-- Random test function lol
local testData = {
    playerName = {
        "Thaloran", "Elyndra", "Gromnak", "Kelthar", "Silvoria",
        "Aelandra", "Rognak", "Tyralynn", "Mordak", "Veladyn",
        "Darnok", "Feylith", "Orlanna", "Kaelthorn", "Bryndis",
        "Lutharion", "Zanith", "Yveris", "Torrek", "Faldryn"
    },
    monsterName = {
        "Murloc Raider", "Defias Bandit", "Gnoll Brute", "Blackrock Grunt", "Worg Stalker",
        "Searing Blade Cultist", "Stonetalon Owl", "Silithid Swarmer", "Goretusk Boar", "Voidwalker Minion",
        "Scarlet Centurion", "Dark Iron Slaver", "Fire Elemental", "Blightcaller", "Rotting Ghoul",
        "Razormane Mystic", "Vilebranch Headhunter", "Burning Felhound", "Twilight Geomancer", "Nether Drake"
    },
    locationName = {
        "Elwynn Forest", "The Barrens", "Stranglethorn Vale", "Dun Morogh", "Tirisfal Glades",
        "Westfall", "Ashenvale", "Redridge Mountains", "Tanaris", "Silverpine Forest",
        "Alterac Mountains", "Thousand Needles", "Duskwood", "Desolace", "The Hinterlands",
        "Felwood", "Darkshore", "Feralas", "Moonglade", "Winterspring"
    }
}

-- Slash commands
SLASH_HARDCOREALERTS1 = "/hcalerts"
SlashCmdList["HARDCOREALERTS"] = function(msg)
    msg = msg:lower()
    -- Only for testing -- REMOVE THIS
    if msg == "test" then
        local randomPlayer = testData.playerName[math.random(#testData.playerName)]
        local randomMonster = testData.monsterName[math.random(#testData.monsterName)]
        local randomLocation = testData.locationName[math.random(#testData.locationName)]
        local randomLevel = math.random(60)

        local message = "[" .. randomPlayer .. "]" .. " has been slain by a " .. randomMonster .. " in " .. randomLocation .. "! They were level " .. randomLevel .. "."
        ProcessDeathMessage(message)
    end

    if msg == "reset" then
        -- Clear the death data
        HCA.deathData = {}

        -- Clear saved variables
        HardcoreAlertsDB.deaths = {}

        -- Reset row counter
        HCA.rowCounter = 0

        -- Remove all rows except the header
        local content = HCA.frameCache.content
        for _, child in ipairs({content:GetChildren()}) do
            if child ~= HCA.frameCache.headerRow then
                child:Hide()
                child:SetParent(nil)
            end
        end

        HCA.lastRow = nil

        print("Hardcore Alerts: Resetting Data!")
    end
end