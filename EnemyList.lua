local ADDON, F = ...
local L = F.L
local M = {}
F:RegisterModule("enemy", M)

-- Enemy list: Blizzard's own target frame art, mirrored (portrait on the left), with Fray's aggro shield,
-- elite icons, resource bar and a cast strip below each frame.
-- The rows are normal (non-secure) frames: they are sorted live by threat in combat and
-- close up without gaps. There is deliberately no click-to-target: secure code does not know
-- nameplate units and cannot be re-arranged in combat (other addons do not solve this either).
-- Nameplate tokens are not handed out in order: with many plates around (cities, friendly players, big pulls)
-- an enemy can sit on nameplate30, so all of them are scanned.
local PLATES = 40
local MAX_ROWS = 18
local COLGAP = 8
local MAX_AURAS, AURA_SIZE, AURA_GAP = 4, 17, 2   -- your debuffs right of each frame
local function AuraWidth()
	return F.db.enemy.showDebuffs ~= false and (MAX_AURAS * (AURA_SIZE + AURA_GAP) + 2) or 0
end
local function PerCol() return F.db.enemy.perCol or 6 end   -- after that another column starts

-- Geometry of Blizzard's target frame art, scaled by S
local S = 0.85
local ROW_W, ROW_H, GAP = 232 * S, 100 * S, 2
local PITCH = 72
local YOFF = 12 * S   -- the frame art only starts about 12 px below the frame edge

local rows = {}

-- Status = aggro situation relative to YOU: red = you have aggro, orange = aggro lost / high threat,
-- green = little threat.
local hadAggro = {}     -- guid -> time at which the enemy was last on you
local LOST_SECS = 15     -- after losing aggro the enemy stays orange this long (as long as there is still some threat)

-- known = threat values readable. Otherwise (Forever, nameplates in combat) only this counts: is the enemy targeting you?
-- Red = yes; orange = it was on you within the last LOST_SECS (aggro lost); otherwise green.
local function ThreatStatus(unit, tanking, pct, guid, known)
	local now = GetTime()
	if tanking or F.TargetsMe(unit) then
		hadAggro[guid] = now
		return "red"
	end
	local lastAggro = hadAggro[guid]
	local lost = lastAggro and now - lastAggro < LOST_SECS and (not known or (pct or 0) >= 15)
	if lost or (known and (pct or 0) >= (F.db.enemy.threatOrange or 50)) then return "orange" end
	return "green"
end

-- Atlas textures, mirrored horizontally (for atlases the coordinates are relative to the atlas region).
local function NewAtlasTex(parent, layer, sub, key, scale)
	local name, w, h = F.AtlasInfo(key)
	if not name then return nil end
	local t = parent:CreateTexture(nil, layer, nil, sub or 0)
	t:SetAtlas(name, false)
	t:SetTexCoord(1, 0, 0, 1)
	t:SetSize(w * S * (scale or 1), h * S * (scale or 1))
	return t
end

local function SetAtlasKey(tex, key)
	local name, w, h = F.AtlasInfo(key)
	if not name or not tex then return false end
	tex:SetAtlas(name, false)
	tex:SetTexCoord(1, 0, 0, 1)
	tex:SetSize(w * S, h * S)
	return true
end

local POWER_KEY = { MANA = "tMana", RAGE = "tRage", ENERGY = "tEnergy", FOCUS = "tFocus", RUNIC_POWER = "tRunic" }

local function AtlasStatusBar(row, level, w, h)
	local bar = CreateFrame("StatusBar", nil, row)
	bar:SetFrameLevel(level)
	bar:SetSize(w * S, h * S)
	bar:SetStatusBarTexture(F.WHITE)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	return bar
end

local function SetBarAtlas(bar, key)
	local name = F.AtlasName(key)
	local t = bar:GetStatusBarTexture()
	if name and t then pcall(t.SetAtlas, t, name, false) end
end

-- Blizzard's bar masks cannot be mirrored (they hid the whole bar), so the mirrored troughs get Fray's
-- invisible mask: straight on the left, rounded on the right.
local function AddBarMask(row, bar)
	local mask = row:CreateMaskTexture()
	mask:SetTexture(F.BAR_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	local t = bar:GetStatusBarTexture()
	if t then t:AddMaskTexture(mask) end
	bar.mask = mask
	return mask
end

local function CreateRow(index)
	local row = CreateFrame("Button", "FrayEnemyRow" .. index, M.frame)
	row:SetSize(ROW_W, ROW_H)
	row:SetPoint("TOPLEFT", M.frame, "TOPLEFT", 0, -(index - 1) * PITCH)   -- final position: M:ApplyLayout()
	local lvl = row:GetFrameLevel() + 1

	-- Portrait behind the frame, round mask
	row.portrait = row:CreateTexture(nil, "BACKGROUND", nil, 1)
	row.portrait:SetSize(58 * S, 58 * S)
	row.portrait:SetPoint("TOPLEFT", row, "TOPLEFT", 26 * S, -19 * S)
	row.portrait:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	local pm = row:CreateMaskTexture()
	pm:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	pm:SetPoint("TOPLEFT", row.portrait, "TOPLEFT", 0, -1 * S)
	pm:SetPoint("BOTTOMRIGHT", row.portrait, "BOTTOMRIGHT", -1 * S, 0)
	row.portrait:AddMaskTexture(pm)

	-- Frame and type bar
	row.frameTex = NewAtlasTex(row, "BACKGROUND", 2, "tFrame")
	row.frameTex:SetPoint("CENTER", row, "CENTER", 0, 0)
	-- evenly dark troughs in every row (otherwise the surroundings shine through the troughs differently)
	row.backFill = row:CreateTexture(nil, "BACKGROUND", nil, 1)
	row.backFill:SetColorTexture(0.07, 0.05, 0.035, 1)
	row.backFill:SetSize(127 * S, 47 * S)
	row.backFill:SetPoint("TOPLEFT", row, "TOPLEFT", 83 * S, -24.6 * S)
	row.type = NewAtlasTex(row, "ARTWORK", 0, "tType")
	if row.type then
		row.type:SetPoint("TOPLEFT", row, "TOPLEFT", 82.1 * S, -25 * S)   -- the fill starts at the trough (84.1)
		row.type:SetWidth(row.type:GetWidth() * 1.015)
	end

	-- Aggro shield (bottom left of the portrait): Fray's crest shield in the status colour, bronze frame,
	-- glow behind it (pulsing on red).
	local badge = CreateFrame("Frame", nil, row)
	badge:SetSize(46 * S, 46 * S)
	badge:SetPoint("CENTER", row.portrait, "BOTTOMLEFT", -2 * S, 4 * S)
	badge:SetFrameLevel(lvl + 7)
	badge.glow = badge:CreateTexture(nil, "BACKGROUND", nil, 0)
	badge.glow:SetPoint("CENTER")
	badge.glow:SetSize(62 * S, 62 * S)
	badge.glow:SetTexture(F.TEXROOT .. "Shield-Red")
	badge.glow:SetBlendMode("ADD")
	badge.glow:Hide()
	badge.fill = badge:CreateTexture(nil, "ARTWORK", nil, 1)
	badge.fill:SetAllPoints()
	badge.fill:SetTexture(F.TEXROOT .. "Shield-Red")
	badge.frame = badge:CreateTexture(nil, "ARTWORK", nil, 2)
	badge.frame:SetAllPoints()
	badge.frame:SetTexture(F.TEXROOT .. "Shield-Frame")
	badge.frame:SetVertexColor(F.SHIELD_RIM[1], F.SHIELD_RIM[2], F.SHIELD_RIM[3])
	local ag = badge.glow:CreateAnimationGroup()
	ag:SetLooping("BOUNCE")
	local an = ag:CreateAnimation("Alpha")
	an:SetFromAlpha(0.2)
	an:SetToAlpha(0.9)
	an:SetDuration(0.5)
	badge.pulse = ag
	row.badge = badge

	-- Bars
	row.hp = AtlasStatusBar(row, lvl, 123.0, 19.5)
	row.hp:SetPoint("TOPLEFT", row, "TOPLEFT", 85.9 * S, -41.5 * S)
	SetBarAtlas(row.hp, "tHealth")
	AddBarMask(row, row.hp):SetAllPoints(row.hp)
	-- The atlas bar has an approx. 6 % transparent margin: make the frame a bit larger so the visible area fits exactly into
	-- the lower trough (trough: x 83..209, y 59..69.6).
	row.power = AtlasStatusBar(row, lvl, 134, 11.5)
	row.power:SetPoint("TOPLEFT", row, "TOPLEFT", 80.5 * S, -59.9 * S)
	local powerMask = AddBarMask(row, row.power)
	powerMask:SetPoint("TOPLEFT", row, "TOPLEFT", 86 * S, -59.9 * S)
	powerMask:SetPoint("BOTTOMRIGHT", row, "TOPLEFT", 208.9 * S, -69.4 * S)
	SetBarAtlas(row.power, "tMana")
	row.power:Hide()
	-- Cast bar: its own strip BELOW the frame (the resource stays in the lower trough of the frame)
	row.cast = AtlasStatusBar(row, lvl, 126, 9)
	row.cast:SetPoint("TOPLEFT", row, "TOPLEFT", 83 * S, -76.5 * S)
	if F.AtlasName("castFill") then SetBarAtlas(row.cast, "castFill") else row.cast:SetStatusBarColor(0.98, 0.74, 0.36) end
	row.cast.back = row.cast:CreateTexture(nil, "BACKGROUND")
	row.cast.back:SetAllPoints()
	row.cast.back:SetColorTexture(0.04, 0.03, 0.02, 0.8)
	row.cast.text = F.CreateText(row.cast, 10, "CENTER", "OVERLAY")
	row.cast.text:SetFont(F.FONT, 10, "OUTLINE")
	row.cast.text:SetPoint("CENTER", row.cast, "CENTER", 0, 0)
	row.cast.text:SetTextColor(1, 0.92, 0.7)
	-- Blizzard's cast bar frame around the strip (three parts of UI-CastingBar-Frame), visible with the strip
	row.castFrame = CreateFrame("Frame", nil, row)
	row.castFrame:SetAllPoints(row)
	row.castFrame:SetFrameLevel(row.cast:GetFrameLevel() + 3)
	local cfr = F.AtlasThreeSlice(row.castFrame, "castFrame", "OVERLAY", 1, 14)
	if cfr then
		F.PlaceThreeSlice(cfr, row.castFrame, 80 * S, 73.5 * S, 132 * S, 15 * S)
		local backName = F.AtlasName("castBack")
		if backName then row.cast.back:SetAtlas(backName, false) end
	else
		F.CreateBorder(row.cast, 1, "OVERLAY"):SetColor(0.45, 0.36, 0.22, 1)
	end
	row.castFrame:Hide()
	row.cast:SetScript("OnShow", function() row.castFrame:Show() end)
	row.cast:SetScript("OnHide", function() row.castFrame:Hide() end)
	row.cast:Hide()

	-- Texts, raid marker, elite icons
	row.over = CreateFrame("Frame", nil, row)
	row.over:SetAllPoints()
	row.over:SetFrameLevel(lvl + 5)
	row.name = F.CreateText(row.over, 10, "CENTER")
	row.name:SetPoint("TOP", row, "TOPLEFT", 147 * S, -26 * S)
	row.name:SetSize(118 * S, 13)
	row.info = F.CreateText(row.over, 10, "RIGHT")
	row.info:SetPoint("RIGHT", row.hp, "RIGHT", -5 * S, 0)
	row.info:SetSize(110 * S, 12)
	row.mark = row.over:CreateTexture(nil, "OVERLAY", nil, 3)
	row.mark:SetSize(26 * S, 26 * S)
	row.mark:SetPoint("CENTER", row, "TOPLEFT", 147 * S, -10.5 * S)   -- centred above the name
	row.mark:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
	row.mark:Hide()
	row.star = NewAtlasTex(row.over, "OVERLAY", 1, "tStar")
	if row.star then row.star:SetPoint("CENTER", row.portrait, "BOTTOM", 0, 0); row.star:Hide() end
	-- small dragon icon (elite) on the portrait ring, top left
	row.dragon = row.over:CreateTexture(nil, "OVERLAY", nil, 2)
	row.dragon:SetSize(30 * S, 30 * S)
	row.dragon:SetPoint("CENTER", row.portrait, "TOPLEFT", -2 * S, -2.5 * S)
	row.dragon:Hide()

	-- Unit tooltip on mouseover. Clicks go through to the world (the frames cannot target anyway).
	if row.SetMouseClickEnabled then
		row:SetMouseClickEnabled(false)
		row:SetMouseMotionEnabled(true)
		row:SetScript("OnEnter", function(self)
			if F.db.enemy.tooltip == false or not self.unit or not F.Bool(UnitExists(self.unit)) then return end
			GameTooltip_SetDefaultAnchor(GameTooltip, self)
			GameTooltip:SetUnit(self.unit)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", GameTooltip_Hide)
	end
	CreateAuras(row)
	row:Hide()
	return row
end

-- Rare enemies get Blizzard's silver rare frame.
local function UpdateFrameArt(row)
	local key = row.rare and F.AtlasName("tRareFrame") and "tRareFrame" or "tFrame"
	if row.frameKey == key then return end
	row.frameKey = key
	SetAtlasKey(row.frameTex, key)
end

-- Dragon icon: nameplate atlas, otherwise the client's default graphic (silver = desaturated)
local function SetDragon(row, kind)
	if not kind then row.dragon:Hide() return end
	local name = F.AtlasName(kind == "gold" and "eliteGold" or "eliteSilver")
	if name then
		row.dragon:SetAtlas(name, false)
		row.dragon:SetDesaturated(false)
	else
		row.dragon:SetTexture("Interface\\Tooltips\\EliteNameplateIcon")
		row.dragon:SetTexCoord(0, 1, 0, 1)
		row.dragon:SetDesaturated(kind == "silver")
	end
	row.dragon:Show()
end

-- Classification -> elite dragon (gold: elite and bosses, silver: rare elite), rare frame and star
local function SetClassification(row, unit)
	local okc, cls = pcall(UnitClassification, unit)
	if not (okc and F.Readable(cls)) then cls = nil end
	local okb, boss = pcall(UnitIsBossMob, unit)
	boss = okb and F.Bool(boss)
	row.rare = cls == "rare" or cls == "rareelite"
	local kind = (boss or cls == "elite" or cls == "worldboss") and "gold" or (cls == "rareelite" and "silver") or nil
	SetDragon(row, kind)
	if row.star then row.star:SetShown(row.rare) end
	UpdateFrameArt(row)
end

local function FillPortrait(row, unit)
	local now = GetTime()
	if not row.pt or now - row.pt > 1 then
		row.pt = now
		pcall(SetPortraitTexture, row.portrait, unit)
	end
	if row.type then
		local ok, r, g, b = pcall(UnitSelectionColor, unit)
		if ok and r and F.AllReadable(r, g, b) then row.type:SetVertexColor(r, g, b) else row.type:SetVertexColor(0.9, 0.25, 0.2) end
	end
	SetClassification(row, unit)
end

-- Placeholder look for test mode and enemies out of sight
local function ClearPortrait(row)
	row.portrait:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	row.portrait:SetTexCoord(0, 1, 0, 1)
	row.pt = nil
	if row.type then row.type:SetVertexColor(0.9, 0.25, 0.2) end
	row.dragon:Hide()
	if row.star then row.star:Hide() end
	row.rare = false
	UpdateFrameArt(row)
end

-- Resource bar of the enemy. Unreadable maximum values count as "none".
local function UpdatePower(row, unit)
	local max = UnitPowerMax and UnitPowerMax(unit)
	if not F.Readable(max) or not max or max <= 0 then
		row.power:Hide()
		return
	end
	local _, token = UnitPowerType(unit)
	local key = F.Readable(token) and POWER_KEY[token] or "tMana"
	if not F.AtlasName(key) then key = "tMana" end
	if row.powerKey ~= key then row.powerKey = key; SetBarAtlas(row.power, key) end
	row.power:SetMinMaxValues(0, max)
	row.power:SetValue(UnitPower(unit))
	row.power:Show()
end

-- Selection like the Blizzard nameplate: a yellow outline that follows the shape of the frame (troughs, corners,
-- portrait ring, decoration). It is made of offset copies of the frame art (desaturated, tinted yellow) BEHIND
-- the frame; only the edge sticks out.
local OUTLINE_R = 2.6
local function EnsureOutline(row)
	if row.outline then return end
	local list = {}
	local function copy(dx, dy, sub, alpha)
		local t = NewAtlasTex(row, "BACKGROUND", sub, "tFrame")
		if t then
			t:SetPoint("CENTER", row, "CENTER", dx, dy)
			t:SetDesaturated(true)
			t:SetVertexColor(1, 0.86, 0.12, alpha)
			t:SetBlendMode("ADD")
			t:Hide()
			list[#list + 1] = t
		end
	end
	for dx = -1, 1 do
		for dy = -1, 1 do
			if dx ~= 0 or dy ~= 0 then
				copy(dx * OUTLINE_R, dy * OUTLINE_R, 0, 1)
				copy(dx * OUTLINE_R, dy * OUTLINE_R, 0, 1)
				-- minimal glow: two more, very faint layers further out (diagonals a bit closer so it stays round)
				local k = (dx ~= 0 and dy ~= 0) and 0.72 or 1
				copy(dx * 4.6 * k, dy * 4.6 * k, -1, 0.17)
				copy(dx * 6.6 * k, dy * 6.6 * k, -1, 0.08)
			end
		end
	end
	row.outline = list
end

local function SetSelected(row, on)
	on = on and true or false
	if on then EnsureOutline(row) end
	for _, t in ipairs(row.outline or {}) do t:SetShown(on) end
end

local function SetMark(row, idx)
	if idx and F.db.enemy.showMarker ~= false then
		SetRaidTargetIconTexture(row.mark, idx)
		row.mark:Show()
	else
		row.mark:Hide()
	end
end

local STATUS_TEX = { red = "Shield-Red", orange = "Shield-Orange", green = "Shield-Green" }

-- grey = enemy out of sight: shield faded, no glow
local function SetStatus(row, status, grey)
	local b = row.badge
	b:SetShown(F.db.enemy.showShield ~= false)
	local tex = F.TEXROOT .. (STATUS_TEX[status] or STATUS_TEX.orange)
	b.fill:SetTexture(tex)
	b.glow:SetTexture(tex)
	b.fill:SetDesaturated(grey and true or false)
	b.frame:SetDesaturated(grey and true or false)
	b.fill:SetAlpha(grey and 0.55 or 1)
	b.frame:SetAlpha(grey and 0.55 or 1)
	if not grey and status == "red" then
		b.glow:SetAlpha(0.9)
		b.glow:Show()
		if not b.pulse:IsPlaying() then b.pulse:Play() end
	elseif not grey and status == "orange" then
		b.pulse:Stop()
		b.glow:SetAlpha(0.45)
		b.glow:Show()
	else
		b.pulse:Stop()
		b.glow:Hide()
	end
end

local function SetName(row, name)
	if name == nil then name = "?" end
	row.name:SetFormattedText("%s", name)      -- also for secret names
end

-- Your own debuffs on the enemy, like the target frame: icon, Blizzard's debuff border, stacks and the
-- running time as a cooldown swipe. Values the client hides in combat are passed on as they are.
local function CreateAuras(row)
	row.auras = {}
	for i = 1, MAX_AURAS do
		local a = CreateFrame("Frame", nil, row)
		a:SetSize(AURA_SIZE, AURA_SIZE)
		a:SetPoint("LEFT", row, "TOPLEFT", ROW_W + 2 + (i - 1) * (AURA_SIZE + AURA_GAP), -51 * S)
		a.icon = a:CreateTexture(nil, "ARTWORK")
		a.icon:SetAllPoints()
		a.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		a.cd = CreateFrame("Cooldown", nil, a, "CooldownFrameTemplate")
		a.cd:SetAllPoints()
		a.cd:SetReverse(true)
		a.cd:SetDrawEdge(false)
		if a.cd.SetHideCountdownNumbers then a.cd:SetHideCountdownNumbers(true) end
		local over = CreateFrame("Frame", nil, a)
		over:SetAllPoints()
		over:SetFrameLevel(a.cd:GetFrameLevel() + 1)
		a.border = over:CreateTexture(nil, "OVERLAY")
		a.border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
		a.border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
		a.border:SetPoint("TOPLEFT", -1, 1)
		a.border:SetPoint("BOTTOMRIGHT", 1, -1)
		local c = DebuffTypeColor and DebuffTypeColor.none
		if c then a.border:SetVertexColor(c.r, c.g, c.b) else a.border:SetVertexColor(0.8, 0, 0) end
		a.count = over:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
		a.count:SetPoint("BOTTOMRIGHT", 2, -1)
		a:Hide()
		row.auras[i] = a
	end
end

local function HideAuras(row)
	for i = 1, MAX_AURAS do row.auras[i]:Hide() end
end

local function UpdateAuras(row, unit)
	local shown = 0
	if F.db.enemy.showDebuffs ~= false and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
		for i = 1, 40 do
			if shown >= MAX_AURAS then break end
			local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HARMFUL|PLAYER")
			if not ok or not aura then break end
			shown = shown + 1
			local a = row.auras[shown]
			pcall(a.icon.SetTexture, a.icon, aura.icon)
			local apps = aura.applications
			if F.Readable(apps) and type(apps) == "number" and apps > 1 then a.count:SetText(apps) else a.count:SetText("") end
			local done = false
			if C_UnitAuras.GetAuraDuration and a.cd.SetCooldownFromDurationObject and aura.auraInstanceID ~= nil then
				done = pcall(function()
					a.cd:SetCooldownFromDurationObject(C_UnitAuras.GetAuraDuration(unit, aura.auraInstanceID))
				end)
			end
			if not done then
				local d, e = aura.duration, aura.expirationTime
				if F.AllReadable(d, e) and type(d) == "number" and type(e) == "number" and d > 0 then
					if a.start ~= e - d then a.start = e - d; a.cd:SetCooldown(e - d, d) end
				else
					a.start = nil
					a.cd:Clear()
				end
			end
			a:Show()
		end
	end
	for i = shown + 1, MAX_AURAS do row.auras[i]:Hide() end
end

local function FillCached(row, e)
	local c = e.cache
	row.unit = nil
	row:SetAlpha(0.55)
	SetName(row, c.name)
	row.name:SetTextColor(0.8, 0.8, 0.8)
	-- last known health, as far as it was readable
	row.hp:SetMinMaxValues(0, 1)
	row.hp:SetValue(c.frac or 0)
	row.cast:Hide()
	row.power:Hide()
	ClearPortrait(row)
	row.info:SetText(L.OUT_OF_SIGHT)
	row.info:SetTextColor(0.7, 0.7, 0.7)
	SetStatus(row, "orange", true)
	SetMark(row, c.mark)
	SetSelected(row, false)
	HideAuras(row)
end

-- Cast of the enemy: spell name in the strip, progress via the client's duration object (also with
-- secret times). Old clients without UnitCastingDuration: time from the timestamps.
local function UpdateCast(row, unit)
	local n = select("#", UnitCastingInfo(unit))
	local channel = false
	local name, startMS, endMS, notInt
	if n > 0 then
		name, _, _, startMS, endMS, _, _, notInt = UnitCastingInfo(unit)
	else
		n = select("#", UnitChannelInfo(unit))
		if n > 0 then
			name, _, _, startMS, endMS, _, notInt = UnitChannelInfo(unit)
			channel = true
		end
	end
	if n == 0 then
		row.cast:Hide()
		return
	end
	-- Fill like Blizzard's cast bar: standard, channel, or grey when it cannot be interrupted
	local key = (F.Readable(notInt) and notInt == true and "castLocked") or (channel and "castChannel") or "castFill"
	if not F.AtlasName(key) then key = "castFill" end
	if row.castKey ~= key and F.AtlasName(key) then row.castKey = key; SetBarAtlas(row.cast, key) end
	if UnitCastingDuration and row.cast.SetTimerDuration and Enum and Enum.StatusBarTimerDirection then
		local duration
		if channel then duration = UnitChannelDuration(unit) else duration = UnitCastingDuration(unit) end
		if F.Readable(duration) and not duration then
			row.cast:Hide()
			return
		end
		row.cast:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate,
			channel and Enum.StatusBarTimerDirection.RemainingTime or Enum.StatusBarTimerDirection.ElapsedTime)
		row.cast:Show()
	elseif F.AllReadable(startMS, endMS) and startMS and endMS and endMS > startMS then
		local now = GetTime() * 1000
		row.cast:SetMinMaxValues(0, endMS - startMS)
		row.cast:SetValue(channel and (endMS - now) or (now - startMS))
		row.cast:Show()
	else
		row.cast:Hide()
	end
	if name ~= nil then row.cast.text:SetFormattedText("%s", name) else row.cast.text:SetText("") end
end

local function FillRow(row, e)
	if e.cache then return FillCached(row, e) end
	row:SetAlpha(1)
	local unit = e.unit
	row.unit = unit

	SetName(row, UnitName(unit))
	row.name:SetTextColor(1, 0.82, 0)
	SetMark(row, F.Readable(GetRaidTargetIndex(unit)) and GetRaidTargetIndex(unit) or nil)
	SetStatus(row, e.status)
	FillPortrait(row, unit)

	F.SetHealthBar(row.hp, unit)
	UpdateCast(row, unit)
	UpdatePower(row, unit)
	F.SetPercentText(row.info, unit)
	row.info:SetTextColor(0.9, 0.9, 0.9)
	SetSelected(row, F.Bool(UnitIsUnit(unit, "target")))
	UpdateAuras(row, unit)
end

-- Test mode (/fray test): placeholder enemies instead of real units.
local DEMO_ENEMIES = {
	{ name = "Aggro Boar", status = "red", frac = 0.79, mark = 8, selected = true, elite = true,
		debuff = "Interface\\Icons\\Spell_Shadow_ShadowWordPain" },
	{ name = "Guard Dog", status = "orange", frac = 0.46, cast = "Shadow Bolt", castLen = 3 },
	{ name = "Plague Servant", status = "orange", frac = 0.91, mark = 1, power = 0.65 },
	{ name = "Sleeping Wolf", status = "green", frac = 1.0 },
}

local function DemoActive()
	return M.demoUntil and GetTime() < M.demoUntil
end

function M:StartDemo(secs)
	M.demoUntil = GetTime() + (secs or 20)
end

local function FillDemo(row, d)
	row.unit = nil
	row:SetAlpha(1)
	row.name:SetText(d.name)
	row.name:SetTextColor(1, 0.82, 0)
	row.hp:SetValue(d.frac)
	ClearPortrait(row)
	if d.elite then SetDragon(row, "gold") end
	if d.power then
		row.power:SetMinMaxValues(0, 1)
		row.power:SetValue(d.power)
		row.power:Show()
	else
		row.power:Hide()
	end
	SetStatus(row, d.status)
	SetMark(row, d.mark)
	if d.cast then
		row.cast:SetMinMaxValues(0, d.castLen)
		row.cast:SetValue(GetTime() % d.castLen)
		row.cast:Show()
		row.cast.text:SetText(d.cast)
	else
		row.cast:Hide()
	end
	row.info:SetText(string.format("%d%%", math.floor(d.frac * 100 + 0.5)))
	row.info:SetTextColor(0.9, 0.9, 0.9)
	SetSelected(row, d.selected)
	HideAuras(row)
	if d.debuff and F.db.enemy.showDebuffs ~= false then
		local a = row.auras[1]
		a.icon:SetTexture(d.debuff)
		a.count:SetText("")
		a.cd:Clear()
		a:Show()
	end
end

local cache = {}   -- guid -> last known values of an enemy seen on a nameplate (for "out of sight")
local CACHE_SECS = 20
local OUT_OF_RANGE_SECS = 45   -- without a combat log: how long an enemy stays listed after its nameplate vanished (out of range)

local STATUS_SCORE = { red = 100, orange = 60, green = 10 }

local function Entry(unit, token)
	local tanking, _, pct, known = F.GetThreat(unit)
	local guid = UnitGUID(unit)
	if not F.Readable(guid) or guid == nil then guid = token and ("plate" .. token) or unit end
	local status = ThreatStatus(unit, tanking, pct, guid, known)
	local nm = UnitName(unit)
	if not F.Readable(nm) then nm = "" end
	-- Sort value: real threat, otherwise roughly from the status
	local score = (known and pct) or STATUS_SCORE[status] or 0
	return { unit = unit, name = nm, tanking = tanking, pct = pct or 0, score = score, guid = guid, status = status,
		token = token, idle = not F.IsEngaged(unit, true) }
end

-- Last known values; health only where it is readable (out of combat or on clients without secret values).
local function Remember(e, unit)
	local mark = GetRaidTargetIndex(unit)
	local cur, max = UnitHealth(unit), UnitHealthMax(unit)
	local frac
	if F.AllReadable(cur, max) and type(cur) == "number" and type(max) == "number" and max > 0 then frac = cur / max end
	local old = cache[e.guid]
	cache[e.guid] = { guid = e.guid, name = UnitName(unit), mark = F.Readable(mark) and mark or nil,
		pct = e.pct, score = e.score, seen = GetTime(), frac = frac or (old and old.frac) }
end

-- All nameplates. Returns the set of guids that have a plate right now (fighting or not).
local function PlateEntries(list, seen)
	local present = {}
	for k = 1, PLATES do
		local unit = "nameplate" .. k
		if F.Bool(UnitExists(unit)) then
			local guid = UnitGUID(unit)
			present[(F.Readable(guid) and guid) or ("plate" .. k)] = true
			if F.IsEngaged(unit) then
				local e = Entry(unit, k)
				if not seen[e.guid] then
					seen[e.guid] = true
					list[#list + 1] = e
					Remember(e, unit)
				end
			end
		end
	end
	return present
end

-- Enemies whose nameplate is gone (out of sight). With a combat log we know whether they still fight;
-- without one they stay listed for a while as long as you are in combat.
local function CachedEntries(list, seen, present)
	local now = GetTime()
	local inCombat = F.Bool(UnitAffectingCombat("player"))
	for guid, c in pairs(cache) do
		if not seen[guid] then
			local alive = false
			if not present[guid] then   -- a plate that is there but no longer fighting: dead or reset
				if F.HasCombatLog then
					alive = F.recent[guid] and now - F.recent[guid] < CACHE_SECS
				else
					alive = inCombat and now - (c.seen or 0) < OUT_OF_RANGE_SECS
				end
			end
			if alive then
				seen[guid] = true
				list[#list + 1] = { cache = c, name = c.name, tanking = false, pct = c.pct, score = c.score or 0, guid = guid }
			else
				cache[guid] = nil
			end
		end
	end
end

-- Pull order: guid -> running number, assigned when an enemy first shows up; cleared when the list empties
local pullSeq, pullNext = {}, 0

local function AssignPullOrder(list)
	if #list == 0 then
		if next(pullSeq) then pullSeq, pullNext = {}, 0 end
		return
	end
	for _, e in ipairs(list) do
		local key = tostring(e.guid)
		local n = pullSeq[key]
		if not n then pullNext = pullNext + 1; n = pullNext; pullSeq[key] = n end
		e.order = n
	end
end

local function SortEntries(list)
	local tank = F.IsTank()
	local mode = F.db.enemy.sort
	local byName = mode == "name"
	local byPull = mode == "pull"
	if byPull then AssignPullOrder(list) end
	table.sort(list, function(a, b)
		local ai, bi = a.idle and true or false, b.idle and true or false
		if ai ~= bi then return bi end -- non-fighting enemies to the end
		if byPull and a.order ~= b.order then return (a.order or 0) < (b.order or 0) end
		if byName and tostring(a.name or "") ~= tostring(b.name or "") then return tostring(a.name or "") < tostring(b.name or "") end
		if a.score ~= b.score then
			if tank then return a.score < b.score end -- Tank: endangered enemies (little threat) first
			return a.score > b.score                  -- otherwise: highest threat first
		end
		return tostring(a.guid) < tostring(b.guid)
	end)
end

-- Enemies without a nameplate (target, focus, bosses, group targets) without duplicates of the nameplate entries.
local function ExtraEntries(seen)
	local list = {}
	for _, unit in ipairs(F.ExtraUnits()) do
		if F.IsEngaged(unit) then
			local guid = UnitGUID(unit)
			if F.Readable(guid) and guid and not seen[guid] then
				seen[guid] = true
				list[#list + 1] = Entry(unit, nil)
			end
		end
	end
	return list
end

-- Display options per row (percent, elite icons, resource)
local function ApplyRowOptions(row)
	local o = F.db.enemy
	row.info:SetShown(o.showPercent ~= false)
	if o.showElite == false then
		row.dragon:Hide()
		if row.star then row.star:Hide() end
	end
	if o.showPower == false then row.power:Hide() end
end

function M:Update()
	if DemoActive() then
		M:SetCount(#DEMO_ENEMIES)
		for i = 1, MAX_ROWS do
			local row, d = rows[i], DEMO_ENEMIES[i]
			if d then
				FillDemo(row, d)
				ApplyRowOptions(row)
				row:Show()
			else
				row:Hide()
			end
		end
		return
	end

	local list, seen = {}, {}
	local present = PlateEntries(list, seen)
	for _, e in ipairs(ExtraEntries(seen)) do list[#list + 1] = e end
	-- out-of-sight enemies stay listed, unless the same enemy is visible again (other nameplate / target)
	CachedEntries(list, seen, present)
	SortEntries(list)

	local maxRows = math.min(MAX_ROWS, F.db.enemy.maxRows or 12)
	M:SetCount(#list)
	for i = 1, MAX_ROWS do
		local row, e = rows[i], list[i]
		if e and i <= maxRows then
			FillRow(row, e)
			ApplyRowOptions(row)
			row:Show()
		else
			row:Hide()
		end
	end
end

-- Heading with the number of enemies (all of them, also those beyond the row limit)
function M:SetCount(n)
	local h = M.frame and M.frame.header
	if not h then return end
	if F.db.enemy.showHeader ~= false and n > 0 then
		h:SetText(L.ENEMY_COUNT:format(n))
		h:Show()
	else
		h:Hide()
	end
end

-- Column layout (enemies per column is configurable)
function M:ApplyLayout()
	if not M.frame then return end
	local pc = PerCol()
	for i, row in ipairs(rows) do
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", M.frame, "TOPLEFT", math.floor((i - 1) / pc) * (ROW_W + AuraWidth() + COLGAP), -((i - 1) % pc) * PITCH + YOFF)
	end
	-- The frame (and its mover) is only as large as the rows that can be shown.
	local shown = math.min(MAX_ROWS, F.db.enemy.maxRows or 12)
	local cols = math.ceil(shown / pc)
	pc = math.min(pc, shown)
	M.frame:SetSize(cols * (ROW_W + AuraWidth()) + (cols - 1) * COLGAP, pc * PITCH - GAP)
end

function M:Init()
	-- The rows are Blizzard's target frame; without that art the list stays off.
	if not (F.AtlasName("tFrame") and F.AtlasName("tType") and F.AtlasName("tHealth")) then
		F.Print(L.NO_ART)
		return
	end
	local f = CreateFrame("Frame", "FrayEnemyList", UIParent)
	f:SetSize(ROW_W, PITCH)
	M.frame = f
	F:MakeMovable(f, "enemy", L.FRAME_ENEMY, 500, 80)

	for i = 1, MAX_ROWS do rows[i] = CreateRow(i) end
	M:ApplyLayout()
	-- Small heading with the number of enemies, in the gold of Blizzard's frame titles
	f.header = F.CreateText(f, 12, "LEFT")
	f.header:SetFontObject("GameFontNormal")
	f.header:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 22 * S, YOFF + 1)
	f.header:Hide()
	f.t = 0
	f:SetScript("OnUpdate", function(self, dt)
		self.t = self.t + dt
		if self.t < 0.1 then return end
		self.t = 0
		M:Update()
	end)

	M:InitPlateWarning()
end

-- Warning when enemy nameplates are off (the list is built from them and would stay empty):
-- big text on screen while in combat (and for a few seconds after login) plus a chat message at every pull.
local function PlatesOff()
	return F.db.enemy.plateWarn ~= false and F:IsEnabled("enemy")
		and GetCVar("nameplateShowEnemies") == "0"
end

function M:InitPlateWarning()
	local w = CreateFrame("Frame", "FrayPlateWarning", UIParent)
	w:SetSize(600, 60)
	w:SetPoint("TOP", UIParent, "TOP", 0, -170)
	w:SetFrameStrata("HIGH")
	w:Hide()
	w.text = w:CreateFontString(nil, "OVERLAY")
	w.text:SetFont(F.FONT, 22, "OUTLINE")
	w.text:SetPoint("CENTER")
	w.text:SetJustifyH("CENTER")
	w.text:SetTextColor(1, 0.25, 0.2)
	w.text:SetText(L.TITLE .. ": " .. L.PLATES_OFF .. "\n|cffffffff" .. L.PLATES_HINT .. "|r")
	M.warn = w

	local loginUntil = GetTime() + 12
	local lastChat = 0
	local function Chat()
		if PlatesOff() and GetTime() - lastChat > 15 then
			lastChat = GetTime()
			F.Print("|cffff4040" .. L.PLATES_OFF .. "|r " .. L.PLATES_HINT)
		end
	end
	F:On("PLAYER_REGEN_DISABLED", Chat)

	local ticker = CreateFrame("Frame")
	ticker.t = 0
	ticker:SetScript("OnUpdate", function(self, dt)
		self.t = self.t + dt
		if self.t < 0.5 then return end
		self.t = 0
		local show = PlatesOff() and (UnitAffectingCombat("player") or GetTime() < loginUntil)
		w:SetShown(show and true or false)
	end)
	if PlatesOff() then Chat() end
end

function M:SetEnabled(on)
	if not M.frame then return end
	M.frame:SetShown(on)
	if not on then
		for i = 1, MAX_ROWS do rows[i]:Hide() end
	end
end
