local ADDON, F = ...
local L = F.L
local M = {}
F:RegisterModule("minimap", M)

-- Minimap button in the classic Blizzard look, the same as Mundi's addon button:
-- left click = options, right click = unlock/lock frames, drag = move along the edge of the map.
-- Mundi (and other button collectors) can take it into their window.
M.ICON = F.ICON   -- Fray logo

-- Round or square minimap edge (GetMinimapShape is set by minimap addons such as Mundi).
local function Place(btn)
	local angle = math.rad(F.db.minimap.angle or 215)
	local x, y = math.cos(angle), math.sin(angle)
	local w = Minimap:GetWidth() / 2 + 5
	local h = Minimap:GetHeight() / 2 + 5
	local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
	btn:ClearAllPoints()
	if shape == "SQUARE" then
		-- same maths LibDBIcon uses for square minimaps
		local diagW, diagH = math.sqrt(2 * w * w) - 10, math.sqrt(2 * h * h) - 10
		x = math.max(-w, math.min(x * diagW, w))
		y = math.max(-h, math.min(y * diagH, h))
		btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
	else
		btn:SetPoint("CENTER", Minimap, "CENTER", x * w, y * h)
	end
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
	btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local border = btn:CreateTexture(nil, "OVERLAY")
	border:SetSize(50, 50)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetPoint("TOPLEFT")

	local background = btn:CreateTexture(nil, "BACKGROUND")
	background:SetSize(24, 24)
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	background:SetPoint("CENTER")

	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetSize(20, 20)
	icon:SetPoint("CENTER")
	icon:SetTexture(M.ICON)
	btn.icon = icon

	btn:SetScript("OnMouseDown", function(self) self.icon:SetPoint("CENTER", 1, -1) end)
	btn:SetScript("OnMouseUp", function(self) self.icon:SetPoint("CENTER", 0, 0) end)
	btn:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			F:SetLocked(F.unlocked)
		else
			F.OpenOptions()
		end
		GameTooltip:Hide()
	end)
	btn:SetScript("OnDragStart", function(self)
		self:LockHighlight()
		self:SetScript("OnUpdate", DragUpdate)
		GameTooltip:Hide()
	end)
	btn:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
		self:UnlockHighlight()
	end)
	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip_SetTitle(GameTooltip, L.TITLE)
		GameTooltip:AddLine(L.TT_LEFT, 0.8, 0.8, 0.8)
		GameTooltip:AddLine(L.TT_RIGHT, 0.8, 0.8, 0.8)
		GameTooltip:AddLine(L.TT_DRAG, 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", GameTooltip_Hide)

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
