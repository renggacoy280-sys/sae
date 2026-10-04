-- StarterPlayer > StarterPlayerScripts > LocalScript (nama: EggClient)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local remotes = RS:WaitForChild("EggRemotes")
local eggsFolder = workspace:WaitForChild("Eggs")
local mouse = player:GetMouse()

---------------------------------------------------------------- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "EggMenu"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.fromOffset(90, 24)
fpsLabel.Position = UDim2.new(0, 8, 0, 8)
fpsLabel.BackgroundColor3 = Color3.new(0, 0, 0)
fpsLabel.BackgroundTransparency = 0.3
fpsLabel.TextColor3 = Color3.new(1, 1, 1)
fpsLabel.Font = Enum.Font.GothamBold
fpsLabel.TextSize = 14
fpsLabel.Text = "FPS: --"
fpsLabel.Parent = gui

local panel = Instance.new("Frame")
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.Size = UDim2.fromOffset(160, 0)
panel.Position = UDim2.new(0, 8, 0, 40)
panel.BackgroundColor3 = Color3.new(0, 0, 0)
panel.BackgroundTransparency = 0.4
panel.Parent = gui

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.Parent = panel

local function makeButton(text, callback)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 30)
	b.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.Gotham
	b.TextSize = 13
	b.Text = text
	b.Parent = panel
	b.Activated:Connect(function()
		callback(b)
	end)
	return b
end

local function makeToggle(label, initial, callback)
	local on = initial
	local function render(b)
		b.Text = label .. ": " .. (on and "ON" or "OFF")
		b.BackgroundColor3 = on and Color3.fromRGB(40, 120, 60) or Color3.fromRGB(40, 40, 50)
	end
	local btn = makeButton("", function(b)
		on = not on
		render(b)
		callback(on)
	end)
	render(btn)
end

---------------------------------------------------------------- FPS counter
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

---------------------------------------------------------------- Anti lag
local antiLag = { fx = {}, effects = {} }

local function setAntiLag(on)
	if on then
		antiLag.shadows = Lighting.GlobalShadows
		Lighting.GlobalShadows = false

		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Smoke")
				or d:IsA("Fire") or d:IsA("Sparkles") then
				if d.Enabled then
					d.Enabled = false
					table.insert(antiLag.fx, d)
				end
			end
		end
		for _, e in ipairs(Lighting:GetChildren()) do
			if e:IsA("BloomEffect") or e:IsA("BlurEffect") or e:IsA("SunRaysEffect")
				or e:IsA("DepthOfFieldEffect") then
				if e.Enabled then
					e.Enabled = false
					table.insert(antiLag.effects, e)
				end
			end
		end
		pcall(function()
			settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
		end)
	else
		Lighting.GlobalShadows = antiLag.shadows ~= false
		for _, d in ipairs(antiLag.fx) do
			if d.Parent then d.Enabled = true end
		end
		for _, e in ipairs(antiLag.effects) do
			if e.Parent then e.Enabled = true end
		end
		table.clear(antiLag.fx)
		table.clear(antiLag.effects)
		pcall(function()
			settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
		end)
	end
end

---------------------------------------------------------------- 8-bit mode
local pixelBackup = {}

local function quantize(c)
	local s = 3 -- makin kecil makin "burik"
	return Color3.new(
		math.floor(c.R * s + 0.5) / s,
		math.floor(c.G * s + 0.5) / s,
		math.floor(c.B * s + 0.5) / s
	)
end

local function setPixel(on)
	if on then
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("BasePart") then
				pixelBackup[d] = { d.Color, d.Material }
				d.Color = quantize(d.Color)
				d.Material = Enum.Material.SmoothPlastic
			elseif d:IsA("Decal") or d:IsA("Texture") then
				pixelBackup[d] = { d.Transparency }
				d.Transparency = 1
			end
		end
	else
		for inst, v in pairs(pixelBackup) do
			if inst.Parent then
				if inst:IsA("BasePart") then
					inst.Color, inst.Material = v[1], v[2]
				else
					inst.Transparency = v[1]
				end
			end
		end
		table.clear(pixelBackup)
	end
end

---------------------------------------------------------------- Egg controls
local chooseMode = false

local function findEgg(inst)
	while inst and inst.Parent ~= eggsFolder do
		inst = inst.Parent
	end
	return inst
end

mouse.Button1Down:Connect(function()
	if not chooseMode then
		return
	end
	local egg = findEgg(mouse.Target)
	if egg then
		remotes.StealEgg:FireServer(egg)
	end
end)

makeButton("Steal Egg (terdekat)", function()
	remotes.StealEgg:FireServer()
end)
makeToggle("Steal Pilih Egg", false, function(on)
	chooseMode = on -- kalau ON, klik/tap telur untuk mencuri
end)
makeToggle("Auto Place Egg", false, function(on)
	remotes.SetAutoPlace:FireServer(on)
end)
makeButton("Place Semua Egg", function()
	remotes.PlaceEgg:FireServer()
end)
makeButton("Equip Best Pet", function()
	remotes.EquipBest:FireServer()
end)
makeToggle("Auto Equip Best", true, function(on)
	remotes.SetAutoEquip:FireServer(on)
end)
makeToggle("Anti Lag", false, setAntiLag)
makeToggle("Mode 8-bit", false, setPixel)
