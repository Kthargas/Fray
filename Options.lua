local ADDON, F = ...
local M = {}
F:RegisterModule("options", M)

-- Einstellungsfenster im Stil der Spieloberflaeche: dunkles Panel mit feinem Goldrand, Reiter links,
-- Inhalt rechts. Oeffnen mit /fray (oder /fray config).
local PW, PH = 620, 560
local TABW = 150
local PAD = 22

local TITLE_GOLD = F.PAL.gold
local TEXT = F.PAL.text
local DIM = F.PAL.dim

local panel
local tabs, pages, widgets = {}, {}, {}

------------------------------------------------------------------------
-- Bausteine
------------------------------------------------------------------------
local function NineSlice(frame, file, c)
	local path = F.TEXROOT .. file
	local u = c / 64
	local function tex(l, r, t, b)
		local x = frame:CreateTexture(nil, "BACKGROUND")
		x:SetTexture(path)
		x:SetTexCoord(l, r, t, b)
		return x
	end
	local tl, tr = tex(0, u, 0, u), tex(1 - u, 1, 0, u)
	local bl, br = tex(0, u, 1 - u, 1), tex(1 - u, 1, 1 - u, 1)
	for _, x in ipairs({ tl, tr, bl, br }) do x:SetSize(c, c) end
	-- Versaetze wie in Blizzards Layout ButtonFrameTemplateNoPortrait: die Kunst ragt ueber den Rahmen hinaus
	tl:SetPoint("TOPLEFT", frame, "TOPLEFT", -8, 16)
	tr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 4, 16)
	bl:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -8, -3)
	br:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 4, -3)
	local top, bottom = tex(u, 1 - u, 0, u), tex(u, 1 - u, 1 - u, 1)
	top:SetPoint("TOPLEFT", tl, "TOPRIGHT"); top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
	bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT"); bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
	local left, right = tex(0, u, u, 1 - u), tex(1 - u, 1, u, 1 - u)
	left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
	right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT"); right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
	local center = tex(u, 1 - u, u, 1 - u)
	center:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT"); center:SetPoint("BOTTOMRIGHT", br, "TOPLEFT")
end

-- Blizzards Metall-Rahmen als Fensterrahmen (Atlas); false, wenn der Client sie nicht hat
local function AtlasPanel(frame)
	for _, k in ipairs({ "metalTL", "metalTR", "metalBL", "metalBR", "metalTop", "metalBottom", "metalLeft", "metalRight" }) do
		if not F.AtlasName(k) then return false end
	end
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetColorTexture(0.07, 0.06, 0.05, 0.97)
	bg:SetPoint("TOPLEFT", 0, 0)
	bg:SetPoint("BOTTOMRIGHT", 0, 0)
	local function tex(key)
		local t = frame:CreateTexture(nil, "OVERLAY")
		t:SetAtlas(F.AtlasName(key), true)
		return t
	end
	local tl, tr, bl, br = tex("metalTL"), tex("metalTR"), tex("metalBL"), tex("metalBR")
	tl:SetPoint("TOPLEFT"); tr:SetPoint("TOPRIGHT"); bl:SetPoint("BOTTOMLEFT"); br:SetPoint("BOTTOMRIGHT")
	local top, bottom, left, right = tex("metalTop"), tex("metalBottom"), tex("metalLeft"), tex("metalRight")
	top:SetPoint("TOPLEFT", tl, "TOPRIGHT"); top:SetPoint("TOPRIGHT", tr, "TOPLEFT")
	bottom:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT"); bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
	left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); left:SetPoint("BOTTOMLEFT", bl, "TOPLEFT")
	right:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT"); right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
	return true
end

local function Label(parent, size, justify)
	local fs = F.CreateText(parent, size, justify)
	fs:SetTextColor(unpack(TEXT))
	return fs
end

local function Header(page, text)
	page.y = page.y - (page.first and 0 or 10)
	page.first = false
	local fs = F.CreateText(page, 14, "LEFT")
	fs:SetFont(F.FONT_TITLE, 14, "")
	fs:SetPoint("TOPLEFT", 0, page.y)
	fs:SetTextColor(unpack(TITLE_GOLD))
	fs:SetText(text)
	local line = page:CreateTexture(nil, "ARTWORK")
	line:SetTexture(F.WHITE)
	line:SetVertexColor(0.66, 0.52, 0.36, 0.35)
	line:SetPoint("TOPLEFT", 0, page.y - 20)
	line:SetSize(PW - TABW - PAD * 3, 1)
	page.y = page.y - 30
end

local function Hint(page, text, height)
	local fs = page:CreateFontString(nil, "OVERLAY")
	fs:SetFont(F.FONT, 11, "")
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetShadowOffset(1, -1)
	fs:SetTextColor(unpack(DIM))
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("TOP")
	if fs.SetWordWrap then fs:SetWordWrap(true) end
	fs:SetPoint("TOPLEFT", 0, page.y)
	fs:SetWidth(PW - TABW - PAD * 3)
	fs:SetHeight(height or 30)
	fs:SetText(text)
	page.y = page.y - (height or 30) - 6
end

local function Checkbox(page, label, get, set)
	local b = CreateFrame("Button", nil, page)
	b:SetSize(PW - TABW - PAD * 3, 24)
	b:SetPoint("TOPLEFT", 0, page.y)
	b.boxBg = b:CreateTexture(nil, "BACKGROUND")
	b.boxBg:SetTexture(F.WHITE)
	b.boxBg:SetVertexColor(0.03, 0.02, 0.015, 0.95)
	b.boxBg:SetSize(18, 18)
	b.boxBg:SetPoint("LEFT", 1, 0)
	b.box = b:CreateTexture(nil, "ARTWORK")
	b.box:SetTexture(F.TEXROOT .. "Icon-Border.tga")
	b.box:SetVertexColor(unpack(F.PAL.edge))
	b.box:SetSize(22, 22)
	b.box:SetPoint("LEFT", -1, 0)
	b.mark = b:CreateTexture(nil, "OVERLAY")
	b.mark:SetTexture(F.TEXROOT .. "Check-Mark.tga")
	b.mark:SetSize(20, 20)
	b.mark:SetPoint("LEFT")
	b.mark:SetVertexColor(unpack(F.PAL.hover))
	if F.AtlasName("cbBox") and F.AtlasName("cbCheck") then
		b.boxBg:Hide()
		b.box:SetAtlas(F.AtlasName("cbBox"), false)
		b.box:SetVertexColor(1, 1, 1)
		b.box:SetSize(26, 26)
		b.mark:SetAtlas(F.AtlasName("cbCheck"), false)
		b.mark:SetVertexColor(1, 1, 1)
		b.mark:SetSize(26, 26)
	end
	b.label = Label(b, 12, "LEFT")
	b.label:SetPoint("LEFT", b.box, "RIGHT", 9, 0)
	b.label:SetText(label)
	function b:Refresh()
		if get() then self.mark:Show() else self.mark:Hide() end
	end
	b:SetScript("OnClick", function(self)
		set(not get())
		self:Refresh()
	end)
	b:SetScript("OnEnter", function(self) self.label:SetTextColor(1, 0.9, 0.6) end)
	b:SetScript("OnLeave", function(self) self.label:SetTextColor(unpack(TEXT)) end)
	widgets[#widgets + 1] = b
	page.y = page.y - 28
	return b
end

local function Slider(page, label, min, max, step, get, set, fmt)
	local holder = CreateFrame("Frame", nil, page)
	holder:SetSize(PW - TABW - PAD * 3, 44)
	holder:SetPoint("TOPLEFT", 0, page.y)
	local name = Label(holder, 12, "LEFT")
	name:SetPoint("TOPLEFT", 0, 0)
	name:SetText(label)
	local value = F.CreateText(holder, 12, "RIGHT")
	value:SetPoint("TOPRIGHT", -2, 0)
	value:SetTextColor(unpack(TITLE_GOLD))

	local s = CreateFrame("Slider", nil, holder)
	s:SetPoint("TOPLEFT", 0, -22)
	s:SetSize(PW - TABW - PAD * 3 - 4, 18)
	s:SetOrientation("HORIZONTAL")
	s.track = s:CreateTexture(nil, "BACKGROUND")
	s.track:SetTexture(F.WHITE)
	s.track:SetVertexColor(0.03, 0.02, 0.015, 0.95)
	s.track:SetPoint("LEFT")
	s.track:SetPoint("RIGHT")
	s.track:SetHeight(6)
	s.rim = s:CreateTexture(nil, "BORDER")
	s.rim:SetTexture(F.WHITE)
	s.rim:SetVertexColor(F.PAL.edge[1], F.PAL.edge[2], F.PAL.edge[3], 0.9)
	s.rim:SetPoint("LEFT", -1, 0)
	s.rim:SetPoint("RIGHT", 1, 0)
	s.rim:SetHeight(8)
	s:SetThumbTexture(F.TEXROOT .. "Slider-Thumb.tga")
	local thumb = s:GetThumbTexture()
	if thumb then thumb:SetSize(20, 20) end
	if F.AtlasName("sliderL") and F.AtlasName("sliderM") and F.AtlasName("sliderR") then
		s.track:Hide()
		s.rim:Hide()
		local l = s:CreateTexture(nil, "BACKGROUND")
		l:SetAtlas(F.AtlasName("sliderL"), true)
		l:SetPoint("LEFT")
		local r = s:CreateTexture(nil, "BACKGROUND")
		r:SetAtlas(F.AtlasName("sliderR"), true)
		r:SetPoint("RIGHT")
		local m = s:CreateTexture(nil, "BACKGROUND")
		m:SetAtlas(F.AtlasName("sliderM"), true)
		m:SetPoint("LEFT", l, "RIGHT")
		m:SetPoint("RIGHT", r, "LEFT")
		if thumb and F.AtlasName("sliderThumb") then thumb:SetAtlas(F.AtlasName("sliderThumb"), true) end
	end
	s:SetMinMaxValues(min, max)
	s:SetValueStep(step)
	if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
	local function show(v) value:SetText(fmt and fmt(v) or tostring(v)) end
	s:SetScript("OnValueChanged", function(self, v)
		if self.refreshing then return end
		v = math.floor(v / step + 0.5) * step
		set(v)
		show(v)
	end)
	function holder:Refresh()
		s.refreshing = true
		local v = get()
		s:SetValue(v)
		show(v)
		s.refreshing = false
	end
	widgets[#widgets + 1] = holder
	page.y = page.y - 50
	return holder
end

-- Groesse eines einzelnen Frames (Prozent); wirkt zusammen mit der Gesamtskalierung
local function ScaleSlider(page, label, key)
	return Slider(page, label, 50, 200, 5,
		function() return math.floor(((F.db.scales and F.db.scales[key]) or 1) * 100 + 0.5) end,
		function(v) F.db.scales = F.db.scales or {}; F.db.scales[key] = v / 100; F.ApplyScale() end,
		function(v) return v .. " %" end)
end

local function Button(page, text, fn, width)
	local w = width or 210
	local b = CreateFrame("Button", nil, page)
	b:SetSize(w, 28)
	b:SetPoint("TOPLEFT", 0, page.y)
	b.band = F.CreateBand(b, 0, 1, w, 26)
	b.text = F.CreateText(b, 12, "CENTER")
	b.text:SetPoint("CENTER")
	b.text:SetTextColor(unpack(TITLE_GOLD))
	b.text:SetText(text)
	b:SetScript("OnEnter", function(self) self.band:SetGlow(true) end)
	b:SetScript("OnLeave", function(self) self.band:SetGlow(false) end)
	b:SetScript("OnClick", function(self) fn(self) end)
	function b:SetLabel(t) self.text:SetText(t) end
	page.y = page.y - 36
	return b
end

------------------------------------------------------------------------
-- Zugriff auf Einstellungen
------------------------------------------------------------------------
local function ModuleGet(name) return function() return F.db.modules[name] end end
local function ModuleSet(name)
	return function(v)
		if InCombatLockdown() then F.Print("Im Kampf nicht moeglich.") return end
		F.db.modules[name] = v
		local m = F.modules[name]
		if m and m.SetEnabled then m:SetEnabled(v) end
	end
end
-- Wert durchschalten (Klick = naechster Eintrag); values = { { key = ..., name = ... }, ... }
local function Cycle(page, label, get, set, values, onSet)
	local b
	local function nameOf()
		for _, v in ipairs(values) do if v.key == get() then return v.name end end
		return values[1].name
	end
	b = Button(page, label .. ": " .. nameOf(), function()
		local cur = 1
		for i, v in ipairs(values) do if v.key == get() then cur = i end end
		local nxt = values[cur % #values + 1]
		set(nxt.key)
		b:SetLabel(label .. ": " .. nameOf())
		if onSet then onSet(nxt.key) end
	end, 300)
	function b:Refresh() self:SetLabel(label .. ": " .. nameOf()) end
	widgets[#widgets + 1] = b
	return b
end

-- Ton waehlen (Klick schaltet durch und spielt den Ton zur Probe)
local function SoundCycle(page, label, optKey)
	local A = F.modules.alerts
	return Cycle(page, label, function() return F.db.alerts[optKey] end, function(v) F.db.alerts[optKey] = v end,
		A.SOUNDS, function(key) A.PlaySound(key) end)
end

local function Opt(tbl, key)
	return function() return F.db[tbl][key] end, function(v) F.db[tbl][key] = v end
end

------------------------------------------------------------------------
-- Seiten
------------------------------------------------------------------------
local PAGES = {
	{ "Allgemein", function(p)
		Header(p, "Rolle")
		Checkbox(p, "Tank-Modus (Threat-Farben und Warnungen fuer Tanks)", function() return F.db.tank end, function(v) F.db.tank = v end)
		Header(p, "Darstellung")
		Slider(p, "Gesamtgroesse aller Elemente", 50, 150, 5,
			function() return math.floor((F.db.scale or 1) * 100 + 0.5) end,
			function(v) F.db.scale = v / 100; F.ApplyScale() end, function(v) return v .. " %" end)
		local function styleName() return (F.RIM[F.db.frameStyle] or F.RIM.bronze).name end
		local styleBtn
		styleBtn = Button(p, "Rahmenfarbe: " .. styleName(), function(b)
			local cur = 1
			for i, k in ipairs(F.RIM_ORDER) do if k == F.db.frameStyle then cur = i end end
			F.db.frameStyle = F.RIM_ORDER[cur % #F.RIM_ORDER + 1]
			b:SetLabel("Rahmenfarbe: " .. styleName())
			F.ApplyFrameStyle()
		end)
		Header(p, "Frames anordnen")
		local lock
		lock = Button(p, "Frames entsperren", function(b)
			F:SetLocked(F.unlocked)
			b:SetLabel(F.unlocked and "Frames sperren" or "Frames entsperren")
		end)
		Checkbox(p, "Raster beim Verschieben (Alt = frei)", function() return F.db.grid.enabled end,
			function(v) F.db.grid.enabled = v; F:UpdateGrid() end)
		Slider(p, "Rasterweite", 8, 60, 2, function() return F.db.grid.size end,
			function(v) F.db.grid.size = v; F:UpdateGrid() end, function(v) return v .. " px" end)
		Button(p, "Positionen zuruecksetzen", function() F:ResetPositions() end)
		Header(p, "Vorschau")
		Button(p, "Testmodus (20 Sekunden)", function() SlashCmdList["FRAY"]("test") end)
		Header(p, "Daten")
		Button(p, "Alle Einstellungen zuruecksetzen", function(b)
			if not b.armed then
				b.armed = true
				b:SetLabel("Wirklich? Nochmal klicken")
				if C_Timer and C_Timer.After then
					C_Timer.After(4, function() b.armed = false; b:SetLabel("Alle Einstellungen zuruecksetzen") end)
				end
			else
				F.ResetAll()
			end
		end, 260)
	end },
	{ "Gegnerliste", function(p)
		Header(p, "Anzeige")
		Checkbox(p, "Gegnerliste anzeigen", ModuleGet("enemy"), ModuleSet("enemy"))
		Checkbox(p, "Alle feindlichen Gegner zeigen (auch ohne Kampf)", function() return F.db.enemy.showAll end,
			function(v) F.db.enemy.showAll = v end)
		ScaleSlider(p, "Groesse der Gegnerliste", "enemy")
		Slider(p, "Gegner pro Spalte", 3, 9, 1, function() return F.db.enemy.perCol end,
			function(v)
				F.db.enemy.perCol = v
				local m = F.modules.enemy
				if m and m.ApplyLayout then m:ApplyLayout() end
			end)
		Slider(p, "Maximale Anzahl Gegner", 3, 18, 1, function() return F.db.enemy.maxRows end,
			function(v) F.db.enemy.maxRows = v end)
		Cycle(p, "Sortierung", function() return F.db.enemy.sort end, function(v) F.db.enemy.sort = v end,
			{ { key = "threat", name = "nach Threat" }, { key = "name", name = "nach Name" } })
		Header(p, "Angezeigte Elemente")
		local g, s
		g, s = Opt("enemy", "showPercent"); Checkbox(p, "Lebensprozent", g, s)
		g, s = Opt("enemy", "showPower"); Checkbox(p, "Ressourcen-Balken (Mana, Wut, Energie)", g, s)
		g, s = Opt("enemy", "showMarker"); Checkbox(p, "Raidmarker", g, s)
		g, s = Opt("enemy", "showElite"); Checkbox(p, "Elite-/Selten-Symbole", g, s)
		g, s = Opt("enemy", "showShield"); Checkbox(p, "Aggro-Schild", g, s)
		Header(p, "Aggro-Symbol")
		Slider(p, "Orange ab Threat", 20, 90, 5, function() return F.db.enemy.threatOrange end,
			function(v) F.db.enemy.threatOrange = v end, function(v) return v .. " %" end)
		Hint(p, "Rot: Du hast die Aggro.   Orange: hoher Threat oder Aggro gerade verloren.   Gruen: kaum Threat.", 34)
	end },
	{ "Zauberleiste", function(p)
		Header(p, "Zauberleisten fuer Ziel und Fokus")
		Checkbox(p, "Zauberleisten anzeigen", ModuleGet("cast"), ModuleSet("cast"))
		ScaleSlider(p, "Groesse der Ziel-Zauberleiste", "castTarget")
		ScaleSlider(p, "Groesse der Fokus-Zauberleiste", "castFocus")
		local g, s = Opt("cast", "onlyHostile")
		Checkbox(p, "Nur fuer Gegner", g, s)
		Header(p, "Anzeige")
		g, s = Opt("cast", "target"); Checkbox(p, "Zauberleiste fuer das Ziel", g, s)
		g, s = Opt("cast", "focus"); Checkbox(p, "Zauberleiste fuer den Fokus", g, s)
		g, s = Opt("cast", "showIcon"); Checkbox(p, "Zaubersymbol", g, s)
		g, s = Opt("cast", "showTime"); Checkbox(p, "Restzeit", g, s)
	end },
	{ "Warnungen", function(p)
		local g, s
		local function AlertTest(title, sub, kind, snd, ...)
			local A = F.modules.alerts
			if A and A.Alert then A:Alert(title, sub, kind, snd, ...) end
		end
		Header(p, "Meldungen")
		Checkbox(p, "Warnungen anzeigen", ModuleGet("alerts"), ModuleSet("alerts"))
		g, s = Opt("alerts", "sound"); Checkbox(p, "Warntoene (Hauptschalter)", g, s)
		Header(p, "Wann soll gewarnt werden?")
		g, s = Opt("alerts", "gain"); Checkbox(p, "Aggro bekommen (ein Gegner greift dich an)", g, s)
		g, s = Opt("alerts", "gainTank"); Checkbox(p, "... auch im Tank-Modus", g, s)
		SoundCycle(p, "Ton: Aggro bekommen", "soundGain")
		g, s = Opt("alerts", "loss"); Checkbox(p, "Aggro verloren (ein Gegner wechselt das Ziel)", g, s)
		SoundCycle(p, "Ton: Aggro verloren", "soundLoss")
		g, s = Opt("alerts", "tankWarn"); Checkbox(p, "Tank: Gegner greift einen Mitspieler an", g, s)
		g, s = Opt("alerts", "threatHigh"); Checkbox(p, "Threat hoch (nur wo Threat lesbar ist)", g, s)
		Slider(p, "Ab Threat", 60, 100, 5, function() return F.db.alerts.threatPct end,
			function(v) F.db.alerts.threatPct = v end, function(v) return v .. " %" end)
		SoundCycle(p, "Ton: Threat hoch", "soundThreat")
		g, s = Opt("alerts", "lowHealth"); Checkbox(p, "Niedrige HP (nur wo HP lesbar sind)", g, s)
		Slider(p, "HP-Schwelle", 10, 60, 5, function() return F.db.alerts.lowHealthPct end,
			function(v) F.db.alerts.lowHealthPct = v end, function(v) return v .. " %" end)
		SoundCycle(p, "Ton: Niedrige HP", "soundLow")
		Header(p, "Bedingungen")
		g, s = Opt("alerts", "onlyInGroup"); Checkbox(p, "Nur in einer Gruppe", g, s)
		g, s = Opt("alerts", "onlyInCombat"); Checkbox(p, "Nur im Kampf", g, s)
		Slider(p, "Pause pro Gegner", 2, 30, 1, function() return F.db.alerts.pause end,
			function(v) F.db.alerts.pause = v end, function(v) return v .. " s" end)
		Header(p, "Darstellung")
		Slider(p, "Anzeigedauer", 1, 8, 0.5, function() return F.db.alerts.hold end,
			function(v) F.db.alerts.hold = v end, function(v) return string.format("%.1f s", v) end)
		Slider(p, "Schriftgroesse", 16, 40, 2, function() return F.db.alerts.textSize end,
			function(v) F.db.alerts.textSize = v end, function(v) return v .. " px" end)
		ScaleSlider(p, "Groesse der Warnungen", "alert")
		g, s = Opt("alerts", "showName"); Checkbox(p, "Gegnernamen zeigen", g, s)
		Header(p, "Testen")
		Button(p, "Aggro bekommen", function() AlertTest("Aggro!", "%s", "red", "soundGain", "Testgegner") end, 260)
		Button(p, "Aggro verloren", function() AlertTest("Aggro verloren", "%s  >  %s", "orange", "soundLoss", "Testgegner", "Mitspieler") end, 260)
		Button(p, "Threat hoch", function() AlertTest("Threat hoch", "%s  (%d%%)", "orange", "soundThreat", "Testgegner", 95) end, 260)
		Hint(p, "Aggro- und Threat-Meldungen nutzen den Threat des Clients; wo er gesperrt ist (Plaketten im Kampf), gilt nur 'Gegner zielt auf dich'.", 34)
	end },
	{ "Kampftext", function(p)
		Header(p, "Schwebende Zahlen")
		if F.modules.float and F.modules.float.unavailable then
			Hint(p, "Auf diesem Client gibt es kein Kampflog fuer Addons, deshalb ist der Kampftext nicht verfuegbar.", 40)
			return
		end
		Checkbox(p, "Kampftext anzeigen", ModuleGet("float"), ModuleSet("float"))
		ScaleSlider(p, "Groesse des Kampftexts", "float")
		Slider(p, "Mindestschaden", 0, 1000, 10, function() return F.db.float.minAmount end,
			function(v) F.db.float.minAmount = v end)
	end },
	{ "Cooldowns", function(p)
		Header(p, "Cooldown-Leiste")
		Checkbox(p, "Cooldown-Leiste anzeigen", ModuleGet("cooldowns"), ModuleSet("cooldowns"))
		ScaleSlider(p, "Groesse der Cooldown-Leiste", "cooldowns")
		local g, s = Opt("cooldowns", "alwaysShow")
		Checkbox(p, "Symbole auch ohne Cooldown zeigen", g, s)
		g, s = Opt("cooldowns", "showTimer"); Checkbox(p, "Restzeit als Zahl", g, s)
		Slider(p, "Symbolgroesse", 24, 64, 2, function() return F.db.cooldowns.size end,
			function(v)
				F.db.cooldowns.size = v
				local m = F.modules.cooldowns
				if m and m.Rebuild then m:Rebuild() end
			end, function(v) return v .. " px" end)
		Hint(p, "Zauber hinzufuegen: /fray cd add <Zauber, ID, slot:13 oder item:ID>.  Entfernen: /fray cd remove <Name oder Nummer>.  Liste: /fray cd list.", 48)
	end },
	{ "Komfort", function(p)
		Header(p, "Haendler")
		Checkbox(p, "Komfortfunktionen aktiv", ModuleGet("qol"), ModuleSet("qol"))
		local g, s = Opt("qol", "autoSell")
		Checkbox(p, "Graue Gegenstaende automatisch verkaufen", g, s)
		g, s = Opt("qol", "autoRepair")
		Checkbox(p, "Automatisch reparieren", g, s)
	end },
}

local function SelectTab(index)
	for i, t in ipairs(tabs) do
		local on = i == index
		t.band:SetGlow(on)
		t.text:SetTextColor(on and 1 or 0.85, on and 0.9 or 0.82, on and 0.6 or 0.74)
		pages[i]:SetShown(on)
	end
	M.current = index
end

function M:Refresh()
	for _, w in ipairs(widgets) do w:Refresh() end
end

function M:Toggle()
	if not panel then return end
	if panel:IsShown() then
		panel:Hide()
	else
		M:Refresh()
		panel:Show()
	end
end

function M:Init()
	panel = CreateFrame("Frame", "FrayOptions", UIParent)
	panel:SetSize(PW, PH)
	panel:SetPoint("CENTER", 0, 20)
	panel:SetFrameStrata("DIALOG")
	panel:SetClampedToScreen(true)
	panel:SetMovable(true)
	panel:EnableMouse(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
	panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	panel.dialogHeader = F.DialogFrame(panel, "Fray")
	panel.atlasFrame = panel.dialogHeader or F.AtlasFrame(panel, { 0.07, 0.06, 0.05, 0.97 }, 7)
	if not panel.atlasFrame then NineSlice(panel, "Panel.tga", 14) end
	panel:Hide()
	if UISpecialFrames then table.insert(UISpecialFrames, "FrayOptions") end

	local title = F.CreateText(panel, 18, "LEFT")
	title:SetPoint("TOPLEFT", PAD, -18)
	title:SetFont(F.FONT_TITLE, 20, "")
	title:SetTextColor(unpack(TITLE_GOLD))
	title:SetText("Fray")
	local sub = F.CreateText(panel, 11, "LEFT")
	sub:SetPoint("LEFT", title, "RIGHT", 10, -2)
	sub:SetTextColor(unpack(DIM))
	sub:SetText("Version " .. F.version)
	if panel.dialogHeader then
		-- der Titel steht in der Plakette; die Version sitzt links oben
		title:Hide()
		sub:ClearAllPoints()
		sub:SetPoint("TOPLEFT", PAD, -22)
	end

	local close = CreateFrame("Button", nil, panel)
	close:SetSize(26, 26)
	close:SetPoint("TOPRIGHT", -12, -12)
	close.tex = close:CreateTexture(nil, "ARTWORK")
	close.tex:SetTexture(F.TEXROOT .. "Close-X.tga")
	close.tex:SetAllPoints()
	if F.AtlasName("closeBtn") then close.tex:SetAtlas(F.AtlasName("closeBtn"), false) end
	close:SetScript("OnClick", function() panel:Hide() end)
	close:SetScript("OnEnter", function(self) self.tex:SetVertexColor(1, 0.55, 0.45) end)
	close:SetScript("OnLeave", function(self) self.tex:SetVertexColor(1, 1, 1) end)

	-- Trennlinie unter dem Titel und zwischen Reitern und Inhalt
	local hline = panel:CreateTexture(nil, "ARTWORK")
	hline:SetTexture(F.WHITE)
	hline:SetVertexColor(0.66, 0.52, 0.36, 0.4)
	hline:SetPoint("TOPLEFT", PAD, -52)
	hline:SetPoint("TOPRIGHT", -PAD, -52)
	hline:SetHeight(1)
	local vline = panel:CreateTexture(nil, "ARTWORK")
	vline:SetTexture(F.WHITE)
	vline:SetVertexColor(0.66, 0.52, 0.36, 0.25)
	vline:SetPoint("TOPLEFT", PAD + TABW, -62)
	vline:SetPoint("BOTTOMLEFT", PAD + TABW, PAD)
	vline:SetWidth(1)

	for i, def in ipairs(PAGES) do
		local tab = CreateFrame("Button", nil, panel)
		tab:SetSize(TABW - 12, 30)
		tab:SetPoint("TOPLEFT", PAD, -64 - (i - 1) * 34)
		tab.band = F.CreateBand(tab, 0, 1, TABW - 12, 28)
		tab.text = F.CreateText(tab, 12, "LEFT")
		tab.text:SetPoint("LEFT", 14, 0)
		tab.text:SetText(def[1])
		tab:SetScript("OnClick", function() SelectTab(i) end)
		tab:SetScript("OnEnter", function(self) self.band:SetGlow(true) end)
		tab:SetScript("OnLeave", function(self) if M.current ~= i then self.band:SetGlow(false) end end)
		tabs[i] = tab

		-- Seite in einem Scrollbereich (Mausrad), falls der Inhalt nicht passt
		local scroll = CreateFrame("ScrollFrame", nil, panel)
		-- Der Scrollbereich ist ringsum 24 px groesser als der Inhalt, damit der Leucht-Halo der Buttons nicht abgeschnitten wird
		scroll:SetPoint("TOPLEFT", PAD + TABW + 20 - 24, -68 + 24)
		scroll:SetPoint("BOTTOMRIGHT", -PAD + 20, PAD - 20)
		local holder = CreateFrame("Frame", nil, scroll)
		holder:SetSize(PW - TABW - PAD * 3 + 4 + 48, 10)
		scroll:SetScrollChild(holder)
		local page = CreateFrame("Frame", nil, holder)
		page:SetPoint("TOPLEFT", holder, "TOPLEFT", 24, -24)
		page:SetSize(PW - TABW - PAD * 3 + 4, 10)
		page.y, page.first = 0, true
		scroll:Hide()
		def[2](page)
		local need = -page.y + 8 + 48
		holder:SetHeight(need)
		page:SetHeight(-page.y + 8)
		scroll:EnableMouseWheel(true)
		scroll:SetScript("OnMouseWheel", function(self, delta)
			local max = math.max(0, need - self:GetHeight())
			self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - delta * 40)))
		end)
		pages[i] = scroll
	end
	SelectTab(1)
end
