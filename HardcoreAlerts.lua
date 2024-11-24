--[[
In Settings:
Hardcore Death Alerts can be set to NEVER and it still works!
Harecore Death Announcements needs to be ALL DEATHS, however.

You need to join the HardcoreDeaths channel but it can be hidden so it doesn't spam.
]]--

-- Namespace
local HardcoreAlerts = {}
HardcoreAlerts.deathData = {}

-- Saved variables
local HardcoreAlertsDB = HardcoreAlertsDB or {}
HardcoreAlerts.deathData = HardcoreAlertsDB

-- Create frame
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_CHANNEL")

-- Addon frame
local addonFrame = CreateFrame("Frame", "DeathTrackerFrame", UIParent, "BackdropTemplate")
addonFrame:SetSize(200, 300)
addonFrame:SetPoint("CENTER", UIParent, "CENTER")
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

local resizeButton = CreateFrame("Button", nil, addonFrame)
resizeButton:SetSize(16, 16)
resizeButton:SetPoint("BOTTOMRIGHT")
resizeButton:SetNormalTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
resizeButton:SetHighlightTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Highlight")
resizeButton:SetPushedTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Down")
resizeButton:SetScript("OnMouseDown", function() addonFrame:StartSizing("BOTTOMRIGHT") end)
resizeButton:SetScript("OnMouseUp", function() addonFrame:StopMovingOrSizing() end)

local title = addonFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
title:SetPoint("TOP", 0, -10)
title:SetText("Death Tracker")

local scrollFrame = CreateFrame("ScrollingMessageFrame", nil, addonFrame)
scrollFrame:SetSize(180, 260)
scrollFrame:SetPoint("BOTTOM", 0, 10)
scrollFrame:SetFontObject(GameFontHighlight)
scrollFrame:SetJustifyH("LEFT")
scrollFrame:SetFading(false)
scrollFrame:SetMaxLines(100)

-- Function to update scrollFrame size and alignment on resizing
local function UpdateScrollFrame()
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", addonFrame, "TOPLEFT", 10, -30) -- Adjust position relative to title
    scrollFrame:SetPoint("BOTTOMRIGHT", addonFrame, "BOTTOMRIGHT", -10, 10) -- Adjust padding from edges
    scrollFrame:SetSize(addonFrame:GetWidth() - 20, addonFrame:GetHeight() - 40) -- Adjust dynamically
end

-- Initial alignment and size setup
UpdateScrollFrame()

-- Hook resizing to dynamically adjust scrollFrame
addonFrame:SetScript("OnSizeChanged", UpdateScrollFrame)

-- Tooltip for commands
title:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Commands:\n/hcalerts reset\n/hcalerts show\n/hcalerts hide", nil, nil, nil, nil, true)
    GameTooltip:Show()
end)
title:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Create a font string for the alert text
local alertText = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
alertText:SetPoint("TOP", UIParent, "TOP", 0, -150) -- Position at the top-center of the screen
alertText:SetTextColor(1, 1, 1, 0) -- White text
alertText:Hide() -- Start hidden

-- Function to show the alert
local function ShowDeathAlert(message)
    -- Remove the brackets
    local cleanedMessage = string.gsub(message, "%[(.-)%]", "%1")
    cleanedMessage = string.gsub(cleanedMessage, "!", "!\n")

    -- Update the text and make it visible
    alertText:SetText(cleanedMessage)
    alertText:SetTextScale(1.5)
    alertText:SetAlpha(0) -- Start fully transparent
    alertText:Show()

    -- Cancel any existing animation group
    if alertText.animGroup then
        alertText.animGroup:Stop()
    end

    -- Create or reuse the animation group
    if not alertText.animGroup then
        alertText.animGroup = alertText:CreateAnimationGroup()

        -- Fade-in animation
        local fadeIn = alertText.animGroup:CreateAnimation("Alpha")
        fadeIn:SetOrder(1)
        fadeIn:SetFromAlpha(0)
        fadeIn:SetToAlpha(1)
        fadeIn:SetDuration(0.5) -- Quick fade-in
        fadeIn:SetSmoothing("IN")

        -- Stay visible (delay)
        local stay = alertText.animGroup:CreateAnimation("Alpha")
        stay:SetOrder(2)
        stay:SetFromAlpha(1)
        stay:SetToAlpha(1)
        stay:SetDuration(3) -- Stay visible for 3 seconds
        stay:SetSmoothing("NONE")

        -- Fade-out animation
        local fadeOut = alertText.animGroup:CreateAnimation("Alpha")
        fadeOut:SetOrder(3)
        fadeOut:SetFromAlpha(1)
        fadeOut:SetToAlpha(0)
        fadeOut:SetDuration(5) -- Smooth fade-out
        fadeOut:SetSmoothing("OUT")
    end

    -- Hide the text when the animation finishes
    alertText.animGroup:SetScript("OnFinished", function()
        alertText:Hide()
    end)

    -- Play the animation sequence
    alertText.animGroup:Play()
end

-- Calculate the color based on proximity to the player level
local function GetLevelColor(deathLevel)
    local playerLevel = UnitLevel("player")
    local levelDiff = deathLevel - playerLevel

    if levelDiff >= 5 then
        return "|cffff0000", true -- Red for much higher level, play a sound
    elseif levelDiff >= 3 then
        return "|cffff7f00", true -- Orange for slightly higher level, play a sound
    elseif levelDiff >= 0 then
        return "|cffffff00", true -- Yellow for similar level, play a sound
    elseif levelDiff >= -2 then
        return "|cffffff00", false -- Yellow for similar level, don't play a sound
    elseif levelDiff >= -5 then
        return "|cff00ff00", false -- Green for slightly lower level, don't play a sound
    else
        return "|cff808080", false -- Gray for much lower level, don't play a sound
    end
end

local function PushMessage(message)
    -- [Player Name] was slain by a Monster Name in Location Name! They were level 20
    --local deathPattern = "%[(.-)%].- in (.-)! They were level (%d+)"
    --local name, zone, level = string.match(message, deathPattern)

    local deathPattern = "%[(.-)%](.-) in (.-)! They were level (%d+)"
    local name, cause, zone, level = string.match(message, deathPattern)

    --[[
        has been slain by a (.-)
        fell to their death
        died of fatigue
        drowned to death
    ]]--

    local rewordedCause = ""
    if string.find(cause, "fell to their death") then
        rewordedCause = "Falling"
    elseif string.find(cause, "died of fatigue") then
        rewordedCause = "Fatigue"
    elseif string.find(cause, "drowned to death") then
        rewordedCause = "Drowned"
    elseif string.find(cause, "has been slain by a") then
        -- Extract just the monster name
        rewordedCause = string.match(cause, "has been slain by a (.+)")
    else
        rewordedCause = cause -- Fallback just in case
    end

    if name and level then
        level = tonumber(level) -- Convert level to a number for comparison
        local levelColor, playSound = GetLevelColor(level)
        local deathInfo = string.format("(%s%s|r) %s - %s - %s", levelColor, level, name, rewordedCause, zone)
        table.insert(HardcoreAlerts.deathData, deathInfo)
        if #HardcoreAlerts.deathData > 100 then
            table.remove(HardcoreAlerts.deathData, 1)
        end
        scrollFrame:AddMessage(deathInfo)

        if playSound then
            ShowDeathAlert(message)
            PlaySound(8959, "Master")
        end
    end
end

-- Event handler
frame:SetScript("OnEvent", function(_, event, message, _, _, channelName, ...)
    local strippedChannelName = string.match(channelName, "%d+%.%s*(.+)")

    if strippedChannelName == "HardcoreDeaths" then
        PushMessage(message)
    end
end)

SLASH_HARDCOREALERTS1 = "/hcalerts"
SlashCmdList["HARDCOREALERTS"] = function(msg)
    if msg == "reset" then
        HardcoreAlerts.deathData = {}
        scrollFrame:Clear()
        print("Hardcore Alerts: Data reset.")
    elseif msg == "hide" then
        addonFrame:Hide()
    elseif msg == "show" then
        addonFrame:Show()
    end
end