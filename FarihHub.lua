-- FarihHub V0.3
-- Developer: FARIH
-- Script tampilan, optimasi & info lokal. Tidak mengotomatiskan gameplay
-- dan tidak mengubah game / pemain lain.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UIS = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local player = Players.LocalPlayer

local VERSION = "V0.6"
local DEVELOPER = "FARIH"
local DISCORD = "Ellll0590"
local WHATSAPP = "Saluran Comming"
local NOTES_FILE = "FarihHub_notes.txt"

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

local function fmtTime(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%02d:%02d:%02d", sec // 3600, (sec % 3600) // 60, sec % 60)
end

local multipliers = { k = 1e3, m = 1e6, b = 1e9, t = 1e12 }
local function parseAmount(s)
	s = (s:lower():gsub("[,%s]", ""))
	local num, suf = s:match("^([%d%.]+)(%a*)$")
	num = tonumber(num)
	if not num then
		return nil
	end
	if suf ~= "" then
		local m = multipliers[suf]
		if not m then
			return nil
		end
		num *= m
	end
	return num
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
			return nil
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
		if applyFn then
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

-- 3) Sembunyikan pemain lain (hanya di layarmu)
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

---------------------------------------------------------------- Tema
local themes = {
	Gelap = {
		bg = Color3.fromRGB(22, 22, 30), bar = Color3.fromRGB(34, 34, 48),
		btn = Color3.fromRGB(45, 45, 60), on = Color3.fromRGB(40, 130, 70),
		accent = Color3.fromRGB(255, 200, 70),
	},
	Biru = {
		bg = Color3.fromRGB(16, 24, 40), bar = Color3.fromRGB(24, 40, 70),
		btn = Color3.fromRGB(34, 54, 90), on = Color3.fromRGB(40, 110, 200),
		accent = Color3.fromRGB(120, 200, 255),
	},
	Hijau = {
		bg = Color3.fromRGB(16, 30, 22), bar = Color3.fromRGB(24, 50, 36),
		btn = Color3.fromRGB(34, 66, 48), on = Color3.fromRGB(50, 160, 90),
		accent = Color3.fromRGB(150, 255, 170),
	},
	Ungu = {
		bg = Color3.fromRGB(28, 18, 40), bar = Color3.fromRGB(48, 30, 70),
		btn = Color3.fromRGB(64, 42, 92), on = Color3.fromRGB(140, 70, 200),
		accent = Color3.fromRGB(230, 170, 255),
	},
}
local themeOrder = { "Gelap", "Biru", "Hijau", "Ungu" }
local theme = themes.Gelap
local registry, rerenders, conns = {}, {}, {}

local function reg(inst, prop, role)
	inst[prop] = theme[role]
	table.insert(registry, { inst, prop, role })
end

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

-- Toast (pesan singkat di atas layar)
local toast = newLabel("", gui)
toast.Size = UDim2.fromOffset(280, 32)
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 0, 10)
toast.BackgroundTransparency = 0.2
toast.BackgroundColor3 = Color3.new(0, 0, 0)
toast.TextXAlignment = Enum.TextXAlignment.Center
toast.TextWrapped = true
toast.TextSize = 12
toast.Visible = false
corner(toast, 6)
local toastId = 0
local function showToast(text)
	toastId += 1
	local id = toastId
	toast.Text = text
	toast.Visible = true
	task.delay(6, function()
		if toastId == id then
			toast.Visible = false
		end
	end)
end

-- Window
local WIN_W, WIN_H = 320, 380

local window = Instance.new("Frame")
window.Size = UDim2.fromOffset(WIN_W, WIN_H)
window.Position = UDim2.new(0, 8, 0, 40)
window.BorderSizePixel = 0
window.Parent = gui
reg(window, "BackgroundColor3", "bg")
corner(window, 8)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 28)
titleBar.BorderSizePixel = 0
titleBar.Parent = window
reg(titleBar, "BackgroundColor3", "bar")
corner(titleBar, 8)

local titleLabel = newLabel("FarihHub " .. VERSION, titleBar)
titleLabel.Size = UDim2.new(1, -70, 1, 0)
titleLabel.Position = UDim2.fromOffset(10, 0)
reg(titleLabel, "TextColor3", "accent")

local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 1, -28)
body.Position = UDim2.fromOffset(0, 28)
body.BackgroundTransparency = 1
body.Parent = window

local function titleButton(text, xOffset, cb)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(26, 20)
	b.Position = UDim2.new(1, xOffset, 0, 4)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.Text = text
	b.Parent = titleBar
	reg(b, "BackgroundColor3", "btn")
	corner(b, 4)
	b.Activated:Connect(cb)
end

titleButton("-", -58, function()
	body.Visible = not body.Visible
	window.Size = body.Visible and UDim2.fromOffset(WIN_W, WIN_H) or UDim2.fromOffset(WIN_W, 28)
end)
titleButton("X", -30, function()
	for _, m in ipairs(allModes) do
		m.disable()
	end
	for _, c in ipairs(conns) do
		c:Disconnect()
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
	table.insert(conns, UIS.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			window.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + d.X,
				startPos.Y.Scale, startPos.Y.Offset + d.Y
			)
		end
	end))
end

-- Tombol pintas: RightShift buka/tutup menu
table.insert(conns, UIS.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.RightShift then
		window.Visible = not window.Visible
	end
end))

---------------------------------------------------------------- Tab system
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -12, 0, 26)
tabBar.Position = UDim2.fromOffset(6, 4)
tabBar.BackgroundTransparency = 1
tabBar.Parent = body
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 3)
tabLayout.Parent = tabBar

local pages, tabButtons = {}, {}
local currentTab

local function showTab(name)
	currentTab = name
	for n, p in pairs(pages) do
		p.Visible = (n == name)
		tabButtons[n].BackgroundColor3 = (n == name) and theme.on or theme.btn
	end
end
table.insert(rerenders, function()
	if currentTab then
		showTab(currentTab)
	end
end)

local function addTab(name)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1 / 6, -3, 1, 0)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 9
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
	reg(l, "TextColor3", "accent")
	return l
end

local function addRow(page, text)
	local l = newLabel(text, page)
	l.Size = UDim2.new(1, 0, 0, 18)
	return l
end

local function addNote(page, text, height)
	local l = newLabel(text, page)
	l.Font = Enum.Font.Gotham
	l.TextSize = 11
	l.TextWrapped = true
	l.TextColor3 = Color3.fromRGB(200, 200, 210)
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Size = UDim2.new(1, 0, 0, height or 30)
	return l
end

local function addButton(page, text, cb)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 26)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.Gotham
	b.TextSize = 12
	b.Text = text
	b.Parent = page
	reg(b, "BackgroundColor3", "btn")
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
		b.BackgroundColor3 = on and theme.on or theme.btn
	end
	render()
	table.insert(rerenders, render)

	local obj = {}
	function obj.set(v)
		if on == v then
			return
		end
		on = v
		render()
		cb(on)
	end
	b.Activated:Connect(function()
		obj.set(not on)
	end)
	return obj
end

local function addInput(page, placeholder, height, multiline)
	local tb = Instance.new("TextBox")
	tb.Size = UDim2.new(1, 0, 0, height or 26)
	tb.TextColor3 = Color3.new(1, 1, 1)
	tb.PlaceholderText = placeholder
	tb.PlaceholderColor3 = Color3.fromRGB(150, 150, 160)
	tb.Text = ""
	tb.ClearTextOnFocus = false
	tb.Font = Enum.Font.Gotham
	tb.TextSize = 12
	tb.MultiLine = multiline or false
	tb.TextWrapped = multiline or false
	tb.TextXAlignment = Enum.TextXAlignment.Left
	tb.TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
	tb.Parent = page
	reg(tb, "BackgroundColor3", "btn")
	corner(tb, 5)
	return tb
end

local function applyTheme(name)
	theme = themes[name]
	pcall(function()
		if writefile then
			writefile("FarihHub_theme.txt", name)
		end
	end)
	for _, r in ipairs(registry) do
		if r[1].Parent then
			r[1][r[2]] = theme[r[3]]
		end
	end
	for _, f in ipairs(rerenders) do
		f()
	end
end

---------------------------------------------------------------- Tab: Optimasi
local optPage = addTab("Optimasi")
addSection(optPage, "Statistik")
local pingRow = addRow(optPage, "Ping: -")
local memRow = addRow(optPage, "Memori: -")
local fpsStats = { min = math.huge, max = 0, sum = 0, n = 0 }
local fpsStatRow = addRow(optPage, "FPS min/rata/max: -")
addButton(optPage, "Reset statistik FPS", function()
	fpsStats.min, fpsStats.max, fpsStats.sum, fpsStats.n = math.huge, 0, 0, 0
	fpsStatRow.Text = "FPS min/rata/max: -"
end)

local tBad, tHeavy, tHide, tMute, tFps

addSection(optPage, "Preset 1 tap")
addButton(optPage, "HP Kentang (paling ringan)", function()
	tBad.set(true)
	tHeavy.set(true)
	tHide.set(true)
	tMute.set(false)
	showToast("Preset HP Kentang aktif.")
end)
addButton(optPage, "Seimbang (efek dimatikan saja)", function()
	tBad.set(false)
	tHeavy.set(true)
	tHide.set(false)
	tMute.set(false)
	showToast("Preset Seimbang aktif.")
end)
addButton(optPage, "Reset semua ke normal", function()
	tBad.set(false)
	tHeavy.set(false)
	tHide.set(false)
	tMute.set(false)
	showToast("Semua optimasi dimatikan.")
end)

addSection(optPage, "Atur manual")
local status = addNote(optPage, "", 28)

tFps = addToggle(optPage, "Tampil FPS", true, function(on)
	fpsFrame.Visible = on
end)
tBad = addToggle(optPage, "Bangunan Buruk", false, function(on)
	if on then badMode.enable() else badMode.disable() end
end)
tHeavy = addToggle(optPage, "Hapus Benda Berat", false, function(on)
	if on then heavyMode.enable() else heavyMode.disable() end
end)
tHide = addToggle(optPage, "Sembunyikan Pemain Lain", false, function(on)
	if on then hidePlayersMode.enable() else hidePlayersMode.disable() end
end)
tMute = addToggle(optPage, "Matikan Suara", false, function(on)
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
local autoClean, nextClean = false, 0
addToggle(optPage, "Auto bersihkan (2 menit)", false, function(on)
	autoClean = on
	nextClean = os.clock() + 120
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

addSection(profPage, "Statistik sesi")
local sessTimeRow = addRow(profPage, "Lama main: 00:00:00")
local sessGainRow = addRow(profPage, "Money didapat: -")
local sessPeakRow = addRow(profPage, "Money/s tertinggi: -")
addNote(profPage, "Stat dideteksi otomatis dari akunmu. Kalau tampil \"-\", game belum menyimpan stat itu di leaderstats.", 42)

---------------------------------------------------------------- Tab: Goal
local goalPage = addTab("Goal")
local function addGoal(page, title, placeholder, withEta)
	addSection(page, title)
	local box = addInput(page, placeholder)
	local g = {
		target = nil,
		prog = addRow(page, "Progress: -"),
		left = addRow(page, "Sisa: -"),
	}
	if withEta then
		g.eta = addRow(page, "Estimasi: -")
	end
	box.FocusLost:Connect(function()
		g.target = parseAmount(box.Text)
		if box.Text ~= "" and not g.target then
			showToast("Format target tidak dikenal. Contoh: 500k atau 1.5m")
		end
	end)
	return g
end

local function updateGoal(g, value, rate)
	if not g.target or type(value) ~= "number" then
		return
	end
	local pct = math.clamp(value / g.target * 100, 0, 100)
	g.prog.Text = string.format("Progress: %.1f%%", pct)
	local remaining = g.target - value
	if remaining <= 0 then
		g.left.Text = "Sisa: target tercapai!"
		if g.eta then
			g.eta.Text = "Estimasi: -"
		end
	else
		g.left.Text = "Sisa: " .. fmt(remaining)
		if g.eta then
			g.eta.Text = "Estimasi: " .. ((rate or 0) > 0 and fmtTime(remaining / rate) or "-")
		end
	end
end

-- Hitung kecepatan naik stat per detik (jendela 5 detik)
local function makeRate()
	local hist = {}
	return function(value)
		if type(value) ~= "number" then
			return nil
		end
		local now = os.clock()
		table.insert(hist, { now, value })
		while #hist > 1 and now - hist[1][1] > 5 do
			table.remove(hist, 1)
		end
		local first, last = hist[1], hist[#hist]
		local dt = last[1] - first[1]
		if dt > 0.5 then
			return math.max(0, (last[2] - first[2]) / dt)
		end
		return nil
	end
end
local treadRate = makeRate()

addNote(goalPage, "Isi target, contoh: 500k, 1.5m, 2b. Estimasi dihitung dari kecepatan naik stat kamu.", 30)
local moneyGoal = addGoal(goalPage, "Target Money", "Target Money (mis. 1.5m)", true)
local treadGoal = addGoal(goalPage, "Target Treadmill", "Target Treadmill (mis. 10k)", true)
local speedGoal = addGoal(goalPage, "Target Speed", "Target Speed (mis. 500)", false)

addSection(goalPage, "Grafik Money/s (1 menit terakhir)")
local GRAPH_N, GRAPH_H = 30, 66
local graphFrame = Instance.new("Frame")
graphFrame.Size = UDim2.new(1, 0, 0, 70)
graphFrame.BorderSizePixel = 0
graphFrame.Parent = goalPage
reg(graphFrame, "BackgroundColor3", "btn")
corner(graphFrame, 5)
local bars, samples = {}, {}
for i = 1, GRAPH_N do
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new((i - 1) / GRAPH_N, 2, 1, -2)
	bar.Size = UDim2.new(1 / GRAPH_N, -2, 0, 1)
	bar.BorderSizePixel = 0
	bar.Visible = false
	bar.Parent = graphFrame
	reg(bar, "BackgroundColor3", "accent")
	bars[i] = bar
end
local graphPeakRow = addRow(goalPage, "Puncak grafik: -")

local function pushSample(v)
	table.insert(samples, v)
	if #samples > GRAPH_N then
		table.remove(samples, 1)
	end
	local peak = 0
	for _, s in ipairs(samples) do
		if s > peak then
			peak = s
		end
	end
	local offset = GRAPH_N - #samples
	for i, bar in ipairs(bars) do
		local s = samples[i - offset]
		if s then
			bar.Visible = true
			local h = peak > 0 and math.floor(s / peak * GRAPH_H) or 0
			bar.Size = UDim2.new(1 / GRAPH_N, -2, 0, math.max(1, h))
		else
			bar.Visible = false
		end
	end
	graphPeakRow.Text = "Puncak grafik: " .. fmt(peak) .. "/s"
end

addSection(goalPage, "Pengingat istirahat")
local remEnabled, remMinutes, nextRemind = false, 30, 0
local remBtn
addToggle(goalPage, "Ingatkan", false, function(on)
	remEnabled = on
	nextRemind = os.clock() + remMinutes * 60
end)
remBtn = addButton(goalPage, "Interval: 30 menit (tap untuk ganti)", function()
	local options = { 15, 30, 45, 60 }
	local idx = table.find(options, remMinutes) or 1
	remMinutes = options[idx % #options + 1]
	remBtn.Text = "Interval: " .. remMinutes .. " menit (tap untuk ganti)"
	nextRemind = os.clock() + remMinutes * 60
end)

addSection(goalPage, "Catatan")
local notesBox = addInput(goalPage, "Tulis catatan di sini...", 90, true)
pcall(function()
	if isfile and readfile and isfile(NOTES_FILE) then
		notesBox.Text = readfile(NOTES_FILE)
	end
end)
notesBox.FocusLost:Connect(function()
	pcall(function()
		if writefile then
			writefile(NOTES_FILE, notesBox.Text)
		end
	end)
end)


---------------------------------------------------------------- Tab: Tools
local toolsPage = addTab("Tools")

addSection(toolsPage, "Server")
local playersRow = addRow(toolsPage, "Pemain: -")
local uptimeRow = addRow(toolsPage, "Server aktif: -")
addRow(toolsPage, "Job ID: " .. string.sub(game.JobId ~= "" and game.JobId or "studio", 1, 8) .. "...")
addButton(toolsPage, "Salin Job ID", function()
	if setclipboard and game.JobId ~= "" then
		pcall(setclipboard, game.JobId)
		showToast("Job ID disalin.")
	end
end)
addButton(toolsPage, "Rejoin server ini", function()
	showToast("Mencoba masuk ulang...")
	pcall(function()
		game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
	end)
end)

local searching = false
addButton(toolsPage, "Cari server sepi & pindah", function()
	if searching then
		return
	end
	searching = true
	showToast("Mencari server paling sepi...")
	task.spawn(function()
		local ok, result = pcall(function()
			local url = string.format(
				"https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100",
				game.PlaceId
			)
			return game:GetService("HttpService"):JSONDecode(game:HttpGet(url))
		end)
		if not ok or type(result) ~= "table" or type(result.data) ~= "table" then
			showToast("Gagal mengambil daftar server. Executor tidak mendukung HttpGet atau sedang kena batas, coba lagi nanti.")
			searching = false
			return
		end

		-- Pilih server dengan pemain paling sedikit (seri: ping terendah)
		local best
		for _, s in ipairs(result.data) do
			if s.id ~= game.JobId and s.playing and s.maxPlayers and s.playing < s.maxPlayers then
				if not best
					or s.playing < best.playing
					or (s.playing == best.playing and (s.ping or 9e9) < (best.ping or 9e9)) then
					best = s
				end
			end
		end
		if not best then
			showToast("Tidak ada server lain yang cocok.")
			searching = false
			return
		end

		showToast("Pindah ke server dengan " .. best.playing .. " pemain...")
		pcall(function()
			game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, best.id, player)
		end)
		task.delay(10, function()
			searching = false
		end)
	end)
end)

addSection(toolsPage, "Waktu")
local clockRow = addRow(toolsPage, "Jam: -")
local swRow = addRow(toolsPage, "Stopwatch: 00:00:00")
local swRunning, swElapsed, swStart = false, 0, 0
addButton(toolsPage, "Start / Stop stopwatch", function()
	if swRunning then
		swElapsed += os.clock() - swStart
		swRunning = false
	else
		swStart = os.clock()
		swRunning = true
	end
end)
addButton(toolsPage, "Reset stopwatch", function()
	swRunning = false
	swElapsed = 0
end)

addSection(toolsPage, "Tampilan")
local startCam = workspace.CurrentCamera
local originalFov = startCam and startCam.FieldOfView or 70
local fovOptions = { 60, 70, 80, 90, 100, 120 }
local fovBtn
fovBtn = addButton(toolsPage, "FOV: " .. math.floor(originalFov + 0.5) .. " (tap ganti)", function()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local nextFov = fovOptions[1]
	for _, f in ipairs(fovOptions) do
		if f > cam.FieldOfView + 0.5 then
			nextFov = f
			break
		end
	end
	cam.FieldOfView = nextFov
	fovBtn.Text = "FOV: " .. nextFov .. " (tap ganti)"
end)
addButton(toolsPage, "Reset FOV", function()
	local cam = workspace.CurrentCamera
	if cam then
		cam.FieldOfView = originalFov
		fovBtn.Text = "FOV: " .. math.floor(originalFov + 0.5) .. " (tap ganti)"
	end
end)

local hiddenGuis = {}
addToggle(toolsPage, "Mode Screenshot", false, function(on)
	if on then
		for _, g in ipairs(player:WaitForChild("PlayerGui"):GetChildren()) do
			if g:IsA("ScreenGui") and g ~= gui and g.Enabled then
				g.Enabled = false
				table.insert(hiddenGuis, g)
			end
		end
		pcall(function()
			game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
		end)
		showToast("UI game disembunyikan. Matikan lagi untuk menampilkan.")
	else
		for _, g in ipairs(hiddenGuis) do
			if g.Parent then
				g.Enabled = true
			end
		end
		table.clear(hiddenGuis)
		pcall(function()
			game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
		end)
	end
end)

---------------------------------------------------------------- Tab: Pemula
local guidePage = addTab("Pemula")
addSection(guidePage, "Panduan singkat")
addNote(guidePage, "1. Game lag? Buka tab Optimasi lalu tap preset \"HP Kentang\". Kalau masih berat, nyalakan Unlock FPS Cap dan Bersihkan Memori.", 56)
addNote(guidePage, "2. Pantau progresmu di tab Profile (Money, Money/s, Speed, Treadmill).", 32)
addNote(guidePage, "3. Pasang target di tab Goal supaya tahu kira-kira kapan tercapai.", 32)
addNote(guidePage, "4. Ping di atas 150 ms biasanya bikin game terasa delay. Coba pindah server atau pakai sinyal yang lebih stabil.", 44)
addNote(guidePage, "5. Nyalakan pengingat istirahat di tab Goal supaya main tetap sehat.", 32)
addSection(guidePage, "Keamanan akun")
addNote(guidePage, "Jangan pernah bagikan password, kode login, atau cookie akun ke siapa pun. Hati-hati dengan script atau link dari sumber yang tidak dikenal.", 56)
addSection(guidePage, "Tips menu")
addNote(guidePage, "Geser jendela lewat judul. Tombol \"-\" untuk kecilkan, tombol RightShift untuk buka/tutup (di PC).", 44)

---------------------------------------------------------------- Tab: Info
local infoPage = addTab("Info")
addSection(infoPage, "Komunitas")
addRow(infoPage, "Discord: " .. DISCORD)
addButton(infoPage, "Salin Discord", function()
	if setclipboard then
		pcall(setclipboard, DISCORD)
		showToast("Discord disalin.")
	end
end)
addRow(infoPage, "WhatsApp: " .. WHATSAPP)
addButton(infoPage, "Salin WhatsApp", function()
	if setclipboard then
		pcall(setclipboard, WHATSAPP)
		showToast("WhatsApp disalin.")
	end
end)

addSection(infoPage, "Tema warna")
for _, name in ipairs(themeOrder) do
	addButton(infoPage, "Tema " .. name, function()
		applyTheme(name)
	end)
end

local credit = addRow(infoPage, "FarihHub " .. VERSION .. " by " .. DEVELOPER)
reg(credit, "TextColor3", "accent")

showTab("Optimasi")

-- Muat tema yang terakhir dipilih
pcall(function()
	if isfile and readfile and isfile("FarihHub_theme.txt") then
		local saved = readfile("FarihHub_theme.txt")
		if themes[saved] then
			applyTheme(saved)
		end
	end
end)

---------------------------------------------------------------- Loop update
local frames, lastTick = 0, os.clock()
table.insert(conns, RunService.RenderStepped:Connect(function()
	frames += 1
	local now = os.clock()
	if now - lastTick >= 0.5 then
		local fps = math.floor(frames / (now - lastTick) + 0.5)
		fpsLabel.Text = "FPS: " .. fps
		fpsStats.min = math.min(fpsStats.min, fps)
		fpsStats.max = math.max(fpsStats.max, fps)
		fpsStats.sum += fps
		fpsStats.n += 1
		fpsStatRow.Text = string.format(
			"FPS min/rata/max: %d/%d/%d",
			fpsStats.min, math.floor(fpsStats.sum / fpsStats.n + 0.5), fpsStats.max
		)
		frames = 0
		lastTick = now
	end
end))

local history = {} -- { {t, money} } untuk Money/s (jendela 5 detik)
local statsTimer, graphTimer = 0, 0
local sessionStart = os.clock()
local startMoney, peakRate, currentRate = nil, 0, 0

task.spawn(function()
	while gui.Parent do
		local now = os.clock()

		-- Money real time
		local money = getMoney()
		moneyRow.Text = "Money: " .. fmt(money)
		if type(money) == "number" then
			if not startMoney then
				startMoney = money
			end
			table.insert(history, { now, money })
			while #history > 1 and now - history[1][1] > 5 do
				table.remove(history, 1)
			end
			local first, last = history[1], history[#history]
			local dt = last[1] - first[1]
			if dt > 0.5 then
				currentRate = math.max(0, (last[2] - first[2]) / dt)
				mpsRow.Text = "Money/s: " .. fmt(currentRate)
				if currentRate > peakRate then
					peakRate = currentRate
				end
			end
			sessGainRow.Text = "Money didapat: " .. fmt(money - startMoney)
			sessPeakRow.Text = "Money/s tertinggi: " .. fmt(peakRate)

			-- Goal
			updateGoal(moneyGoal, money, currentRate)
		end
		sessTimeRow.Text = "Lama main: " .. fmtTime(now - sessionStart)

		-- Speed
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local walkSpeed = hum and hum.WalkSpeed
		speedRow.Text = "Speed: " .. fmt(walkSpeed)
		updateGoal(speedGoal, walkSpeed)

		-- Treadmill
		local tread = getTreadmill()
		treadRow.Text = "Treadmill: " .. fmt(tread)
		updateGoal(treadGoal, tread, treadRate(tread))

		-- Grafik Money/s (tiap 2 detik)
		graphTimer += 0.25
		if graphTimer >= 2 then
			graphTimer = 0
			pushSample(currentRate)
		end

		-- Auto bersihkan memori
		if autoClean and now >= nextClean then
			pcall(collectgarbage, "collect")
			nextClean = now + 120
		end

		-- Info server, jam, stopwatch
		playersRow.Text = "Pemain: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers
		uptimeRow.Text = "Server aktif: " .. fmtTime(workspace.DistributedGameTime)
		clockRow.Text = "Jam: " .. os.date("%H:%M:%S")
		swRow.Text = "Stopwatch: " .. fmtTime(swElapsed + (swRunning and (now - swStart) or 0))

		-- Pengingat istirahat
		if remEnabled and now >= nextRemind then
			showToast("Sudah " .. remMinutes .. " menit main. Waktunya istirahat sebentar!")
			nextRemind = now + remMinutes * 60
		end

		-- Ping + memori (tiap ~0.5 detik)
		statsTimer += 0.25
		if statsTimer >= 0.5 then
			statsTimer = 0
			local okP, p = pcall(function()
				return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
			end)
			pingRow.Text = "Ping: " .. (okP and (math.floor(p) .. " ms") or "-")
			local okM, mem = pcall(function()
				return Stats:GetTotalMemoryUsageMb()
			end)
			memRow.Text = "Memori: " .. (okM and (math.floor(mem) .. " MB") or "-")
		end

		task.wait(0.25)
	end
end)
