-- FarihHub V0.2
-- Developer: FARIH
-- Script tampilan & optimasi lokal. Tidak mengubah game / pemain lain.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UIS = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local player = Players.LocalPlayer

local VERSION = "V0.2"
local DEVELOPER = "FARIH"
local DISCORD = "Ellll0590"
local WHATSAPP = "Saluran Comming"

---------------------------------------------------------------- Helper umum
local function guiParent()
	local ok, ui = pcall(function()
		return gethui and gethui()
	end)
	if ok and ui then
		return ui
	end
	return player:WaitForChild("PlayerGui")
end

local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp" }
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

---------------------------------------------------------------- Auto detect stat
local function nameMatches(name, keywords)
	name = name:lower()
	for _, k in ipairs(keywords) do
		if name:find(k, 1, true) then
			return true
		end
	end
	return false
end

local function scanStat(keywords)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		for _, v in ipairs(ls:GetChildren()) do
			if v:IsA("ValueBase") and nameMatches(v.Name, keywords) then
				return { inst = v }
			end
		end
	end
	for _, v in ipairs(player:GetDescendants()) do
		if v:IsA("ValueBase") and nameMatches(v.Name, keywords) then
			return { inst = v }
		end
	end
	for k in pairs(player:GetAttributes()) do
		if nameMatches(k, keywords) then
			return { attr = k }
		end
	end
	return nil
end

local function makeDetector(keywords, fallbackFirstNumber)
	local cached, lastScan = nil, 0
	return function()
		if cached then
			if cached.inst then
				if cached.inst.Parent then
					return cached.inst.Value
				end
			else
				local a = player:GetAttribute(cached.attr)
				if a ~= nil then
					return a
				end
			end
			cached = nil
		end

		local now = os.clock()
		if now - lastScan < 3 then
			return nil -- jangan scan terus-menerus
		end
		lastScan = now

		cached = scanStat(keywords)
		if not cached and fallbackFirstNumber then
			local ls = player:FindFirstChild("leaderstats")
			if ls then
				for _, v in ipairs(ls:GetChildren()) do
					if v:IsA("IntValue") or v:IsA("NumberValue") then
						cached = { inst = v }
						break
					end
				end
			end
		end
		if cached then
			if cached.inst then
				return cached.inst.Value
			end
			return player:GetAttribute(cached.attr)
		end
		return nil
	end
end

local getMoney = makeDetector({ "money", "cash", "coin" }, true)
local getTreadmill = makeDetector({ "treadmill" }, false)

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
			local all = workspace:GetDescendants()
			for i, d in ipairs(all) do
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

local terrain = workspace:FindFirstChildOfClass("Terrain")

-- 1) Bangunan buruk (grafis rendah)
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
	pcall(m.set, Lighting, "GlobalShadows", false)
	pcall(function()
		sethiddenproperty(Lighting, "Technology", Enum.Technology.Compatibility)
	end)
	if terrain then
		pcall(m.set, terrain, "WaterWaveSize", 0)
		pcall(m.set, terrain, "WaterWaveSpeed", 0)
		pcall(m.set, terrain, "WaterReflectance", 0)
		pcall(m.set, terrain, "Decoration", false)
	end
	pcall(function()
		settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
	end)
end, function()
	pcall(function()
		settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
	end)
end)

-- 2) Hapus benda berat (efek, partikel, tekstur, lampu)
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
		elseif e:IsA("Atmosphere") then
			m.set(e, "Density", 0)
		end
	end
end)

-- 3) Sembunyikan pemain lain
local hidePlayersMode = newMode(function(m, d)
	if d:IsA("BasePart") or d:IsA("Decal") then
		local model = d:FindFirstAncestorOfClass("Model")
		local plr = model and Players:GetPlayerFromCharacter(model)
		if plr and plr ~= player then
			m.set(d, "Transparency", 1)
		end
	end
end)

-- 4) Matikan suara
local muteMode = newMode(function(m, d)
	if d:IsA("Sound") then
		m.set(d, "Volume", 0)
	end
end)

local allModes = { badMode, heavyMode, hidePlayersMode, muteMode }

---------------------------------------------------------------- GUI dasar
local parent = guiParent()
local old = parent:FindFirstChild("FarihHub")
if old then
	old:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "FarihHub"
gui.ResetOnSpawn = false
gui.Parent = parent

local COL_BG = Color3.fromRGB(22, 22, 30)
local COL_BAR = Color3.fromRGB(34, 34, 48)
local COL_BTN = Color3.fromRGB(45, 45, 60)
local COL_ON = Color3.fromRGB(40, 130, 70)
local COL_ACCENT = Color3.fromRGB(255, 200, 70)

local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 6)
	c.Parent = inst
end

local function newLabel(text, parentFrame)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextSize = 13
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = parentFrame
	return l
end

-- FPS overlay
local fpsFrame = Instance.new("Frame")
fpsFrame.Size = UDim2.fromOffset(84, 24)
fpsFrame.Position = UDim2.new(0, 8, 0, 8)
fpsFrame.BackgroundColor3 = Color3.new(0, 0, 0)
fpsFrame.BackgroundTransparency = 0.3
fpsFrame.Parent = gui
corner(fpsFrame, 5)
local fpsLabel = newLabel("FPS: --", fpsFrame)
fpsLabel.Size = UDim2.new(1, -10, 1, 0)
fpsLabel.Position = UDim2.fromOffset(6, 0)

-- Window
local window = Instance.new("Frame")
window.Size = UDim2.fromOffset(270, 340)
window.Position = UDim2.new(0, 8, 0, 40)
window.BackgroundColor3 = COL_BG
window.BorderSizePixel = 0
window.Parent = gui
corner(window, 8)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 28)
titleBar.BackgroundColor3 = COL_BAR
titleBar.BorderSizePixel = 0
titleBar.Parent = window
corner(titleBar, 8)

local titleLabel = newLabel("FarihHub " .. VERSION, titleBar)
titleLabel.Size = UDim2.new(1, -70, 1, 0)
titleLabel.Position = UDim2.fromOffset(10, 0)
titleLabel.TextColor3 = COL_ACCENT

local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 1, -28)
body.Position = UDim2.fromOffset(0, 28)
body.BackgroundTransparency = 1
body.Parent = window

local function titleButton(text, xOffset, cb)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(26, 20)
	b.Position = UDim2.new(1, xOffset, 0, 4)
	b.BackgroundColor3 = COL_BTN
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.Text = text
	b.Parent = titleBar
	corner(b, 4)
	b.Activated:Connect(cb)
end

titleButton("-", -58, function()
	body.Visible = not body.Visible
	window.Size = body.Visible and UDim2.fromOffset(270, 340) or UDim2.fromOffset(270, 28)
end)
titleButton("X", -30, function()
	for _, m in ipairs(allModes) do
		m.disable()
	end
	gui:Destroy()
end)

-- Drag window
do
	local dragging, dragStart, startPos
	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = window.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			window.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y
			)
		end
	end)
end

---------------------------------------------------------------- Tab system
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -12, 0, 26)
tabBar.Position = UDim2.fromOffset(6, 4)
tabBar.BackgroundTransparency = 1
tabBar.Parent = body
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 4)
tabLayout.Parent = tabBar

local pages, tabButtons = {}, {}

local function showTab(name)
	for n, p in pairs(pages) do
		p.Visible = (n == name)
		tabButtons[n].BackgroundColor3 = (n == name) and COL_ON or COL_BTN
	end
end

local function addTab(name)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1 / 3, -3, 1, 0)
	btn.BackgroundColor3 = COL_BTN
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.Text = name
	btn.Parent = tabBar
	corner(btn, 5)
	tabButtons[name] = btn

	local page = Instance.new("ScrollingFrame")
	page.Size = UDim2.new(1, -12, 1, -40)
	page.Position = UDim2.fromOffset(6, 34)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 3
	page.CanvasSize = UDim2.new()
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.Visible = false
	page.Parent = body
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 4)
	l.Parent = page
	pages[name] = page

	btn.Activated:Connect(function()
		showTab(name)
	end)
	return page
end

local function addSection(page, text)
	local l = newLabel(text, page)
	l.Size = UDim2.new(1, 0, 0, 20)
	l.TextColor3 = COL_ACCENT
	return l
end

local function addRow(page, text)
	local l = newLabel(text, page)
	l.Size = UDim2.new(1, 0, 0, 18)
	return l
end

local function addButton(page, text, cb)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 26)
	b.BackgroundColor3 = COL_BTN
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.Gotham
	b.TextSize = 12
	b.Text = text
	b.Parent = page
	corner(b, 5)
	b.Activated:Connect(cb)
	return b
end

local function addToggle(page, text, initial, cb)
	local on = initial
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 26)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.Gotham
	b.TextSize = 12
	b.Parent = page
	corner(b, 5)
	local function render()
		b.Text = text .. ": " .. (on and "ON" or "OFF")
		b.BackgroundColor3 = on and COL_ON or COL_BTN
	end
	render()
	b.Activated:Connect(function()
		on = not on
		render()
		cb(on)
	end)
end

---------------------------------------------------------------- Tab: Optimasi
local optPage = addTab("Optimasi")
addSection(optPage, "Statistik")
local ping = addRow(optPage, "Ping: -")
local memRow = addRow(optPage, "Memori: -")

addSection(optPage, "Naikkan FPS")
local status = addRow(optPage, "")
status.TextColor3 = Color3.fromRGB(180, 180, 190)
status.TextSize = 11
status.TextWrapped = true
status.Size = UDim2.new(1, 0, 0, 28)

addToggle(optPage, "Tampil FPS", true, function(on)
	fpsFrame.Visible = on
end)
addToggle(optPage, "Bangunan Buruk", false, function(on)
	if on then badMode.enable() else badMode.disable() end
end)
addToggle(optPage, "Hapus Benda Berat", false, function(on)
	if on then heavyMode.enable() else heavyMode.disable() end
end)
addToggle(optPage, "Sembunyikan Pemain Lain", false, function(on)
	if on then hidePlayersMode.enable() else hidePlayersMode.disable() end
end)
addToggle(optPage, "Matikan Suara", false, function(on)
	if on then muteMode.enable() else muteMode.disable() end
end)
addToggle(optPage, "Unlock FPS Cap", false, function(on)
	if setfpscap then
		pcall(setfpscap, on and 999 or 60)
		status.Text = on and "FPS cap dibuka (999)." or "FPS cap kembali 60."
	else
		status.Text = "Executor kamu tidak mendukung setfpscap."
	end
end)
addButton(optPage, "Bersihkan Memori", function()
	pcall(collectgarbage, "collect")
	status.Text = "Memori dibersihkan."
end)

---------------------------------------------------------------- Tab: Profile
local profPage = addTab("Profile")
addSection(profPage, "Akun")
addRow(profPage, "Nama: " .. player.Name)
local moneyRow = addRow(profPage, "Money: -")
local mpsRow = addRow(profPage, "Money/s: -")
local speedRow = addRow(profPage, "Speed: -")
local treadRow = addRow(profPage, "Treadmill: -")
local devRow = addRow(profPage, "Developer: " .. DEVELOPER)
devRow.TextColor3 = Color3.fromRGB(120, 220, 255)
local detectNote = addRow(profPage, "Stat dideteksi otomatis dari akunmu.")
detectNote.TextSize = 11
detectNote.TextColor3 = Color3.fromRGB(180, 180, 190)
detectNote.TextWrapped = true
detectNote.Size = UDim2.new(1, 0, 0, 28)

---------------------------------------------------------------- Tab: Community
local comPage = addTab("Community")
addSection(comPage, "Gabung komunitas")
addRow(comPage, "Discord: " .. DISCORD)
addButton(comPage, "Salin Discord", function()
	if setclipboard then
		pcall(setclipboard, DISCORD)
	end
end)
addRow(comPage, "WhatsApp: " .. WHATSAPP)
addButton(comPage, "Salin WhatsApp", function()
	if setclipboard then
		pcall(setclipboard, WHATSAPP)
	end
end)
local credit = addRow(comPage, "FarihHub " .. VERSION .. " by " .. DEVELOPER)
credit.TextColor3 = COL_ACCENT

showTab("Optimasi")

---------------------------------------------------------------- Loop update
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

local history = {} -- { {t, money} } untuk Money/s (jendela 5 detik)
local statsTimer = 0

task.spawn(function()
	while gui.Parent do
		-- Money real time
		local money = getMoney()
		moneyRow.Text = "Money: " .. fmt(money)
		if type(money) == "number" then
			local now = os.clock()
			table.insert(history, { now, money })
			while #history > 1 and now - history[1][1] > 5 do
				table.remove(history, 1)
			end
			local first, last = history[1], history[#history]
			local dt = last[1] - first[1]
			if dt > 0.5 then
				mpsRow.Text = "Money/s: " .. fmt(math.max(0, (last[2] - first[2]) / dt))
			end
		end

		-- Speed
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		speedRow.Text = "Speed: " .. (hum and fmt(hum.WalkSpeed) or "-")

		-- Treadmill
		treadRow.Text = "Treadmill: " .. fmt(getTreadmill())

		-- Ping + memori (tiap ~0.5 detik)
		statsTimer += 0.25
		if statsTimer >= 0.5 then
			statsTimer = 0
			local okP, p = pcall(function()
				return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
			end)
			ping.Text = "Ping: " .. (okP and (math.floor(p) .. " ms") or "-")
			local okM, mem = pcall(function()
				return Stats:GetTotalMemoryUsageMb()
			end)
			memRow.Text = "Memori: " .. (okM and (math.floor(mem) .. " MB") or "-")
		end

		task.wait(0.25)
	end
end)
