local ADDON, F = ...
local M = {}
F:RegisterModule("cast", M)

local bars = {}
local COLORS = {
	standard = { 0.98, 0.74, 0.36 },
	channel = { 0.5, 0.82, 0.55 },
	locked = { 0.62, 0.6, 0.66 },
}

-- Cast bar: brown plate with a bronze frame (falls back when the Blizzard casting bar art is missing),
-- icon on the left with a grey bevel frame (tinted bronze).
local function CreateCastBar(key, unit, w, h, label, defX, defY)
	local f = CreateFrame("Frame", "FrayCast" .. key, UIParent)
	local iconSize = h + 4
	f:SetSize(w + iconSize + 4, h + 4)
	f.unit = unit
	f.key = key

	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetSize(iconSize - 4, iconSize - 4)
	f.icon:SetPoint("LEFT", 2, 0)
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.iconBorder = f:CreateTexture(nil, "OVERLAY")
	f.iconBorder:SetTexture(F.TEXROOT .. "Icon-Border.tga")
	f.iconBorder:SetPoint("CENTER", f.icon, "CENTER", 0, 0)
	f.iconBorder:SetSize(iconSize + 4, iconSize + 4)
	f.iconBorder:SetVertexColor(unpack(F.PAL.edge))

	f.plate = F.CreateBand(f, iconSize + 4, 0, w, h + 4)
	-- Blizzard's cast bar frame and background instead of our plate
	local atlasFrame = F.AtlasThreeSlice(f, "castFrame", "OVERLAY", 1, 14)
	if atlasFrame then
		f.plate.frame:Hide()
		local backName = F.AtlasName("castBack")
		f.back = f:CreateTexture(nil, "BACKGROUND")
		if backName then f.back:SetAtlas(backName, false) else f.back:SetColorTexture(0.05, 0.04, 0.03, 0.9) end
		f.back:SetPoint("TOPLEFT", f, "TOPLEFT", iconSize + 4 + 3, -3)
		f.back:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
	end

	-- The bar fills the plate flush (2.5 px frame); straight on the left, rounded on the right like the plate
	f.bar = F.CreateSlimBar(f, w - 8, h - 4, "right")
	f.bar:SetPoint("LEFT", f, "LEFT", iconSize + 4 + 4, 0)
	f.bar:SetFrameLevel(f.plate.frame:GetFrameLevel() + 1)
	F.AtlasBar(f.bar, "castFill", "BarRight.tga")

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

	f.over = CreateFrame("Frame", nil, f)
	f.over:SetAllPoints(f.bar)
	f.over:SetFrameLevel(f.bar:GetFrameLevel() + 4)
	if atlasFrame then
		-- Frame in its own frame above the bar (bars are child frames and would otherwise sit on top)
		local bf = CreateFrame("Frame", nil, f)
		bf:SetAllPoints(f)
		bf:SetFrameLevel(f.bar:GetFrameLevel() + 6)
		local fr = F.AtlasThreeSlice(bf, "castFrame", "OVERLAY", 1, 14)
		F.PlaceThreeSlice(fr, bf, iconSize + 4, 0, w, h + 4)
		atlasFrame.L:Hide(); atlasFrame.M:Hide(); atlasFrame.R:Hide()
	end
	local fontSize = math.max(9, math.floor(h * 0.55))
	f.spell = F.CreateText(f.over, fontSize, "LEFT")
	f.spell:SetFont(F.FONT_BOLD, fontSize, "")
	f.spell:SetPoint("LEFT", 6, 0)
	f.spell:SetPoint("RIGHT", -40, 0)
	f.time = F.CreateText(f.over, fontSize, "RIGHT")
	f.time:SetFont(F.FONT_BOLD, fontSize, "")
	f.time:SetPoint("RIGHT", -6, 0)

	f:Hide()
	F:MakeMovable(f, "cast" .. key, label, defX, defY)
	bars[#bars + 1] = f
	return f
end

local function SetKind(f, kind)
	if f.kind == kind then return end
	f.kind = kind
	local c = COLORS[kind]
	f.bar:SetStatusBarColor(c[1], c[2], c[3])
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
		f.spell:SetText("Spell (placeholder)")
		f.time:SetText("1.5")
		f:Show()
		return
	end
	if not F.Bool(UnitExists(unit)) or (F.db.cast.onlyHostile and not F.Bool(UnitCanAttack("player", unit))) then
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
	f.iconBorder:SetShown(co.showIcon ~= false)
	f.time:SetShown(co.showTime ~= false)
	if name ~= nil then f.spell:SetFormattedText("%s", name) else f.spell:SetText("") end
	f:Show()
end

function M:Init()
	CreateCastBar("Target", "target", 300, 20, "Target cast bar", 0, 120)
	CreateCastBar("Focus", "focus", 220, 15, "Focus cast bar", 0, 85)

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
