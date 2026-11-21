local ADDON, F = ...
local M = {}
F:RegisterModule("alerts", M)

local state = {}      -- guid -> hatte Aggro beim letzten Scan
local lastWarn = {}   -- guid -> Zeitpunkt der letzten Warnung
local lastLowHP = 0

local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

local KINDS = {
	red = { tex = "Shield-Red.tga", title = { 1, 0.5, 0.44 } },
	orange = { tex = "Shield-Orange.tga", title = { 1, 0.78, 0.36 } },
	green = { tex = "Shield-Green.tga", title = { 0.62, 0.95, 0.66 } },
}

-- Warntoene (Dateien des Clients); "off" = kein Ton
local SOUNDS = {
	{ key = "off", name = "Aus" },
	{ key = "raid", name = "Raidwarnung", file = "Sound\\Interface\\RaidWarning.ogg" },
	{ key = "boss", name = "Boss-Emote", file = "Sound\\Interface\\RaidBossEmoteWarning.ogg" },
	{ key = "ready", name = "Bereitschaftscheck", file = "Sound\\Interface\\ReadyCheck.ogg" },
	{ key = "alarm", name = "Wecker", file = "Sound\\Interface\\AlarmClockWarning3.ogg" },
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

-- Banner: Schild + Titel + Untertitel. kind: red / orange / green.
-- sub: Format-Text, danach die Werte ("%s  >  %s", name, ziel); Namen duerfen geheime Werte sein.
-- soundOpt: Name der Ton-Einstellung ("soundGain" ...), true = Raidwarnung, false/nil = kein Ton.
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
		-- Schild + Text als Einheit mittig im Frame ausrichten, die beiden Zeilen zueinander zentriert
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
		-- Schild mittig UEBER dem Text, darunter Titel und Untertitel, alles auf der Mittelachse des Frames
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

-- Pause pro Gegner und Ereignis
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

	-- HP-Warnung nur, wenn die HP lesbar sind (auf Forever sind sie es meist nicht)
	if o.lowHealth and inCombat and not F.Bool(UnitIsDeadOrGhost("player")) then
		local cur, max = UnitHealth("player"), UnitHealthMax("player")
		if F.AllReadable(cur, max) and type(cur) == "number" and type(max) == "number" and max > 0
			and cur / max < (o.lowHealthPct or 25) / 100 and now - lastLowHP > 10 then
			lastLowHP = now
			M:Alert("Niedrige HP!", nil, "red", "soundLow")
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
					-- Aggro bekommen (fuer Tanks normalerweise gewollt, daher abschaltbar)
					if o.gain and (not F.db.tank or o.gainTank) and Cooldown(guid .. "g", pause) then
						M:Alert("Aggro!", "%s", "red", "soundGain", UnitName(unit))
					end
				elseif was and not tanking then
					-- Aggro verloren: ein Gegner, der eben noch auf dir war, hat das Ziel gewechselt
					if o.loss and Cooldown(guid .. "l", pause) then
						if hasTarget then
							M:Alert("Aggro verloren", "%s  >  %s", "orange", "soundLoss", UnitName(unit), UnitName(tt))
						else
							M:Alert("Aggro verloren", "%s", "orange", "soundLoss", UnitName(unit))
						end
					end
				elseif F.db.tank and o.tankWarn and not tanking and hasTarget and F.Bool(UnitIsPlayer(tt))
					and not F.Bool(UnitIsUnit(tt, "player")) and F.Bool(UnitAffectingCombat(unit))
					and Cooldown(guid .. "t", 6) then
					-- Tank: ein Gegner greift einen Mitspieler an (nie auf dir gewesen)
					M:Alert("Gegner ohne Aggro", "%s  >  %s", "orange", "soundLoss", UnitName(unit), UnitName(tt))
				end
				if o.threatHigh and known and not tanking and pct >= (o.threatPct or 90) and Cooldown(guid .. "h", pause) then
					M:Alert("Threat hoch", "%s  (%d%%)", "orange", "soundThreat", UnitName(unit), pct)
				end
			end
		end
	end
	state = newState
end

local W, H = 300, 50

-- Banner wie die Boss-Warnungen: kein Kasten, grosse farbige Schrift mit dicker Kontur; links das Status-Schild.
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

	-- Inhalt in einem Kind-Frame, damit der "Pop" skalieren kann, ohne die Position zu verschieben
	local inner = CreateFrame("Frame", nil, f)
	inner:SetAllPoints()
	f.inner = inner
	if not BuildBlizz(f, inner) then
	f.band = F.CreateBand(inner, 30, 9, W - 30, 32)
	-- Schild in eigenem Frame ueber der Platte (sonst liegt die Platte davor)
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
	F:MakeMovable(f, "alert", "Warnmeldungen", 0, 200)

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
