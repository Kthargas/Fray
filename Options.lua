local ADDON, F = ...
local M = {}
F:RegisterModule("options", M)

-- Settings window in the style of the game UI: dark panel with a fine gold edge, tabs on the left,
-- content on the right. Open with /fray (or /fray config).
local PW, PH = 620, 560
local TABW = 150
local PAD = 22

local TITLE_GOLD = F.PAL.gold
local TEXT = F.PAL.text
local DIM = F.PAL.dim

local panel
local tabs, pages, widgets = {}, {}, {}

------------------------------------------------------------------------
-- Building blocks
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
	-- Offsets as in Blizzard's layout ButtonFrameTemplateNoPortrait: the art reaches beyond the frame
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

-- Blizzard's metal frame as the window frame (atlas); false if the client does not have it
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

-- Size of a single frame (percent); works together with the overall scale
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
-- Access to settings
------------------------------------------------------------------------
local function ModuleGet(name) return function() return F.db.modules[name] end end
local function ModuleSet(name)
	return function(v)
		if InCombatLockdown() then F.Print("Not possible in combat.") return end
		F.db.modules[name] = v
		local m = F.modules[name]
		if m and m.SetEnabled then m:SetEnabled(v) end
	end
end
-- Cycle a value (click = next entry); values = { { key = ..., name = ... }, ... }
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

-- Pick a sound (click cycles and plays the sound as a preview)
local function SoundCycle(page, label, optKey)
	local A = F.modules.alerts
	return Cycle(page, label, function() return F.db.alerts[optKey] end, function(v) F.db.alerts[optKey] = v end,
		A.SOUNDS, function(key) A.PlaySound(key) end)
end

local function Opt(tbl, key)
	return function() return F.db[tbl][key] end, function(v) F.db[tbl][key] = v end
end

------------------------------------------------------------------------
-- Pages
------------------------------------------------------------------------
local PAGES = {
	{ "General", function(p)
		Header(p, "Role")
		Checkbox(p, "Tank mode (threat colours and alerts for tanks)", function() return F.db.tank end, function(v) F.db.tank = v end)
		Header(p, "Appearance")
		Slider(p, "Overall size of all elements", 50, 150, 5,
			function() return math.floor((F.db.scale or 1) * 100 + 0.5) end,
			function(v) F.db.scale = v / 100; F.ApplyScale() end, function(v) return v .. " %" end)
		local function styleName() return (F.RIM[F.db.frameStyle] or F.RIM.bronze).name end
		local styleBtn
		styleBtn = Button(p, "Frame colour: " .. styleName(), function(b)
			local cur = 1
			for i, k in ipairs(F.RIM_ORDER) do if k == F.db.frameStyle then cur = i end end
			F.db.frameStyle = F.RIM_ORDER[cur % #F.RIM_ORDER + 1]
			b:SetLabel("Frame colour: " .. styleName())
			F.ApplyFrameStyle()
		end)
		Header(p, "Arrange frames")
		local lock
		lock = Button(p, "Unlock frames", function(b)
			F:SetLocked(F.unlocked)
			b:SetLabel(F.unlocked and "Lock frames" or "Unlock frames")
		end)
		Checkbox(p, "Snap to grid while moving (Alt = free)", function() return F.db.grid.enabled end,
			function(v) F.db.grid.enabled = v; F:UpdateGrid() end)
		Slider(p, "Grid size", 8, 60, 2, function() return F.db.grid.size end,
			function(v) F.db.grid.size = v; F:UpdateGrid() end, function(v) return v .. " px" end)
		Button(p, "Reset positions", function() F:ResetPositions() end)
		Checkbox(p, "Show minimap button", function() return not F.db.minimap.hide end,
			function(v) F.db.minimap.hide = not v; local m = F.modules.minimap; if m then m:Refresh() end end)
		Header(p, "Preview")
		Button(p, "Test mode (20 seconds)", function() SlashCmdList["FRAY"]("test") end)
		Header(p, "Data")
		Button(p, "Reset all settings", function(b)
			if not b.armed then
				b.armed = true
				b:SetLabel("Sure? Click again")
				if C_Timer and C_Timer.After then
					C_Timer.After(4, function() b.armed = false; b:SetLabel("Reset all settings") end)
				end
			else
				F.ResetAll()
			end
		end, 260)
	end },
	{ "Enemy list", function(p)
		Header(p, "Display")
		Checkbox(p, "Show enemy list", ModuleGet("enemy"), ModuleSet("enemy"))
		Checkbox(p, "Show all hostile enemies (even out of combat)", function() return F.db.enemy.showAll end,
			function(v) F.db.enemy.showAll = v end)
		ScaleSlider(p, "Enemy list size", "enemy")
		Slider(p, "Enemies per column", 3, 9, 1, function() return F.db.enemy.perCol end,
			function(v)
				F.db.enemy.perCol = v
				local m = F.modules.enemy
				if m and m.ApplyLayout then m:ApplyLayout() end
			end)
		Slider(p, "Maximum number of enemies", 3, 18, 1, function() return F.db.enemy.maxRows end,
			function(v) F.db.enemy.maxRows = v end)
		Cycle(p, "Sorting", function() return F.db.enemy.sort end, function(v) F.db.enemy.sort = v end,
			{ { key = "pull", name = "by pull order" }, { key = "threat", name = "by threat" }, { key = "name", name = "by name" } })
		Header(p, "Shown elements")
		local g, s
		g, s = Opt("enemy", "showPercent"); Checkbox(p, "Health percent", g, s)
		g, s = Opt("enemy", "showPower"); Checkbox(p, "Resource bar (mana, rage, energy)", g, s)
		g, s = Opt("enemy", "showMarker"); Checkbox(p, "Raid markers", g, s)
		g, s = Opt("enemy", "showElite"); Checkbox(p, "Elite / rare icons", g, s)
		g, s = Opt("enemy", "showShield"); Checkbox(p, "Aggro shield", g, s)
		Header(p, "Aggro indicator")
		Slider(p, "Orange from threat", 20, 90, 5, function() return F.db.enemy.threatOrange end,
			function(v) F.db.enemy.threatOrange = v end, function(v) return v .. " %" end)
		Hint(p, "Red: you have aggro.   Orange: high threat or aggro just lost.   Green: little threat.", 34)
	end },
	{ "Cast bars", function(p)
		Header(p, "Cast bars for target and focus")
		Checkbox(p, "Show cast bars", ModuleGet("cast"), ModuleSet("cast"))
		ScaleSlider(p, "Target cast bar size", "castTarget")
		ScaleSlider(p, "Focus cast bar size", "castFocus")
		local g, s = Opt("cast", "onlyHostile")
		Checkbox(p, "Enemies only", g, s)
		Header(p, "Display")
		g, s = Opt("cast", "target"); Checkbox(p, "Cast bar for the target", g, s)
		g, s = Opt("cast", "focus"); Checkbox(p, "Cast bar for the focus", g, s)
		g, s = Opt("cast", "showIcon"); Checkbox(p, "Spell icon", g, s)
		g, s = Opt("cast", "showTime"); Checkbox(p, "Remaining time", g, s)
	end },
	{ "Alerts", function(p)
		local g, s
		local function AlertTest(title, sub, kind, snd, ...)
			local A = F.modules.alerts
			if A and A.Alert then A:Alert(title, sub, kind, snd, ...) end
		end
		Header(p, "Messages")
		Checkbox(p, "Show alerts", ModuleGet("alerts"), ModuleSet("alerts"))
		g, s = Opt("alerts", "sound"); Checkbox(p, "Alert sounds (master switch)", g, s)
		Header(p, "When should alerts appear?")
		g, s = Opt("alerts", "gain"); Checkbox(p, "Aggro gained (an enemy attacks you)", g, s)
		g, s = Opt("alerts", "gainTank"); Checkbox(p, "... also in tank mode", g, s)
		SoundCycle(p, "Sound: aggro gained", "soundGain")
		g, s = Opt("alerts", "loss"); Checkbox(p, "Aggro lost (an enemy switches target)", g, s)
		SoundCycle(p, "Sound: aggro lost", "soundLoss")
		g, s = Opt("alerts", "tankWarn"); Checkbox(p, "Tank: an enemy attacks a party member", g, s)
		g, s = Opt("alerts", "threatHigh"); Checkbox(p, "High threat (only where threat is readable)", g, s)
		Slider(p, "From threat", 60, 100, 5, function() return F.db.alerts.threatPct end,
			function(v) F.db.alerts.threatPct = v end, function(v) return v .. " %" end)
		SoundCycle(p, "Sound: high threat", "soundThreat")
		g, s = Opt("alerts", "lowHealth"); Checkbox(p, "Low health (only where health is readable)", g, s)
		Slider(p, "Health threshold", 10, 60, 5, function() return F.db.alerts.lowHealthPct end,
			function(v) F.db.alerts.lowHealthPct = v end, function(v) return v .. " %" end)
		SoundCycle(p, "Sound: low health", "soundLow")
		Header(p, "Conditions")
		g, s = Opt("alerts", "onlyInGroup"); Checkbox(p, "Only in a group", g, s)
		g, s = Opt("alerts", "onlyInCombat"); Checkbox(p, "Only in combat", g, s)
		Slider(p, "Pause per enemy", 2, 30, 1, function() return F.db.alerts.pause end,
			function(v) F.db.alerts.pause = v end, function(v) return v .. " s" end)
		Header(p, "Appearance")
		Slider(p, "Display duration", 1, 8, 0.5, function() return F.db.alerts.hold end,
			function(v) F.db.alerts.hold = v end, function(v) return string.format("%.1f s", v) end)
		Slider(p, "Font size", 16, 40, 2, function() return F.db.alerts.textSize end,
			function(v) F.db.alerts.textSize = v end, function(v) return v .. " px" end)
		ScaleSlider(p, "Alert size", "alert")
		g, s = Opt("alerts", "showName"); Checkbox(p, "Show enemy names", g, s)
		Header(p, "Test")
		Button(p, "Aggro gained", function() AlertTest("Aggro!", "%s", "red", "soundGain", "Test enemy") end, 260)
		Button(p, "Aggro lost", function() AlertTest("Aggro lost", "%s  >  %s", "orange", "soundLoss", "Test enemy", "Party member") end, 260)
		Button(p, "High threat", function() AlertTest("High threat", "%s  (%d%%)", "orange", "soundThreat", "Test enemy", 95) end, 260)
		Hint(p, "Aggro and threat alerts use the client's threat values; where they are hidden (nameplates in combat) only 'enemy is targeting you' counts.", 34)
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
		-- the title is in the plaque; the version sits at the top left
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

	-- Divider under the title and between tabs and content
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

		-- Page in a scroll area (mouse wheel) in case the content does not fit
		local scroll = CreateFrame("ScrollFrame", nil, panel)
		-- The scroll area is 24 px larger all around than the content so the glow halo of the buttons is not cut off
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
