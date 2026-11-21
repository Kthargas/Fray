local ADDON, F = ...
local M = {}
F:RegisterModule("cooldowns", M)

local SPACING = 5
local function Size() return (F.db and F.db.cooldowns.size) or 40 end
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"
local icons = {}

local function SpellCD(ref)
	if GetSpellCooldown then return GetSpellCooldown(ref) end
	if C_Spell and C_Spell.GetSpellCooldown then
		local i = C_Spell.GetSpellCooldown(ref)
		if i then return i.startTime, i.duration, i.isEnabled and 1 or 0 end
	end
end

local function ItemCD(id)
	if GetItemCooldown then return GetItemCooldown(id) end
	if C_Container and C_Container.GetItemCooldown then return C_Container.GetItemCooldown(id) end
end

-- Eintrag: "Zaubername", "12345" (Spell-ID), "slot:13" (Ausruestung), "item:ID"
local function Resolve(entry)
	local kind, val = entry:match("^(%a+):(.+)$")
	if kind == "slot" then
		local slot = tonumber(val)
		if not slot then return QUESTION, function() end end
		return GetInventoryItemTexture("player", slot) or QUESTION,
			function() return GetInventoryItemCooldown("player", slot) end
	elseif kind == "item" then
		local id = tonumber(val)
		if not id then return QUESTION, function() end end
		return (GetItemIcon and GetItemIcon(id)) or QUESTION, function() return ItemCD(id) end
	end
	local ref = tonumber(entry) or entry
	local tex
	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(ref)
		tex = info and info.iconID
	elseif GetSpellInfo then
		local _, _, t = GetSpellInfo(ref)
		tex = t
	end
	return tex or QUESTION, function() return SpellCD(ref) end
end

local function CreateIcon()
	local f = CreateFrame("Frame", nil, M.frame)
	f:SetSize(Size(), Size())
	f.tex = f:CreateTexture(nil, "ARTWORK")
	f.tex:SetAllPoints()
	f.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
	f.cd:SetAllPoints()
	if f.cd.SetHideCountdownNumbers then f.cd:SetHideCountdownNumbers(true) end
	f.over = CreateFrame("Frame", nil, f)
	f.over:SetAllPoints()
	f.over:SetFrameLevel(f.cd:GetFrameLevel() + 2)
	-- goldener, abgerundeter Rahmen (Ecken ausserhalb dunkel, damit das Icon rund wirkt)
	f.frameTex = f.over:CreateTexture(nil, "OVERLAY", nil, 1)
	f.frameTex:SetTexture(F.TEXROOT .. "Icon-Border.tga")
	f.frameTex:SetPoint("TOPLEFT", -2, 2)
	f.frameTex:SetPoint("BOTTOMRIGHT", 2, -2)
	f.frameTex:SetVertexColor(unpack(F.PAL.edge))
	f.timeText = F.CreateText(f.over, 15, "CENTER")
	f.timeText:SetFont(F.FONT_BOLD, 15, "OUTLINE")
	f.timeText:SetPoint("CENTER")
	f.flash = f.over:CreateTexture(nil, "OVERLAY")
	f.flash:SetAllPoints()
	f.flash:SetTexture(F.WHITE)
	f.flash:SetVertexColor(unpack(F.PAL.hover))
	f.flash:SetBlendMode("ADD")
	f.flash:SetAlpha(0)
	return f
end

local function Layout()
	local shown = {}
	for _, ic in ipairs(icons) do
		if ic.visible then shown[#shown + 1] = ic else ic:Hide() end
	end
	local size = Size()
	for i, ic in ipairs(shown) do
		ic:SetSize(size, size)
		ic.timeText:SetFont(F.FONT_BOLD, math.max(10, math.floor(size * 0.38)), "OUTLINE")
		ic:ClearAllPoints()
		ic:SetPoint("LEFT", M.frame, "LEFT", (i - 1) * (size + SPACING), 0)
		ic:Show()
	end
	local n = math.max(1, #shown)
	M.frame:SetSize(n * (size + SPACING) - SPACING, size)
end

function M:Rebuild()
	local list = F.db.cooldowns.list
	for i = #icons + 1, #list do icons[i] = CreateIcon() end
	for i, ic in ipairs(icons) do
		local entry = list[i]
		if entry then
			ic.entry = entry
			ic.tex:SetTexture((Resolve(entry)))
			local _, getcd = Resolve(entry)
			ic.getcd = getcd
			ic.cdStart = nil
			ic.wasCD = false
			ic.visible = true
		else
			ic.entry = nil
			ic.visible = false
		end
	end
	Layout()
end

local function Update(dt)
	local always = F.db.cooldowns.alwaysShow
	local changed = false
	for _, ic in ipairs(icons) do
		if ic.entry then
			local start, dur = ic.getcd()
			-- geheime Werte (Kampf): zuletzt lesbare Werte weiterverwenden
			if F.AllReadable(start, dur) then ic.lastStart, ic.lastDur = start, dur else start, dur = ic.lastStart, ic.lastDur end
			local onCD = start and start > 0 and dur and dur > 1.6
			if onCD then
				if ic.cdStart ~= start then
					ic.cd:SetCooldown(start, dur)
					ic.cdStart = start
				end
				ic.tex:SetDesaturated(true)
				ic.frameTex:SetVertexColor(0.36, 0.3, 0.24)
				ic.timeText:SetText(F.db.cooldowns.showTimer == false and "" or F.FormatTime(math.max(0, start + dur - GetTime())))
				ic.wasCD = true
			else
				if ic.cdStart then
					ic.cd:SetCooldown(0, 0)
					ic.cdStart = nil
				end
				ic.tex:SetDesaturated(false)
				ic.frameTex:SetVertexColor(unpack(F.PAL.edge))
				ic.timeText:SetText("")
				if ic.wasCD then
					ic.wasCD = false
					ic.flashT = 0.6
				end
			end
			if ic.flashT then
				ic.flashT = ic.flashT - dt
				if ic.flashT <= 0 then
					ic.flashT = nil
					ic.flash:SetAlpha(0)
				else
					ic.flash:SetAlpha(ic.flashT / 0.6 * 0.7)
				end
			end
			local vis = always or onCD or ic.flashT ~= nil
			if F.unlocked then vis = true end
			if vis ~= ic.visible then
				ic.visible = vis
				changed = true
			end
		end
	end
	if changed then Layout() end
end

function M:Command(arg)
	local sub, rest = arg:match("^(%S*)%s*(.-)$")
	sub = sub:lower()
	local list = F.db.cooldowns.list
	if sub == "add" and rest ~= "" then
		table.insert(list, rest)
		local tex = Resolve(rest)
		if tex == QUESTION then
			F.Print("'" .. rest .. "' hinzugefuegt, aber nicht erkannt (Zauber muss im Zauberbuch stehen, oder ID/slot:/item: nutzen).")
		else
			F.Print("'" .. rest .. "' hinzugefuegt.")
		end
		M:Rebuild()
	elseif sub == "remove" and rest ~= "" then
		local n = tonumber(rest)
		for i = #list, 1, -1 do
			if (n and i == n) or (not n and list[i]:lower() == rest:lower()) then
				table.remove(list, i)
				F.Print("Entfernt.")
				M:Rebuild()
				return
			end
		end
		F.Print("Nicht gefunden (Name oder Nummer aus /fray cd list).")
	elseif sub == "clear" then
		wipe(list)
		M:Rebuild()
		F.Print("Cooldown-Liste geleert.")
	elseif sub == "list" then
		if #list == 0 then F.Print("Cooldown-Liste ist leer.") end
		for i, e in ipairs(list) do print(i .. ". " .. e) end
	elseif sub == "always" then
		F.db.cooldowns.alwaysShow = not F.db.cooldowns.alwaysShow
		F.Print("Immer anzeigen: " .. (F.db.cooldowns.alwaysShow and "an" or "aus"))
	else
		F.Print("/fray cd add <Zauber | ID | slot:13 | item:ID>, remove <Name|Nr>, list, clear, always")
	end
end

function M:Init()
	local f = CreateFrame("Frame", "FrayCooldowns", UIParent)
	f:SetSize(Size(), Size())
	M.frame = f
	F:MakeMovable(f, "cooldowns", "Cooldowns", 0, -200)
	M:Rebuild()

	f.t = 0
	f:SetScript("OnUpdate", function(self, dt)
		self.t = self.t + dt
		if self.t < 0.1 then return end
		Update(self.t)
		self.t = 0
	end)
end

function M:SetEnabled(on)
	M.frame:SetShown(on)
end
