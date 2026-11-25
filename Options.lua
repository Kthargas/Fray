local ADDON, F = ...
local L = F.L
local O = { settings = {} }
F:RegisterModule("options", O)

-- Options in Blizzard's own settings window (Esc > Options > AddOns > Fray), built only from the stock
-- Settings controls so they look and behave like every other game option. Same layout as SquareMap:
-- the main page and its subpages hold the settings, the last subpage ("Actions") the buttons.

local function ListOptions(list)
	return function()
		local container = Settings.CreateControlTextContainer()
		for _, item in ipairs(list) do container:Add(item.key, item.label) end
		return container:GetData()
	end
end

-- A setting stored in F.db[section][field] (section nil: F.db[field]). onSet runs after the value changed.
function O:Proxy(category, section, field, varType, name, default, onSet)
	local variable = "FRAY_" .. (section and section:upper() .. "_" or "") .. field:upper()
	local function tbl() return section and F.db[section] or F.db end
	local setting = Settings.RegisterProxySetting(category, variable, varType, name, default,
		function()
			local value = tbl()[field]
			if value == nil then return default end
			return value
		end,
		function(value)
			tbl()[field] = value
			if onSet then onSet(value) end
		end)
	self.settings[#self.settings + 1] = setting
	return setting
end

function O:Checkbox(category, section, field, name, tooltip, default, onSet)
	local setting = self:Proxy(category, section, field, Settings.VarType.Boolean, name, default, onSet)
	return Settings.CreateCheckbox(category, setting, tooltip), setting
end

function O:Slider(category, section, field, name, tooltip, default, minValue, maxValue, step, formatter, onSet)
	local setting = self:Proxy(category, section, field, Settings.VarType.Number, name, default, onSet)
	local options = Settings.CreateSliderOptions(minValue, maxValue, step)
	options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, formatter or function(value)
		return tostring(math.floor(value + 0.5))
	end)
	return Settings.CreateSlider(category, setting, options, tooltip), setting
end

function O:Dropdown(category, section, field, name, tooltip, default, list, onSet)
	local setting = self:Proxy(category, section, field, Settings.VarType.String, name, default, onSet)
	return Settings.CreateDropdown(category, setting, ListOptions(list), tooltip), setting
end

local function Header(layout, text)
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
end

local function DependsOn(child, parent, predicate)
	if child and parent and child.SetParentInitializer then
		child:SetParentInitializer(parent, predicate)
	end
end

local function Percent(value) return L.PERCENT:format(math.floor(value * 100 + 0.5)) end
local function Pct(value) return L.PERCENT:format(math.floor(value + 0.5)) end
local function Px(value) return L.PIXELS:format(math.floor(value + 0.5)) end
local function Sec(value) return L.SECONDS:format(math.floor(value * 10 + 0.5) / 10) end

-- Module switch: F.db.modules[name], turns the module on or off right away
function O:Module(category, name, label, tooltip)
	return self:Checkbox(category, "modules", name, label, tooltip, true, function(value)
		local m = F.modules[name]
		if m and m.SetEnabled then m:SetEnabled(value) end
	end)
end

-- Size of a single frame (factor); works together with the overall scale
function O:Scale(category, key, name)
	return self:Slider(category, "scales", key, name, L.ELEMENT_SCALE_TT, 1, 0.5, 2, 0.05, Percent, F.ApplyScale)
end

------------------------------------------------------------------------
-- Pages
------------------------------------------------------------------------
function O:BuildGeneral(category, layout)
	Header(layout, L.SECTION_ROLE)
	self:Checkbox(category, nil, "tank", L.TANK, L.TANK_TT, false)

	Header(layout, L.SECTION_APPEARANCE)
	self:Slider(category, nil, "scale", L.SCALE, L.SCALE_TT, 1, 0.5, 1.5, 0.05, Percent, F.ApplyScale)
	-- Stored the other way round (minimap.hide), like LibDBIcon does.
	local minimap = Settings.RegisterProxySetting(category, "FRAY_MINIMAP_SHOW", Settings.VarType.Boolean, L.MINIMAP_BUTTON, true,
		function() return not F.db.minimap.hide end,
		function(value)
			F.db.minimap.hide = not value
			F.modules.minimap:Refresh()
		end)
	self.settings[#self.settings + 1] = minimap
	Settings.CreateCheckbox(category, minimap, L.MINIMAP_BUTTON_TT)

	Header(layout, L.SECTION_ARRANGE)
	local function Grid() F:UpdateGrid() end
	local gridInit = self:Checkbox(category, "grid", "enabled", L.GRID, L.GRID_TT, true, Grid)
	DependsOn(self:Slider(category, "grid", "size", L.GRID_SIZE, nil, 10, 8, 60, 2, Px, Grid), gridInit,
		function() return F.db.grid.enabled end)
end

function O:BuildEnemy(category, layout)
	Header(layout, L.SECTION_ENEMY)
	local on = self:Module(category, "enemy", L.ENEMY_ENABLE)
	local function Dep(init) DependsOn(init, on, function() return F.db.modules.enemy end) return init end
	Dep(self:Checkbox(category, "enemy", "showAll", L.SHOW_ALL, L.SHOW_ALL_TT, false))
	Dep(self:Checkbox(category, "enemy", "plateWarn", L.PLATE_WARN, L.PLATE_WARN_TT, true))

	Header(layout, L.SECTION_DISPLAY)
	Dep(self:Scale(category, "enemy", L.ENEMY_SCALE))
	Dep(self:Slider(category, "enemy", "perCol", L.PER_COL, nil, 6, 3, 9, 1, nil, function() F.modules.enemy:ApplyLayout() end))
	Dep(self:Slider(category, "enemy", "maxRows", L.MAX_ROWS, nil, 12, 3, 18, 1))
	Dep(self:Dropdown(category, "enemy", "sort", L.SORT, nil, "pull", {
		{ key = "pull", label = L.SORT_PULL },
		{ key = "threat", label = L.SORT_THREAT },
		{ key = "name", label = L.SORT_NAME },
	}))

	Header(layout, L.SECTION_ELEMENTS)
	Dep(self:Checkbox(category, "enemy", "showPercent", L.SHOW_PERCENT, nil, true))
	Dep(self:Checkbox(category, "enemy", "showPower", L.SHOW_POWER, L.SHOW_POWER_TT, true))
	Dep(self:Checkbox(category, "enemy", "showMarker", L.SHOW_MARKER, nil, true))
	Dep(self:Checkbox(category, "enemy", "showElite", L.SHOW_ELITE, nil, true))

	Header(layout, L.SECTION_AGGRO)
	local glow = Dep(self:Checkbox(category, "enemy", "showShield", L.SHOW_SHIELD, L.SHOW_SHIELD_TT, true))
	DependsOn(self:Slider(category, "enemy", "threatOrange", L.THREAT_ORANGE, L.THREAT_ORANGE_TT, 50, 20, 90, 5, Pct), glow,
		function() return F.db.modules.enemy and F.db.enemy.showShield end)
end

function O:BuildCast(category, layout)
	Header(layout, L.SECTION_CAST_UNITS)
	local on = self:Module(category, "cast", L.CAST_ENABLE)
	local function Dep(init) DependsOn(init, on, function() return F.db.modules.cast end) return init end
	Dep(self:Checkbox(category, "cast", "target", L.CAST_TARGET, nil, true))
	Dep(self:Scale(category, "castTarget", L.CAST_TARGET_SCALE))
	Dep(self:Checkbox(category, "cast", "focus", L.CAST_FOCUS, nil, true))
	Dep(self:Scale(category, "castFocus", L.CAST_FOCUS_SCALE))

	Header(layout, L.SECTION_CAST_WHOSE)
	Dep(self:Checkbox(category, "cast", "onlyHostile", L.ONLY_HOSTILE, L.ONLY_HOSTILE_TT, false))
	Dep(self:Checkbox(category, "cast", "hideGroup", L.HIDE_GROUP, L.HIDE_GROUP_TT, true))

	Header(layout, L.SECTION_DISPLAY)
	Dep(self:Checkbox(category, "cast", "showIcon", L.SHOW_ICON, nil, true))
	Dep(self:Checkbox(category, "cast", "showTime", L.SHOW_TIME, nil, true))
end

function O:BuildAlerts(category, layout)
	local A = F.modules.alerts
	local sounds = {}
	for _, snd in ipairs(A.SOUNDS) do sounds[#sounds + 1] = { key = snd.key, label = snd.label } end
	local function Enabled() return F.db.modules.alerts end

	Header(layout, L.SECTION_ALERTS)
	local on = self:Module(category, "alerts", L.ALERTS_ENABLE, L.ALERTS_ENABLE_TT)
	local function Dep(init, parent, pred)
		DependsOn(init, parent or on, function() return Enabled() and (not pred or pred()) end)
		return init
	end

	Header(layout, L.SECTION_ALERT_WHEN)
	local gain = Dep(self:Checkbox(category, "alerts", "gain", L.GAIN, L.GAIN_TT, true))
	Dep(self:Checkbox(category, "alerts", "gainTank", L.GAIN_TANK, nil, false), gain, function() return F.db.alerts.gain end)
	Dep(self:Checkbox(category, "alerts", "loss", L.LOSS, L.LOSS_TT, true))
	Dep(self:Checkbox(category, "alerts", "tankWarn", L.TANK_WARN, nil, true))
	local high = Dep(self:Checkbox(category, "alerts", "threatHigh", L.THREAT_HIGH, L.THREAT_HIGH_TT, true))
	Dep(self:Slider(category, "alerts", "threatPct", L.THREAT_PCT, nil, 90, 60, 100, 5, Pct), high,
		function() return F.db.alerts.threatHigh end)
	local low = Dep(self:Checkbox(category, "alerts", "lowHealth", L.LOW_HEALTH, L.LOW_HEALTH_TT, true))
	Dep(self:Slider(category, "alerts", "lowHealthPct", L.LOW_HEALTH_PCT, nil, 25, 10, 60, 5, Pct), low,
		function() return F.db.alerts.lowHealth end)

	Header(layout, L.SECTION_ALERT_SOUNDS)
	local soundOn = Dep(self:Checkbox(category, "alerts", "sound", L.SOUND, L.SOUND_TT, true))
	local function Sound(field, name, default)
		Dep(self:Dropdown(category, "alerts", field, name, L.SOUND_PREVIEW_TT, default, sounds, A.PlaySound), soundOn,
			function() return F.db.alerts.sound end)
	end
	Sound("soundGain", L.SOUND_GAIN, "raid")
	Sound("soundLoss", L.SOUND_LOSS, "alarm")
	Sound("soundThreat", L.SOUND_THREAT, "boss")
	Sound("soundLow", L.SOUND_LOW, "alarm")

	Header(layout, L.SECTION_CONDITIONS)
	Dep(self:Checkbox(category, "alerts", "onlyInGroup", L.ONLY_GROUP, nil, true))
	Dep(self:Checkbox(category, "alerts", "onlyInCombat", L.ONLY_COMBAT, nil, true))
	Dep(self:Slider(category, "alerts", "pause", L.PAUSE, L.PAUSE_TT, 8, 2, 30, 1, Sec))

	Header(layout, L.SECTION_APPEARANCE)
	Dep(self:Slider(category, "alerts", "hold", L.HOLD, nil, 2.6, 1, 8, 0.5, Sec))
	Dep(self:Slider(category, "alerts", "textSize", L.TEXT_SIZE, nil, 24, 16, 40, 2, Px))
	Dep(self:Scale(category, "alert", L.ALERT_SCALE))
	Dep(self:Checkbox(category, "alerts", "showName", L.SHOW_NAME, nil, true))
end

------------------------------------------------------------------------
-- Actions page: same look as SquareMap's (title, divider, sections with a label, a button and a note per row).
------------------------------------------------------------------------
local function TestAlert(title, sub, kind, sound, ...)
	local A = F.modules.alerts
	if A and A.Alert then A:Alert(title, sub, kind, sound, ...) end
end

function O:CreateActionsPanel()
	local panel = CreateFrame("Frame")
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
	title:SetPoint("TOPLEFT", 7, -22)
	title:SetText(L.SECTION_ACTIONS)
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
	local function Row(label, buttonText, desc, onClick)
		local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		fs:SetPoint("TOPLEFT", 37, y)
		fs:SetText(label)
		local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		button:SetSize(200, 26)
		button:SetPoint("TOPLEFT", panel, "TOPLEFT", 300, y + 6)
		button:SetText(buttonText)
		button:SetScript("OnClick", onClick)
		if desc then
			local d = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			d:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -6)
			d:SetPoint("RIGHT", button, "LEFT", -12, 0)
			d:SetJustifyH("LEFT")
			d:SetText(desc)
			y = y - 52
		else
			y = y - 36
		end
		return button
	end

	Section(L.SECTION_FRAMES)
	local lock = Row(L.MOVE, L.UNLOCK_BTN, L.MOVE_TT, function(button)
		F:SetLocked(F.unlocked)
		button:SetText(F.unlocked and L.LOCK_BTN or L.UNLOCK_BTN)
	end)
	Row(L.RESET_POS, L.RESET_BTN, L.RESET_POS_TT, function() F:ResetPositions() end)
	Row(L.TEST, L.TEST_BTN, L.TEST_TT, function() F.StartTest() end)

	Section(L.SECTION_TESTS)
	Row(L.GAIN, L.TEST_ALERT_BTN, nil, function() TestAlert(L.ALERT_AGGRO, "%s", "red", "soundGain", L.TEST_ENEMY) end)
	Row(L.LOSS, L.TEST_ALERT_BTN, nil, function()
		TestAlert(L.ALERT_LOST, "%s  >  %s", "orange", "soundLoss", L.TEST_ENEMY, L.PARTY_MEMBER)
	end)
	Row(L.THREAT_HIGH, L.TEST_ALERT_BTN, nil, function()
		TestAlert(L.ALERT_HIGH, "%s  (%d%%)", "orange", "soundThreat", L.TEST_ENEMY, 95)
	end)

	Section(L.SECTION_DATA)
	Row(L.RESET_ALL, L.RESET_BTN, L.RESET_ALL_TT, function() StaticPopup_Show("FRAY_RESET_ALL") end)

	panel:SetScript("OnShow", function() lock:SetText(F.unlocked and L.LOCK_BTN or L.UNLOCK_BTN) end)
	return panel
end

StaticPopupDialogs["FRAY_RESET_ALL"] = {
	text = L.RESET_CONFIRM,
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
function O:Init()
	if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end

	local category, layout = Settings.RegisterVerticalLayoutCategory(L.TITLE)
	self.category = category
	self:BuildGeneral(category, layout)

	local function Sub(name, build)
		local sub, subLayout = Settings.RegisterVerticalLayoutSubcategory(category, name)
		build(self, sub, subLayout)
	end
	Sub(L.SECTION_ENEMY, O.BuildEnemy)
	Sub(L.SECTION_CAST, O.BuildCast)
	Sub(L.SECTION_ALERTS, O.BuildAlerts)

	Settings.RegisterAddOnCategory(category)
	-- Taint: the settings list reuses its control frames for every category. A button control first shown
	-- for an addon page stays tainted, and when Blizzard later reuses it for one of its own buttons (the
	-- Discord button under Social) that button gets blocked. So the action buttons live on their own page,
	-- with frames that belong to Fray alone.
	if Settings.RegisterCanvasLayoutSubcategory then
		self.actionsCategory = Settings.RegisterCanvasLayoutSubcategory(category, self:CreateActionsPanel(), L.SECTION_ACTIONS)
	end
end

-- Values changed elsewhere: let open controls show the new state
function O:Refresh()
	for _, setting in ipairs(self.settings) do
		if setting.NotifyUpdate then setting:NotifyUpdate() end
	end
end

function O:Open()
	if self.category and Settings.OpenToCategory then
		Settings.OpenToCategory(self.category:GetID())
	end
end
