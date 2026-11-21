local ADDON, F = ...
local M = {}
F:RegisterModule("minimap", M)

-- Minimap button: left click = settings, right click = lock/unlock frames, drag = move around the minimap.
local RADIUS_PAD = 5

local function Place(btn)
	local angle = math.rad(F.db.minimap.angle or 215)
	local r = (Minimap:GetWidth() / 2) + RADIUS_PAD
	btn:ClearAllPoints()
	btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function DragUpdate(btn)
	local mx, my = Minimap:GetCenter()
	local scale = Minimap:GetEffectiveScale()
	local cx, cy = GetCursorPosition()
	F.db.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
	Place(btn)
end

function M:Init()
	local btn = CreateFrame("Button", "FrayMinimapButton", Minimap)
	btn:SetSize(31, 31)
	btn:SetFrameStrata("MEDIUM")
	btn:SetFrameLevel(8)
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	btn:RegisterForDrag("LeftButton")

	local bg = btn:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(22, 22)
	bg:SetPoint("CENTER")
	bg:SetColorTexture(0.06, 0.05, 0.04, 1)
	local mask = btn:CreateMaskTexture()
	mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKANDWHITE", "CLAMPTOBLACKANDWHITE")
	mask:SetAllPoints(bg)
	bg:AddMaskTexture(mask)

	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetSize(20, 20)
	icon:SetPoint("CENTER")
	icon:SetTexture(F.TEXROOT .. "Icon.tga")
	btn.icon = icon

	local ring = btn:CreateTexture(nil, "OVERLAY")
	ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	ring:SetSize(54, 54)
	ring:SetPoint("TOPLEFT")

	local hl = btn:CreateTexture(nil, "HIGHLIGHT")
	hl:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	hl:SetBlendMode("ADD")
	hl:SetAllPoints()

	btn:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			if InCombatLockdown() then F.Print("Not possible in combat.") return end
			F:SetLocked(F.unlocked)
		else
			local o = F.modules.options
			if o and o.Toggle then o:Toggle() end
		end
	end)
	btn:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", DragUpdate)
		GameTooltip:Hide()
	end)
	btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Fray", 1, 0.82, 0.45)
		GameTooltip:AddLine("Left click: settings", 1, 1, 1)
		GameTooltip:AddLine("Right click: unlock/lock frames", 1, 1, 1)
		GameTooltip:AddLine("Drag: move button", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	self.button = btn
	Place(btn)
end

function M:Refresh()
	if not self.button then return end
	Place(self.button)
	self.button:SetShown(not F.db.minimap.hide)
end

-- called by the loader with the module's enabled state; the button is controlled by its own option instead
function M:SetEnabled()
	self:Refresh()
end
