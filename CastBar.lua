local ADDON, F = ...
local L = F.L
local M = {}
F:RegisterModule("cast", M)

local bars = {}

-- Fill per cast type: Blizzard's casting bar atlases (standard, channel, not interruptible); a tint
-- of the standard fill where the client lacks one.
local KINDS = {
	standard = { atlas = "castFill", color = { 1, 0.7, 0 } },
	channel = { atlas = "castChannel", color = { 0.5, 0.82, 0.55 } },
	locked = { atlas = "castLocked", color = { 0.62, 0.6, 0.66 } },
}

-- Cast bar built from Blizzard's casting bar: background, fill, spark and frame; spell icon on the left.
local function CreateCastBar(key, unit, w, h, label, defX, defY)
	local f = CreateFrame("Frame", "FrayCast" .. key, UIParent)
	local iconSize = h + 4
	local x0 = iconSize + 4      -- the bar starts right of the icon
	f:SetSize(x0 + w, h + 4)
	f.unit = unit
	f.key = key

	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetSize(iconSize, iconSize)
	f.icon:SetPoint("LEFT", 0, 0)
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	f.back = f:CreateTexture(nil, "BACKGROUND")
	local backName = F.AtlasName("castBack")
	if backName then f.back:SetAtlas(backName, false) else f.back:SetColorTexture(0.05, 0.04, 0.03, 0.9) end
	f.back:SetPoint("TOPLEFT", f, "TOPLEFT", x0 + 3, -3)
	f.back:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)

	f.bar = CreateFrame("StatusBar", nil, f)
	f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", x0 + 3, -3)
	f.bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
	f.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	f.bar:SetMinMaxValues(0, 1)

	-- Spark at the leading edge of the fill (also works when the progress is a secret value)
	f.spark = f.bar:CreateTexture(nil, "OVERLAY")
	local sparkAtlas = F.AtlasName("castSpark")
	if sparkAtlas then
		f.spark:SetAtlas(sparkAtlas, false)
	else
		f.spark:SetColorTexture(1, 0.92, 0.6, 0.85)
	end
	f.spark:SetBlendMode("ADD")
	f.spark:SetSize(h * 1.1, h * 2.2)
	f.spark:SetPoint("CENTER", f.bar:GetStatusBarTexture(), "RIGHT", 0, 0)

	-- Blizzard's cast bar frame in its own frame above the bar (the bar is a child frame and would cover it)
	local border = CreateFrame("Frame", nil, f)
	border:SetAllPoints(f)
	border:SetFrameLevel(f.bar:GetFrameLevel() + 2)
	local art = F.AtlasThreeSlice(border, "castFrame", "OVERLAY", 1, 14)
	if art then
		F.PlaceThreeSlice(art, border, x0, 0, w, h + 4)
	else
		F.CreateBorder(f.bar, 1, "OVERLAY"):SetColor(0, 0, 0, 1)
	end

	f.over = CreateFrame("Frame", nil, f)
	f.over:SetAllPoints(f.bar)
	f.over:SetFrameLevel(border:GetFrameLevel() + 1)
	local fontSize = math.max(9, math.floor(h * 0.55))
	f.spell = F.CreateText(f.over, fontSize, "LEFT")
	f.spell:SetPoint("LEFT", 6, 0)
	f.spell:SetPoint("RIGHT", -40, 0)
	f.time = F.CreateText(f.over, fontSize, "RIGHT")
	f.time:SetPoint("RIGHT", -6, 0)

	f:Hide()
	F:MakeMovable(f, "cast" .. key, label, defX, defY)
	bars[#bars + 1] = f
	return f
end

local function SetKind(f, kind)
	if f.kind == kind then return end
	f.kind = kind
	local k = KINDS[kind]
	local exact = F.AtlasName(k.atlas)
	local name = exact or F.AtlasName("castFill")
	if name then f.bar:GetStatusBarTexture():SetAtlas(name, false) end
	if exact then
		f.bar:SetStatusBarColor(1, 1, 1)
	else
		f.bar:SetStatusBarColor(k.color[1], k.color[2], k.color[3])
	end
end

-- Progress: the client's duration object (works with secret times), otherwise calculated from readable times.
local function SetProgress(f, unit, channel, startMS, endMS)
	if UnitCastingDuration and f.bar.SetTimerDuration and Enum and Enum.StatusBarTimerDirection then
		local duration
		if channel then duration = UnitChannelDuration(unit) else duration = UnitCastingDuration(unit) end
		if F.Readable(duration) and not duration then return false end
		f.bar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate,
			channel and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime)
		if duration.GetRemainingDuration then
			f.time:SetFormattedText("%.1f", duration:GetRemainingDuration())
		else
			f.time:SetText("")
		end
		return true
	end
	if F.AllReadable(startMS, endMS) and startMS and endMS and endMS > startMS then
		local now = GetTime() * 1000
		f.bar:SetMinMaxValues(0, endMS - startMS)
		f.bar:SetValue(channel and (endMS - now) or (now - startMS))
		f.time:SetText(string.format("%.1f", math.max(0, (endMS - now) / 1000)))
		return true
	end
	return false
end

-- Is the unit you, a party/raid member or one of their pets?
local function IsGroupUnit(unit)
	if F.Bool(UnitIsUnit(unit, "player")) then return true end
	if UnitPlayerOrPetInParty and F.Bool(UnitPlayerOrPetInParty(unit)) then return true end
	if UnitPlayerOrPetInRaid and F.Bool(UnitPlayerOrPetInRaid(unit)) then return true end
	if UnitInParty and F.Bool(UnitInParty(unit)) then return true end
	if UnitInRaid and F.Readable(UnitInRaid(unit)) and UnitInRaid(unit) then return true end
	return false
end

local function Poll(f)
	local unit = f.unit
	local co = F.db.cast
	if (f.key == "Target" and co.target == false) or (f.key == "Focus" and co.focus == false) then
		if not F.unlocked then f:Hide() return end
	end
	if F.unlocked then
		SetKind(f, "standard")
		f.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
		f.bar:SetMinMaxValues(0, 1)
		f.bar:SetValue(0.5)
		f.spell:SetText(L.SPELL_PLACEHOLDER)
		f.time:SetText("1.5")
		f:Show()
		return
	end
	if not F.Bool(UnitExists(unit)) or (co.onlyHostile and not F.Bool(UnitCanAttack("player", unit)))
		or (co.hideGroup ~= false and IsGroupUnit(unit)) then
		f:Hide()
		return
	end

	local channel = false
	local n = select("#", UnitCastingInfo(unit))
	local name, tex, startMS, endMS, notInt
	if n > 0 then
		name, _, tex, startMS, endMS, _, _, notInt = UnitCastingInfo(unit)
	else
		n = select("#", UnitChannelInfo(unit))
		if n > 0 then
			name, _, tex, startMS, endMS, _, notInt = UnitChannelInfo(unit)
			channel = true
		end
	end
	if n == 0 then
		f:Hide()
		return
	end

	local locked = F.Readable(notInt) and notInt == true
	SetKind(f, locked and "locked" or (channel and "channel" or "standard"))
	if not SetProgress(f, unit, channel, startMS, endMS) then
		f:Hide()
		return
	end
	f.icon:SetTexture(tex)
	f.icon:SetShown(co.showIcon ~= false)
	f.time:SetShown(co.showTime ~= false)
	if name ~= nil then f.spell:SetFormattedText("%s", name) else f.spell:SetText("") end
	f:Show()
end

function M:Init()
	CreateCastBar("Target", "target", 300, 20, L.FRAME_TARGET, 0, 120)
	CreateCastBar("Focus", "focus", 220, 15, L.FRAME_FOCUS, 0, 85)

	local d = CreateFrame("Frame")
	d.t = 0
	d:SetScript("OnUpdate", function(self, dt)
		self.t = self.t + dt
		if self.t < 0.03 then return end
		self.t = 0
		for i = 1, #bars do Poll(bars[i]) end
	end)
	M.driver = d
end

function M:SetEnabled(on)
	M.driver:SetShown(on)
	if not on then
		for i = 1, #bars do bars[i]:Hide() end
	end
end
