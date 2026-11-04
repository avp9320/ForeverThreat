local ADDON_NAME = ...

local DEFAULTS = {
    enabled = true,
    showSolo = false,
    testMode = false,
}

local function CopyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = value
        end
    end
end

local function Clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

local function IsSecret(value)
    if type(issecretvalue) ~= "function" then return false end
    local ok, result = pcall(issecretvalue, value)
    return ok and result == true
end

local function IsGrouped()
    if IsInRaid and IsInRaid() then return true end
    if IsInGroup and IsInGroup() then return true end
    return false
end

local function ValidThreatTarget()
    if not UnitExists("target") then return false end
    if UnitIsDeadOrGhost("target") then return false end
    if not UnitCanAttack("player", "target") then return false end
    return true
end

local function ThreatFor(unit)
    if not UnitExists(unit) then return nil end

    local ok, isTanking, status, scaledPct, rawPct, threatValue =
        pcall(UnitDetailedThreatSituation, unit, "target")

    if not ok or IsSecret(isTanking) or IsSecret(status) or IsSecret(scaledPct) then return nil end
    return isTanking, status, scaledPct, rawPct, threatValue
end

local function HighestOtherThreat()
    local highest = 0
    local found = false

    local function CheckUnit(unit)
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local _, status, scaledPct = ThreatFor(unit)
            if status ~= nil and type(scaledPct) == "number" then
                found = true
                if scaledPct > highest then
                    highest = scaledPct
                end
            end
        end
    end

    if IsInRaid and IsInRaid() then
        for i = 1, 40 do
            CheckUnit("raid" .. i)
        end
    elseif IsInGroup and IsInGroup() then
        for i = 1, 4 do
            CheckUnit("party" .. i)
        end
    end

    if not found then return nil end
    return highest
end

-- ForeverThreat deliberately attaches to the stock target frame instead of
-- creating another movable combat window. The target health/mana globals are
-- used when available, with fallbacks for UI variants.
-- A compact threat readout, not a third health/power bar.  It lives just
-- below the right end of the target's resource bar, inside its visual stack.
local strip = CreateFrame("Frame", "ForeverThreatTargetStrip", UIParent)
strip:SetSize(76, 15)
strip:Hide()

local border = strip:CreateTexture(nil, "BACKGROUND")
border:SetAllPoints()
border:SetColorTexture(0.32, 0.26, 0.13, 0.88)

local background = strip:CreateTexture(nil, "BORDER")
background:SetPoint("TOPLEFT", strip, "TOPLEFT", 1, -1)
background:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", -1, 1)
background:SetColorTexture(0.025, 0.025, 0.03, 0.94)

local accent = strip:CreateTexture(nil, "ARTWORK")
accent:SetPoint("TOPLEFT", strip, "TOPLEFT", 2, -2)
accent:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 2, 2)
accent:SetWidth(3)
accent:SetColorTexture(0.85, 0.70, 0.10, 1)

local text = strip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
text:SetPoint("LEFT", accent, "RIGHT", 4, 0)
text:SetPoint("RIGHT", strip, "RIGHT", -5, 0)
text:SetJustifyH("RIGHT")
text:SetTextColor(0.95, 0.95, 0.88)
text:SetText("")

local attached = false
local attachedFrame = nil

local function FindTargetFramePieces()
    local targetFrame = _G.TargetFrame
    if not targetFrame then return nil end

    local healthBar = _G.TargetFrameHealthBar or targetFrame.healthbar
    local manaBar = _G.TargetFrameManaBar or targetFrame.manabar

    -- Some UI branches expose child frames through parent keys instead of
    -- classic global names. These checks are intentionally defensive.
    if not healthBar and targetFrame.TargetFrameContent then
        local content = targetFrame.TargetFrameContent
        local main = content.TargetFrameContentMain
        if main then
            healthBar = main.HealthBar or main.healthBar
            manaBar = manaBar or main.ManaBar or main.manaBar
        end
    end

    return targetFrame, healthBar, manaBar
end

local function AttachToTargetFrame()
    local targetFrame, healthBar, manaBar = FindTargetFramePieces()
    if not targetFrame then
        attached = false
        attachedFrame = nil
        return false
    end

    strip:SetParent(targetFrame)
    strip:ClearAllPoints()

    -- A small right-anchored chip follows the existing target frame rather
    -- than stretching into a mismatched full-width status bar.
    if manaBar then
        strip:SetPoint("TOPRIGHT", manaBar, "BOTTOMRIGHT", 0, -2)
    elseif healthBar then
        strip:SetPoint("TOPRIGHT", healthBar, "BOTTOMRIGHT", 0, -16)
    else
        strip:SetPoint("TOPRIGHT", targetFrame, "TOPRIGHT", -82, -67)
    end

    if strip.SetFrameLevel and targetFrame.GetFrameLevel then
        strip:SetFrameLevel(targetFrame:GetFrameLevel() + 6)
    end

    attached = true
    attachedFrame = targetFrame
    return true
end

local function TargetFrameVisible()
    if not attached or not attachedFrame then
        if not AttachToTargetFrame() then return false end
    end

    return attachedFrame:IsShown()
end

local function SetColor(r, g, b)
    accent:SetColorTexture(r, g, b, 1)
end

-- Label makes it clear whether we are showing our threat (THR) or
-- the highest groupmate threat while tanking (OTH). Color signals urgency.
local function RenderDamageMode(scaledPct, status)
    local pct = tonumber(scaledPct) or 0
    local displayPct = math.floor(pct + 0.5)
    if status and status >= 2 then
        text:SetText("AGGRO")
        SetColor(0.95, 0.24, 0.18)
    else
        text:SetText("THR " .. displayPct .. "%")
        if pct >= 90 then
            SetColor(0.95, 0.40, 0.12)
        elseif pct >= 80 then
            SetColor(0.95, 0.76, 0.14)
        else
            SetColor(0.26, 0.74, 0.38)
        end
    end
end

local function RenderTankMode(otherPct)
    if otherPct == nil then
        text:SetText("TANKING")
        SetColor(0.26, 0.74, 0.38)
        return
    end
    local pct = tonumber(otherPct) or 0
    text:SetText("OTH " .. math.floor(pct + 0.5) .. "%")
    if pct >= 95 then
        SetColor(0.95, 0.24, 0.18)
    elseif pct >= 85 then
        SetColor(0.95, 0.76, 0.14)
    else
        SetColor(0.26, 0.74, 0.38)
    end
end

local function RenderTest()
    if not TargetFrameVisible() then
        strip:Hide()
        return
    end
    text:SetText("THR 87%")
    SetColor(0.95, 0.76, 0.14)
    strip:Show()
end

local function UpdateThreat()
    if not ForeverThreatDB or not ForeverThreatDB.enabled then
        strip:Hide()
        return
    end

    if not TargetFrameVisible() then
        strip:Hide()
        return
    end

    if ForeverThreatDB.testMode then
        RenderTest()
        return
    end

    if not ForeverThreatDB.showSolo and not IsGrouped() then
        strip:Hide()
        return
    end

    if not UnitAffectingCombat("player") or not ValidThreatTarget() then
        strip:Hide()
        return
    end

    local isTanking, status, scaledPct = ThreatFor("player")
    if status == nil then
        strip:Hide()
        return
    end

    if isTanking or status == 2 or status == 3 then
        RenderTankMode(HighestOtherThreat())
    else
        RenderDamageMode(scaledPct, status)
    end

    strip:Show()
end

local function SafeUpdateThreat()
    local ok = pcall(UpdateThreat)
    if not ok then strip:Hide() end
end

local elapsedSinceUpdate = 0
local updater = CreateFrame("Frame")
updater:SetScript("OnUpdate", function(_, elapsed)
    elapsedSinceUpdate = elapsedSinceUpdate + elapsed
    if elapsedSinceUpdate >= 0.15 then
        elapsedSinceUpdate = 0
        SafeUpdateThreat()
    end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
events:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")

events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        ForeverThreatDB = ForeverThreatDB or {}
        CopyDefaults(ForeverThreatDB, DEFAULTS)
        AttachToTargetFrame()
        SafeUpdateThreat()
    elseif ForeverThreatDB then
        if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
            AttachToTargetFrame()
        end
        SafeUpdateThreat()
    end
end)

SLASH_FOREVERTHREAT1 = "/fthreat"
SLASH_FOREVERTHREAT2 = "/foreverthreat"

SlashCmdList.FOREVERTHREAT = function(msg)
    if not ForeverThreatDB then return end

    msg = (msg or ""):lower():match("^%s*(.-)%s*$")

    if msg == "test" then
        ForeverThreatDB.testMode = not ForeverThreatDB.testMode
        if ForeverThreatDB.testMode then
            print("|cff66ccffForeverThreat:|r test mode ON. Target anything so the target frame is visible. Type /fthreat test again to turn it off.")
        else
            print("|cff66ccffForeverThreat:|r test mode OFF.")
        end
        SafeUpdateThreat()
    elseif msg == "show" then
        ForeverThreatDB.enabled = true
        print("|cff66ccffForeverThreat:|r enabled.")
        SafeUpdateThreat()
    elseif msg == "hide" then
        ForeverThreatDB.enabled = false
        strip:Hide()
        print("|cff66ccffForeverThreat:|r disabled.")
    elseif msg == "solo" then
        ForeverThreatDB.showSolo = not ForeverThreatDB.showSolo
        print("|cff66ccffForeverThreat:|r show while solo: " .. (ForeverThreatDB.showSolo and "ON" or "OFF"))
        SafeUpdateThreat()
    elseif msg == "reset" then
        ForeverThreatDB.enabled = DEFAULTS.enabled
        ForeverThreatDB.showSolo = DEFAULTS.showSolo
        ForeverThreatDB.testMode = DEFAULTS.testMode
        AttachToTargetFrame()
        print("|cff66ccffForeverThreat:|r settings reset.")
        SafeUpdateThreat()
    else
        print("|cff66ccffForeverThreat commands:|r")
        print("  /fthreat test - preview the target-frame threat strip")
        print("  /fthreat solo - toggle display while solo")
        print("  /fthreat show - enable")
        print("  /fthreat hide - disable")
        print("  /fthreat reset - reset settings")
    end
end

strip:Hide()
