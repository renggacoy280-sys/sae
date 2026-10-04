-- ServerScriptService > Script (nama: EggServer)
-- Struktur yang dibutuhkan di game:
--   workspace.Eggs                     -> folder berisi telur (Model/Part), tiap telur punya attribute "OwnerId"
--   workspace.Base_<NamaPlayer>.EggSlots -> folder berisi Part sebagai slot tempat telur
--   player.Pets                        -> folder berisi pet, tiap pet punya attribute "Power" (angka)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local eggsFolder = workspace:WaitForChild("Eggs")

local MAX_EQUIPPED = 3
local STEAL_COOLDOWN = 5
local STEAL_RANGE = 15

-- Buat RemoteEvent otomatis
local remotes = RS:FindFirstChild("EggRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "EggRemotes"
	remotes.Parent = RS
end
for _, name in ipairs({ "StealEgg", "PlaceEgg", "EquipBest", "SetAutoPlace", "SetAutoEquip" }) do
	if not remotes:FindFirstChild(name) then
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remotes
	end
end

local lastSteal = {}

---------------------------------------------------------------- helpers
local function getInventory(player)
	local inv = player:FindFirstChild("EggInventory")
	if not inv then
		inv = Instance.new("Folder")
		inv.Name = "EggInventory"
		inv.Parent = player
	end
	return inv
end

local function slotTaken(slot)
	local name = slot:GetFullName()
	for _, e in ipairs(eggsFolder:GetChildren()) do
		if e:GetAttribute("Slot") == name then
			return true
		end
	end
	return false
end

-- Taruh telur di slot kosong milik player. Return true kalau berhasil.
local function placeEgg(player, egg)
	local base = workspace:FindFirstChild("Base_" .. player.Name)
	local slots = base and base:FindFirstChild("EggSlots")
	if not slots then
		return false
	end
	for _, slot in ipairs(slots:GetChildren()) do
		if not slotTaken(slot) then
			egg.Parent = eggsFolder
			egg:SetAttribute("OwnerId", player.UserId)
			egg:SetAttribute("Slot", slot:GetFullName())
			local target = slot.CFrame + Vector3.new(0, 2, 0)
			if egg:IsA("Model") then
				egg:PivotTo(target)
			else
				egg.CFrame = target
			end
			return true
		end
	end
	return false
end

local function toInventory(player, egg)
	egg:SetAttribute("OwnerId", player.UserId)
	egg:SetAttribute("Slot", nil)
	egg.Parent = getInventory(player)
end

local function distanceIfStealable(player, root, egg)
	local owner = egg:GetAttribute("OwnerId")
	if not owner or owner == player.UserId then
		return nil
	end
	local dist = (egg:GetPivot().Position - root.Position).Magnitude
	if dist > STEAL_RANGE then
		return nil
	end
	return dist
end

local function equipBest(player)
	local pets = player:FindFirstChild("Pets")
	if not pets then
		return
	end
	local list = pets:GetChildren()
	table.sort(list, function(a, b)
		return (a:GetAttribute("Power") or 0) > (b:GetAttribute("Power") or 0)
	end)
	for i, pet in ipairs(list) do
		pet:SetAttribute("Equipped", i <= MAX_EQUIPPED)
	end
end

---------------------------------------------------------------- steal
remotes.StealEgg.OnServerEvent:Connect(function(player, target)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local now = os.clock()
	if lastSteal[player] and now - lastSteal[player] < STEAL_COOLDOWN then
		return
	end

	local egg
	if typeof(target) == "Instance" and target.Parent == eggsFolder then
		-- Steal egg pilihan
		if distanceIfStealable(player, root, target) then
			egg = target
		end
	else
		-- Steal telur terdekat
		local best = math.huge
		for _, e in ipairs(eggsFolder:GetChildren()) do
			local d = distanceIfStealable(player, root, e)
			if d and d < best then
				best = d
				egg = e
			end
		end
	end
	if not egg then
		return
	end

	lastSteal[player] = now

	-- Auto place setelah steal (kalau diaktifkan), kalau gagal masuk inventory
	if player:GetAttribute("AutoPlace") then
		if not placeEgg(player, egg) then
			toInventory(player, egg)
		end
	else
		toInventory(player, egg)
	end
end)

remotes.PlaceEgg.OnServerEvent:Connect(function(player)
	for _, egg in ipairs(getInventory(player):GetChildren()) do
		if not placeEgg(player, egg) then
			break
		end
	end
end)

remotes.SetAutoPlace.OnServerEvent:Connect(function(player, value)
	player:SetAttribute("AutoPlace", value == true)
end)

---------------------------------------------------------------- pets
remotes.EquipBest.OnServerEvent:Connect(equipBest)

remotes.SetAutoEquip.OnServerEvent:Connect(function(player, value)
	player:SetAttribute("AutoEquip", value == true)
	if value == true then
		equipBest(player)
	end
end)

local function watchPets(player)
	local pets = player:WaitForChild("Pets", 30)
	if not pets then
		return
	end
	pets.ChildAdded:Connect(function()
		if player:GetAttribute("AutoEquip") then
			task.defer(equipBest, player)
		end
	end)
end

local function onPlayer(player)
	player:SetAttribute("AutoEquip", true)
	task.spawn(watchPets, player)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayer(p)
end

Players.PlayerRemoving:Connect(function(p)
	lastSteal[p] = nil
end)
