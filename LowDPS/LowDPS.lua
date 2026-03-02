----------------------------------------------------------------------
-- LowDPS - Shame Alert for WotLK 3.3.5
-- Warns you when you die last in DPS inside an instance!
-- Requires: Details! Damage Meter
----------------------------------------------------------------------

local ADDON_NAME = "LowDPS"
local SOUND_FILE = "Interface\\AddOns\\LowDPS\\Sounds\\low_dps.ogg"
local FALLBACK_SOUND = "Sound\\Interface\\RaidWarning.wav"

-- Saved variables defaults
local defaults = {
    enabled = true,
    soundEnabled = true,
    messageEnabled = true,
    threshold = 1, -- position from bottom (1 = last, 2 = second to last)
}

----------------------------------------------------------------------
-- Warning Frame (big on-screen raid warning style message)
----------------------------------------------------------------------
local WarningFrame = CreateFrame("Frame", "LowDPSWarningFrame", UIParent)
WarningFrame:SetFrameStrata("HIGH")
WarningFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
WarningFrame:SetSize(600, 80)
WarningFrame:Hide()

local WarningText = WarningFrame:CreateFontString(nil, "OVERLAY")
WarningText:SetFont("Fonts\\FRIZQT__.TTF", 32, "OUTLINE")
WarningText:SetPoint("CENTER")
WarningText:SetTextColor(1, 0.2, 0.2, 1)
WarningText:SetShadowOffset(2, -2)
WarningText:SetShadowColor(0, 0, 0, 1)

-- Secondary text with DPS details
local DetailText = WarningFrame:CreateFontString(nil, "OVERLAY")
DetailText:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
DetailText:SetPoint("TOP", WarningText, "BOTTOM", 0, -8)
DetailText:SetTextColor(1, 0.6, 0.2, 1)
DetailText:SetShadowOffset(1, -1)
DetailText:SetShadowColor(0, 0, 0, 1)

-- Fade-out animation
local FadeOutGroup = WarningFrame:CreateAnimationGroup()
local FadeOut = FadeOutGroup:CreateAnimation("Alpha")
FadeOut:SetChange(-1)
FadeOut:SetDuration(2)
FadeOut:SetStartDelay(4) -- visible for 4 seconds, then 2 second fade
FadeOut:SetSmoothing("OUT")
FadeOutGroup:SetScript("OnFinished", function()
    WarningFrame:Hide()
end)

----------------------------------------------------------------------
-- Full-screen red flash for extra drama
----------------------------------------------------------------------
local FlashFrame = CreateFrame("Frame", "LowDPSFlashFrame", UIParent)
FlashFrame:SetFrameStrata("BACKGROUND")
FlashFrame:SetAllPoints(UIParent)
FlashFrame:Hide()

local FlashTexture = FlashFrame:CreateTexture(nil, "BACKGROUND")
FlashTexture:SetAllPoints()
FlashTexture:SetTexture("Interface\\FullScreenTextures\\LowHealth")
FlashTexture:SetBlendMode("ADD")
FlashTexture:SetVertexColor(1, 0, 0, 0.3)

local FlashFadeGroup = FlashFrame:CreateAnimationGroup()
local FlashFade = FlashFadeGroup:CreateAnimation("Alpha")
FlashFade:SetChange(-1)
FlashFade:SetDuration(1.5)
FlashFade:SetStartDelay(0.5)
FlashFade:SetSmoothing("OUT")
FlashFadeGroup:SetScript("OnFinished", function()
    FlashFrame:Hide()
end)

----------------------------------------------------------------------
-- Core Logic
----------------------------------------------------------------------
local LowDPS = CreateFrame("Frame", "LowDPSFrame", UIParent)
LowDPS:RegisterEvent("ADDON_LOADED")
LowDPS:RegisterEvent("PLAYER_DEAD")
LowDPS:RegisterEvent("PLAYER_ENTERING_WORLD")

local function IsInInstance()
    local inInstance, instanceType = IsInInstance()
    return inInstance and (instanceType == "party" or instanceType == "raid")
end

local function GetPlayerDPSRanking()
    -- Check that Details! is loaded
    if not _G.Details then
        return nil, nil, nil
    end

    local Details = _G.Details

    -- Get the current combat segment (or the last overall)
    local combat = Details:GetCurrentCombat()
    if not combat then
        combat = Details:GetCombat(1) -- overall
    end
    if not combat then
        return nil, nil, nil
    end

    -- Damage container (1 = damage)
    local damageContainer = combat:GetContainer(1)
    if not damageContainer then
        return nil, nil, nil
    end

    local playerName = UnitName("player")
    local rankings = {}

    -- Iterate all actors in the damage container
    for _, actor in damageContainer:ListActors() do
        if actor:IsPlayer() then
            local dps = actor.total / max(combat:GetCombatTime(), 1)
            table.insert(rankings, {
                name = actor:name(),
                dps = dps,
            })
        end
    end

    -- Sort from highest to lowest DPS
    table.sort(rankings, function(a, b) return a.dps > b.dps end)

    -- Find the player's position
    local playerPos = nil
    local playerDPS = 0
    for i, entry in ipairs(rankings) do
        if entry.name == playerName then
            playerPos = i
            playerDPS = entry.dps
            break
        end
    end

    return playerPos, #rankings, playerDPS
end

local function FormatDPS(dps)
    if dps >= 1000000 then
        return string.format("%.1fM", dps / 1000000)
    elseif dps >= 1000 then
        return string.format("%.1fK", dps / 1000)
    else
        return string.format("%.0f", dps)
    end
end

local function ShowWarning(playerPos, totalPlayers, playerDPS)
    if not LowDPSDB.enabled then return end

    -- On-screen message
    if LowDPSDB.messageEnabled then
        WarningText:SetText("HAI UN DPS TROPPO BASSO!")
        DetailText:SetText(string.format(
            "Rank %d of %d  —  DPS: %s",
            playerPos, totalPlayers, FormatDPS(playerDPS)
        ))

        WarningFrame:SetAlpha(1)
        WarningFrame:Show()
        FadeOutGroup:Stop()
        FadeOutGroup:Play()

        -- Red flash
        FlashFrame:SetAlpha(1)
        FlashFrame:Show()
        FlashFadeGroup:Stop()
        FlashFadeGroup:Play()

        -- Chat message
        DEFAULT_CHAT_FRAME:AddMessage(
            string.format(
                "|cFFFF3333[LowDPS]|r HAI UN DPS TROPPO BASSO! Rank |cFFFF6600%d|r of %d (DPS: |cFFFFCC00%s|r)",
                playerPos, totalPlayers, FormatDPS(playerDPS)
            )
        )
    end

    -- Warning sound
    if LowDPSDB.soundEnabled then
        -- Try custom sound first, fall back to built-in raid warning
        local soundPlayed = PlaySoundFile(SOUND_FILE, "Master")
        if not soundPlayed then
            PlaySoundFile(FALLBACK_SOUND, "Master")
        end
    end
end

local function CheckDPSOnDeath()
    if not IsInInstance() then return end
    if not LowDPSDB.enabled then return end

    local playerPos, totalPlayers, playerDPS = GetPlayerDPSRanking()

    if not playerPos or not totalPlayers then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cFFFF3333[LowDPS]|r Unable to read data from Details! Make sure it is active."
        )
        return
    end

    -- Check if the player is among the last (within threshold)
    local posFromBottom = totalPlayers - playerPos + 1
    if posFromBottom <= LowDPSDB.threshold then
        ShowWarning(playerPos, totalPlayers, playerDPS)
    end
end

----------------------------------------------------------------------
-- Event Handler
----------------------------------------------------------------------
LowDPS:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        -- Initialize saved variables
        if not LowDPSDB then
            LowDPSDB = {}
        end
        for k, v in pairs(defaults) do
            if LowDPSDB[k] == nil then
                LowDPSDB[k] = v
            end
        end

        DEFAULT_CHAT_FRAME:AddMessage("|cFF00CC66[LowDPS]|r Addon loaded! Type |cFFFFCC00/lowdps|r for options.")

    elseif event == "PLAYER_DEAD" then
        -- Small delay to make sure Details! has updated its data
        C_Timer.After(0.5, CheckDPSOnDeath)

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Reserved for future use
    end
end)

----------------------------------------------------------------------
-- Slash Commands
----------------------------------------------------------------------
SLASH_LOWDPS1 = "/lowdps"
SLASH_LOWDPS2 = "/ldps"

SlashCmdList["LOWDPS"] = function(msg)
    msg = msg:lower():trim()

    if msg == "on" then
        LowDPSDB.enabled = true
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00CC66[LowDPS]|r Addon |cFF00FF00ENABLED|r!")

    elseif msg == "off" then
        LowDPSDB.enabled = false
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00CC66[LowDPS]|r Addon |cFFFF0000DISABLED|r!")

    elseif msg == "sound on" then
        LowDPSDB.soundEnabled = true
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00CC66[LowDPS]|r Sound |cFF00FF00ENABLED|r!")

    elseif msg == "sound off" then
        LowDPSDB.soundEnabled = false
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00CC66[LowDPS]|r Sound |cFFFF0000DISABLED|r!")

    elseif msg == "test" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00CC66[LowDPS]|r Testing warning...")
        ShowWarning(5, 5, 1234.5)

    elseif msg == "status" then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00CC66[LowDPS]|r === Status ===")
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Addon: %s", LowDPSDB.enabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Sound: %s", LowDPSDB.soundEnabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Message: %s", LowDPSDB.messageEnabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"))
        DEFAULT_CHAT_FRAME:AddMessage(string.format("  Threshold: last %d position(s)", LowDPSDB.threshold))

        if IsInInstance() then
            local pos, total, dps = GetPlayerDPSRanking()
            if pos then
                DEFAULT_CHAT_FRAME:AddMessage(string.format("  Current DPS: %s (rank %d/%d)", FormatDPS(dps), pos, total))
            else
                DEFAULT_CHAT_FRAME:AddMessage("  DPS: data not available")
            end
        else
            DEFAULT_CHAT_FRAME:AddMessage("  Not in an instance")
        end

    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00CC66[LowDPS]|r Available commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFCC00/lowdps on|r - Enable the addon")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFCC00/lowdps off|r - Disable the addon")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFCC00/lowdps sound on/off|r - Toggle sound")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFCC00/lowdps test|r - Test the warning")
        DEFAULT_CHAT_FRAME:AddMessage("  |cFFFFCC00/lowdps status|r - Show current status")
    end
end
