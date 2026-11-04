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
local strip = CreateFrame("StatusBar", "ForeverThreatTargetStrip", UIParent)
strip:SetHeight(11)
strip:SetMinMaxValues(0, 100)
strip:SetValue(0)
strip:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
strip:Hide()

local background = strip:CreateTexture(nil, "BACKGROUND")
background:SetAllPoints()
background:SetColorTexture(0.04, 0.04, 0.04, 0.90)

local text = strip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
text:SetPoint("CENTER", strip, "CENTER", 0, 0)
text:SetJustifyH("CENTER")
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

    -- Put the threat strip directly beneath the target's resource bars. This
    -- keeps health, power and threat in one compact visual stack.
    if manaBar then
        strip:SetPoint("TOPLEFT", manaBar, "BOTTOMLEFT", 0, -2)
        strip:SetPoint("TOPRIGHT", manaBar, "BOTTOMRIGHT", 0, -2)
    elseif healthBar then
        strip:SetPoint("TOPLEFT", healthBar, "BOTTOMLEFT", 0, -14)
        strip:SetPoint("TOPRIGHT", healthBar, "BOTTOMRIGHT", 0, -14)
    else
        strip:SetWidth(119)
        strip:SetPoint("TOP", targetFrame, "TOP", 0, -66)
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
    strip:SetStatusBarColor(r, g, b, 0.95)
end

local function RenderDamageMode(scaledPct, status)
    local pct = tonumber(scaledPct) or 0
    local displayPct = math.floor(pct + 0.5)

    strip:SetMinMaxValues(0, 100)
    strip:SetValue(Clamp(pct, 0, 100))

    if status and status >= 2 then
        text:SetText("AGGRO  •  " .. displayPct .. "%")
        SetColor(0.85, 0.12, 0.10)
    elseif pct >= 90 then
        text:SetText("DANGER  •  " .. displayPct .. "%")
        SetColor(0.92, 0.38, 0.08)
    elseif pct >= 80 then
        text:SetText("WATCH  •  " .. displayPct .. "%")
        SetColor(0.88, 0.72, 0.08)
    else
        text:SetText("SAFE  •  " .. displayPct .. "%")
        SetColor(0.16, 0.68, 0.28)
    end
end

local function RenderTankMode(otherPct)
    strip:SetMinMaxValues(0, 100)

    if otherPct == nil then
        strip:SetValue(0)
        text:SetText("TANKING")
        SetColor(0.16, 0.68, 0.28)
        return
    end

    local pct = tonumber(otherPct) or 0
    local displayPct = math.floor(pct + 0.5)
    strip:SetValue(Clamp(pct, 0, 100))

    if pct >= 95 then
        text:SetText("LOSING  •  " .. displayPct .. "%")
        SetColor(0.85, 0.12, 0.10)
    elseif pct >= 85 then
        text:SetText("WATCH  •  " .. displayPct .. "%")
        SetColor(0.92, 0.38, 0.08)
    else
        text:SetText("HOLDING  •  " .. displayPct .. "%")
        SetColor(0.16, 0.68, 0.28)
    end
end

local function RenderTest()
    if not TargetFrameVisible() then
        strip:Hide()
        return
    end

    strip:SetMinMaxValues(0, 100)
    strip:SetValue(87)
    text:SetText("WATCH  •  87%")
    SetColor(0.88, 0.72, 0.08)
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
