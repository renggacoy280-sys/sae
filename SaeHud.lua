-- SAE HUD + Anti Lag (tampilan lokal saja)
-- Developer: FARIH
-- Tidak mengubah apa pun di server / pemain lain, hanya visual di layarmu.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer

---------------------------------------------------------------- Pengaturan
local DEVELOPER = "FARIH"
-- Kalau nama stat di game beda, ganti daftar nama di sini:
local MONEY_NAMES = { "Money", "Cash", "Coins", "Coin", "Gold" }
local TREADMILL_NAMES = { "Treadmill", "Treadmills" }

---------------------------------------------------------------- Helper
local function guiParent()
	local ok, ui = pcall(function()
		return gethui and gethui()
	end)
	if ok and ui then
		return ui
	end
	return player:WaitForChild("PlayerGui")
end

local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi" }
local function fmt(n)
	if type(n) ~= "number" then
		return tostring(n == nil and "-" or n)
	end
	local i = 1
	while math.abs(n) >= 1000 and i < #suffixes do
		n = n / 1000
		i += 1
	end
	if i == 1 then
		return string.format("%.0f", n)
	end
	return string.format("%.2f%s", n, suffixes[i])
end

local function findStat(names)
	local ls = player:FindFirstChild("leaderstats")
	for _, n in ipairs(names) do
		local v = (ls and ls:FindFirstChild(n)) or player:FindFirstChild(n)
		if v and v:IsA("ValueBase") then
			return v.Value
		end
		local a = player:GetAttribute(n)
		if a ~= nil then
			return a
		end
	end
	return nil
end

local function findMoney()
	local m = findStat(MONEY_NAMES)
	if m ~= nil then
		return m
	end
	-- cadangan: angka pertama di leaderstats
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		for _, v in ipairs(ls:GetChildren()) do
			if v:IsA("IntValue") or v:IsA("NumberValue") then
				return v.Value
			end
		end
	end
	return nil
end

---------------------------------------------------------------- Mode optimasi
local function newMode(applyFn, onEnable, onDisable)
	local m = { on = false, backup = {}, conn = nil }

	function m.set(inst, prop, value)
		local b = m.backup[inst]
		if not b then
			b = {}
			m.backup[inst] = b
		end
		if b[prop] == nil then
			b[prop] = inst[prop]
		end
		inst[prop] = value
	end

	function m.enable()
		if m.on then
			return
		end
		m.on = true
		if onEnable then
			pcall(onEnable, m)
		end
		m.conn = workspace.DescendantAdded:Connect(function(d)
			pcall(applyFn, m, d)
		end)
		task.spawn(function()
			local list = workspace:GetDescendants()
			for i, d in ipairs(list) do
				if not m.on then
					break
				end
				pcall(applyFn, m, d)
				if i % 300 == 0 then
					task.wait()
				end
			end
		end)
	end

	function m.disable()
		if not m.on then
			return
		end
		m.on = false
		if m.conn then
			m.conn:Disconnect()
			m.conn = nil
		end
		for inst, props in pairs(m.backup) do
			if inst.Parent then
				for prop, val in pairs(props) do
					pcall(function()
						inst[prop] = val
					end)
				end
			end
		end
		table.clear(m.backup)
		if onDisable then
			pcall(onDisable, m)
		end
	end

	return m
end

-- 1) Optimasi bangunan jadi "buruk" (grafis rendah)
local badMode = newMode(function(m, d)
	if d:IsA("BasePart") and not d:IsA("Terrain") then
		m.set(d, "Material", Enum.Material.SmoothPlastic)
		m.set(d, "Reflectance", 0)
		m.set(d, "CastShadow", false)
		if d:IsA("MeshPart") then
			m.set(d, "RenderFidelity", Enum.RenderFidelity.Performance)
		end
	end
end, function(m)
	m.set(Lighting, "GlobalShadows", false)
	pcall(function()
		settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
	end)
end, function()
	pcall(function()
		settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
	end)
end)

-- 2) Hilangkan benda berat (efek, partikel, tekstur, lampu)
local heavyMode = newMode(function(m, d)
	if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Smoke")
		or d:IsA("Fire") or d:IsA("Sparkles") or d:IsA("Highlight")
		or d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
		m.set(d, "Enabled", false)
	elseif d:IsA("Decal") or d:IsA("Texture") then
		m.set(d, "Transparency", 1)
	elseif d:IsA("Explosion") then
		m.set(d, "Visible", false)
	end
end, function(m)
	for _, e in ipairs(Lighting:GetChildren()) do
		if e:IsA("PostEffect") then
			m.set(e, "Enabled", false)
		end
	end
end)

---------------------------------------------------------------- GUI
local parent = guiParent()
local old = parent:FindFirstChild("SaeHud")
if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "SaeHud"
gui.ResetOnSpawn = false
gui.Parent = parent

local function label(text, size, pos, parentFrame)
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = pos or UDim2.new()
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextSize = 13
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = parentFrame or gui
	return l
end

-- FPS (otomatis tampil)
local fpsFrame = Instance.new("Frame")
fpsFrame.Size = UDim2.fromOffset(80, 24)
fpsFrame.Position = UDim2.new(0, 8, 0, 8)
fpsFrame.BackgroundColor3 = Color3.new(0, 0, 0)
fpsFrame.BackgroundTransparency = 0.3
fpsFrame.Parent = gui
local fpsLabel = label("FPS: --", UDim2.new(1, -8, 1, 0), UDim2.fromOffset(6, 0), fpsFrame)

-- Panel profil + tombol
local panel = Instance.new("Frame")
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.Size = UDim2.fromOffset(170, 0)
panel.Position = UDim2.new(0, 8, 0, 38)
panel.BackgroundColor3 = Color3.new(0, 0, 0)
panel.BackgroundTransparency = 0.35
panel.Parent = gui

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 3)
list.Parent = panel
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 6)
pad.PaddingBottom = UDim.new(0, 6)
pad.PaddingLeft = UDim.new(0, 6)
pad.PaddingRight = UDim.new(0, 6)
pad.Parent = panel

local function row(text)
	return label(text, UDim2.new(1, 0, 0, 18), nil, panel)
end

local title = row("PROFILE")
title.TextColor3 = Color3.fromRGB(255, 220, 90)
local nameRow = row("Nama: " .. player.Name)
local moneyRow = row("Money: -")
local speedRow = row("Speed: -")
local mpsRow = row("Money/s: -")
local treadRow = row("Treadmill: -")
local devRow = row("Developer: " .. DEVELOPER)
devRow.TextColor3 = Color3.fromRGB(120, 220, 255)

local function toggle(text, initial, callback)
	local on = initial
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 26)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.Gotham
	b.TextSize = 12
	b.Parent = panel
	local function render()
		b.Text = text .. ": " .. (on and "ON" or "OFF")
		b.BackgroundColor3 = on and Color3.fromRGB(40, 120, 60) or Color3.fromRGB(45, 45, 55)
	end
	render()
	b.Activated:Connect(function()
		on = not on
		render()
		callback(on)
	end)
end

toggle("Tampil FPS", true, function(on)
	fpsFrame.Visible = on
end)
toggle("Bangunan Buruk", false, function(on)
	if on then badMode.enable() else badMode.disable() end
end)
toggle("Hapus Benda Berat", false, function(on)
	if on then heavyMode.enable() else heavyMode.disable() end
end)

---------------------------------------------------------------- Update loop
local frames, lastTick = 0, os.clock()
RunService.RenderStepped:Connect(function()
	frames += 1
	local now = os.clock()
	if now - lastTick >= 0.5 then
		fpsLabel.Text = "FPS: " .. math.floor(frames / (now - lastTick) + 0.5)
		frames = 0
		lastTick = now
	end
end)

local samples, lastMoney = {}, nil
task.spawn(function()
	while gui.Parent do
		local money = findMoney()
		moneyRow.Text = "Money: " .. fmt(money)

		if type(money) == "number" then
			if lastMoney then
				table.insert(samples, money - lastMoney)
				if #samples > 5 then
					table.remove(samples, 1)
				end
				local sum = 0
				for _, s in ipairs(samples) do
					sum += s
				end
				mpsRow.Text = "Money/s: " .. fmt(math.max(0, sum / #samples))
			end
			lastMoney = money
		end

		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		speedRow.Text = "Speed: " .. (hum and fmt(hum.WalkSpeed) or "-")

		treadRow.Text = "Treadmill: " .. fmt(findStat(TREADMILL_NAMES))
		task.wait(1)
	end
end)
