--[[ 
Hardcore Death Alerts Addon v1.0.0
- Tracks and displays deaths in Hardcore realms.

Quick Setup:
1. Enable Hardcore Death Announcements and set them to ALL DEATHS. (Hardcore Death Alerts can be 'never' and it still works fine.)
2. Join the 'HardcoreDeaths' channel. You can hide this channel in your chat settings.
3. Use /hcalerts for commands.

Commands:
/hcalerts reset     - Clears the death log.
/hcalerts log on    - Shows the death tracker window. (Showing by default)
/hcalerts log off   - Hides the death tracker window.
/hcalerts on        - Turns the alerts on. (On by default)
/hcalerts off       - Turns the alerts off.

Enjoy tracking the inevitable!
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
    patterns = {
        {"fell to their death", "Falling"}, -- Falling
        {"died of fatigue", "Fatigue"},     -- Fatigue
        {"drowned to death", "Drowned"},    -- Drowned
        {"has been slain by a (.+)", nil},  -- Monster Death
        {"has been slain by (.+)", nil}     -- Player / Duel Death
    }
}

-- Initialize saved variables
HardcoreAlertsDB = HardcoreAlertsDB or {}
showingAlerts = showingAlerts or true
showingTracker = showingTracker or true

-- Hook into the ADDON_LOADED event to initialize saved data -> Might need to throw this somewhere else and see what happens
local frame = CreateFrame("Frame") -- I'm not actually sure I need to create this frame again. I bet it can fit under the addonFrame one, but this works for now!
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == "HardcoreAlerts" then
        if showingTracker then
            HCA.frameCache.addonFrame:Show()
        else
            HCA.frameCache.addonFrame:Hide()
        end

        -- Initialize saved data if not present
        HCA.deathData = HardcoreAlertsDB.deaths or {}

        -- Populate the data
        for _, deathEntry in ipairs(HCA.deathData) do
            HCA.frameCache.scrollFrame:AddMessage(deathEntry)
        end
    end
end)

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
        return color, true
    elseif levelDiff >= 3 then
        color = COLOR_CACHE[3]
        return color, true
    elseif levelDiff >= 0 then
        color = COLOR_CACHE[0]
        return color, true
    elseif levelDiff >= -2 then
        color = COLOR_CACHE[-2]
        return color, false
    elseif levelDiff >= -5 then
        color = COLOR_CACHE[-5]
        return color, false
    else
        color = COLOR_CACHE[-6]
        return color, false
    end
end

-- Create UI elements
local function InitializeUI()
    -- Main frame
    local addonFrame = CreateFrame("Frame", "DeathTrackerFrame", UIParent, "BackdropTemplate")
    addonFrame:SetSize(200, 300)
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
    addonFrame:SetResizable(true)
    addonFrame:SetResizeBounds(150, 200, 400, 600)

    -- Resize button
    local resizeButton = CreateFrame("Button", nil, addonFrame)
    resizeButton:SetSize(16, 16)
    resizeButton:SetPoint("BOTTOMRIGHT")
    resizeButton:SetNormalTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
    resizeButton:SetHighlightTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Highlight")
    resizeButton:SetPushedTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Down")
    resizeButton:SetScript("OnMouseDown", function() addonFrame:StartSizing("BOTTOMRIGHT") end)
    resizeButton:SetScript("OnMouseUp", function() addonFrame:StopMovingOrSizing() end)

    -- Title
    local title = addonFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -10)
    title:SetFont("Fonts\\MORPHEUS.TTF", 14, "OUTLINE")
    title:SetText("Death Tracker")

    -- Tooltip (for commands)
    title:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Show Alerts: /hcalerts on\nHide Alerts: /hcalerts off\nShow Tracker: /hcalerts log on\nHide Tracker: /hcalerts log off\nReset Data: /hcalerts reset", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    title:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Scroll frame
    local scrollFrame = CreateFrame("ScrollingMessageFrame", nil, addonFrame)
    scrollFrame:SetSize(180, 260)
    scrollFrame:SetPoint("BOTTOM", 0, 10)
    scrollFrame:SetFontObject(GameFontHighlight)
    scrollFrame:SetJustifyH("LEFT")
    scrollFrame:SetFading(false)
    scrollFrame:SetMaxLines(100)

    -- Cache frames for faster access
    HCA.frameCache.addonFrame = addonFrame
    HCA.frameCache.scrollFrame = scrollFrame
    HCA.frameCache.title = title

    -- Alert text
    local alertText = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    alertText:SetPoint("TOP", UIParent, "TOP", 0, -150)
    alertText:SetTextColor(1, 1, 1, 0)
    alertText:SetFont("Fonts\\MORPHEUS.TTF", 28, "THICKOUTLINE")
    alertText:Hide()
    HCA.frameCache.alertText = alertText

    -- Create animation group once
    local animGroup = alertText:CreateAnimationGroup()
    
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

    animGroup:SetScript("OnFinished", function()
        alertText:Hide()
    end)

    HCA.frameCache.animGroup = animGroup

    -- Update scroll frame size function
    local function UpdateScrollFrame()
        scrollFrame:ClearAllPoints()
        scrollFrame:SetPoint("TOPLEFT", addonFrame, "TOPLEFT", 10, -30)
        scrollFrame:SetPoint("BOTTOMRIGHT", addonFrame, "BOTTOMRIGHT", -10, 10)
        scrollFrame:SetSize(addonFrame:GetWidth() - 20, addonFrame:GetHeight() - 40)
    end

    addonFrame:SetScript("OnSizeChanged", UpdateScrollFrame)
    UpdateScrollFrame()

    return addonFrame, scrollFrame, alertText
end

-- Alert display
local function ShowDeathAlert(message)
    local alertText = HCA.frameCache.alertText
    --local cleanedMessage = message:gsub("%[(.-)%]", "%1"):gsub("!", "!\n")
    
    alertText:SetText(message)
    alertText:SetAlpha(0)
    alertText:Show()
    
    HCA.frameCache.animGroup:Stop()
    HCA.frameCache.animGroup:Play()
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

    -- Guild Check
    local isInGuild
    if IsInGuild() then
        isInGuild = IsPlayerInGuild(name)

        if isInGuild then
            name = "|cff00ff00" .. name .. "|r" -- Turn the name green!
        end
    end

    local levelColor, playSound = GetLevelColor(level)
    local deathInfo = format("(%s%s|r) %s - %s - %s", levelColor, level, name, rewordedCause, zone) -- TODO: Rework this to be tab-spaced? Or put it in a table instead?
    
    insert(HCA.deathData, deathInfo)
    if #HCA.deathData > 100 then
        remove(HCA.deathData, 1)
    end

    SaveDeathData()
    
    HCA.frameCache.scrollFrame:AddMessage(deathInfo)
    
    if not showingAlerts then return end

    if playSound then
        local alertMessage

        if isInGuild then
            alertMessage = "|cff00ff00" .. name .. "|r" .. cause .. " in " .. zone .. "!\nThey were level " .. level
            PlaySound(8959, "Master")
            print(alertMessage)
        elseif name == UnitName("player") then
            alertMessage = "|cffff0000" .. name .. "|r" .. cause .. " in " .. zone .. "!\nYou were level " .. level
            PlaySound(1483, "Master")
        else
            alertMessage = name .. cause .. " in " .. zone .. "!\nThey were level " .. level
            PlaySound(8959, "Master")
        end

        ShowDeathAlert(alertMessage)
    end
end

-- Event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CHAT_MSG_CHANNEL")
eventFrame:SetScript("OnEvent", function(_, _, message, _, _, channelName)
    local channel = match(channelName, "%d+%.%s*(.+)")
    if channel == "HardcoreDeaths" then
        ProcessDeathMessage(message)
    end
end)

-- Initialize UI
local addonFrame, scrollFrame = InitializeUI()

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
    if msg == "reset" then
        HCA.deathData = {}
        SaveDeathData() -- Resave the data because it will be clear
        scrollFrame:Clear()
        print("Hardcore Alerts: Data reset.")
    elseif msg == "log off" then
        showingTracker = false
        HCA.frameCache.addonFrame:Hide()
        print("Hardcore Alerts: Tracker Hidden.")
    elseif msg == "log on" then
        showingTracker = true
        HCA.frameCache.addonFrame:Show()
        print("Hardcore Alerts: Tracker Showing.")
    elseif msg == "on" then
        showingAlerts = true
        print("Hardcore Alerts: Showing alerts")
    elseif msg == "off" then
        showingAlerts = false
        print("Hardcore Alerts: Hiding alerts.")
    -- Only for testing -- REMOVE THIS
    elseif msg == "test" then
        local randomPlayer = testData.playerName[math.random(#testData.playerName)]
        local randomMonster = testData.monsterName[math.random(#testData.monsterName)]
        local randomLocation = testData.locationName[math.random(#testData.locationName)]
        local randomLevel = math.random(60)

        local message = "[" .. randomPlayer .. "]" .. " has been slain by a " .. randomMonster .. " in " .. randomLocation .. "! They were level " .. randomLevel .. "."
        ProcessDeathMessage(message)
    end
end