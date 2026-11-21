local ADDON, F = ...
local M = {}
F:RegisterModule("qol", M)

local function NumSlots(bag)
	if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) end
	return GetContainerNumSlots(bag)
end

-- Rueckgabe: Link, Qualitaet, Anzahl
local function SlotInfo(bag, slot)
	if C_Container and C_Container.GetContainerItemInfo then
		local info = C_Container.GetContainerItemInfo(bag, slot)
		if info then return info.hyperlink, info.quality, info.stackCount end
		return
	end
	local _, count, _, quality, _, _, link = GetContainerItemInfo(bag, slot)
	return link, quality, count
end

local function UseSlot(bag, slot)
	if C_Container and C_Container.UseContainerItem then
		C_Container.UseContainerItem(bag, slot)
	else
		UseContainerItem(bag, slot)
	end
end

local function SellJunk()
	local total = 0
	for bag = 0, NUM_BAG_SLOTS or 4 do
		for slot = 1, NumSlots(bag) or 0 do
			local link, quality, count = SlotInfo(bag, slot)
			if link and quality == 0 then
				local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
				local price = select(11, getInfo(link)) or 0
				if price > 0 then
					total = total + price * (count or 1)
					UseSlot(bag, slot)
				end
			end
		end
	end
	if total > 0 then
		F.Print("Muell verkauft: " .. (GetCoinTextureString and GetCoinTextureString(total) or total))
	end
end

local function Repair()
	if not CanMerchantRepair or not CanMerchantRepair() then return end
	local cost, canRepair = GetRepairAllCost()
	if canRepair and cost > 0 then
		if GetMoney() >= cost then
			RepairAllItems()
			F.Print("Repariert fuer " .. (GetCoinTextureString and GetCoinTextureString(cost) or cost))
		else
			F.Print("Nicht genug Gold fuer die Reparatur.")
		end
	end
end

function M:Init()
	F:On("MERCHANT_SHOW", function()
		if not F:IsEnabled("qol") then return end
		if F.db.qol.autoSell then SellJunk() end
		if F.db.qol.autoRepair then Repair() end
	end)
end
