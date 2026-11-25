local ADDON, F = ...
local L = F.L
local M = {}
F:RegisterModule("alerts", M)

local state = {}      -- guid -> had aggro at the last scan
local lastWarn = {}   -- guid -> time of the last alert
local lastLowHP = 0

-- Per kind: Fray's shield above the text and the title colour.
local KINDS = {
	red = { tex = "Shield-Red", 1, 0.5, 0.44 },
	orange = { tex = "Shield-Orange", 1, 0.78, 0.36 },
	green = { tex = "Shield-Green", 0.62, 0.95, 0.66 },
}

-- Alert sounds: Blizzard's sound kits (the file path only where the client lacks the kit); "off" = no sound
local KIT = SOUNDKIT or {}
local SOUNDS = {
	{ key = "off", label = L.SND_OFF },
	{ key = "raid", label = L.SND_RAID, kit = KIT.RAID_WARNING, file = "Sound\\Interface\\RaidWarning.ogg" },
	{ key = "boss", label = L.SND_BOSS, kit = KIT.RAID_BOSS_EMOTE_WARNING, file = "Sound\\Interface\\RaidBossEmoteWarning.ogg" },
	{ key = "ready", label = L.SND_READY, kit = KIT.READY_CHECK, file = "Sound\\Interface\\ReadyCheck.ogg" },
	{ key = "alarm", label = L.SND_ALARM, kit = KIT.ALARM_CLOCK_WARNING_3, file = "Sound\\Interface\\AlarmClockWarning3.ogg" },
}
M.SOUNDS = SOUNDS

function M.PlaySound(key)
	for _, snd in ipairs(SOUNDS) do
		if snd.key == key then
			if snd.kit and pcall(PlaySound, snd.kit, "Master") then return end
			if snd.file then pcall(PlaySoundFile, snd.file, "Master") end
			return
		end
	end
end

-- Alerts that need numbers the client hides in combat say so once per session, instead of silently never firing.
local told = {}
local function TellLimited(key, text)
	if told[key] then return end
	told[key] = true
	F.Print(text)
end

-- Banner like Blizzard's boss warnings: status shield, large coloured title with a thick outline, subtitle below,
-- all centred. kind: red / orange / green.
-- sub: format string, followed by its values ("%s  >  %s", name, target); names may be secret values.
-- soundOpt: name of the sound setting ("soundGain" ...), false/nil = no sound.
function M:Alert(title, sub, kind, soundOpt, ...)
	local f = M.frame
	if not f then return end
	-- Two banners: a new alert never wipes one that is still showing; it takes the free banner, or the
	-- older one when both are busy.
	local second = M.second
	if f:IsShown() then
		if not second:IsShown() or (second.start or 0) < (f.start or 0) then
			f = second
		end
	end
	if f == second then second:SetScale(M.frame:GetScale()) end
	local o = F.db.alerts
	local color = KINDS[kind] or KINDS.red
	local size = o.textSize or 24
	f.title:SetFont(F.FONT, size, "THICKOUTLINE")
	f:SetHeight(size + 88)
	f.title:SetText(title or "")
	f.title:SetTextColor(color[1], color[2], color[3])
	f.icon:SetTexture(F.TEXROOT .. color.tex)
	if sub and o.showName ~= false then f.sub:SetFormattedText(sub, ...) else f.sub:SetText("") end
	f.start = GetTime()
	f:SetAlpha(0)
	f:Show()
	if soundOpt and o.sound then M.PlaySound(o[soundOpt] or soundOpt) end
end

-- Pause per enemy and event
local function Cooldown(key, secs)
	local now = GetTime()
	if lastWarn[key] and now - lastWarn[key] < secs then return false end
	lastWarn[key] = now
	return true
end

function M:Scan()
	local o = F.db.alerts
	local now = GetTime()
	local inCombat = F.Bool(UnitAffectingCombat("player"))
	local pause = o.pause or 8

	-- Low health alert only if health is readable (on Forever it usually is not)
	if o.lowHealth and inCombat and not F.Bool(UnitIsDeadOrGhost("player")) then
		local cur, max = UnitHealth("player"), UnitHealthMax("player")
		if not F.AllReadable(cur, max) then TellLimited("low", L.LIMITED_LOW) end
		if F.AllReadable(cur, max) and type(cur) == "number" and type(max) == "number" and max > 0
			and cur / max < (o.lowHealthPct or 25) / 100 and now - lastLowHP > 10 then
			lastLowHP = now
			M:Alert(L.ALERT_LOW, nil, "red", "soundLow")
		end
	end

	if o.onlyInGroup and not F.InGroup() then
		wipe(state)
		return
	end

	local quiet = o.onlyInCombat and not inCombat
	local newState = {}
	for _, unit in ipairs(F.EnumerateEnemies()) do
		local guid = UnitGUID(unit)
		if F.Readable(guid) and guid then
			local tanking, _, pct, known = F.GetThreat(unit)
			pct = pct or 0
			newState[guid] = tanking
			local was = state[guid]

			if not quiet then
				local tt = unit .. "target"
				local hasTarget = F.Bool(UnitExists(tt))
				if tanking and not was then
					-- Aggro gained (normally wanted by tanks, hence switchable)
					if o.gain and (not F.IsTank() or o.gainTank) and Cooldown(guid .. "g", pause) then
						M:Alert(L.ALERT_AGGRO, "%s", "red", "soundGain", UnitName(unit))
					end
				elseif was and not tanking then
					-- Aggro lost: an enemy that was on you a moment ago switched target
					if o.loss and Cooldown(guid .. "l", pause) then
						if hasTarget then
							M:Alert(L.ALERT_LOST, "%s  >  %s", "orange", "soundLoss", UnitName(unit), UnitName(tt))
						else
							M:Alert(L.ALERT_LOST, "%s", "orange", "soundLoss", UnitName(unit))
						end
					end
				elseif F.IsTank() and o.tankWarn and not tanking and hasTarget and F.Bool(UnitIsPlayer(tt))
					and not F.Bool(UnitIsUnit(tt, "player")) and F.Bool(UnitAffectingCombat(unit))
					and Cooldown(guid .. "t", 6) then
					-- Tank: an enemy attacks a party member (it never was on you)
					M:Alert(L.ALERT_TANK, "%s  >  %s", "orange", "soundLoss", UnitName(unit), UnitName(tt))
				end
				if o.threatHigh and not known and F.Bool(UnitAffectingCombat(unit)) then TellLimited("threat", L.LIMITED_THREAT) end
				if o.threatHigh and known and not tanking and pct >= (o.threatPct or 90) and Cooldown(guid .. "h", pause) then
					M:Alert(L.ALERT_HIGH, "%s  (%d%%)", "orange", "soundThreat", UnitName(unit), pct)
				end
			end
		end
	end
	state = newState
end

local function CreateBanner(name)
	local f = CreateFrame("Frame", name, UIParent)
	f:SetSize(520, 130)
	f:SetFrameStrata("HIGH")
	f:Hide()

	-- Content in a child frame so the "pop" can scale without moving the position
	local inner = CreateFrame("Frame", nil, f)
	inner:SetAllPoints()
	f.inner = inner
	f.icon = inner:CreateTexture(nil, "ARTWORK")
	f.icon:SetTexture(F.TEXROOT .. "Shield-Red")
	f.icon:SetSize(50, 50)
	f.icon:SetPoint("TOP", inner, "TOP", 0, 0)
	f.iconFrame = inner:CreateTexture(nil, "ARTWORK", nil, 1)
	f.iconFrame:SetTexture(F.TEXROOT .. "Shield-Frame")
	f.iconFrame:SetAllPoints(f.icon)
	f.iconFrame:SetVertexColor(F.SHIELD_RIM[1], F.SHIELD_RIM[2], F.SHIELD_RIM[3])
	f.title = F.CreateText(inner, 24, "CENTER")
	f.title:SetFont(F.FONT, 24, "THICKOUTLINE")
	f.title:SetPoint("TOP", f.icon, "BOTTOM", 0, -4)
	f.title:SetWidth(700)
	f.sub = F.CreateText(inner, 13, "CENTER")
	f.sub:SetFont(F.FONT, 13, "OUTLINE")
	f.sub:SetPoint("TOP", f.title, "BOTTOM", 0, -3)
	f.sub:SetWidth(700)
	f.sub:SetTextColor(0.92, 0.9, 0.85)

	local OUT = 0.7
	f:SetScript("OnUpdate", function(self)
		local HOLD = F.db.alerts.hold or 2.6
		local t = GetTime() - (self.start or 0)
		if t >= HOLD + OUT then
			self:Hide()
			return
		end
		local a = 1
		local s = 1
		if t < 0.18 then
			local p = t / 0.18
			a = p
			s = 0.82 + 0.18 * (1 - (1 - p) * (1 - p))
		elseif t > HOLD then
			a = 1 - (t - HOLD) / OUT
		end
		self:SetAlpha(a)
		self.inner:SetScale(s)
	end)
	return f
end

function M:Init()
	local f = CreateBanner("FrayAlert")
	M.frame = f
	F:MakeMovable(f, "alert", L.FRAME_ALERT, 0, 200)
	-- second banner right below the first
	local second = CreateBanner("FrayAlert2")
	second:SetPoint("TOP", f, "BOTTOM", 0, 14)
	M.second = second

	local d = CreateFrame("Frame")
	d.t = 0
	d:SetScript("OnUpdate", function(self, dt)
		self.t = self.t + dt
		if self.t < 0.25 then return end
		self.t = 0
		M:Scan()
	end)
	M.driver = d
end

function M:SetEnabled(on)
	M.driver:SetShown(on)
	if not on then
		M.frame:Hide()
		M.second:Hide()
		wipe(state)
	end
end
