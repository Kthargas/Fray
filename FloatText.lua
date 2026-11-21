local ADDON, F = ...
local M = {}
F:RegisterModule("float", M)

-- Schwebender Kampftext: Zahlen steigen mit Abbremsen auf, treffen mit einem kleinen "Pop" ein
-- (Krits staerker), driften leicht nach aussen und blenden weich aus.
local MAX = 36
local pool = {}
local nextIdx = 1
local lane = 0
local playerGUID

local COLORS = {
	out = { 1, 0.96, 0.88 },
	crit = { 1, 0.76, 0.22 },
	pet = { 0.74, 0.72, 0.68 },
	hit = { 1, 0.4, 0.36 },
	heal = { 0.46, 1, 0.52 },
	miss = { 1, 0.9, 0.38 },
}

local function Spawn(text, side, color, kind)
	local e = pool[nextIdx]
	nextIdx = nextIdx % MAX + 1
	lane = (lane + 1) % 3
	local size = 19
	local dur = 1.3
	if kind == "crit" then size, dur = 26, 1.7
	elseif kind == "small" then size = 13
	elseif kind == "big" then size = 22 end
	e.t, e.dur, e.active = 0, dur, true
	e.side = side
	e.crit = kind == "crit"
	e.x0 = side * 120 + (lane - 1) * 26 + math.random(-8, 8)
	e.fs:SetFont(F.FONT, size, "OUTLINE")
	e.fs:SetText(text)
	e.fs:SetTextColor(color[1], color[2], color[3])
	e.f:SetAlpha(0)
	e.f:Show()
end

local function OnCombatLog()
	if not F.db.modules.float then return end
	local _, sub, _, srcGUID, _, _, _, dstGUID, _, _, _, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21 = CombatLogGetCurrentEventInfo()
	local petGUID = UnitGUID("pet")
	local out = srcGUID == playerGUID or (petGUID and srcGUID == petGUID)
	local isPet = out and srcGUID ~= playerGUID
	local inc = dstGUID == playerGUID
	if not out and not inc then return end

	local amount, crit, heal, missType
	if sub == "SWING_DAMAGE" then
		amount, crit = a12, a18
	elseif sub == "RANGE_DAMAGE" or sub == "SPELL_DAMAGE" or sub == "SPELL_PERIODIC_DAMAGE" then
		amount, crit = a15, a21
	elseif sub == "ENVIRONMENTAL_DAMAGE" then
		amount = a13
	elseif sub == "SPELL_HEAL" or sub == "SPELL_PERIODIC_HEAL" then
		amount = (a15 or 0) - (a16 or 0)
		crit = a18
		heal = true
	elseif sub == "SWING_MISSED" then
		missType = a12
	elseif sub == "SPELL_MISSED" or sub == "RANGE_MISSED" then
		missType = a15
	else
		return
	end

	if missType then
		if inc then Spawn(_G[missType] or missType, -1, COLORS.miss, "small") end
		return
	end
	if not amount or amount <= 0 or amount < F.db.float.minAmount then return end

	local txt = F.Short(amount)
	if heal then
		if inc then Spawn("+" .. txt, -1, COLORS.heal, crit and "crit" or nil) end
	elseif inc then
		Spawn("-" .. txt, -1, COLORS.hit, crit and "crit" or nil)
	elseif out and dstGUID ~= playerGUID then
		if isPet then
			Spawn(txt, 1, COLORS.pet, "small")
		elseif crit then
			Spawn(txt, 1, COLORS.crit, "crit")
		else
			Spawn(txt, 1, COLORS.out)
		end
	end
end

function M:Test()
	Spawn("-1234", -1, COLORS.hit)
	Spawn("+560", -1, COLORS.heal)
	Spawn("2200", 1, COLORS.crit, "crit")
	Spawn("812", 1, COLORS.out)
	Spawn("Parade", -1, COLORS.miss, "small")
end

function M:Init()
	local f = CreateFrame("Frame", "FrayFloatText", UIParent)
	f:SetSize(60, 30)
	M.frame = f
	F:MakeMovable(f, "float", "Kampftext", 0, 20)

	for i = 1, MAX do
		local e = { t = 0, dur = 1.3, active = false }
		e.f = CreateFrame("Frame", nil, f)
		e.f:SetSize(1, 1)
		e.fs = F.CreateText(e.f, 19, "CENTER")
		e.fs:SetPoint("CENTER")
		e.f:Hide()
		pool[i] = e
	end

	f:SetScript("OnUpdate", function(_, dt)
		for i = 1, MAX do
			local e = pool[i]
			if e.active then
				e.t = e.t + dt
				local p = e.t / e.dur
				if p >= 1 then
					e.active = false
					e.f:Hide()
				else
					-- Aufstieg mit Abbremsen, leichter Drift nach aussen
					local rise = 1 - (1 - p) * (1 - p)
					local y = 86 * rise
					local x = e.x0 + e.side * 24 * rise
					-- Pop beim Erscheinen (Krits staerker), danach ruhige Groesse
					local pop = math.max(0, 1 - p / 0.16)
					local s = 1 + (e.crit and 0.8 or 0.3) * pop * pop
					e.f:SetScale(s)
					e.f:ClearAllPoints()
					e.f:SetPoint("CENTER", f, "CENTER", x / s, y / s)
					local a = p < 0.04 and p / 0.04 or (p < 0.55 and 1 or 1 - (p - 0.55) / 0.45)
					e.f:SetAlpha(a)
				end
			end
		end
	end)

	playerGUID = UnitGUID("player")
	F:On("PLAYER_ENTERING_WORLD", function() playerGUID = UnitGUID("player") end)
	-- Ohne Kampflog (z. B. Forever) gibt es keine Schadenszahlen fuer Addons: das Modul bleibt aus.
	M.unavailable = not F.HasCombatLog
	if F.HasCombatLog then F:On("COMBAT_LOG_EVENT_UNFILTERED", OnCombatLog) end
end

function M:SetEnabled(on)
	M.frame:SetShown(on and not M.unavailable)
end
