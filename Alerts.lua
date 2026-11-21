local ADDON, F = ...
local M = {}
F:RegisterModule("alerts", M)

local state = {}      -- guid -> had aggro at the last scan
local lastWarn = {}   -- guid -> time of the last alert
local lastLowHP = 0

local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

local KINDS = {
	red = { tex = "Shield-Red.tga", title = { 1, 0.5, 0.44 } },
	orange = { tex = "Shield-Orange.tga", title = { 1, 0.78, 0.36 } },
	green = { tex = "Shield-Green.tga", title = { 0.62, 0.95, 0.66 } },
}

-- Alert sounds (client files); "off" = no sound
local SOUNDS = {
	{ key = "off", name = "Off" },
	{ key = "raid", name = "Raid warning", file = "Sound\\Interface\\RaidWarning.ogg" },
	{ key = "boss", name = "Boss emote", file = "Sound\\Interface\\RaidBossEmoteWarning.ogg" },
	{ key = "ready", name = "Ready check", file = "Sound\\Interface\\ReadyCheck.ogg" },
	{ key = "alarm", name = "Alarm clock", file = "Sound\\Interface\\AlarmClockWarning3.ogg" },
}
M.SOUNDS = SOUNDS

function M.PlaySound(key)
	for _, snd in ipairs(SOUNDS) do
		if snd.key == key and snd.file then
			pcall(PlaySoundFile, snd.file, "Master")
			return
		end
	end
end

-- Banner: shield + title + subtitle. kind: red / orange / green.
-- sub: format string, followed by its values ("%s  >  %s", name, target); names may be secret values.
-- soundOpt: name of the sound setting ("soundGain" ...), true = raid warning, false/nil = no sound.
function M:Alert(title, sub, kind, soundOpt, ...)
	local f = M.frame
	local o = F.db.alerts
	local k = KINDS[kind] or KINDS.red
	f.shield:SetTexture(F.TEXROOT .. k.tex)
	if f.blizzBanner then
		local size = o.textSize or 24
		f.title:SetFont(FONT, size, "THICKOUTLINE")
		f:SetHeight(size + 82)
	end
	f.title:SetText(title or "")
	f.title:SetTextColor(k.title[1], k.title[2], k.title[3])
	if sub and o.showName ~= false then f.sub:SetFormattedText(sub, ...) else f.sub:SetText("") end
	if f.blizzBanner then
		-- Centre shield + text as one unit in the frame, with the two lines centred on each other
		f.title:SetWidth(700)
		f.sub:SetWidth(700)
		local okT, tw = pcall(f.title.GetStringWidth, f.title)
		local okS, sw = pcall(f.sub.GetStringWidth, f.sub)
		tw = (okT and type(tw) == "number" and F.Readable(tw) and tw) or 200
		sw = (okS and type(sw) == "number" and F.Readable(sw) and sw) or 0
		local w = math.max(tw, sw) + 6
		f.title:SetWidth(w)
		f.sub:SetWidth(w)
		f.title:SetJustifyH("CENTER")
		f.sub:SetJustifyH("CENTER")
		-- Shield centred ABOVE the text, then title and subtitle, all on the frame's centre axis
		f.shield:ClearAllPoints()
		f.shield:SetPoint("TOP", f.inner, "TOP", 0, 0)
		f.title:ClearAllPoints()
		f.title:SetPoint("TOP", f.inner, "TOP", 0, -54)
		f.sub:ClearAllPoints()
		f.sub:SetPoint("TOP", f.title, "BOTTOM", 0, -3)
	end
	f.start = GetTime()
	f:SetAlpha(0)
	f:Show()
	if soundOpt and o.sound then
		M.PlaySound(soundOpt == true and "raid" or (o[soundOpt] or soundOpt))
	end
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
		if F.AllReadable(cur, max) and type(cur) == "number" and type(max) == "number" and max > 0
			and cur / max < (o.lowHealthPct or 25) / 100 and now - lastLowHP > 10 then
			lastLowHP = now
			M:Alert("Low health!", nil, "red", "soundLow")
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
					if o.gain and (not F.db.tank or o.gainTank) and Cooldown(guid .. "g", pause) then
						M:Alert("Aggro!", "%s", "red", "soundGain", UnitName(unit))
					end
				elseif was and not tanking then
					-- Aggro lost: an enemy that was on you a moment ago switched target
					if o.loss and Cooldown(guid .. "l", pause) then
						if hasTarget then
							M:Alert("Aggro lost", "%s  >  %s", "orange", "soundLoss", UnitName(unit), UnitName(tt))
						else
							M:Alert("Aggro lost", "%s", "orange", "soundLoss", UnitName(unit))
						end
					end
				elseif F.db.tank and o.tankWarn and not tanking and hasTarget and F.Bool(UnitIsPlayer(tt))
					and not F.Bool(UnitIsUnit(tt, "player")) and F.Bool(UnitAffectingCombat(unit))
					and Cooldown(guid .. "t", 6) then
					-- Tank: an enemy attacks a party member (it never was on you)
					M:Alert("Enemy without aggro", "%s  >  %s", "orange", "soundLoss", UnitName(unit), UnitName(tt))
				end
				if o.threatHigh and known and not tanking and pct >= (o.threatPct or 90) and Cooldown(guid .. "h", pause) then
					M:Alert("High threat", "%s  (%d%%)", "orange", "soundThreat", UnitName(unit), pct)
				end
			end
		end
	end
	state = newState
end

local W, H = 300, 50

-- Banner like boss warnings: no box, large coloured text with a thick outline; status shield on the left.
local function BuildBlizz(f, inner)
	f:SetSize(520, 130)
	f.blizzBanner = true
	f.shield = inner:CreateTexture(nil, "ARTWORK")
	f.shield:SetTexture(F.TEXROOT .. "Shield-Red.tga")
	f.shield:SetSize(50, 50)
	f.shield:SetPoint("LEFT", inner, "LEFT", 2, 0)
	f.shieldFrame = inner:CreateTexture(nil, "ARTWORK", nil, 1)
	f.shieldFrame:SetTexture(F.TEXROOT .. "Shield-Frame.tga")
	f.shieldFrame:SetAllPoints(f.shield)
	F.TintRim(f.shieldFrame)
	f.title = F.CreateText(inner, 24, "LEFT")
	f.title:SetFont(FONT, 24, "THICKOUTLINE")
	f.title:SetPoint("TOPLEFT", 62, -4)
	f.sub = F.CreateText(inner, 13, "LEFT")
	f.sub:SetFont(FONT, 13, "OUTLINE")
	f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 2, -3)
	f.sub:SetTextColor(unpack(F.PAL.text))
	return true
end

function M:Init()
	local f = CreateFrame("Frame", "FrayAlert", UIParent)
	f:SetSize(W, H)
	f:SetFrameStrata("HIGH")
	f:Hide()

	-- Content in a child frame so the "pop" can scale without moving the position
	local inner = CreateFrame("Frame", nil, f)
	inner:SetAllPoints()
	f.inner = inner
	if not BuildBlizz(f, inner) then
	f.band = F.CreateBand(inner, 30, 9, W - 30, 32)
	-- Shield in its own frame above the plate (otherwise the plate would cover it)
	f.emblem = CreateFrame("Frame", nil, inner)
	f.emblem:SetSize(64, 64)
	f.emblem:SetPoint("CENTER", inner, "LEFT", 33, 0)
	f.emblem:SetFrameLevel(f.band.frame:GetFrameLevel() + 8)
	f.shield = f.emblem:CreateTexture(nil, "ARTWORK")
	f.shield:SetTexture(F.TEXROOT .. "Shield-Red.tga")
	f.shield:SetAllPoints()
	f.shieldFrame = f.emblem:CreateTexture(nil, "ARTWORK", nil, 1)
	f.shieldFrame:SetTexture(F.TEXROOT .. "Shield-Frame.tga")
	f.shieldFrame:SetAllPoints()
	F.TintRim(f.shieldFrame)
	f.title = F.CreateText(inner, 17, "LEFT")
	f.title:SetFont(F.FONT_BOLD, 17, "")
	f.title:SetPoint("TOPLEFT", 76, -12)
	f.sub = F.CreateText(inner, 11, "LEFT")
	f.sub:SetPoint("TOPLEFT", 76, -29)
	f.sub:SetTextColor(unpack(F.PAL.text))
	end

	local HOLD, OUT = 2.6, 0.7
	f:SetScript("OnUpdate", function(self)
		HOLD = F.db.alerts.hold or 2.6
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
	M.frame = f
	F:MakeMovable(f, "alert", "Alerts", 0, 200)

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
		wipe(state)
	end
end
