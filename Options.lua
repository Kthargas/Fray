local ADDON, F = ...
local M = { settings = {} }
F:RegisterModule("options", M)

-- Options in Blizzard's own settings window (Esc > Options > AddOns > Fray), built only from the stock
-- Settings controls so they look and behave like every other game option. /fray opens them.
--
-- Taint: the settings list reuses its control frames for every category. A button control first shown
-- for an addon page stays tainted, and when Blizzard later reuses it for one of its own buttons (e.g. the
-- Discord button under Social) that button gets blocked. So all action buttons live on a separate
-- "Actions" page, with frames that belong to Fray alone.

------------------------------------------------------------------------
-- Building blocks
------------------------------------------------------------------------
local function Percent(v) return math.floor(v * 100 + 0.5) .. " %" end
local function Pct(v) return math.floor(v + 0.5) .. " %" end
local function Px(v) return math.floor(v + 0.5) .. " px" end
local function Sec(v) return (math.floor(v * 10 + 0.5) / 10) .. " s" end

-- A setting backed by any getter/setter (all values live in FRAYDB)
function M:Proxy(category, id, varType, name, default, get, set)
	local setting = Settings.RegisterProxySetting(category, "FRAY_" .. id:upper(), varType, name, default, get, set)
	self.settings[#self.settings + 1] = setting
	return setting
end

-- Shortcut for F.db[tbl][key]
local function Field(tbl, key, after)
	return function() return F.db[tbl][key] end,
		function(v) F.db[tbl][key] = v; if after then after(v) end end
end

function M:Checkbox(category, id, name, tooltip, default, get, set)
	local s = self:Proxy(category, id, Settings.VarType.Boolean, name, default, get, set)
	return Settings.CreateCheckbox(category, s, tooltip)
end

function M:Slider(category, id, name, tooltip, default, get, set, minV, maxV, step, fmt)
	local s = self:Proxy(category, id, Settings.VarType.Number, name, default, get, set)
	local o = Settings.CreateSliderOptions(minV, maxV, step)
	o:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, fmt or function(v) return tostring(math.floor(v + 0.5)) end)
	return Settings.CreateSlider(category, s, o, tooltip)
end

function M:Dropdown(category, id, name, tooltip, default, get, set, list)
	local s = self:Proxy(category, id, Settings.VarType.String, name, default, get, set)
	local function options()
		local c = Settings.CreateControlTextContainer()
		for _, item in ipairs(list) do c:Add(item.key, item.name) end
		return c:GetData()
	end
	return Settings.CreateDropdown(category, s, options, tooltip)
end

local function Header(layout, text)
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
end

local function DependsOn(child, parent, predicate)
	if child and parent and child.SetParentInitializer then child:SetParentInitializer(parent, predicate) end
end

local function Module(name)
	return function() return F.db.modules[name] end,
		function(v)
			F.db.modules[name] = v
			local m = F.modules[name]
			if m and m.SetEnabled then m:SetEnabled(v) end
		end
end

-- Size of a single frame (factor); works together with the overall scale
function M:Scale(category, key, name)
	return self:Slider(category, "scale_" .. key, name, "Size of this element, on top of the overall size.", 1,
		function() return (F.db.scales and F.db.scales[key]) or 1 end,
		function(v) F.db.scales = F.db.scales or {}; F.db.scales[key] = v; F.ApplyScale() end,
		0.5, 2, 0.05, Percent)
end

------------------------------------------------------------------------
-- Pages
------------------------------------------------------------------------
function M:BuildGeneral(cat, layout)
	Header(layout, "Role")
	self:Checkbox(cat, "tank", "Tank mode", "Threat colours and alerts for tanks: holding aggro is good, losing it is bad.", false,
		function() return F.db.tank end, function(v) F.db.tank = v end)

	Header(layout, "Appearance")
	self:Slider(cat, "scale", "Overall size", "Size of all Fray elements.", 1,
		function() return F.db.scale or 1 end, function(v) F.db.scale = v; F.ApplyScale() end, 0.5, 1.5, 0.05, Percent)
	local styles = {}
	for _, k in ipairs(F.RIM_ORDER) do styles[#styles + 1] = { key = k, name = F.RIM[k].name } end
	self:Dropdown(cat, "frameStyle", "Frame colour", "Colour of the frames around bars and plates.", "bronze",
		function() return F.db.frameStyle or "bronze" end, function(v) F.db.frameStyle = v; F.ApplyFrameStyle() end, styles)

	Header(layout, "Arrange frames")
	local gridInit = self:Checkbox(cat, "grid", "Snap to grid", "Frames snap to a grid while you move them. Hold Alt for free placement.", true,
		Field("grid", "enabled", function() F:UpdateGrid() end))
	local g, s = Field("grid", "size", function() F:UpdateGrid() end)
	DependsOn(self:Slider(cat, "gridSize", "Grid size", nil, 10, g, s, 8, 60, 2, Px), gridInit, function() return F.db.grid.enabled end)
	self:Checkbox(cat, "minimap", "Minimap button", "Left click: settings. Right click: unlock/lock frames.", true,
		function() return not F.db.minimap.hide end,
		function(v) F.db.minimap.hide = not v; local m = F.modules.minimap; if m then m:Refresh() end end)
end

function M:BuildEnemy(cat, layout)
	Header(layout, "Display")
	local on = self:Checkbox(cat, "mod_enemy", "Show enemy list", nil, true, Module("enemy"))
	local function Enabled() return F.db.modules.enemy end
	local function Dep(init) DependsOn(init, on, Enabled) return init end
	local g, s
	g, s = Field("enemy", "showAll")
	Dep(self:Checkbox(cat, "showAll", "Show all hostile enemies", "Also list hostile units that are not in combat.", false, g, s))
	Dep(self:Scale(cat, "enemy", "Enemy list size"))
	g, s = Field("enemy", "perCol", function()
		local m = F.modules.enemy
		if m and m.ApplyLayout then m:ApplyLayout() end
	end)
	Dep(self:Slider(cat, "perCol", "Enemies per column", nil, 6, g, s, 3, 9, 1))
	g, s = Field("enemy", "maxRows")
	Dep(self:Slider(cat, "maxRows", "Maximum number of enemies", nil, 12, g, s, 3, 18, 1))
	g, s = Field("enemy", "sort")
	Dep(self:Dropdown(cat, "sort", "Sorting", nil, "pull", g, s, {
		{ key = "pull", name = "By pull order" }, { key = "threat", name = "By threat" }, { key = "name", name = "By name" } }))
	Dep(self:Checkbox(cat, "plateWarn", "Warn when enemy nameplates are off", "The list is built from enemy nameplates.", true,
		function() return F.db.enemy.plateWarn ~= false end, function(v) F.db.enemy.plateWarn = v end))

	Header(layout, "Shown elements")
	for _, row in ipairs({
		{ "showPercent", "Health percent" },
		{ "showPower", "Resource bar", "Mana, rage or energy." },
		{ "showMarker", "Raid markers" },
		{ "showElite", "Elite / rare icons" },
		{ "showShield", "Aggro shield" },
	}) do
		g, s = Field("enemy", row[1])
		Dep(self:Checkbox(cat, row[1], row[2], row[3], true, g, s))
	end

	Header(layout, "Aggro indicator")
	g, s = Field("enemy", "threatOrange")
	Dep(self:Slider(cat, "threatOrange", "Orange from threat",
		"Red: you have aggro. Orange: high threat or aggro just lost. Green: little threat.", 50, g, s, 20, 90, 5, Pct))
end

function M:BuildCast(cat, layout)
	Header(layout, "Cast bars for target and focus")
	local on = self:Checkbox(cat, "mod_cast", "Show cast bars", nil, true, Module("cast"))
	local function Enabled() return F.db.modules.cast end
	local function Dep(init) DependsOn(init, on, Enabled) return init end
	local g, s
	g, s = Field("cast", "target")
	Dep(self:Checkbox(cat, "castTarget", "Target cast bar", nil, true, g, s))
	g, s = Field("cast", "focus")
	Dep(self:Checkbox(cat, "castFocus", "Focus cast bar", nil, true, g, s))
	Dep(self:Scale(cat, "castTarget", "Target cast bar size"))
	Dep(self:Scale(cat, "castFocus", "Focus cast bar size"))

	Header(layout, "Whose casts")
	g, s = Field("cast", "onlyHostile")
	Dep(self:Checkbox(cat, "onlyHostile", "Enemies only", "Only show casts of units you can attack.", false, g, s))
	Dep(self:Checkbox(cat, "hideGroup", "Hide casts of your group",
		"No cast bar when your target or focus is you, a party or raid member, or one of their pets.", true,
		function() return F.db.cast.hideGroup ~= false end, function(v) F.db.cast.hideGroup = v end))

	Header(layout, "Display")
	g, s = Field("cast", "showIcon")
	Dep(self:Checkbox(cat, "showIcon", "Spell icon", nil, true, g, s))
	g, s = Field("cast", "showTime")
	Dep(self:Checkbox(cat, "showTime", "Remaining time", nil, true, g, s))
end

function M:BuildAlerts(cat, layout)
	local A = F.modules.alerts
	local sounds = {}
	for _, snd in ipairs(A and A.SOUNDS or {}) do sounds[#sounds + 1] = { key = snd.key, name = snd.name } end
	local g, s

	Header(layout, "Messages")
	local on = self:Checkbox(cat, "mod_alerts", "Show alerts",
		"Aggro and threat alerts use the client's threat values; where they are hidden (nameplates in combat) only 'enemy is targeting you' counts.",
		true, Module("alerts"))
	local function Enabled() return F.db.modules.alerts end
	local function Dep(init, parent, pred)
		DependsOn(init, parent or on, function() return Enabled() and (not pred or pred()) end)
		return init
	end
	g, s = Field("alerts", "sound")
	local soundOn = Dep(self:Checkbox(cat, "sound", "Alert sounds", "Master switch for all alert sounds.", true, g, s))
	local function Sound(id, name, default)
		local get, set = Field("alerts", id, function(v) if A then A.PlaySound(v) end end)
		return Dep(self:Dropdown(cat, id, name, "Choosing a sound plays it as a preview.", default, get, set, sounds),
			soundOn, function() return F.db.alerts.sound end)
	end

	Header(layout, "When should alerts appear?")
	g, s = Field("alerts", "gain")
	local gain = Dep(self:Checkbox(cat, "gain", "Aggro gained", "An enemy attacks you.", true, g, s))
	g, s = Field("alerts", "gainTank")
	Dep(self:Checkbox(cat, "gainTank", "Aggro gained, also in tank mode", nil, false, g, s), gain, function() return F.db.alerts.gain end)
	Sound("soundGain", "Sound: aggro gained", "raid")
	g, s = Field("alerts", "loss")
	Dep(self:Checkbox(cat, "loss", "Aggro lost", "An enemy switches its target away from you.", true, g, s))
	Sound("soundLoss", "Sound: aggro lost", "alarm")
	g, s = Field("alerts", "tankWarn")
	Dep(self:Checkbox(cat, "tankWarn", "Tank: an enemy attacks a party member", nil, true, g, s))
	g, s = Field("alerts", "threatHigh")
	local high = Dep(self:Checkbox(cat, "threatHigh", "High threat", "Only where the client makes threat readable.", true, g, s))
	g, s = Field("alerts", "threatPct")
	Dep(self:Slider(cat, "threatPct", "High threat from", nil, 90, g, s, 60, 100, 5, Pct), high, function() return F.db.alerts.threatHigh end)
	Sound("soundThreat", "Sound: high threat", "boss")
	g, s = Field("alerts", "lowHealth")
	local low = Dep(self:Checkbox(cat, "lowHealth", "Low health", "Only where the client makes health readable.", true, g, s))
	g, s = Field("alerts", "lowHealthPct")
	Dep(self:Slider(cat, "lowHealthPct", "Health threshold", nil, 25, g, s, 10, 60, 5, Pct), low, function() return F.db.alerts.lowHealth end)
	Sound("soundLow", "Sound: low health", "alarm")

	Header(layout, "Conditions")
	g, s = Field("alerts", "onlyInGroup")
	Dep(self:Checkbox(cat, "onlyInGroup", "Only in a group", nil, true, g, s))
	g, s = Field("alerts", "onlyInCombat")
	Dep(self:Checkbox(cat, "onlyInCombat", "Only in combat", nil, true, g, s))
	g, s = Field("alerts", "pause")
	Dep(self:Slider(cat, "pause", "Pause per enemy", "Minimum time between two alerts for the same enemy.", 8, g, s, 2, 30, 1, Sec))

	Header(layout, "Appearance")
	g, s = Field("alerts", "hold")
	Dep(self:Slider(cat, "hold", "Display duration", nil, 2.6, g, s, 1, 8, 0.5, Sec))
	g, s = Field("alerts", "textSize")
	Dep(self:Slider(cat, "textSize", "Font size", nil, 24, g, s, 16, 40, 2, Px))
	Dep(self:Scale(cat, "alert", "Alert size"))
	g, s = Field("alerts", "showName")
	Dep(self:Checkbox(cat, "showName", "Show enemy names", nil, true, g, s))
end

------------------------------------------------------------------------
-- Actions page (own frames, see the taint note at the top)
------------------------------------------------------------------------
local function AlertTest(title, sub, kind, snd, ...)
	local A = F.modules.alerts
	if A and A.Alert then A:Alert(title, sub, kind, snd, ...) end
end

function M:CreateActionsPanel()
	local panel = CreateFrame("Frame")
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
	title:SetPoint("TOPLEFT", 7, -22)
	title:SetText("Actions")
	local divider = panel:CreateTexture(nil, "ARTWORK")
	divider:SetAtlas("Options_HorizontalDivider", true)
	divider:SetPoint("TOP", 0, -50)

	local y = -70
	local function Section(text)
		local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
		fs:SetPoint("TOPLEFT", 7, y - 6)
		fs:SetText(text)
		y = y - 36
	end
	local function Row(label, buttonText, desc, fn)
		local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		fs:SetPoint("TOPLEFT", 37, y)
		fs:SetText(label)
		local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		b:SetSize(200, 26)
		b:SetPoint("TOPLEFT", panel, "TOPLEFT", 300, y + 6)
		b:SetText(buttonText)
		b:SetScript("OnClick", fn)
		if desc then
			local d = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			d:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -6)
			d:SetPoint("RIGHT", b, "LEFT", -12, 0)
			d:SetJustifyH("LEFT")
			d:SetText(desc)
			y = y - 52
		else
			y = y - 36
		end
		return b
	end

	Section("Frames")
	local lock = Row("Move frames", "Unlock frames", "Drag the overlays to move Fray's frames. Hold Alt for free placement.", function(b)
		if InCombatLockdown() then F.Print("Not possible in combat.") return end
		F:SetLocked(F.unlocked)
		b:SetText(F.unlocked and "Lock frames" or "Unlock frames")
	end)
	Row("Reset positions", "Reset", nil, function() F:ResetPositions() end)
	Row("Test mode", "Start (20 seconds)", "Placeholder enemy list and a test alert.", function() SlashCmdList["FRAY"]("test") end)

	Section("Test alerts")
	Row("Aggro gained", "Test", nil, function() AlertTest("Aggro!", "%s", "red", "soundGain", "Test enemy") end)
	Row("Aggro lost", "Test", nil, function() AlertTest("Aggro lost", "%s  >  %s", "orange", "soundLoss", "Test enemy", "Party member") end)
	Row("High threat", "Test", nil, function() AlertTest("High threat", "%s  (%d%%)", "orange", "soundThreat", "Test enemy", 95) end)

	Section("Data")
	Row("Reset all settings", "Reset", "Deletes all Fray settings and reloads the interface.", function() StaticPopup_Show("FRAY_RESET_ALL") end)

	panel:SetScript("OnShow", function() lock:SetText(F.unlocked and "Lock frames" or "Unlock frames") end)
	return panel
end

StaticPopupDialogs["FRAY_RESET_ALL"] = {
	text = "Reset all Fray settings and reload the interface?",
	button1 = YES,
	button2 = NO,
	OnAccept = function() F.ResetAll() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

------------------------------------------------------------------------
-- Registration
------------------------------------------------------------------------
function M:Init()
	if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end

	local cat, layout = Settings.RegisterVerticalLayoutCategory("Fray")
	self.category = cat
	self:BuildGeneral(cat, layout)

	local function Sub(name, build)
		local sub, subLayout = Settings.RegisterVerticalLayoutSubcategory(cat, name)
		build(self, sub, subLayout)
		return sub
	end
	Sub("Enemy list", M.BuildEnemy)
	Sub("Cast bars", M.BuildCast)
	Sub("Alerts", M.BuildAlerts)

	Settings.RegisterAddOnCategory(cat)
	if Settings.RegisterCanvasLayoutSubcategory then
		self.actionsCategory = Settings.RegisterCanvasLayoutSubcategory(cat, self:CreateActionsPanel(), "Actions")
	end
end

-- Values changed elsewhere (slash commands): let open controls show the new state
function M:Refresh()
	for _, setting in ipairs(self.settings) do
		if setting.NotifyUpdate then setting:NotifyUpdate() end
	end
end

function M:Open()
	if self.category and Settings.OpenToCategory then
		Settings.OpenToCategory(self.category:GetID())
	else
		F.Print("This client has no AddOns settings page.")
	end
end

-- Kept for the minimap button and the slash command
function M:Toggle()
	if SettingsPanel and SettingsPanel:IsShown() then
		HideUIPanel(SettingsPanel)
	else
		M:Open()
	end
end
