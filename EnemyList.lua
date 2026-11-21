local ADDON, F = ...
local M = {}
F:RegisterModule("enemy", M)

-- Gegnerliste: Original-Dragonflight-Rahmen (Ring links, Band rechts, aus dem Atlas uiunitframe.blp)
-- mit Aggro-Schild, Elite-Symbolen, Ressourcen- und Zauberstreifen.
-- Die Zeilen sind normale (nicht gesicherte) Frames: Sie werden im Kampf live nach Threat sortiert und
-- ruecken lueckenlos zusammen. Klicken zum Zielwechsel gibt es bewusst nicht: Gesicherter Code kennt
-- Plaketten-Einheiten nicht und laesst sich im Kampf nicht umstellen (auch andere Addons loesen das nicht).
local TOKENS = 12             -- nameplate1..12 haben je eine feste Klickflaeche
local EXTRA = 6               -- Zusatzplaetze fuer Gegner ohne Plakette (nicht klickbar)
local MAX_ROWS = TOKENS + EXTRA
local COLGAP = 8
local function PerCol() return F.db.enemy.perCol or 6 end   -- danach beginnt eine weitere Spalte
local ROW_W, GAP = 232, 6
local ROW_H = 62
local PITCH = ROW_H + GAP

-- Blizzard-Zielrahmen-Zeilen : gibt der Client die Ziel-Frame-Atlanten her, besteht jede Zeile aus
-- Blizzards eigenem Rahmen, Balken und Masken (verkleinert um S). Sonst bleibt die eigene Optik unten.
local BLIZZ = F.AtlasName("tFrame") ~= nil and F.AtlasName("tType") ~= nil and F.AtlasName("tHealth") ~= nil
local S = 0.85
local MIRROR = true   -- Portrait links (Blizzards Rahmen werden waagerecht gespiegelt)
local YOFF = 0
if BLIZZ then
	ROW_W, ROW_H, GAP = 232 * S, 100 * S, 2
	PITCH = 72
	YOFF = 12 * S   -- Rahmenkunst beginnt erst etwa 12 px unter dem Frame-Rand
end
-- Geometrie: links das Wappenschild (mit Abzeichen), rechts EINE abgerundete Platte. Die Balken fuellen
-- sie buendig aus (Plattenrand 2.5 px) und laufen links unter das Schild, damit dort keine Rundung zu sehen ist.
local ORB = 72
local ORB_CX, ORB_CY = 33, -31
local PLATE_X, PLATE_Y, PLATE_H = 30, 13, 36
local BAR_X = 32                -- Beginn der Balken (liegt unter dem Schild)
local EDGE = 4                  -- Dicke des Plattenrahmens (schwarz, hell, schwarz)
local HP_H, CAST_H = 20, 7
local FULL_H = HP_H + 1 + CAST_H   -- Lebensbalken ohne zweiten Balken fuellt die ganze Platte
local BARTEX = { split = "BarTop.tga", full = "BarFull.tga" }
local LEFT = 68                 -- Text beginnt rechts vom Schild
local PADX = 8                  -- Textabstand zum rechten Rand

local rows = {}

-- Status = Aggro-Lage gegenueber DIR: rot = du hast die Aggro, orange = Aggro verloren / hoher Threat,
-- gruen = kaum Threat. (Wappenschild-Symbole)
local STATUS_TEX = {
	red = "Shield-Red.tga",
	orange = "Shield-Orange.tga",
	yellow = "Shield-Orange.tga",
	green = "Shield-Green.tga",
}
local hadAggro = {}     -- guid -> Zeitpunkt, zu dem der Gegner zuletzt auf dir war
local LOST_SECS = 15     -- nach Aggroverlust bleibt der Gegner so lange orange (solange noch etwas Threat da ist)

-- known = Threat-Werte lesbar. Sonst (Forever, Plaketten im Kampf) zaehlt nur: zielt der Gegner auf dich?
-- Rot = ja; Orange = er war in den letzten LOST_SECS auf dir (Aggro verloren); sonst Gruen.
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

local STATUS_RGB = {
	red = { 0.92, 0.2, 0.17 }, orange = { 0.96, 0.56, 0.12 }, yellow = { 0.96, 0.56, 0.12 }, green = { 0.28, 0.78, 0.32 },
}

local function AtlasInfoOf(key)
	local name = F.AtlasName(key)
	if not name then return nil end
	local ok, info = pcall(C_Texture.GetAtlasInfo, name)
	if ok and info then return name, info.width or 0, info.height or 0 end
end

-- Spiegelung: Ausschnitt des Atlas links/rechts vertauschen
local function Flip(tex, name)
	if not MIRROR then return end
	-- bei Atlas-Texturen gelten die Koordinaten relativ zum Atlas-Ausschnitt: (1,0,0,1) = waagerecht gespiegelt
	tex:SetTexCoord(1, 0, 0, 1)
end

local function NewAtlasTex(parent, layer, sub, key, scale)
	local name, w, h = AtlasInfoOf(key)
	if not name then return nil end
	local t = parent:CreateTexture(nil, layer, nil, sub or 0)
	t:SetAtlas(name, false)
	Flip(t, name)
	t:SetSize(w * S * (scale or 1), h * S * (scale or 1))
	return t
end

local function SetAtlasKey(tex, key, scale)
	local name, w, h = AtlasInfoOf(key)
	if not name or not tex then return false end
	tex:SetAtlas(name, false)
	Flip(tex, name)
	tex:SetSize(w * S * (scale or 1), h * S * (scale or 1))
	return true
end

local POWER_KEY = { MANA = "tMana", RAGE = "tRage", ENERGY = "tEnergy", FOCUS = "tFocus", RUNIC_POWER = "tRunic" }

-- Statusbar mit Atlas-Fuellung; Maske rundet die Enden wie bei Blizzard
local function AtlasStatusBar(row, level, w, h)
	local bar = CreateFrame("StatusBar", nil, row)
	bar:SetFrameLevel(level)
	bar:SetSize(w * S, h * S)
	bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	return bar
end

local function SetBarAtlas(bar, key)
	local name = F.AtlasName(key)
	local t = bar:GetStatusBarTexture()
	if name and t then pcall(t.SetAtlas, t, name, false) end
end

local function BlizzMask(row, bar, key, dx, dy)
	-- Gespiegelt kann Blizzards Maske nicht benutzt werden (sie verdeckte den ganzen Balken). Stattdessen eine eigene
	-- Maske aus BarFull.tga: links gerade, rechts abgerundet - passend zu den Rinnen des gespiegelten Rahmens.
	if MIRROR then
		if not bar.mask then
			bar.mask = row:CreateMaskTexture()
			bar.mask:SetTexture(F.TEXROOT .. "BarFull.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			local t = bar:GetStatusBarTexture()
			if t then t:AddMaskTexture(bar.mask) end
		end
		bar.mask:ClearAllPoints()
		bar.mask:SetAllPoints(bar)
		return
	end
	local name, w, h = AtlasInfoOf(key)
	if not name or not row.CreateMaskTexture then return end
	if not bar.mask then
		bar.mask = row:CreateMaskTexture()
		local t = bar:GetStatusBarTexture()
		if t then t:AddMaskTexture(bar.mask) end
	end
	bar.mask:SetAtlas(name, false)
	Flip(bar.mask, name)
	bar.mask:SetSize(w * S, h * S)
	bar.mask:ClearAllPoints()
	if MIRROR then
		bar.mask:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -dx * S, dy * S)
	else
		bar.mask:SetPoint("TOPLEFT", bar, "TOPLEFT", dx * S, dy * S)
	end
end

local function CreateRowBlizz(index)
	local row = CreateFrame("Button", "FrayEnemyRow" .. index, M.frame)
	row.blizz = true
	row:SetSize(ROW_W, ROW_H)
	row:SetPoint("TOPLEFT", M.frame, "TOPLEFT", 0, -(index - 1) * PITCH)
	function row:SetBorderColor() end
	local lvl = row:GetFrameLevel() + 1

	-- Portrait hinter dem Rahmen, rund maskiert
	row.portrait = row:CreateTexture(nil, "BACKGROUND", nil, 1)
	row.portrait:SetSize(58 * S, 58 * S)
	row.portrait:SetPoint("TOPLEFT", row, "TOPLEFT", 26 * S, -19 * S)
	row.portrait:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	if row.CreateMaskTexture then
		local m = row:CreateMaskTexture()
		m:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		m:SetPoint("TOPLEFT", row.portrait, "TOPLEFT", 0, -1 * S)
		m:SetPoint("BOTTOMRIGHT", row.portrait, "BOTTOMRIGHT", -1 * S, 0)
		row.portrait:AddMaskTexture(m)
	end

	-- Rahmen, Kampf-Leuchten (Status), Auswahl-Leuchten, Typ-Leiste
	row.frameTex = NewAtlasTex(row, "BACKGROUND", 2, "tFrame")
	row.frameTex:SetPoint("CENTER", row, "CENTER", 0, 0)
	-- gleichmaessig dunkle Rinnen in jeder Zeile (sonst scheint die Umgebung unterschiedlich durch die Rinnen)
	row.backFill = row:CreateTexture(nil, "BACKGROUND", nil, 1)
	row.backFill:SetColorTexture(0.07, 0.05, 0.035, 1)
	row.backFill:SetSize(127 * S, 47 * S)
	row.backFill:SetPoint("TOPLEFT", row, "TOPLEFT", 83 * S, -24.6 * S)
	-- Auswahl: Blizzards rotes Kampf-Leuchten (Frame + Portraitring), in Gold. Die rote Textur wird entsaettigt und
	-- eingefaerbt; drei Lagen uebereinander ersetzen die verlorene Helligkeit.
	row.glows = {}
	for i = 1, 3 do
		local t = NewAtlasTex(row, "ARTWORK", 1 + i, "tFlash")
		if t then
			t:SetPoint("CENTER", row, "CENTER", 0, 2 * S)
			t:SetDesaturated(true)
			t:SetVertexColor(1, 0.8, 0.18)
			t:Hide()
			row.glows[#row.glows + 1] = t
		end
	end
	row.selGlow = row.glows[1]
	row.type = NewAtlasTex(row, "ARTWORK", 0, "tType")
	if row.type then
		row.type:SetPoint("TOPLEFT", row, "TOPLEFT", 82.1 * S, -25 * S)   -- Fuellung beginnt bei der Rinne (84.1)
		row.type:SetWidth(row.type:GetWidth() * 1.015)
	end

	-- Verzierungen (Elite, Boss, selten)
	row.deco = NewAtlasTex(row, "ARTWORK", 3, "tElite", 0.85) or row:CreateTexture(nil, "ARTWORK", nil, 3)
	row.deco:SetPoint("TOPLEFT", row, "TOPLEFT", 11 * S, -8 * S)
	row.deco:Hide()

	-- Balken
	row.hp = AtlasStatusBar(row, lvl, 123.0, 19.5)
	row.hp:SetPoint("TOPLEFT", row, "TOPLEFT", 85.9 * S, -41.5 * S)
	SetBarAtlas(row.hp, "tHealth")
	BlizzMask(row, row.hp, "tHealthMask", -1, 6)
	-- Der Atlas-Balken hat ca. 6 % durchsichtigen Rand: Rahmen etwas groesser, damit die sichtbare Flaeche genau in
	-- die untere Rinne passt (Rinne: x 83..209, y 59..69.6).
	row.power = AtlasStatusBar(row, lvl, 134, 11.5)
	row.power:SetPoint("TOPLEFT", row, "TOPLEFT", 80.5 * S, -59.9 * S)
	row.power.mask = row:CreateMaskTexture()
	row.power.mask:SetTexture(F.TEXROOT .. "BarFull.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	row.power.mask:SetPoint("TOPLEFT", row, "TOPLEFT", 86 * S, -59.9 * S)
	row.power.mask:SetPoint("BOTTOMRIGHT", row, "TOPLEFT", 208.9 * S, -69.4 * S)
	do
		local t = row.power:GetStatusBarTexture()
		if t then t:AddMaskTexture(row.power.mask) end
	end
	SetBarAtlas(row.power, "tMana")
	row.power:Hide()
	-- Castbar: eigener Streifen UNTER dem Frame (Ressource bleibt in der unteren Rinne des Frames)
	row.cast = AtlasStatusBar(row, lvl, 126, 9)
	row.cast:SetPoint("TOPLEFT", row, "TOPLEFT", 83 * S, -76.5 * S)
	if F.AtlasName("castFill") then SetBarAtlas(row.cast, "castFill") else row.cast:SetStatusBarColor(0.98, 0.74, 0.36) end
	row.cast.back = row.cast:CreateTexture(nil, "BACKGROUND")
	row.cast.back:SetAllPoints()
	row.cast.back:SetTexture("Interface\\Buttons\\WHITE8X8")
	row.cast.back:SetVertexColor(0.04, 0.03, 0.02, 0.8)
	local castEdge = F.CreateBorder(row.cast, 1, "OVERLAY")
	castEdge:SetColor(0.45, 0.36, 0.22, 1)
	row.cast.text = F.CreateText(row.cast, 10, "CENTER", "OVERLAY")
	row.cast.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
	row.cast.text:SetPoint("CENTER", row.cast, "CENTER", 0, 0)
	row.cast.text:SetTextColor(1, 0.92, 0.7)
	row.castText = row.cast.text
	-- Blizzards Zauberleisten-Rahmen um den Streifen (drei Teile aus UI-CastingBar-Frame), sichtbar mit dem Streifen
	row.castFrame = CreateFrame("Frame", nil, row)
	row.castFrame:SetAllPoints(row)
	row.castFrame:SetFrameLevel(row.cast:GetFrameLevel() + 3)
	local cfr = F.AtlasThreeSlice(row.castFrame, "castFrame", "OVERLAY", 1, 14)
	if cfr then
		F.PlaceThreeSlice(cfr, row.castFrame, 80 * S, 73.5 * S, 132 * S, 15 * S)
		castEdge:SetColor(0, 0, 0, 0)
		local backName = F.AtlasName("castBack")
		if backName then
			row.cast.back:SetAtlas(backName, false)
			row.cast.back:SetVertexColor(1, 1, 1, 1)
		end
	end
	row.castFrame:Hide()
	row.cast:SetScript("OnShow", function() row.castFrame:Show() end)
	row.cast:SetScript("OnHide", function() row.castFrame:Hide() end)
	row.cast:Hide()

	-- Texte, Raidmarker, Buchstaben-Abzeichen
	row.over = CreateFrame("Frame", nil, row)
	row.over:SetAllPoints()
	row.over:SetFrameLevel(lvl + 5)
	row.name = F.CreateText(row.over, 11, "CENTER")
	row.name:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
	row.name:SetPoint("TOP", row, "TOPLEFT", 147 * S, -26 * S)
	row.name:SetSize(118 * S, 13)
	row.info = F.CreateText(row.over, 11, "RIGHT")
	row.info:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
	row.info:SetPoint("RIGHT", row.hp, "RIGHT", -5 * S, 0)
	row.info:SetSize(110 * S, 12)
	row.mark = row.over:CreateTexture(nil, "OVERLAY", nil, 3)
	row.mark:SetSize(26 * S, 26 * S)
	row.mark:SetPoint("CENTER", row, "TOPLEFT", 147 * S, -10.5 * S)   -- mittig ueber dem Namen
	row.mark:SetTexture("Interface/TargetingFrame/UI-RaidTargetingIcons")
	row.mark:Hide()
	row.star = NewAtlasTex(row.over, "OVERLAY", 1, "tStar")
	if row.star then row.star:SetPoint("CENTER", row.portrait, "BOTTOM", 0, 0); row.star:Hide() end
	-- kleines Drachen-Symbol (Elite) oben rechts am Portraitring, statt der grossen Drachen-Verzierung
	row.dragon = row.over:CreateTexture(nil, "OVERLAY", nil, 2)
	row.dragon:SetSize(30 * S, 30 * S)
	row.dragon:SetPoint("CENTER", row.portrait, "TOPLEFT", -2 * S, -2.5 * S)   -- gleiche Spalte wie das Schild   -- auf dem Portraitring, oben links
	row.dragon:Hide()

	-- Aggro-Symbol (frei stehend, unten links am Portrait): unser Wappenschild, komplett in der Statusfarbe
	-- (Shield-Red/Orange/Green.tga, dazu Metallrahmen). Rot pulsiert (Aggro auf dir), Orange leuchtet ruhig
	-- (verloren), Gruen ist gedaempft (sicher).
	row.badge = CreateFrame("Frame", nil, row)
	row.badge:SetSize(46 * S, 46 * S)
	row.badge:SetPoint("CENTER", row.portrait, "BOTTOMLEFT", -2 * S, 4 * S)
	row.badge:SetFrameLevel(lvl + 7)
	row.badge.glow = row.badge:CreateTexture(nil, "BACKGROUND", nil, 0)
	row.badge.glow:SetPoint("CENTER")
	row.badge.glow:SetSize(62 * S, 62 * S)
	row.badge.glow:SetTexture(F.TEXROOT .. "Shield-Red.tga")
	row.badge.glow:SetBlendMode("ADD")
	row.badge.glow:Hide()
	row.badge.fill = row.badge:CreateTexture(nil, "ARTWORK", nil, 1)
	row.badge.fill:SetAllPoints()
	row.badge.fill:SetTexture(F.TEXROOT .. "Shield-Red.tga")
	row.badge.frame = row.badge:CreateTexture(nil, "ARTWORK", nil, 2)
	row.badge.frame:SetAllPoints()
	row.badge.frame:SetTexture(F.TEXROOT .. "Shield-Frame.tga")
	F.TintRim(row.badge.frame)
	if row.badge.glow.CreateAnimationGroup then
		local ag = row.badge.glow:CreateAnimationGroup()
		ag:SetLooping("BOUNCE")
		local an = ag:CreateAnimation("Alpha")
		an:SetFromAlpha(0.2)
		an:SetToAlpha(0.9)
		an:SetDuration(0.5)
		row.badge.pulse = ag
	end
	row.letter = F.CreateText(row.badge, 11, "CENTER")   -- nur noch Platzhalter fuer gemeinsamen Code
	row.letter:Hide()

	row:Hide()
	return row
end

-- normal = Lebensbalken + Streifen (Ressource/Cast); minus = nur Lebensbalken (Blizzards Minus-Mob-Rahmen)
local function BlizzLayout(row, mode)
	if mode == "minus" and not AtlasInfoOf("mFrame") then mode = "normal" end
	if row.mode == mode then return end
	row.mode = mode
	if mode == "minus" then
		SetAtlasKey(row.frameTex, "mFrame")
		SetAtlasKey(row.flash, "mFlash")
		SetAtlasKey(row.selGlow, "mFlash")
		row.hp:SetSize(125 * S, 12 * S)
		row.hp:ClearAllPoints()
		row.hp:SetPoint("TOPLEFT", row, "TOPLEFT", 84 * S, -39 * S)
		SetBarAtlas(row.hp, F.AtlasName("mHealth") and "mHealth" or "tHealth")
		BlizzMask(row, row.hp, F.AtlasName("mHealthMask") and "mHealthMask" or "tHealthMask", -1, 2)
	else
		SetAtlasKey(row.frameTex, row.rare and F.AtlasName("tRareFrame") and "tRareFrame" or "tFrame")
		SetAtlasKey(row.flash, "tFlash")
		SetAtlasKey(row.selGlow, "tFlash")
		row.hp:SetSize(123.0 * S, 19.5 * S)
		row.hp:ClearAllPoints()
		row.hp:SetPoint("TOPLEFT", row, "TOPLEFT", 85.9 * S, -41.5 * S)
		SetBarAtlas(row.hp, "tHealth")
		BlizzMask(row, row.hp, "tHealthMask", -1, 6)
	end
end

-- Drachen-Symbol: Atlas der Namensplaketten, sonst die Standard-Grafik des Clients (Silber = entsaettigt)
local function SetDragon(row, kind)
	if not row.dragon then return end
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

-- Klassifizierung -> Verzierung (Elite-Gold, Boss geflügelt, selten silber + Stern)
local function BlizzClass(row, unit)
	local okc, cls = pcall(UnitClassification, unit)
	if not (okc and F.Readable(cls)) then cls = nil end
	local okb, boss = pcall(UnitIsBossMob, unit)
	boss = okb and F.Bool(boss)
	local deco, rare = nil, false
	if boss then deco = "tBoss"
	elseif cls == "rareelite" then deco, rare = "tRareDeco", true
	elseif cls == "elite" or cls == "worldboss" then deco = "tElite"
	elseif cls == "rare" then rare = true end
	if row.rare ~= rare then row.rare = rare; row.mode = nil end
	row.deco:Hide()
	local kind = (boss or cls == "elite" or cls == "worldboss") and "gold" or (cls == "rareelite" and "silver") or nil
	SetDragon(row, kind)
	if row.star then row.star:SetShown(rare) end
end

local function BlizzFill(row, unit)
	local now = GetTime()
	if not row.pt or now - row.pt > 1 then
		row.pt = now
		pcall(SetPortraitTexture, row.portrait, unit)
	end
	if row.type then
		local ok, r, g, b = pcall(UnitSelectionColor, unit)
		if ok and r and F.AllReadable(r, g, b) then row.type:SetVertexColor(r, g, b) else row.type:SetVertexColor(0.9, 0.25, 0.2) end
	end
	BlizzClass(row, unit)
end

local function BlizzStatic(row)
	row.portrait:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	row.portrait:SetTexCoord(0, 1, 0, 1)
	row.pt = nil
	if row.type then row.type:SetVertexColor(0.9, 0.25, 0.2) end
	row.deco:Hide()
	if row.dragon then row.dragon:Hide() end
	if row.star then row.star:Hide() end
	if row.rare then row.rare = false; row.mode = nil end
end

local function CreateRow(index)
	local row = CreateFrame("Button", "FrayEnemyRow" .. index, M.frame)
	row:SetSize(ROW_W, ROW_H)
	-- feste Position (die Zeilen bewegen sich nie; Zusammenruecken = erste n Zeilen zeigen)
	row:SetPoint("TOPLEFT", M.frame, "TOPLEFT", 0, -(index - 1) * PITCH)  -- endgueltige Lage: M:ApplyLayout()

	-- eine gemeinsame Platte (dunkles Braun + Bronzerahmen), wie ein Unitframe
	row.band = F.CreateBand(row, PLATE_X, PLATE_Y, ROW_W - PLATE_X, PLATE_H, 40)   -- Halo blendet links unter dem Schild ein
	function row:SetBorderColor(cr, cg, cb) self.band:SetBorderColor(cr, cg, cb) end
	local barW = ROW_W - BAR_X - EDGE   -- bis in die Rundung der Platte
	local lvl = row.band.frame:GetFrameLevel() + 1

	row.hp = F.CreateSlimBar(row, barW, HP_H, "top")
	row.hp:SetPoint("TOPLEFT", row, "TOPLEFT", BAR_X, -(PLATE_Y + EDGE))
	row.hp:SetStatusBarColor(0.82, 0.27, 0.23)
	row.hp:SetFrameLevel(lvl)

	-- feine Trennlinie zwischen den Balken
	row.divider = row.band.frame:CreateTexture(nil, "ARTWORK", nil, 2)
	row.divider:SetTexture(F.WHITE)
	row.divider:SetVertexColor(0, 0, 0, 0.8)
	row.divider:SetPoint("TOPLEFT", row, "TOPLEFT", BAR_X, -(PLATE_Y + EDGE + HP_H))
	row.divider:SetSize(barW, 1)

	row.cast = F.CreateSlimBar(row, barW, CAST_H, "bottom")
	row.cast:SetPoint("TOPLEFT", row, "TOPLEFT", BAR_X, -(PLATE_Y + EDGE + HP_H + 1))
	row.cast:SetStatusBarColor(0.98, 0.74, 0.36)
	F.AtlasBar(row.cast, "castFill", "BarBottom.tga")
	row.cast:SetFrameLevel(lvl)
	row.cast:Hide()

	-- Ressourcenbalken (Mana, Wut, Energie ...): nur wenn der Gegner einen hat
	row.power = F.CreateSlimBar(row, barW, CAST_H, "bottom")
	row.power:SetPoint("TOPLEFT", row, "TOPLEFT", BAR_X, -(PLATE_Y + EDGE + HP_H + 1))
	row.power:SetStatusBarColor(0.25, 0.45, 0.9)
	F.AtlasBar(row.power, "manaFill", "BarBottom.tga")
	row.power:SetFrameLevel(lvl)
	row.power:Hide()

	-- Texte ueber Balken und Rahmen
	row.over = CreateFrame("Frame", nil, row)
	row.over:SetAllPoints()
	row.over:SetFrameLevel(lvl + 5)
	row.name = F.CreateText(row.over, 12, "LEFT")
	row.name:SetFont(F.FONT_BOLD, 12, "")
	row.name:SetPoint("LEFT", row, "TOPLEFT", LEFT, -(PLATE_Y + EDGE + HP_H / 2))
	row.name:SetSize(ROW_W - LEFT - PADX - 40, 13)
	row.info = F.CreateText(row.over, 11, "RIGHT")
	row.info:SetPoint("RIGHT", row, "TOPRIGHT", -PADX, -(PLATE_Y + EDGE + HP_H / 2))
	row.info:SetSize(90, 12)

	-- Wappenschild als eigener Frame ganz oben (sonst ueberdecken Platte und Rahmen es)
	row.emblem = CreateFrame("Frame", nil, row)
	row.emblem:SetPoint("CENTER", row, "TOPLEFT", ORB_CX, ORB_CY)
	row.emblem:SetSize(ORB, ORB)
	row.emblem:SetFrameLevel(lvl + 8)
	row.orb = row.emblem:CreateTexture(nil, "ARTWORK")
	row.orb:SetAllPoints()
	row.orb:SetTexture(F.TEXROOT .. "Shield-Red.tga")
	row.orbFrame = row.emblem:CreateTexture(nil, "ARTWORK", nil, 1)   -- Metallrahmen in der Rahmenfarbe
	row.orbFrame:SetAllPoints()
	row.orbFrame:SetTexture(F.TEXROOT .. "Shield-Frame.tga")
	F.TintRim(row.orbFrame)
	row.mark = row.emblem:CreateTexture(nil, "OVERLAY", nil, 3)
	row.mark:SetSize(20, 20)
	row.mark:SetPoint("CENTER", row.emblem, "TOP", 0, -4)
	row.mark:SetTexture("Interface/TargetingFrame/UI-RaidTargetingIcons")
	row.mark:Hide()

	-- Abzeichen unten links (nur Klassikoptik)
	row.badge = CreateFrame("Frame", nil, row)
	row.badge:SetSize(20, 20)
	row.badge:SetPoint("CENTER", row.emblem, "BOTTOMLEFT", 18, 20)
	row.badge:SetFrameLevel(row.emblem:GetFrameLevel() + 2)
	row.badge.tex = row.badge:CreateTexture(nil, "ARTWORK")
	row.badge.tex:SetAllPoints()
	row.badge.tex:SetTexture(F.TEXROOT .. "Badge-Ring.tga")
	F.TintRim(row.badge.tex)
	row.letter = F.CreateText(row.badge, 11, "CENTER")
	row.letter:SetFont(F.FONT_BOLD, 11, "")
	row.letter:SetTextColor(unpack(F.PAL.gold))
	row.letter:SetSize(20, 20)
	row.letter:SetJustifyV("MIDDLE")
	row.letter:SetPoint("CENTER", row.badge, "CENTER", 1, -1)   -- Versalien sitzen im Zeilenkasten etwas hoch

	row:Hide()
	return row
end

-- split = true: Lebensbalken oben + Streifen darunter (Ressource/Cast); false: Lebensbalken fuellt alles
local function SetSplit(row, split)
	split = split and true or false
	if row.blizz then return BlizzLayout(row, "normal") end
	if row.split == split then return end
	row.split = split
	local h = split and HP_H or FULL_H
	row.hp:SetHeight(h)
	local tex = F.TEXROOT .. (split and BARTEX.split or BARTEX.full)
	row.hp:SetStatusBarTexture(tex)
	row.hp.bg:SetTexture(tex)
	row.hp.bg:SetVertexColor(0, 0, 0, 0.3)
	row.hp:SetStatusBarColor(0.82, 0.27, 0.23)   -- neue Textur: Farbe neu setzen
	F.AtlasBar(row.hp, "hpFill", split and "BarTop.tga" or "BarFull.tga")
	row.divider:SetShown(split)
	local y = -(PLATE_Y + EDGE + h / 2)
	row.name:SetPoint("LEFT", row, "TOPLEFT", LEFT, y)
	row.info:SetPoint("RIGHT", row, "TOPRIGHT", -PADX, y)
end

-- Ressourcenbalken des Gegners; true wenn einer sichtbar ist. Unlesbare Maximalwerte gelten als "keine".
local function UpdatePower(row, unit)
	local max = UnitPowerMax and UnitPowerMax(unit)
	if not F.Readable(max) or not max or max <= 0 then
		row.power:Hide()
		return false
	end
	local ptype, token = UnitPowerType(unit)
	if row.blizz then
		local key = F.Readable(token) and POWER_KEY[token] or "tMana"
		if not F.AtlasName(key) then key = "tMana" end
		if row.powerKey ~= key then row.powerKey = key; SetBarAtlas(row.power, key) end
	else
		local c = F.Readable(ptype) and PowerBarColor and PowerBarColor[ptype]
		if c then row.power:SetStatusBarColor(c.r, c.g, c.b) else row.power:SetStatusBarColor(0.25, 0.45, 0.9) end
	end
	row.power:SetMinMaxValues(0, max)
	row.power:SetValue(UnitPower(unit))
	row.power:Show()
	return true
end

-- Auswahl wie bei der Blizzard-Namensplakette: kraeftige gelbe Kontur HINTER dem Frame, nur um den AEUSSEREN Rand
-- (Rinnenkoerper als Rechteck + Portraitring als Kreis, je 2.6 px groesser). Eine dunkle Flaeche in Groesse des
-- Rinnenkoerpers verhindert, dass das Gelb durch die Rinnen scheint.
-- Auswahl wie bei der Blizzard-Namensplakette: eine gelbe Kontur, die der Form des Frames folgt (Rinnen, Ecken,
-- Portraitring, Verzierung). Sie entsteht aus versetzten Kopien der Rahmenkunst (entsaettigt, gelb eingefaerbt) HINTER
-- dem Frame; nur der Rand ragt heraus. Eine dunkle Flaeche in Groesse des Rinnenkoerpers verhindert, dass das Gelb
-- durch die (teilweise durchsichtigen) Rinnen scheint.
local OUTLINE_R = 2.6
local function EnsureOutline(row)
	if row.outline then return end
	local list = {}
	for dx = -1, 1 do
		for dy = -1, 1 do
			if dx ~= 0 or dy ~= 0 then
				for _ = 1, 2 do
					local t = NewAtlasTex(row, "BACKGROUND", 0, "tFrame")
					if t then
						t:SetPoint("CENTER", row, "CENTER", dx * OUTLINE_R, dy * OUTLINE_R)
						t:SetDesaturated(true)
						t:SetVertexColor(1, 0.86, 0.12)
						t:SetBlendMode("ADD")
						t:Hide()
						list[#list + 1] = t
					end
				end
			end
		end
	end
	-- minimaler Schein: zwei weitere, sehr schwache Lagen weiter aussen (halbtransparent, additiv)
	for _, ring in ipairs({ { 4.6, 0.17 }, { 6.6, 0.08 } }) do
		for dx = -1, 1 do
			for dy = -1, 1 do
				if dx ~= 0 or dy ~= 0 then
					local k = (dx ~= 0 and dy ~= 0) and 0.72 or 1   -- Diagonalen etwas naeher, damit der Schein rund bleibt
					local t = NewAtlasTex(row, "BACKGROUND", -1, "tFrame")
					if t then
						t:SetPoint("CENTER", row, "CENTER", dx * ring[1] * k, dy * ring[1] * k)
						t:SetDesaturated(true)
						t:SetVertexColor(1, 0.86, 0.12, ring[2])
						t:SetBlendMode("ADD")
						t:Hide()
						list[#list + 1] = t
					end
				end
			end
		end
	end
	row.outline = list
end

local function SetSelected(row, on)
	if row.blizz then
		on = on and true or false
		if on and not row.outline then
			local ok, err = pcall(EnsureOutline, row)
			if not ok and not M.outlineErr then
				M.outlineErr = true
				F.Print("Kontur-Fehler: " .. tostring(err))
			end
		end
		if row.outline then
			for _, t in ipairs(row.outline) do t:SetShown(on) end
		end
		return
	end
	row.band:SetGlow(on)
end

local function SetMark(row, idx)
	if idx then
		SetRaidTargetIconTexture(row.mark, idx)
		row.mark:Show()
	else
		row.mark:Hide()
	end
end

local function SetStatus(row, status, grey)
	if row.blizz then
		local b = row.badge
		local tex = F.TEXROOT .. (STATUS_TEX[status] or STATUS_TEX.yellow)
		b.fill:SetTexture(tex)
		b.glow:SetTexture(tex)
		b.fill:SetDesaturated(grey and true or false)
		b.frame:SetDesaturated(grey and true or false)
		b.fill:SetAlpha(grey and 0.55 or 1)
		b.frame:SetAlpha(grey and 0.55 or 1)
		if not grey and status == "red" then
			b.glow:SetAlpha(0.9)
			b.glow:Show()
			if b.pulse and not b.pulse:IsPlaying() then b.pulse:Play() end
		elseif not grey and (status == "orange" or status == "yellow") then
			if b.pulse then b.pulse:Stop() end
			b.glow:SetAlpha(0.45)
			b.glow:Show()
		else
			if b.pulse then b.pulse:Stop() end
			b.glow:Hide()
		end
		return
	end
	row.orb:SetTexture(F.TEXROOT .. (STATUS_TEX[status] or STATUS_TEX.yellow))
	row.orb:SetDesaturated(grey and true or false)
end

local function SetName(row, name)
	if name == nil then name = "?" end
	row.name:SetFormattedText("%s", name)      -- auch fuer geheime Namen
end

local function FillCached(row, e, pos)
	local c = e.cache
	row.unit = nil
	row:SetAlpha(0.55)
	row.letter:SetText(string.char(64 + pos))
	SetName(row, c.name)
	row.name:SetTextColor(0.8, 0.8, 0.8)
	row.hp:SetValue(0)
	row.cast:Hide()
	row.power:Hide()
	SetSplit(row, false)
	if row.blizz then BlizzStatic(row) end
	row.info:SetText("ausser Sicht")
	row.info:SetTextColor(0.7, 0.7, 0.7)
	SetStatus(row, "orange", true)
	SetMark(row, c.mark)
	SetSelected(row, false)
	row:SetBorderColor(0.5, 0.47, 0.45)
end

-- Cast des Gegners: Zaubername als Text, Fortschritt ueber das Dauer-Objekt des Clients (auch bei
-- geheimen Zeiten). Alte Clients ohne UnitCastingDuration: Zeit aus den Zeitstempeln.
local function UpdateCast(row, unit)
	local n = select("#", UnitCastingInfo(unit))
	local channel = false
	local name, startMS, endMS
	if n > 0 then
		name, _, _, startMS, endMS = UnitCastingInfo(unit)
	else
		n = select("#", UnitChannelInfo(unit))
		if n > 0 then
			name, _, _, startMS, endMS = UnitChannelInfo(unit)
			channel = true
		end
	end
	if n == 0 then
		row.cast:Hide()
		return false
	end
	if UnitCastingDuration and row.cast.SetTimerDuration and Enum and Enum.StatusBarTimerDirection then
		local duration
		if channel then duration = UnitChannelDuration(unit) else duration = UnitCastingDuration(unit) end
		if F.Readable(duration) and not duration then
			row.cast:Hide()
			return false
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
	if row.castText then
		if name ~= nil then row.castText:SetFormattedText("%s", name) else row.castText:SetText("") end
		return true
	end
	if name ~= nil then row.info:SetFormattedText("%s", name) else row.info:SetText("") end
	row.info:SetTextColor(0.98, 0.74, 0.36)
	return true
end

local function FillRow(row, e, pos)
	if e.cache then return FillCached(row, e, pos) end
	row:SetAlpha(1)
	local unit = e.unit
	row.unit = unit

	row.letter:SetText(string.char(64 + pos))
	SetName(row, UnitName(unit))
	if row.blizz then row.name:SetTextColor(1, 0.82, 0) else row.name:SetTextColor(1, 1, 1) end
	SetMark(row, F.Readable(GetRaidTargetIndex(unit)) and GetRaidTargetIndex(unit) or nil)
	SetStatus(row, e.status, false)
	if row.blizz then BlizzFill(row, unit) end

	F.SetHealthBar(row.hp, unit)
	local casting = UpdateCast(row, unit)
	local hasPower = UpdatePower(row, unit)
	if casting and not row.blizz then row.power:Hide() end
	SetSplit(row, casting or hasPower)
	if not casting or row.blizz then
		F.SetPercentText(row.info, unit)
		row.info:SetTextColor(0.9, 0.9, 0.9)
	end

	local selected = F.Bool(UnitIsUnit(unit, "target"))
	SetSelected(row, selected)
	if selected then
		row:SetBorderColor(F.RimColor())
	elseif (F.db.tank and not e.tanking) or (not F.db.tank and e.tanking) then
		row:SetBorderColor(0.88, 0.36, 0.3)
	else
		row:SetBorderColor(F.RimColor())
	end
end

-- Testmodus (/fray test): Platzhalter-Gegner statt echter Einheiten.
local DEMO_ENEMIES = {
	{ name = "Aggro-Eber", status = "red", frac = 0.79, mark = 8, selected = true, elite = true },
	{ name = "Wachhund", status = "orange", frac = 0.46, cast = "Schattenblitz", castLen = 3 },
	{ name = "Plagueknecht", status = "orange", frac = 0.91, mark = 1, power = 0.65 },
	{ name = "Schlafender Wolf", status = "green", frac = 1.0 },
}

local function DemoActive()
	return M.demoUntil and GetTime() < M.demoUntil
end

function M:StartDemo(secs)
	M.demoUntil = GetTime() + (secs or 20)
end

local function FillDemo(row, d, pos)
	row.unit = nil
	row:SetAlpha(1)
	row.letter:SetText(string.char(64 + pos))
	row.name:SetText(d.name)
	if row.blizz then row.name:SetTextColor(1, 0.82, 0) else row.name:SetTextColor(1, 1, 1) end
	row.hp:SetValue(d.frac)
	SetSplit(row, d.cast or d.power)
	if row.blizz then
		BlizzStatic(row)
		if d.elite then SetDragon(row, "gold") end
	end
	if d.power and (row.blizz or not d.cast) then
		row.power:SetMinMaxValues(0, 1)
		row.power:SetValue(d.power)
		row.power:Show()
	else
		row.power:Hide()
	end
	SetStatus(row, d.status, false)
	SetMark(row, d.mark)
	if d.cast then
		local len = d.castLen
		row.cast:SetMinMaxValues(0, len)
		row.cast:SetValue(GetTime() % len)
		row.cast:Show()
		if row.castText then
			row.castText:SetText(d.cast)
			row.info:SetText(string.format("%d%%", d.frac * 100 + 0.5))
			row.info:SetTextColor(0.9, 0.9, 0.9)
		else
			row.info:SetText(d.cast)
			row.info:SetTextColor(0.98, 0.74, 0.36)
		end
	else
		row.cast:Hide()
		row.info:SetText(string.format("%d%%", d.frac * 100 + 0.5))
		row.info:SetTextColor(0.9, 0.9, 0.9)
	end
	SetSelected(row, d.selected)
	if d.selected then
		row:SetBorderColor(F.RimColor())
	elseif d.status == "red" and not F.db.tank then
		row:SetBorderColor(0.88, 0.36, 0.3)
	else
		row:SetBorderColor(F.RimColor())
	end
end

local cacheTok = {}   -- Plakette -> zuletzt bekannte Werte (fuer "ausser Sicht")
local CACHE_SECS = 20

local STATUS_SCORE = { red = 100, orange = 60, green = 10 }

local function Entry(unit, token)
	local tanking, _, pct, known = F.GetThreat(unit)
	local guid = UnitGUID(unit)
	if not F.Readable(guid) or guid == nil then guid = token and ("plate" .. token) or unit end
	local status = ThreatStatus(unit, tanking, pct, guid, known)
	local nm = UnitName(unit)
	if not F.Readable(nm) then nm = "" end
	-- Sortierwert: echter Threat, sonst grob aus dem Status
	local score = (known and pct) or STATUS_SCORE[status] or 0
	return { unit = unit, name = nm, tanking = tanking, pct = pct or 0, score = score, guid = guid, status = status,
		token = token, idle = not F.IsEngaged(unit, true) }
end

local function TokenEntry(k)
	local unit = "nameplate" .. k
	if F.IsEngaged(unit) then
		local e = Entry(unit, k)
		local mark = GetRaidTargetIndex(unit)
		cacheTok[k] = { guid = e.guid, name = UnitName(unit), mark = F.Readable(mark) and mark or nil,
			pct = e.pct, score = e.score, seen = GetTime() }
		return e
	end
	-- Plakette weg (Gegner ausser Sicht): nur mit Kampflog moeglich zu erkennen, ob er noch kaempft
	local c = cacheTok[k]
	if c then
		local alive = F.HasCombatLog and not F.Bool(UnitExists(unit)) and F.recent[c.guid]
			and GetTime() - F.recent[c.guid] < CACHE_SECS
		if alive then
			return { cache = c, name = c.name, tanking = false, pct = c.pct, score = c.score or 0, guid = c.guid, token = k }
		end
		cacheTok[k] = nil
	end
	return nil
end

local function SortEntries(list)
	local tank = F.db.tank
	local byName = F.db.enemy.sort == "name"
	table.sort(list, function(a, b)
		local ai, bi = a.idle and true or false, b.idle and true or false
		if ai ~= bi then return bi end -- nicht kaempfende Gegner ans Ende
		if byName and tostring(a.name or "") ~= tostring(b.name or "") then return tostring(a.name or "") < tostring(b.name or "") end
		if a.score ~= b.score then
			if tank then return a.score < b.score end -- Tank: gefaehrdete Gegner (wenig Threat) zuerst
			return a.score > b.score                  -- sonst: hoechster Threat zuerst
		end
		return tostring(a.guid) < tostring(b.guid)
	end)
end

-- Gegner ohne Plakette (Ziel, Fokus, Gruppenziele) ohne Doppelungen zu den Plaketten-Eintraegen.
local function ExtraEntries(seen)
	local list = {}
	local units = { "target", "focus", "party1target", "party2target", "party3target", "party4target" }
	for _, unit in ipairs(units) do
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

-- Anzeige-Optionen pro Zeile (Prozent, Raidmarker, Elite-Symbol, Aggro-Schild, Ressource)
local function ApplyRowOptions(row)
	local o = F.db.enemy
	if row.info then row.info:SetShown(o.showPercent ~= false) end
	if row.blizz then
		if o.showMarker == false then row.mark:Hide() end
		if o.showElite == false then
			if row.dragon then row.dragon:Hide() end
			if row.star then row.star:Hide() end
		end
		if row.badge then row.badge:SetShown(o.showShield ~= false) end
		if o.showPower == false then row.power:Hide() end
	end
end

function M:Update()
	if DemoActive() then
		for i = 1, MAX_ROWS do
			local row, d = rows[i], DEMO_ENEMIES[i]
			if d then
				FillDemo(row, d, i)
				ApplyRowOptions(row)
				row:Show()
			else
				row:Hide()
			end
		end
		return
	end

	local list, seen = {}, {}
	for k = 1, TOKENS do
		local e = TokenEntry(k)
		if e then
			list[#list + 1] = e
			seen[e.guid] = true
		end
	end
	for _, e in ipairs(ExtraEntries(seen)) do list[#list + 1] = e end
	SortEntries(list)

	local maxRows = math.min(MAX_ROWS, F.db.enemy.maxRows or 12)
	for i = 1, MAX_ROWS do
		local row, e = rows[i], list[i]
		if e and i <= maxRows then
			FillRow(row, e, i)
			ApplyRowOptions(row)
			row:Show()
		else
			row:Hide()
		end
	end
end

-- Spalten-Layout (Gegner pro Spalte einstellbar)
function M:ApplyLayout()
	local pc = PerCol()
	for i, row in ipairs(rows) do
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", M.frame, "TOPLEFT", math.floor((i - 1) / pc) * (ROW_W + COLGAP), -((i - 1) % pc) * PITCH + YOFF)
	end
	local cols = math.ceil(MAX_ROWS / pc)
	M.frame:SetSize(cols * ROW_W + (cols - 1) * COLGAP, pc * PITCH - GAP)
end

function M:Init()
	local f = CreateFrame("Frame", "FrayEnemyList", UIParent)
	f:SetSize(ROW_W, PITCH)
	M.frame = f
	F:MakeMovable(f, "enemy", "Gegnerliste", 500, 80)

	for i = 1, MAX_ROWS do rows[i] = (BLIZZ and CreateRowBlizz or CreateRow)(i) end
	M:ApplyLayout()

	f.t = 0
	f:SetScript("OnUpdate", function(self, dt)
		self.t = self.t + dt
		if self.t < 0.1 then return end
		self.t = 0
		M:Update()
	end)

	if GetCVar and GetCVar("nameplateShowEnemies") == "0" then
		F.Print("Gegner-Namensplaketten sind aus - die Gegnerliste braucht sie. /fray plates aktiviert sie.")
	end
end

function M:SetEnabled(on)
	M.frame:SetShown(on)
	if not on then
		for i = 1, MAX_ROWS do rows[i]:Hide() end
	end
end

function M:Debug()
	F.Print("Gegnerliste:")
	local list, seen = {}, {}
	for k = 1, TOKENS do
		local e = TokenEntry(k)
		if e then list[#list + 1] = e; seen[e.guid] = true end
	end
	for _, e in ipairs(ExtraEntries(seen)) do list[#list + 1] = e end
	SortEntries(list)
	for i, e in ipairs(list) do
		print(i, e.unit and UnitName(e.unit) or (e.cache and e.cache.name), e.status, e.unit or "ausser Sicht")
	end
end
