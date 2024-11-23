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
    GameTooltip:SetText("Commands:\n/deathtracker reset\n/deathtracker show\n/deathtracker hide", nil, nil, nil, nil, true)
    GameTooltip:Show()
end)
title:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Create a font string for the alert text
local alertText = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
alertText:SetPoint("TOP", UIParent, "TOP", 0, -150) -- Position at the top-center of the screen
alertText:SetTextColor(1, 1, 0, 1) -- Yellow text
alertText:Hide() -- Start hidden

-- Function to show the alert
local function ShowDeathAlert(message)
    -- Update the text and make it visible
    alertText:SetText(message)
    alertText:SetTextScale(1.5)
    alertText:SetAlpha(1)
    alertText:Show()

    -- Cancel any existing fade-out animation
    if alertText.fadeOut then
        alertText.fadeOut:Stop()
    end

    -- Create a fade-out animation
    local fadeOut = alertText:CreateAnimationGroup()
    local fade = fadeOut:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetDuration(3) -- 3 seconds fade-out duration
    fade:SetStartDelay(3) -- Stay visible for 2 seconds before fading
    fade:SetSmoothing("OUT")

    fadeOut:SetScript("OnFinished", function()
        alertText:Hide()
    end)

    fadeOut:Play()
    alertText.fadeOut = fadeOut
end

-- Calculate the color based on proximity to the player level
local function GetLevelColor(deathLevel)
    local playerLevel = UnitLevel("player")
    local levelDiff = deathLevel - playerLevel

    if levelDiff >= 5 then
        return "|cffff0000", true -- Red for much higher level, play a sound
    elseif levelDiff >= 3 then
        return "|cffff7f00", true -- Orange for slightly higher level, play a sound
    elseif levelDiff >= -2 then
        return "|cffffff00", true -- Yellow for similar level, play a sound
    elseif levelDiff >= -5 then
        return "|cff00ff00", true -- Green for slightly lower level, play a sound
    else
        return "|cff808080", false -- Gray for much lower level, don't play a sound
    end
end

-- Event handler
frame:SetScript("OnEvent", function(_, event, ...)
    local message, _, _, channelName = ...
    local strippedChannelName = string.match(channelName, "%d+%.%s*(.+)")
    local deathPattern = "%[(.-)%].-They were level (%d+)"
    local name, level = string.match(message, deathPattern)

    if name and level then
        level = tonumber(level) -- Convert level to a number for comparison
        local levelColor, playSound = GetLevelColor(level)
        -- local deathInfo = string.format("%s - %sLevel %s|r", name, levelColor, level)
        local deathInfo = string.format("(%s%s|r) %s", levelColor, level, name)
        table.insert(HardcoreAlerts.deathData, deathInfo)
        if #HardcoreAlerts.deathData > 100 then
            table.remove(HardcoreAlerts.deathData, 1)
        end
        scrollFrame:AddMessage(deathInfo)

        if strippedChannelName == "HardcoreDeaths" and playSound then
            ShowDeathAlert(message)
            PlaySound(8959, "Master")
        end
    end
end)

SLASH_DEATHTRACKER1 = "/deathtracker"
SlashCmdList["DEATHTRACKER"] = function(msg)
    if msg == "reset" then
        HardcoreAlerts.deathData = {}
        scrollFrame:Clear()
        print("Death Tracker: Data reset.")
    elseif msg == "hide" then
        addonFrame:Hide()
    elseif msg == "show" then
        addonFrame:Show()
    end
end