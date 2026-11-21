local ADDON, F = ...
_G.Fray = F

F.version = "1.0.0"
F.modules = {}
F.order = {}
F.movables = {}
F.unlocked = false

F.TEXROOT = "Interface\\AddOns\\Fray\\Textures\\"
F.WHITE = "Interface\\Buttons\\WHITE8X8"

-- Fonts: only the game's own fonts, resolved through Blizzard's font objects so they fit the client's locale.
local function GameFont(objName, fallback)
	local o = _G[objName]
	if o and o.GetFont then
		local ok, path = pcall(o.GetFont, o)
		if ok and type(path) == "string" and path ~= "" then return path end
	end
	return fallback
end
F.FONT = STANDARD_TEXT_FONT or GameFont("GameFontNormal", "Fonts\\FRIZQT__.TTF")
F.FONT_BOLD = F.FONT
F.FONT_TITLE = GameFont("QuestTitleFont", F.FONT)

-- Copper palette (matches the Forever interface)
F.PAL = {
	edge = { 0.58, 0.46, 0.30 },     -- Bronze (Fenster, Symbole)
	rim = { 0.82, 0.76, 0.72 },      -- heller Plattenrand wie bei Namensplaketten
	hover = { 0.92, 0.74, 0.50 },    -- Rahmen unter der Maus / gewaehlt
	gold = { 0.88, 0.74, 0.50 },     -- Titel, Hervorhebungen
	text = { 0.92, 0.90, 0.85 },
	dim = { 0.72, 0.70, 0.66 },
	bg = { 0.09, 0.065, 0.04 },      -- dunkles Braun
	bgLight = { 0.24, 0.17, 0.10 },
}
F.BAR_TEX = F.TEXROOT .. "Pill.tga"             -- abgerundeter Balken (grau-weiss, wird eingefaerbt)
F.PANEL_BORDER = { 0.55, 0.42, 0.24, 1 }

-- Rahmenfarbe der Platten (Option): die Metalltextur ist grau und wird eingefaerbt
F.RIM = {
	bronze = { name = "Kupfer (Forever)", c = { 0.88, 0.70, 0.48 } },
	silver = { name = "Silber", c = { 0.86, 0.82, 0.78 } },
	gold = { name = "Gold", c = { 1.0, 0.84, 0.34 } },
}
F.RIM_ORDER = { "bronze", "silver", "gold" }

-- Blizzard-Atlanten: pro Zweck eine Kandidatenliste, der erste Name, den der Client kennt, wird benutzt.
-- Ohne Treffer bleiben die eigenen Texturen. Die Namen sind Retail-/Dragonflight-Namen; ob Forever sie kennt,
-- zeigt /fray atlas.
F.ATLAS = {
	hpFill = { "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health", "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health-Texture",
		"UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health", "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health-Texture" },
	manaFill = { "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana", "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana-Texture",
		"UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana", "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana-Texture" },
	castFill = { "UI-CastingBar-Filling-Standard", "ui-castingbar-filling-standard" },
	castChannel = { "UI-CastingBar-Filling-Channel", "ui-castingbar-filling-channel" },
	castSpark = { "UI-CastingBar-Pip", "ui-castingbar-pip", "UI-CastingBar-Spark" },
	-- Blizzards Ziel-Frame (Dragonflight): Rahmen, Leuchten im Kampf, Typ-Leiste, Balken, Masken, Verzierungen
	tFrame = { "UI-HUD-UnitFrame-Target-PortraitOn" },
	tRareFrame = { "UI-HUD-UnitFrame-Target-Rare-PortraitOn" },
	tFlash = { "UI-HUD-UnitFrame-Target-PortraitOn-InCombat" },
	tType = { "UI-HUD-UnitFrame-Target-PortraitOn-Type" },
	tHealth = { "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health" },
	tHealthMask = { "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Health-Mask" },
	tMana = { "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana" },
	tRage = { "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Rage" },
	tEnergy = { "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Energy" },
	tFocus = { "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Focus" },
	tRunic = { "UI-HUD-UnitFrame-Target-PortraitOn-Bar-RunicPower" },
	mFrame = { "UI-HUD-UnitFrame-Target-MinusMob-PortraitOn" },
	mFlash = { "UI-HUD-UnitFrame-Target-MinusMob-PortraitOn-InCombat" },
	mHealth = { "UI-HUD-UnitFrame-Target-MinusMob-PortraitOn-Bar-Health" },
	mHealthMask = { "UI-HUD-UnitFrame-Target-MinusMob-PortraitOn-Bar-Health-Mask" },
	tElite = { "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold" },
	tBoss = { "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged" },
	tRareDeco = { "ui-hud-unitframe-target-portraiton-boss-rare-silver" },
	tStar = { "UnitFrame-Target-PortraitOn-Boss-Rare-Star", "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star" },
	tCircle = { "UI-HUD-UnitFrame-SmallCircle" },
	-- kleine Drachen-Symbole der Namensplaketten (Elite gold, seltener Elite silber)
	eliteGold = { "nameplates-icon-elite-gold", "Nameplates-Icon-Elite-Gold", "nameplates-icon-elite-boss" },
	eliteSilver = { "nameplates-icon-elite-silver", "Nameplates-Icon-Elite-Silver" },
	-- Zauberleiste (Namen aus Blizzards Ziel-Zauberleiste)
	castFrame = { "UI-CastingBar-Frame" },
	castBack = { "UI-CastingBar-Background" },
	castShield = { "UI-CastingBar-Shield" },
	-- Fensterrahmen (Blizzards Metall-Rahmen, Layout ButtonFrameTemplateNoPortrait)
	metalTL = { "UI-Frame-Metal-CornerTopLeft" }, metalTR = { "UI-Frame-Metal-CornerTopRight" },
	metalBL = { "UI-Frame-Metal-CornerBottomLeft" }, metalBR = { "UI-Frame-Metal-CornerBottomRight" },
	metalTop = { "_UI-Frame-Metal-EdgeTop" }, metalBottom = { "_UI-Frame-Metal-EdgeBottom" },
	metalLeft = { "!UI-Frame-Metal-EdgeLeft" }, metalRight = { "!UI-Frame-Metal-EdgeRight" },
	-- Tooltip-Rahmen (Layout TooltipDefaultLayout) fuer die Warnungen
	ttTL = { "Tooltip-NineSlice-CornerTopLeft" }, ttTR = { "Tooltip-NineSlice-CornerTopRight" },
	ttBL = { "Tooltip-NineSlice-CornerBottomLeft" }, ttBR = { "Tooltip-NineSlice-CornerBottomRight" },
	ttT = { "_Tooltip-NineSlice-EdgeTop" }, ttB = { "_Tooltip-NineSlice-EdgeBottom" },
	ttL = { "!Tooltip-NineSlice-EdgeLeft" }, ttR = { "!Tooltip-NineSlice-EdgeRight" },
	ttC = { "Tooltip-NineSlice-Center" },
	-- schlichter Metall-Rahmen (SimplePanelTemplate): eine Ecke fuer alle vier (gespiegelt), eine Kante oben/unten,
	-- eine Kante links/rechts
	smC = { "UI-Frame-SimpleMetal-CornerTopLeft" }, smT = { "_UI-Frame-SimpleMetal-EdgeTop" },
	smL = { "!UI-Frame-SimpleMetal-EdgeLeft" },
	-- Dialog-Rahmen des Spielmenues (Layout "Dialog"): Rautenecken, Kanten, Titelplakette
	dmTL = { "UI-Frame-DiamondMetal-CornerTopLeft" }, dmTR = { "UI-Frame-DiamondMetal-CornerTopRight" },
	dmBL = { "UI-Frame-DiamondMetal-CornerBottomLeft" }, dmBR = { "UI-Frame-DiamondMetal-CornerBottomRight" },
	dmT = { "_UI-Frame-DiamondMetal-EdgeTop" }, dmB = { "_UI-Frame-DiamondMetal-EdgeBottom" },
	dmL = { "!UI-Frame-DiamondMetal-EdgeLeft" }, dmR = { "!UI-Frame-DiamondMetal-EdgeRight" },
	dmHL = { "UI-Frame-DiamondMetal-Header-CornerLeft" }, dmHR = { "UI-Frame-DiamondMetal-Header-CornerRight" },
	dmHC = { "_UI-Frame-DiamondMetal-Header-Tile" },
	-- Bedienelemente
	closeBtn = { "RedButton-Exit" },
	cbBox = { "checkbox-minimal" }, cbCheck = { "checkmark-minimal" },
	sliderL = { "Minimal_SliderBar_Left" }, sliderM = { "_Minimal_SliderBar_Middle" }, sliderR = { "Minimal_SliderBar_Right" },
	sliderThumb = { "Minimal_SliderBar_Button" },
	-- Aggro-Symbol im Kreis: Tank-Schild der Rollen-Symbole (Kandidatenliste, erster Treffer gewinnt)
	aggroIcon = { "UI-LFG-RoleIcon-Tank", "groupfinder-icon-role-large-tank", "roleicon-tiny-tank", "UI-LFG-RoleIcon-Tank-Micro",
		"GarrMission_RoleIcon-Tank", "Ping_Chat_Warning" },
}

function F.AtlasName(key)
	F.atlasCache = F.atlasCache or {}
	local c = F.atlasCache[key]
	if c ~= nil then return c or nil end
	local list = F.ATLAS[key]
	if list and C_Texture and C_Texture.GetAtlasInfo then
		for _, n in ipairs(list) do
			local ok, info = pcall(C_Texture.GetAtlasInfo, n)
			if ok and info then
				F.atlasCache[key] = n
				return n
			end
		end
	end
	F.atlasCache[key] = false
	return nil
end

-- Statusbar-Fuellung mit einem Atlas belegen; die Rundung der eigenen Balkenform kommt als Maske (wie bei Blizzard).
function F.AtlasBar(bar, key, shapeFile)
	local name = F.AtlasName(key)
	if not name then return false end
	local t = bar:GetStatusBarTexture()
	if not t then return false end
	if not pcall(t.SetAtlas, t, name, false) then return false end
	if bar.CreateMaskTexture then
		if not bar.atlasMask then
			bar.atlasMask = bar:CreateMaskTexture()
			bar.atlasMask:SetAllPoints(bar)
			t:AddMaskTexture(bar.atlasMask)
		end
		bar.atlasMask:SetTexture(F.TEXROOT .. shapeFile, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	end
	return true
end

-- Name und Groesse eines Atlas (nil, wenn der Client ihn nicht kennt)
function F.AtlasInfo(key)
	local name = F.AtlasName(key)
	if not name then return nil end
	local ok, info = pcall(C_Texture.GetAtlasInfo, name)
	if ok and info then return name, info.width or 0, info.height or 0 end
end

-- Leiste aus drei Teilen eines Atlas (Kappe links, Mitte gestreckt, Kappe rechts); capPx = Kappenbreite im Atlas
function F.AtlasThreeSlice(parent, key, layer, sub, capPx)
	local name, w, h = F.AtlasInfo(key)
	if not name then return nil end
	local cap = math.min(0.45, (capPx or 12) / math.max(w, 1))
	local t = { capFrac = cap, atlasW = w, atlasH = h }
	local function piece(l, r)
		local x = parent:CreateTexture(nil, layer, nil, sub or 0)
		x:SetAtlas(name, false)
		x:SetTexCoord(l, r, 0, 1)
		return x
	end
	t.L, t.M, t.R = piece(0, cap), piece(cap, 1 - cap), piece(1 - cap, 1)
	return t
end

-- Position relativ zu TOPLEFT des Parents (x nach rechts, y nach unten)
function F.PlaceThreeSlice(t, parent, x, y, w, h)
	local capw = t.capFrac * t.atlasW * (h / math.max(t.atlasH, 1))
	t.L:ClearAllPoints(); t.L:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y); t.L:SetSize(capw, h)
	t.R:ClearAllPoints(); t.R:SetPoint("TOPLEFT", parent, "TOPLEFT", x + w - capw, -y); t.R:SetSize(capw, h)
	t.M:ClearAllPoints()
	t.M:SetPoint("TOPLEFT", t.L, "TOPRIGHT", 0, 0)
	t.M:SetPoint("BOTTOMRIGHT", t.R, "BOTTOMLEFT", 0, 0)
end

-- Schlichter Metall-Rahmen aus Atlanten um "frame" (Ecken gespiegelt, Kanten gekachelt) + dunkle Flaeche.
-- Liefert false, wenn der Client die Atlanten nicht hat. Die Kunst sitzt genau auf den Rahmenecken (keine Versaetze).
function F.AtlasFrame(frame, bg, inset)
	if not (F.AtlasName("smC") and F.AtlasName("smT") and F.AtlasName("smL")) then return false end
	local back = frame:CreateTexture(nil, "BACKGROUND")
	back:SetColorTexture(bg[1], bg[2], bg[3], bg[4] or 1)
	back:SetPoint("TOPLEFT", inset or 3, -(inset or 3))
	back:SetPoint("BOTTOMRIGHT", -(inset or 3), inset or 3)
	local function t(key, flipX, flipY)
		local x = frame:CreateTexture(nil, "OVERLAY")
		x:SetAtlas(F.AtlasName(key), true)
		if flipX or flipY then
			x:SetTexCoord(flipX and 1 or 0, flipX and 0 or 1, flipY and 1 or 0, flipY and 0 or 1)
		end
		return x
	end
	local tl, tr, bl, br = t("smC"), t("smC", true), t("smC", false, true), t("smC", true, true)
	tl:SetPoint("TOPLEFT"); tr:SetPoint("TOPRIGHT"); bl:SetPoint("BOTTOMLEFT"); br:SetPoint("BOTTOMRIGHT")
	local top, bottom, left, right = t("smT"), t("smT", false, true), t("smL"), t("smL", true)
	top:SetPoint("TOPLEFT", tl, "TOPRIGHT"); top:SetPoint("TOPRIGHT", tr, "TOPLEFT")
	bottom:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT"); bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
	left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); left:SetPoint("BOTTOMLEFT", bl, "TOPLEFT")
	right:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT"); right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
	return true
end

-- Rahmen wie das Spielmenue (Blizzards Dialog-Rahmen): Rautenecken, gekachelte Kanten, Dialog-Hintergrund und
-- eine Titelplakette, die ueber den oberen Rand ragt. Liefert die Plakette (Frame) oder nil, wenn der Client
-- die Atlanten nicht hat.
function F.DialogFrame(frame, headerText)
	for _, k in ipairs({ "dmTL", "dmTR", "dmBL", "dmBR", "dmT", "dmB", "dmL", "dmR", "dmHL", "dmHR", "dmHC" }) do
		if not F.AtlasName(k) then return nil end
	end
	local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
	bg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background", "REPEAT", "REPEAT")
	bg:SetHorizTile(true)
	bg:SetVertTile(true)
	bg:SetPoint("TOPLEFT", 7, -7)
	bg:SetPoint("BOTTOMRIGHT", -7, 7)
	local function tex(key, parent, layer)
		local t = (parent or frame):CreateTexture(nil, layer or "OVERLAY")
		t:SetAtlas(F.AtlasName(key), true)
		return t
	end
	local tl, tr, bl, br = tex("dmTL"), tex("dmTR"), tex("dmBL"), tex("dmBR")
	tl:SetPoint("TOPLEFT"); tr:SetPoint("TOPRIGHT"); bl:SetPoint("BOTTOMLEFT"); br:SetPoint("BOTTOMRIGHT")
	local top, bottom, left, right = tex("dmT"), tex("dmB"), tex("dmL"), tex("dmR")
	top:SetPoint("TOPLEFT", tl, "TOPRIGHT"); top:SetPoint("TOPRIGHT", tr, "TOPLEFT")
	bottom:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT"); bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
	left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); left:SetPoint("BOTTOMLEFT", bl, "TOPLEFT")
	right:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT"); right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")

	local h = CreateFrame("Frame", nil, frame)
	h:SetFrameLevel(frame:GetFrameLevel() + 10)
	local fs = h:CreateFontString(nil, "OVERLAY")
	fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "")
	fs:SetTextColor(1, 0.82, 0)
	fs:SetText(headerText or "")
	local sw = fs:GetStringWidth()
	if type(sw) ~= "number" then sw = 60 end
	local w = sw + 64
	h:SetSize(w, 39)
	h:SetPoint("TOP", frame, "TOP", 0, 11)
	fs:SetPoint("TOP", h, "TOP", 0, -13)
	local hl, hr, hc = tex("dmHL", h, "BACKGROUND"), tex("dmHR", h, "BACKGROUND"), tex("dmHC", h, "BACKGROUND")
	hl:SetPoint("LEFT")
	hr:SetPoint("RIGHT")
	hc:SetPoint("TOPLEFT", hl, "TOPRIGHT")
	hc:SetPoint("BOTTOMRIGHT", hr, "BOTTOMLEFT")
	h.text = fs
	return h
end

function F.AtlasReport()
	if not (C_Texture and C_Texture.GetAtlasInfo) then
		F.Print("C_Texture.GetAtlasInfo fehlt in diesem Client - es werden die eigenen Texturen benutzt.")
		return
	end
	for _, key in ipairs({ "hpFill", "manaFill", "castFill", "castChannel", "castSpark", "tFrame", "tFlash", "tType", "tHealth",
		"tHealthMask", "tMana", "mFrame", "tElite", "tBoss", "tRareDeco", "tStar", "tCircle", "eliteGold", "eliteSilver" }) do
		local n = F.AtlasName(key)
		F.Print(string.format("%s: %s", key, n and ("|cff55dd55" .. n .. "|r") or "|cffdd5555nicht vorhanden - eigene Textur|r"))
	end
end
F.bands = {}
function F.RimColor()
	local s = F.RIM[(F.db and F.db.frameStyle) or "bronze"] or F.RIM.bronze
	return s.c[1], s.c[2], s.c[3]
end
F.rimTex = {}
-- Textur (grauer Metallrahmen) in der Rahmenfarbe einfaerben und fuer spaetere Farbwechsel merken
function F.TintRim(tex)
	tex:SetVertexColor(F.RimColor())
	F.rimTex[#F.rimTex + 1] = tex
end
function F.ApplyFrameStyle()
	for _, t in ipairs(F.rimTex) do t:SetVertexColor(F.RimColor()) end
	for _, band in ipairs(F.bands) do band:SetBorderColor(F.RimColor()) end
	local m = F.modules and F.modules.enemy
	if m and m.Update then m:Update() end
end

local MODULE_NAMES = { "enemy", "cast", "alerts", "float", "cooldowns", "qol" }

local defaults = {
	tank = false,
	frameStyle = "bronze",
	scale = 1,
	scales = {},
	modules = {
		enemy = true, cast = true, alerts = true,
		float = true, cooldowns = true, qol = true,
	},
	pos = {},
	grid = { enabled = true, size = 10 },
	enemy = { showAll = false, perCol = 6, threatOrange = 50, maxRows = 12, sort = "threat",
		showPercent = true, showPower = true, showMarker = true, showElite = true, showShield = true },
	cast = { onlyHostile = false, target = true, focus = true, showIcon = true, showTime = true },
	alerts = { sound = true, lowHealth = true, lowHealthPct = 25, gain = true, gainTank = false, loss = true,
		tankWarn = true, threatHigh = true, threatPct = 90, onlyInGroup = true, onlyInCombat = true, pause = 8,
		hold = 2.6, textSize = 24, showName = true,
		soundGain = "raid", soundLoss = "alarm", soundThreat = "boss", soundLow = "alarm" },
	float = { minAmount = 0 },
	cooldowns = { list = {}, alwaysShow = true, size = 40, showTimer = true },
	qol = { autoSell = true, autoRepair = true },
}

local function Merge(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then dst[k] = {} end
			Merge(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

function F.Print(msg)
	print("|cff66ccffFray|r: " .. tostring(msg))
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local handlers = {}
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, ...)
	local list = handlers[event]
	if list then
		for i = 1, #list do list[i](event, ...) end
	end
end)

-- Mehrere Handler pro Event; unbekannte Events (anderer Client-Build) werden ignoriert.
function F:On(event, fn)
	if not handlers[event] then
		handlers[event] = {}
		pcall(eventFrame.RegisterEvent, eventFrame, event)
	end
	table.insert(handlers[event], fn)
end

------------------------------------------------------------------------
-- Module
------------------------------------------------------------------------
function F:RegisterModule(name, mod)
	mod.name = name
	self.modules[name] = mod
	table.insert(self.order, name)
end

function F:IsEnabled(name)
	return self.db and self.db.modules[name] and true or false
end

------------------------------------------------------------------------
-- Kleine UI-Helfer
------------------------------------------------------------------------
function F.Short(n)
	n = n or 0
	if n >= 1e6 then return string.format("%.1fm", n / 1e6) end
	if n >= 1e4 then return string.format("%.1fk", n / 1e3) end
	return tostring(math.floor(n + 0.5))
end

function F.FormatTime(s)
	if s >= 60 then return string.format("%dm", math.floor(s / 60)) end
	if s >= 10 then return string.format("%d", math.floor(s)) end
	return string.format("%.1f", s)
end

function F.CreateText(parent, size, justify, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY")
	fs:SetFont(F.FONT, size or 11, "")
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetShadowOffset(1, -1)
	fs:SetJustifyH(justify or "LEFT")
	if fs.SetWordWrap then fs:SetWordWrap(false) end
	return fs
end

-- Leuchtender Halo um ein Rechteck (9-Slice aus Glow.tga, additiv): wie die gelbe Auswahl bei Namensplaketten.
-- fadeLeft: Pixel, ueber die der Halo links aus dem Nichts einblendet (statt einer Kappe); so gibt es keine
-- harte Kante, wo links ein Emblem darueber liegt.
function F.CreateGlow(frame, fadeLeft)
	local path = F.TEXROOT .. "Glow.tga"
	local c, inset = 32, 22   -- Glow.tga: 96x96, Ecken 32 px, Eckenradius 8 wie die Platte
	local u = c / 96
	local all, fades = {}, {}
	local function tex(l, r, t, b)
		local x = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
		x:SetTexture(path)
		x:SetTexCoord(l, r, t, b)
		x:SetBlendMode("ADD")
		all[#all + 1] = x
		return x
	end
	local tr, br = tex(1 - u, 1, 0, u), tex(1 - u, 1, 1 - u, 1)
	local right = tex(1 - u, 1, u, 1 - u)
	local top, bottom = tex(u, 1 - u, 0, u), tex(u, 1 - u, 1 - u, 1)
	for _, x in ipairs({ tr, br }) do x:SetSize(c, c) end
	tr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", inset, inset)
	br:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", inset, -inset)
	right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT"); right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
	if fadeLeft then
		local tf, bf = tex(u, 1 - u, 0, u), tex(u, 1 - u, 1 - u, 1)
		tf:SetSize(fadeLeft, c); tf:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, inset)
		bf:SetSize(fadeLeft, c); bf:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, -inset)
		fades[1], fades[2] = tf, bf
		top:SetPoint("TOPLEFT", tf, "TOPRIGHT"); top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
		bottom:SetPoint("TOPLEFT", bf, "TOPRIGHT"); bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
	else
		local tl, bl = tex(0, u, 0, u), tex(0, u, 1 - u, 1)
		local left = tex(0, u, u, 1 - u)
		for _, x in ipairs({ tl, bl }) do x:SetSize(c, c) end
		tl:SetPoint("TOPLEFT", frame, "TOPLEFT", -inset, inset)
		bl:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -inset, -inset)
		top:SetPoint("TOPLEFT", tl, "TOPRIGHT"); top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
		bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT"); bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
		left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
	end
	local glow = { color = { 1, 0.8, 0.22 } }
	function glow:SetColor(r, g, b, a)
		self.color = { r, g, b }
		for _, x in ipairs(all) do x:SetVertexColor(r, g, b, a or 1) end
		-- die Einblend-Stuecke: Verlauf von durchsichtig nach voll
		if CreateColor then
			for _, x in ipairs(fades) do
				pcall(x.SetGradient, x, "HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, a or 1))
			end
		end
	end
	function glow:SetShown(on)
		for _, x in ipairs(all) do if on then x:Show() else x:Hide() end end
	end
	glow:SetColor(1, 0.92, 0.18, 1)
	glow:SetShown(false)
	return glow
end

-- Abgerundete dunkle Braunplatte mit Bronzerahmen (3-Slice aus Plate-*.tga, 
-- angelehnt). Liegt bei (x0, -y0) mit Groesse w x h im Parent. SetBorderColor faerbt den Rahmen,
-- SetGlow zeigt Schimmer und Leucht-Halo (gewaehlt).
function F.CreateBand(parent, x0, y0, w, h, fadeLeft)
	local band = {}
	local holder = CreateFrame("Frame", nil, parent)
	holder:SetPoint("TOPLEFT", parent, "TOPLEFT", x0, -y0)
	holder:SetSize(w, h)
	holder:SetFrameLevel(parent:GetFrameLevel())
	band.frame = holder

	local cap = 12
	local function build(file, layer, sub)
		local path = F.TEXROOT .. file
		local function tex()
			local t = holder:CreateTexture(nil, layer, nil, sub or 0)
			t:SetTexture(path)
			return t
		end
		local l, r, m = tex(), tex(), tex()
		l:SetTexCoord(0, cap / 128, 0, 1); l:SetSize(cap, h); l:SetPoint("TOPLEFT")
		r:SetTexCoord(1 - cap / 128, 1, 0, 1); r:SetSize(cap, h); r:SetPoint("TOPRIGHT")
		m:SetTexCoord(cap / 128, 1 - cap / 128, 0, 1)
		m:SetPoint("TOPLEFT", l, "TOPRIGHT"); m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
		return { l, m, r }
	end
	band.halo = F.CreateGlow(holder, fadeLeft)
	band.fill = build("Plate-Fill.tga", "BACKGROUND", 0)
	band.glow = build("Plate-Glow.tga", "BORDER", 0)
	band.border = build("Plate-Border.tga", "ARTWORK", 3)
	for _, t in ipairs(band.glow) do
		t:SetVertexColor(1, 0.8, 0.25, 0.14)
		t:Hide()
	end
	local function tint(r, g, b)
		for _, t in ipairs(band.border) do t:SetVertexColor(r, g, b) end
	end
	tint(F.RimColor())
	F.bands[#F.bands + 1] = band
	function band:SetBorderColor(r, g, b) tint(r, g, b) end
	function band:SetGlow(on)
		for _, t in ipairs(self.glow) do
			if on then t:Show() else t:Hide() end
		end
		self.halo:SetShown(on)
	end
	function band:SetSize(nw, nh) holder:SetSize(nw, nh) end
	return band
end

-- Balken: dunkler Hintergrund + bar texture (Farbe per SetStatusBarColor), duenne dunkle Kante.
-- style: nil = Pille (beidseitig rund); "top"/"bottom" = links gerade, rechts oben/unten abgerundet
-- (laeuft unter das Schild und sitzt buendig in den Ecken der Platte).
function F.CreateSlimBar(parent, w, h, style)
	local tex = style == "top" and (F.TEXROOT .. "BarTop.tga") or style == "bottom" and (F.TEXROOT .. "BarBottom.tga")
		or style == "right" and (F.TEXROOT .. "BarRight.tga") or style == "full" and (F.TEXROOT .. "BarFull.tga") or F.BAR_TEX
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetSize(w, h)
	bar:SetStatusBarTexture(tex)
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints()
	bar.bg:SetTexture(tex)
	bar.bg:SetVertexColor(0, 0, 0, 0.3)   -- nur leicht abdunkeln: die Platte soll durchscheinen, keine harte Kante
	-- Schlagschatten nach innen: Licht kommt von oben. Duenner, kraeftiger Streifen am oberen Rand (3 px),
	-- nach unten ausblendend; rechts 3 px frei, damit er nicht in die runde Ecke ragt.
	bar.shade = bar:CreateTexture(nil, "OVERLAY", nil, 1)
	bar.shade:SetTexture(F.WHITE)
	bar.shade:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
	bar.shade:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -3, 0)
	bar.shade:SetHeight(3)
	if CreateColor and bar.shade.SetGradient then
		pcall(bar.shade.SetGradient, bar.shade, "VERTICAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.85))
	elseif bar.shade.SetGradientAlpha then
		bar.shade:SetGradientAlpha("VERTICAL", 0, 0, 0, 0, 0, 0, 0, 0.85)
	else
		bar.shade:SetVertexColor(0, 0, 0, 0.4)
	end
	return bar
end

F.CreateBar = F.CreateSlimBar

function F.CreateBorder(frame, size, layer)
	local b = {}
	local edges = {}
	for i = 1, 4 do
		local t = frame:CreateTexture(nil, layer or "OVERLAY")
		t:SetTexture(F.WHITE)
		edges[i] = t
	end
	local top, bottom, left, right = edges[1], edges[2], edges[3], edges[4]
	top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(size)
	bottom:SetPoint("BOTTOMLEFT"); bottom:SetPoint("BOTTOMRIGHT"); bottom:SetHeight(size)
	left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); left:SetWidth(size)
	right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT"); right:SetWidth(size)
	function b:SetColor(r, g, bl, a)
		for i = 1, 4 do edges[i]:SetVertexColor(r, g, bl, a or 1) end
	end
	function b:Show() for i = 1, 4 do edges[i]:Show() end end
	function b:Hide() for i = 1, 4 do edges[i]:Hide() end end
	b:Hide()
	return b
end

function F.ClassColor(unit)
	local _, class = UnitClass(unit)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then return c.r, c.g, c.b end
	return 0.6, 0.6, 0.6
end

------------------------------------------------------------------------
-- Threat / Gegner
------------------------------------------------------------------------
function F.InGroup()
	if IsInGroup then return IsInGroup() and true or false end
	return (GetNumPartyMembers and GetNumPartyMembers() or 0) > 0
end

local STATUS_PCT = { [0] = 20, [1] = 70, [2] = 95, [3] = 100 }

------------------------------------------------------------------------
-- Geheime Werte (Forever / neuere Clients): Viele Zahlen (HP, Threat ...) sind im Kampf "geheim".
-- Man darf sie nicht vergleichen, nicht rechnen und nicht formatieren, nur an Funktionen reichen,
-- die sie annehmen (StatusBar:SetValue, FontString:SetFormattedText).
------------------------------------------------------------------------
function F.Readable(v)
	if v == nil or not canaccessvalue then return true end
	return canaccessvalue(v) and true or false
end

function F.AllReadable(...)
	for i = 1, select("#", ...) do
		if not F.Readable((select(i, ...))) then return false end
	end
	return true
end

-- Gibt einen Wahrheitswert nur zurueck, wenn er lesbar ist (sonst false).
function F.Bool(v)
	return F.Readable(v) and v and true or false
end

F.HasCombatLog = CombatLogGetCurrentEventInfo ~= nil
F.SCALE100 = CurveConstants and CurveConstants.ScaleTo100

-- Zielt die Einheit auf dich? (lesbar, auch im Kampf)
function F.TargetsMe(unit)
	local tt = unit .. "target"
	if not F.Bool(UnitExists(tt)) then return false end
	return F.Bool(UnitIsUnit(tt, "player"))
end

-- HP-Balken: SetValue/SetMinMaxValues nehmen auch geheime Werte an.
function F.SetHealthBar(bar, unit)
	bar:SetMinMaxValues(0, UnitHealthMax(unit))
	bar:SetValue(UnitHealth(unit))
end

-- HP in Prozent als Text: UnitHealthPercent (geheim moeglich) -> SetFormattedText; sonst Rechnung.
function F.SetPercentText(fs, unit)
	if UnitHealthPercent and F.SCALE100 then
		fs:SetFormattedText("%.0f%%", UnitHealthPercent(unit, true, F.SCALE100))
		return
	end
	local cur, max = UnitHealth(unit), UnitHealthMax(unit)
	if F.AllReadable(cur, max) and type(cur) == "number" and type(max) == "number" and max > 0 then
		fs:SetText(string.format("%d%%", cur / max * 100 + 0.5))
	else
		fs:SetText("")
	end
end

-- Rueckgabe: tanking (bool), status (0-3, nil = unbekannt), pct (0-100, nil = unbekannt), known (bool:
-- Threat-Werte waren lesbar). Auf Plaketten ist Threat im Kampf geheim: dann gilt nur "zielt auf dich".
function F.GetThreat(unit)
	local tanking, status, pct
	if UnitDetailedThreatSituation then
		tanking, status, pct = UnitDetailedThreatSituation("player", unit)
	elseif UnitThreatSituation then
		status = UnitThreatSituation("player", unit)
		tanking = status == 3
	end
	local known = F.AllReadable(tanking, status, pct)
	if not known then tanking, status, pct = nil, nil, nil end
	if status == nil and F.TargetsMe(unit) then
		tanking, status = true, 3
	end
	if status and not pct then pct = STATUS_PCT[status] end
	if tanking then pct = 100 end
	return tanking and true or false, status, pct, known
end

local function IsFriendlyGroupUnit(tt)
	if not F.Bool(UnitExists(tt)) or not F.Bool(UnitIsFriend("player", tt)) then return false end
	-- nur du, deine Gruppe/dein Raid und deren Begleiter - keine fremden Spieler
	if F.Bool(UnitIsUnit(tt, "player")) or F.Bool(UnitInParty(tt)) or F.Bool(UnitInRaid(tt))
		or F.Bool(UnitIsUnit(tt, "pet")) then
		return true
	end
	for i = 1, 4 do
		if F.Bool(UnitIsUnit(tt, "partypet" .. i)) then return true end
	end
	return false
end

-- Kampflog-Verfolgung (nur wo es ein Kampflog gibt): Wer zuletzt mit uns/der Gruppe Schaden/Zauber
-- getauscht hat, gilt 20 s als im Kampf - unabhaengig davon, ob er Ziel ist oder Threat liefert.
F.recent = {}
local RECENT_SECS = 20
if F.HasCombatLog then
	F:On("COMBAT_LOG_EVENT_UNFILTERED", function()
		local _, sub, _, sGUID, _, sFlags, _, dGUID, _, dFlags = CombatLogGetCurrentEventInfo()
		if not sGUID or not dGUID or not sub then return end
		if sub == "UNIT_DIED" or sub == "PARTY_KILL" or sub == "UNIT_DESTROYED" then
			F.recent[dGUID] = nil
			return
		end
		if sub:find("^ENVIRONMENTAL") then return end
		sFlags, dFlags = sFlags or 0, dFlags or 0
		if bit.band(sFlags, 7) > 0 and bit.band(dFlags, 0x40) > 0 then
			F.recent[dGUID] = GetTime()
		elseif bit.band(dFlags, 7) > 0 and bit.band(sFlags, 0x40) > 0 then
			F.recent[sGUID] = GetTime()
		end
	end)
end

-- Gegner, der gegen uns oder unsere Gruppe kaempft (oder alle feindlichen, wenn showAll).
function F.IsEngaged(unit, strict)
	if not F.Bool(UnitExists(unit)) then return false end
	local dead = UnitIsDeadOrGhost(unit)
	if F.Readable(dead) and dead then return false end
	if not F.Bool(UnitCanAttack("player", unit)) then return false end
	if F.db.enemy.showAll and not strict then return true end
	local guid = UnitGUID(unit)
	local t = F.Readable(guid) and guid and F.recent[guid]
	if t then
		if GetTime() - t < RECENT_SECS then return true end
		F.recent[guid] = nil
	end
	if not F.Bool(UnitAffectingCombat(unit)) then return false end
	local _, status = F.GetThreat(unit)
	if status ~= nil then return true end
	return IsFriendlyGroupUnit(unit .. "target")
end

function F.EnumerateEnemies()
	local list, seen = {}, {}
	local function add(unit)
		if unit and F.IsEngaged(unit) then
			local guid = UnitGUID(unit)
			if not F.Readable(guid) then guid = nil end
			if not guid or not seen[guid] then
				if guid then seen[guid] = true end
				list[#list + 1] = unit
			end
		end
	end
	-- Unit-Tokens direkt abfragen (C_NamePlate.GetNamePlates liefert nicht in jedem Client brauchbare Daten).
	for i = 1, 40 do add("nameplate" .. i) end
	add("target")
	add("focus")
	for i = 1, 4 do add("party" .. i .. "target") end
	return list
end

------------------------------------------------------------------------
-- Verschiebbare Frames
------------------------------------------------------------------------
-- Skalierung: Gesamtfaktor mal Faktor des einzelnen Frames. Positionen sind in UIParent-Einheiten gespeichert
-- (Mitte des Frames), daher bleibt die Mitte beim Skalieren an Ort und Stelle.
function F.GetScale(key)
	local s = (F.db.scale or 1) * ((F.db.scales and F.db.scales[key]) or 1)
	return math.max(0.4, math.min(2.5, s))
end

local function Place(frame, m)
	local p = F.db.pos[m.key]
	local x = p and p.x or m.defX
	local y = p and p.y or m.defY
	local s = F.GetScale(m.key)
	frame:SetScale(s)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", x / s, y / s)
end

-- Alle Einstellungen loeschen; beim naechsten Laden gelten wieder die Standardwerte
function F.ResetAll()
	if InCombatLockdown() then F.Print("Im Kampf nicht moeglich.") return end
	for k in pairs(F.db) do F.db[k] = nil end
	ReloadUI()
end

function F.ApplyScale()
	if InCombatLockdown() then F.Print("Im Kampf nicht moeglich.") return end
	for _, m in ipairs(F.movables) do
		Place(m.frame, m)
		local ov = m.overlay
		if ov and ov:IsShown() then
			local s = F.GetScale(m.key)
			ov:SetSize(math.max(m.frame:GetWidth() * s, 40), math.max(m.frame:GetHeight() * s, 24))
			local cx, cy = ov:GetCenter()
			if cx and cy then ov:UpdateCoords(cx - UIParent:GetWidth() / 2, cy - UIParent:GetHeight() / 2) end
		end
	end
end

function F:MakeMovable(frame, key, label, defX, defY)
	local m = { frame = frame, key = key, label = label, defX = defX, defY = defY }
	table.insert(self.movables, m)
	if not InCombatLockdown() then Place(frame, m) end
	return m
end

local function CreateOverlay(m)
	local ov = CreateFrame("Frame", nil, UIParent)
	ov:SetFrameStrata("FULLSCREEN_DIALOG")
	ov:SetClampedToScreen(true)
	ov:SetMovable(true)
	ov:EnableMouse(true)
	ov:RegisterForDrag("LeftButton")
	local t = ov:CreateTexture(nil, "BACKGROUND")
	t:SetAllPoints()
	t:SetTexture(F.WHITE)
	t:SetVertexColor(0.2, 0.6, 1, 0.4)
	local fs = F.CreateText(ov, 12, "CENTER")
	fs:SetPoint("CENTER", 0, 7)
	fs:SetText(m.label)
	-- Koordinaten: linke obere Ecke, Ursprung unten links (X nach rechts, Y nach oben)
	local cs = F.CreateText(ov, 11, "CENTER")
	cs:SetPoint("CENTER", 0, -7)
	cs:SetTextColor(1, 0.82, 0.35)
	function ov:UpdateCoords(x, y)
		local w, h = self:GetSize()
		local left = UIParent:GetWidth() / 2 + x - w / 2
		local top = UIParent:GetHeight() / 2 + y + h / 2
		cs:SetText(string.format("X %d   Y %d", math.floor(left + 0.5), math.floor(top + 0.5)))
	end
	ov:SetScript("OnDragStart", function(self)
		local cx, cy = GetCursorPosition()
		local es = UIParent:GetEffectiveScale()
		local ux, uy = UIParent:GetCenter()
		local fx, fy = self:GetCenter()
		self.drag = { cx = cx / es, cy = cy / es, x = fx - ux, y = fy - uy }
		self.curX, self.curY = self.drag.x, self.drag.y
	end)
	ov:SetScript("OnUpdate", function(self)
		local d = self.drag
		if not d then return end
		local cx, cy = GetCursorPosition()
		local es = UIParent:GetEffectiveScale()
		local x = d.x + (cx / es - d.cx)
		local y = d.y + (cy / es - d.cy)
		local g = F.db.grid
		if g.enabled and not IsAltKeyDown() then
			-- linke obere Ecke auf das Raster legen (Alt gedrueckt halten = frei verschieben)
			local w, h = self:GetSize()
			local size = g.size
			local left = math.floor((x - w / 2) / size + 0.5) * size
			local top = math.floor((y + h / 2) / size + 0.5) * size
			x, y = left + w / 2, top - h / 2
		end
		self.curX, self.curY = x, y
		self:ClearAllPoints()
		self:SetPoint("CENTER", UIParent, "CENTER", x, y)
		self:UpdateCoords(x, y)
	end)
	ov:SetScript("OnDragStop", function(self)
		if not self.drag then return end
		F.db.pos[m.key] = { x = self.curX, y = self.curY }
		self.drag = nil
		if not InCombatLockdown() then Place(m.frame, m) end
	end)
	ov:Hide()
	m.overlay = ov
end

-- Raster beim Verschieben: duenne Linien im Abstand g.size, Mittellinien golden.
local gridFrame, gridLines = nil, {}

function F:UpdateGrid()
	local want = F.unlocked and F.db.grid.enabled
	if not want then
		if gridFrame then gridFrame:Hide() end
		return
	end
	if not gridFrame then
		gridFrame = CreateFrame("Frame", nil, UIParent)
		gridFrame:SetAllPoints(UIParent)
		gridFrame:SetFrameStrata("FULLSCREEN")
	end
	local size = math.max(8, F.db.grid.size)
	local W, H = UIParent:GetWidth(), UIParent:GetHeight()
	local used = 0
	local function line(vertical, k)
		used = used + 1
		local t = gridLines[used]
		if not t then
			t = gridFrame:CreateTexture(nil, "BACKGROUND")
			t:SetTexture(F.WHITE)
			gridLines[used] = t
		end
		t:ClearAllPoints()
		if vertical then
			t:SetSize(1, H)
			t:SetPoint("CENTER", UIParent, "CENTER", k * size, 0)
		else
			t:SetSize(W, 1)
			t:SetPoint("CENTER", UIParent, "CENTER", 0, k * size)
		end
		if k == 0 then t:SetVertexColor(1, 0.82, 0.35, 0.45) else t:SetVertexColor(1, 1, 1, 0.1) end
		t:Show()
	end
	for k = -math.floor(W / 2 / size), math.floor(W / 2 / size) do line(true, k) end
	for k = -math.floor(H / 2 / size), math.floor(H / 2 / size) do line(false, k) end
	for i = used + 1, #gridLines do gridLines[i]:Hide() end
	gridFrame:Show()
end

function F:SetLocked(locked)
	if not locked and InCombatLockdown() then
		F.Print("Im Kampf nicht moeglich.")
		return
	end
	F.unlocked = not locked
	for _, m in ipairs(F.movables) do
		if not m.overlay then CreateOverlay(m) end
		local ov = m.overlay
		if F.unlocked then
			local p = F.db.pos[m.key]
			local sc = F.GetScale(m.key)
				ov:SetSize(math.max(m.frame:GetWidth() * sc, 40), math.max(m.frame:GetHeight() * sc, 24))
			ov:ClearAllPoints()
			ov:SetPoint("CENTER", UIParent, "CENTER", p and p.x or m.defX, p and p.y or m.defY)
			ov:UpdateCoords(p and p.x or m.defX, p and p.y or m.defY)
			ov:Show()
		else
			ov.drag = nil
			ov:Hide()
		end
	end
	F:UpdateGrid()
	if F.unlocked then
		F.Print("Frames entsperrt - per Drag verschieben" .. (F.db.grid.enabled and " (Raster aktiv, Alt = frei)" or "") .. ", danach /fray lock.")
	else
		F.Print("Frames gesperrt.")
	end
end

function F:ResetPositions()
	if InCombatLockdown() then F.Print("Im Kampf nicht moeglich.") return end
	wipe(F.db.pos)
	for _, m in ipairs(F.movables) do Place(m.frame, m) end
	F.Print("Positionen zurueckgesetzt.")
end

F:On("PLAYER_REGEN_DISABLED", function()
	if F.unlocked then
		for _, m in ipairs(F.movables) do
			if m.overlay then m.overlay:Hide() end
		end
		F.unlocked = false
		F:UpdateGrid()
		F.Print("Kampf: Frames wurden gesperrt.")
	end
end)

------------------------------------------------------------------------
-- Start
------------------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == ADDON then
		FRAYDB = FRAYDB or {}
		Merge(FRAYDB, defaults)
		F.db = FRAYDB
	elseif event == "PLAYER_LOGIN" then
		for _, name in ipairs(F.order) do
			local m = F.modules[name]
			local ok, err = pcall(function()
				if m.Init then m:Init() end
				if m.SetEnabled then m:SetEnabled(F:IsEnabled(name)) end
			end)
			if not ok then F.Print("Fehler in Modul '" .. name .. "': " .. tostring(err)) end
		end
		F.ready = true
		F.Print("v" .. F.version .. " geladen. /fray oeffnet die Einstellungen.")
	end
end)


------------------------------------------------------------------------
-- Diagnose fuer andere Clients (z. B. Forever): zeigt, welche Funktionen es gibt und welche Werte der
-- Client "geheim" (Secret Value) macht. /fray probe - am besten einmal ohne und einmal im Kampf ausfuehren.
------------------------------------------------------------------------
local function Val(v)
	if v == nil then return "nil" end
	if canaccessvalue and not canaccessvalue(v) then return "GEHEIM" end
	if type(v) == "number" then return string.format("%.2f", v) end
	return tostring(v)
end

function F.Probe()
	local function line(...) print("  " .. string.format(...)) end
	local ver, build, _, toc = GetBuildInfo()
	F.Print(string.format("Probe: Version %s, Build %s, Interface %s, Kampf=%s, Gruppe=%s",
		tostring(ver), tostring(build), tostring(toc), tostring(InCombatLockdown()), tostring(F.InGroup())))
	local apis = {
		"canaccessvalue", "issecretvalue", "UnitHealthPercent", "CurveConstants", "UnitCastingDuration",
		"UnitDetailedThreatSituation", "UnitThreatSituation", "CombatLogGetCurrentEventInfo", "C_NamePlate",
		"C_Timer", "C_Container", "C_Spell", "GetSpellCooldown", "SetPortraitTexture", "UnitGUID",
	}
	local have = {}
	for _, n in ipairs(apis) do have[#have + 1] = n .. "=" .. (_G[n] ~= nil and "ja" or "NEIN") end
	line("API: %s", table.concat(have, " "))
	local units = { "player", "target", "nameplate1", "nameplate2", "nameplate3" }
	for _, u in ipairs(units) do
		if UnitExists(u) then
			local function try(fn, ...)
				if not fn then return "fehlt" end
				local ok, a, b, c, d = pcall(fn, ...)
				if not ok then return "FEHLER" end
				if select("#", ...) >= 0 and (b ~= nil or c ~= nil or d ~= nil) then
					return Val(a) .. "/" .. Val(b) .. "/" .. Val(c) .. "/" .. Val(d)
				end
				return Val(a)
			end
			line("%s: Name=%s HP=%s/%s GUID=%s Kampf=%s Feind=%s Ich=%s",
				u, try(UnitName, u), try(UnitHealth, u), try(UnitHealthMax, u), try(UnitGUID, u),
				try(UnitAffectingCombat, u), try(UnitCanAttack, "player", u), try(UnitIsUnit, u, "player"))
			if u ~= "player" then
				line("   Threat(%s)=%s  Ziel-von=%s  Cast=%s  Raidmarker=%s",
					u, try(UnitDetailedThreatSituation, "player", u), try(UnitExists, u .. "target"),
					try(UnitCastingInfo, u), try(GetRaidTargetIndex, u))
				if UnitHealthPercent then
					line("   HP-Prozent=%s", try(UnitHealthPercent, u, true, CurveConstants and CurveConstants.ScaleTo100))
				end
			end
		end
	end
	if C_NamePlate and C_NamePlate.GetNamePlates then
		local ok, plates = pcall(C_NamePlate.GetNamePlates)
		line("Plakettenliste: %s", ok and tostring(#plates) or "FEHLER")
	end
	F.Print("Probe Ende. Bitte den Chat-Text (auch ohne Kampf/mit Kampf) kopieren oder abfotografieren.")
end

------------------------------------------------------------------------
-- Slash-Befehle
------------------------------------------------------------------------
local function ToggleOption(tbl, key, label)
	tbl[key] = not tbl[key]
	F.Print(label .. ": " .. (tbl[key] and "an" or "aus"))
end

local function Help()
	F.Print("Befehle:")
	print("  /fray unlock | lock       - Frames verschieben")
	print("  /fray grid [on|off|<px>]  - Raster beim Verschieben (ohne Argument umschalten, Alt = frei)")
	print("  /fray reset               - Positionen zuruecksetzen")
	print("  /fray toggle <modul>      - Modul an/aus (" .. table.concat(MODULE_NAMES, ", ") .. ")")
	print("  /fray tank                - Tank-Modus (Threat-Farben/Warnungen invertiert)")
	print("  /fray all                 - Gegnerliste: alle feindlichen Einheiten statt nur Kampf")
	print("  /fray plates              - Gegner-Namensplaketten aktivieren")
	print("  /fray opt <name>          - Option umschalten: autosell, autorepair, lowhp, onlyhostile")
	print("  /fray cd add|remove|list|clear <Zauber/ID | slot:13 | item:ID>")
	print("  /fray test                - Testanzeige")
end

SLASH_FRAY1 = "/fray"
SlashCmdList["FRAY"] = function(msg)
	if not F.db then return end
	local cmd, rest = (msg or ""):match("^(%S*)%s*(.-)$")
	cmd = cmd:lower()
	if cmd == "" or cmd == "config" or cmd == "optionen" then
		local o = F.modules.options
		if o and o.Toggle then o:Toggle() end
	elseif cmd == "unlock" then
		F:SetLocked(false)
	elseif cmd == "lock" then
		F:SetLocked(true)
	elseif cmd == "grid" then
		local arg = rest:lower()
		local g = F.db.grid
		local n = tonumber(arg)
		if n then
			g.size = math.max(8, math.min(100, math.floor(n)))
			g.enabled = true
		elseif arg == "on" then
			g.enabled = true
		elseif arg == "off" then
			g.enabled = false
		else
			g.enabled = not g.enabled
		end
		F.Print("Raster: " .. (g.enabled and ("an, " .. g.size .. " px") or "aus"))
		F:UpdateGrid()
	elseif cmd == "reset" then
		F:ResetPositions()
	elseif cmd == "tank" then
		ToggleOption(F.db, "tank", "Tank-Modus")
	elseif cmd == "all" then
		ToggleOption(F.db.enemy, "showAll", "Alle feindlichen Einheiten anzeigen")
	elseif cmd == "plates" then
		if InCombatLockdown() then F.Print("Im Kampf nicht moeglich.") return end
		SetCVar("nameplateShowEnemies", 1)
		F.Print("Gegner-Namensplaketten aktiviert.")
	elseif cmd == "toggle" then
		local name = rest:lower()
		if F.db.modules[name] == nil then
			F.Print("Unbekanntes Modul. Moeglich: " .. table.concat(MODULE_NAMES, ", "))
		elseif InCombatLockdown() then
			F.Print("Im Kampf nicht moeglich.")
		else
			F.db.modules[name] = not F.db.modules[name]
			local m = F.modules[name]
			if m and m.SetEnabled then m:SetEnabled(F.db.modules[name]) end
			F.Print(name .. ": " .. (F.db.modules[name] and "an" or "aus"))
		end
	elseif cmd == "opt" then
		local o = rest:lower()
		if o == "autosell" then ToggleOption(F.db.qol, "autoSell", "Muell automatisch verkaufen")
		elseif o == "autorepair" then ToggleOption(F.db.qol, "autoRepair", "Automatisch reparieren")
		elseif o == "lowhp" then ToggleOption(F.db.alerts, "lowHealth", "Warnung bei niedrigen HP")
		elseif o == "onlyhostile" then ToggleOption(F.db.cast, "onlyHostile", "Cast-Bars nur fuer Gegner")
		else Help() end
	elseif cmd == "cd" then
		local m = F.modules.cooldowns
		if m and m.Command then m:Command(rest) end
	elseif cmd == "atlas" then
		F.AtlasReport()
	elseif cmd == "probe" then
		F.Probe()
	elseif cmd == "debug" then
		local m = F.modules.enemy
		if m and m.Debug then m:Debug() end
	elseif cmd == "test" then
		if F.modules.alerts and F.modules.alerts.Alert then
			F.modules.alerts:Alert("Aggro!", "%s", "red", "soundGain", "Testgegner")
		end
		if F.modules.float and F.modules.float.Test then F.modules.float:Test() end
		for _, name in ipairs({ "enemy" }) do
			local m = F.modules[name]
			if m and m.StartDemo and F:IsEnabled(name) then m:StartDemo(20) end
		end
		F.Print("Testmodus: Platzhalter-Listen fuer 20 Sekunden.")
	else
		Help()
	end
end
