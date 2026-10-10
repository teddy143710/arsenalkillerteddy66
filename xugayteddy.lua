local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local VIM = game:GetService("VirtualInputManager")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")

local S = {
    ESP = false, ESPBoxes = true, ESPLines = false, ESPHealth = true, ESPDistance = 1500,
    TeamCheck = true,
    Chams = false, ChamsRainbow = false,
    Aim = false, AimPart = "Head", AimFOV = 150, AimSmooth = 12, AimWalls = false, AimDistance = 1000,
    Hitbox = false, HitboxW = 6, HitboxH = 6, HitboxVisible = true,
    FOVVisible = true, FOVSize = 150,
    SilentAim = false,
    AmmoMod = false,
    RecoilMod = false,
    MenuOpen = true,
    ActiveCategory = "Combat",
}

local COL = {
    BG       = Color3.fromRGB(10, 12, 22),
    Panel    = Color3.fromRGB(16, 20, 38),
    Panel2   = Color3.fromRGB(22, 28, 52),
    Accent   = Color3.fromRGB(65, 145, 255),
    Text     = Color3.fromRGB(235, 240, 255),
    Muted    = Color3.fromRGB(120, 140, 190),
    White    = Color3.fromRGB(255, 255, 255),
    Black    = Color3.fromRGB(0, 0, 0),
    ON       = Color3.fromRGB(65, 145, 255),
    OFF      = Color3.fromRGB(35, 42, 70),
    Red      = Color3.fromRGB(255, 70, 80),
    Green    = Color3.fromRGB(60, 220, 100),
    Yellow   = Color3.fromRGB(255, 210, 50),
}

local espObjects = {}
local chamsObjects = {}
local oldHitboxes = {}
local lockedTarget = nil
local rainbowHue = 0

local function corner(o, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = o
end

local function stroke(o, col, thick)
    local s = Instance.new("UIStroke")
    s.Color = col or COL.Accent
    s.Thickness = thick or 1.5
    s.Transparency = 0.2
    s.Parent = o
    return s
end

local function alive(p)
    local c = p.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    local r = c and c:FindFirstChild("HumanoidRootPart")
    return c and h and r and h.Health > 0
end

local function isEnemy(p)
    if p == LocalPlayer then return false end
    if not alive(p) then return false end
    if S.TeamCheck and LocalPlayer.Team and p.Team and LocalPlayer.Team == p.Team then return false end
    return true
end

local function getRoot(p)
    return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end

local function getAimPart(p)
    local c = p.Character
    if not c then return nil end
    if S.AimPart == "Head" then
        return c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart")
    elseif S.AimPart == "Torso" then
        return c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso") or c:FindFirstChild("HumanoidRootPart")
    else
        return c:FindFirstChild("HumanoidRootPart")
    end
end

local function isVisible(part)
    if not part then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    local dir = part.Position - Camera.CFrame.Position
    local hit = workspace:Raycast(Camera.CFrame.Position, dir, params)
    return not hit or hit.Instance:IsDescendantOf(part.Parent)
end

local function inFOV(part)
    if not part then return false end
    local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
    if not onScreen then return false end
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    return (Vector2.new(pos.X, pos.Y) - center).Magnitude <= S.AimFOV
end

local function getBestTarget()
    if lockedTarget and isEnemy(lockedTarget) then
        local part = getAimPart(lockedTarget)
        if part and inFOV(part) and (S.AimWalls or isVisible(part)) then
            return lockedTarget
        end
    end
    lockedTarget = nil
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local best, bestScore = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if isEnemy(p) then
            local part = getAimPart(p)
            local r = getRoot(p)
            if part and r then
                local dist = (r.Position - Camera.CFrame.Position).Magnitude
                if dist <= S.AimDistance and (S.AimWalls or isVisible(part)) then
                    local pos, on = Camera:WorldToViewportPoint(part.Position)
                    if on then
                        local sd = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                        if sd <= S.AimFOV and sd < bestScore then
                            bestScore = sd
                            best = p
                        end
                    end
                end
            end
        end
    end
    if best then lockedTarget = best end
    return best
end

local function doAim(p)
    local part = getAimPart(p)
    if not part then return end
    local cam = Camera.CFrame
    local goal = CFrame.lookAt(cam.Position, part.Position)
    Camera.CFrame = cam:Lerp(goal, math.clamp(S.AimSmooth / 100, 0.01, 1))
end

local function clearESP()
    for _, t in pairs(espObjects) do
        for _, obj in pairs(t) do
            pcall(function() obj:Destroy() end)
        end
    end
    espObjects = {}
end

local function clearChams()
    for _, h in pairs(chamsObjects) do
        pcall(function() h:Destroy() end)
    end
    chamsObjects = {}
end

local drawingEnabled = Drawing and true or false

local function renderESP()
    clearESP()
    if not S.ESP then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if isEnemy(p) and p.Character then
            local c = p.Character
            local head = c:FindFirstChild("Head")
            local root = c:FindFirstChild("HumanoidRootPart")
            local hum = c:FindFirstChildOfClass("Humanoid")
            if not head or not root or not hum then continue end
            local dist = (root.Position - Camera.CFrame.Position).Magnitude
            if dist > S.ESPDistance then continue end
            local _, cf, size = c:GetBoundingBox()
            local corners3D = {
                cf * Vector3.new( size.X/2,  size.Y/2,  size.Z/2),
                cf * Vector3.new(-size.X/2,  size.Y/2,  size.Z/2),
                cf * Vector3.new( size.X/2, -size.Y/2,  size.Z/2),
                cf * Vector3.new(-size.X/2, -size.Y/2,  size.Z/2),
                cf * Vector3.new( size.X/2,  size.Y/2, -size.Z/2),
                cf * Vector3.new(-size.X/2,  size.Y/2, -size.Z/2),
                cf * Vector3.new( size.X/2, -size.Y/2, -size.Z/2),
                cf * Vector3.new(-size.X/2, -size.Y/2, -size.Z/2),
            }
            local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
            local allVisible = true
            for _, v in ipairs(corners3D) do
                local sp, on = Camera:WorldToViewportPoint(v)
                if not on then allVisible = false end
                if sp.X < minX then minX = sp.X end
                if sp.Y < minY then minY = sp.Y end
                if sp.X > maxX then maxX = sp.X end
                if sp.Y > maxY then maxY = sp.Y end
            end
            if not allVisible and minX == math.huge then continue end

            local objs = {}
            if S.ESPBoxes then
                local box = Drawing.new("Square")
                box.Visible = true
                box.Position = Vector2.new(minX, minY)
                box.Size = Vector2.new(maxX - minX, maxY - minY)
                box.Color = COL.Accent
                box.Thickness = 1.5
                box.Filled = false
                table.insert(objs, box)
            end
            if S.ESPHealth then
                local hp = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                local hcol = hp > 0.6 and COL.Green or hp > 0.3 and COL.Yellow or COL.Red
                local barH = maxY - minY
                local barX = minX - 6
                local bg = Drawing.new("Square")
                bg.Visible = true
                bg.Position = Vector2.new(barX - 1, minY - 1)
                bg.Size = Vector2.new(4, barH + 2)
                bg.Color = Color3.fromRGB(0, 0, 0)
                bg.Filled = true
                bg.Thickness = 1
                table.insert(objs, bg)
                local bar = Drawing.new("Square")
                bar.Visible = true
                bar.Position = Vector2.new(barX, minY + barH * (1 - hp))
                bar.Size = Vector2.new(3, barH * hp)
                bar.Color = hcol
                bar.Filled = true
                bar.Thickness = 1
                table.insert(objs, bar)
            end
            if S.ESPLines then
                local rp, on = Camera:WorldToViewportPoint(root.Position)
                if on then
                    local ln = Drawing.new("Line")
                    ln.Visible = true
                    ln.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    ln.To = Vector2.new(rp.X, rp.Y)
                    ln.Color = COL.Accent
                    ln.Thickness = 1
                    table.insert(objs, ln)
                end
            end
            espObjects[p] = objs
        end
    end
end

local function renderChams()
    clearChams()
    if not S.Chams then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if isEnemy(p) and p.Character then
            local hi = Instance.new("Highlight")
            hi.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hi.FillTransparency = 0.5
            hi.OutlineTransparency = 0
            if S.ChamsRainbow then
                hi.FillColor = Color3.fromHSV(rainbowHue, 1, 1)
                hi.OutlineColor = Color3.fromHSV(rainbowHue, 1, 1)
            else
                hi.FillColor = COL.Accent
                hi.OutlineColor = COL.Accent
            end
            hi.Adornee = p.Character
            hi.Parent = CoreGui
            table.insert(chamsObjects, hi)
        end
    end
end

local function applyHitbox(p)
    if not isEnemy(p) then return end
    local c = p.Character
    if not c then return end
    local parts = {}
    local head = c:FindFirstChild("Head")
    local torso = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")
    local root = c:FindFirstChild("HumanoidRootPart")
    if head then table.insert(parts, head) end
    if torso then table.insert(parts, torso) end
    if root then table.insert(parts, root) end
    for _, part in ipairs(parts) do
        if part:IsA("BasePart") then
            if not oldHitboxes[part] then
                oldHitboxes[part] = {Size = part.Size, LocalTransparencyModifier = part.LocalTransparencyModifier}
            end
            part.Size = Vector3.new(S.HitboxW, S.HitboxH, S.HitboxW)
            part.LocalTransparencyModifier = S.HitboxVisible and 0.4 or 1
        end
    end
end

local function restoreHitboxes()
    for part, data in pairs(oldHitboxes) do
        if part and part.Parent then
            part.Size = data.Size
            part.LocalTransparencyModifier = data.LocalTransparencyModifier
        end
    end
    oldHitboxes = {}
end

local function applyAmmoMod()
    if not S.AmmoMod then return end
    pcall(function()
        local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if not tool then return end
        for _, v in ipairs(tool:GetDescendants()) do
            if v:IsA("IntValue") or v:IsA("NumberValue") then
                local n = v.Name:lower()
                if n:find("ammo") or n:find("mag") or n:find("clip") or n:find("bullet") then
                    v.Value = 9999
                end
            end
        end
    end)
end

local function applyRecoilMod()
    if not S.RecoilMod then return end
    pcall(function()
        local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if not tool then return end
        for _, v in ipairs(tool:GetDescendants()) do
            if v:IsA("NumberValue") or v:IsA("Vector3Value") then
                local n = v.Name:lower()
                if n:find("recoil") or n:find("spread") or n:find("kick") then
                    if v:IsA("NumberValue") then v.Value = 0
                    elseif v:IsA("Vector3Value") then v.Value = Vector3.zero end
                end
            end
        end
    end)
end

-- GUI
local existing = CoreGui:FindFirstChild("KrovotokGUI")
if existing then existing:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "KrovotokGUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = CoreGui

-- FOV Circle
local fovFrame = Instance.new("Frame")
fovFrame.Name = "FOVCircle"
fovFrame.AnchorPoint = Vector2.new(0.5, 0.5)
fovFrame.Position = UDim2.fromScale(0.5, 0.5)
fovFrame.Size = UDim2.fromOffset(S.FOVSize * 2, S.FOVSize * 2)
fovFrame.BackgroundTransparency = 1
fovFrame.Parent = gui
corner(fovFrame, S.FOVSize)
local fovStroke = Instance.new("UIStroke")
fovStroke.Color = COL.Accent
fovStroke.Thickness = 2
fovStroke.Transparency = 0.2
fovStroke.Parent = fovFrame

-- Orb button
local orb = Instance.new("TextButton")
orb.Size = UDim2.fromOffset(72, 72)
orb.Position = UDim2.fromOffset(20, 180)
orb.BackgroundColor3 = COL.White
orb.Text = "Krovotok"
orb.TextColor3 = COL.Black
orb.TextSize = 11
orb.Font = Enum.Font.GothamBold
orb.ZIndex = 10
orb.Parent = gui
corner(orb, 72)
stroke(orb, COL.Accent, 2)

-- Main window (35% of screen, centered)
local main = Instance.new("Frame")
main.Name = "MainWindow"
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.fromScale(0.5, 0.5)
main.Size = UDim2.fromScale(0.35, 0.72)
main.BackgroundColor3 = COL.BG
main.ZIndex = 5
main.Parent = gui
corner(main, 14)
stroke(main, COL.Accent, 1.5)

-- Top bar
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 52)
topBar.BackgroundColor3 = COL.Panel
topBar.ZIndex = 6
topBar.Parent = main
corner(topBar, 14)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -90, 1, 0)
titleLabel.Position = UDim2.fromOffset(14, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Krovotok"
titleLabel.TextColor3 = COL.White
titleLabel.TextSize = 18
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex = 7
titleLabel.Parent = topBar

local subLabel = Instance.new("TextLabel")
subLabel.Size = UDim2.new(1, -90, 0, 14)
subLabel.Position = UDim2.fromOffset(15, 34)
subLabel.BackgroundTransparency = 1
subLabel.Text = "BoogaJohnyBoy | @bogteddy"
subLabel.TextColor3 = COL.Muted
subLabel.TextSize = 9
subLabel.Font = Enum.Font.Gotham
subLabel.TextXAlignment = Enum.TextXAlignment.Left
subLabel.ZIndex = 7
subLabel.Parent = topBar

-- Minimize button
local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.fromOffset(32, 28)
minBtn.Position = UDim2.new(1, -72, 0, 12)
minBtn.BackgroundColor3 = COL.Panel2
minBtn.Text = "-"
minBtn.TextColor3 = COL.White
minBtn.TextSize = 18
minBtn.Font = Enum.Font.GothamBold
minBtn.ZIndex = 8
minBtn.Parent = topBar
corner(minBtn, 8)

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(32, 28)
closeBtn.Position = UDim2.new(1, -36, 0, 12)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 50)
closeBtn.Text = "x"
closeBtn.TextColor3 = COL.White
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.GothamBold
closeBtn.ZIndex = 8
closeBtn.Parent = topBar
corner(closeBtn, 8)

-- Confirm popup
local popup = Instance.new("Frame")
popup.Size = UDim2.fromOffset(280, 130)
popup.AnchorPoint = Vector2.new(0.5, 0.5)
popup.Position = UDim2.fromScale(0.5, 0.5)
popup.BackgroundColor3 = COL.Panel
popup.Visible = false
popup.ZIndex = 20
popup.Parent = gui
corner(popup, 12)
stroke(popup, COL.Accent, 1.5)

local popupText = Instance.new("TextLabel")
popupText.Size = UDim2.new(1, -20, 0, 50)
popupText.Position = UDim2.fromOffset(10, 14)
popupText.BackgroundTransparency = 1
popupText.Text = "Вы уверены, что хотите\nзакрыть чит полностью?"
popupText.TextColor3 = COL.Text
popupText.TextSize = 13
popupText.Font = Enum.Font.Gotham
popupText.TextWrapped = true
popupText.ZIndex = 21
popupText.Parent = popup

local cancelBtn = Instance.new("TextButton")
cancelBtn.Size = UDim2.fromOffset(110, 34)
cancelBtn.Position = UDim2.fromOffset(12, 82)
cancelBtn.BackgroundColor3 = COL.Panel2
cancelBtn.Text = "Отменить"
cancelBtn.TextColor3 = COL.Text
cancelBtn.TextSize = 12
cancelBtn.Font = Enum.Font.GothamSemibold
cancelBtn.ZIndex = 22
cancelBtn.Parent = popup
corner(cancelBtn, 8)

local confirmCloseBtn = Instance.new("TextButton")
confirmCloseBtn.Size = UDim2.fromOffset(110, 34)
confirmCloseBtn.Position = UDim2.fromOffset(158, 82)
confirmCloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 50)
confirmCloseBtn.Text = "Да, закрыть"
confirmCloseBtn.TextColor3 = COL.White
confirmCloseBtn.TextSize = 12
confirmCloseBtn.Font = Enum.Font.GothamSemibold
confirmCloseBtn.ZIndex = 22
confirmCloseBtn.Parent = popup
corner(confirmCloseBtn, 8)

-- Body: left column (categories) + right column (settings)
local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 1, -52)
body.Position = UDim2.fromOffset(0, 52)
body.BackgroundTransparency = 1
body.ZIndex = 6
body.Parent = main

-- Left column
local leftCol = Instance.new("Frame")
leftCol.Size = UDim2.new(0, 110, 1, -8)
leftCol.Position = UDim2.fromOffset(6, 4)
leftCol.BackgroundColor3 = COL.Panel
leftCol.ZIndex = 6
leftCol.Parent = body
corner(leftCol, 10)

-- Bacon avatar placeholder
local baconFrame = Instance.new("Frame")
baconFrame.Size = UDim2.fromOffset(72, 72)
baconFrame.Position = UDim2.fromOffset(19, 8)
baconFrame.BackgroundColor3 = COL.Panel2
baconFrame.ZIndex = 7
baconFrame.Parent = leftCol
corner(baconFrame, 10)
stroke(baconFrame, COL.Accent, 1)

local baconLabel = Instance.new("TextLabel")
baconLabel.Size = UDim2.fromScale(1, 1)
baconLabel.BackgroundTransparency = 1
baconLabel.Text = "🥓"
baconLabel.TextSize = 30
baconLabel.Font = Enum.Font.GothamBold
baconLabel.TextColor3 = COL.White
baconLabel.ZIndex = 8
baconLabel.Parent = baconFrame

local playerLabel = Instance.new("TextLabel")
playerLabel.Size = UDim2.new(1, -8, 0, 18)
playerLabel.Position = UDim2.fromOffset(4, 83)
playerLabel.BackgroundTransparency = 1
playerLabel.Text = LocalPlayer.Name
playerLabel.TextColor3 = COL.Muted
playerLabel.TextSize = 9
playerLabel.Font = Enum.Font.Gotham
playerLabel.TextTruncate = Enum.TextTruncate.AtEnd
playerLabel.ZIndex = 7
playerLabel.Parent = leftCol

local catLayout = Instance.new("UIListLayout")
catLayout.Padding = UDim.new(0, 4)
catLayout.Parent = leftCol

-- spacer
local spacer = Instance.new("Frame")
spacer.Size = UDim2.new(1, 0, 0, 105)
spacer.BackgroundTransparency = 1
spacer.Parent = leftCol

local categories = {
    {name = "Combat",   emoji = "⚔"},
    {name = "ESP",      emoji = "👁"},
    {name = "Chams",    emoji = "✨"},
    {name = "Hitbox",   emoji = "🎯"},
    {name = "Weapon",   emoji = "🔫"},
    {name = "Settings", emoji = "⚙"},
}

local catButtons = {}

for _, cat in ipairs(categories) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -8, 0, 34)
    b.BackgroundColor3 = COL.Panel2
    b.Text = cat.emoji .. "  " .. cat.name
    b.TextColor3 = COL.Muted
    b.TextSize = 11
    b.Font = Enum.Font.GothamSemibold
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.ZIndex = 7
    b.Parent = leftCol
    corner(b, 8)
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 10)
    pad.Parent = b
    catButtons[cat.name] = b
end

-- Right column (pages)
local rightCol = Instance.new("Frame")
rightCol.Size = UDim2.new(1, -122, 1, -8)
rightCol.Position = UDim2.fromOffset(118, 4)
rightCol.BackgroundColor3 = COL.Panel
rightCol.ZIndex = 6
rightCol.Parent = body
corner(rightCol, 10)

local pages = {}
local function makePage(name)
    local p = Instance.new("ScrollingFrame")
    p.Name = name
    p.Size = UDim2.fromScale(1, 1)
    p.BackgroundTransparency = 1
    p.BorderSizePixel = 0
    p.ScrollBarThickness = 2
    p.AutomaticCanvasSize = Enum.AutomaticSize.Y
    p.CanvasSize = UDim2.new()
    p.Visible = false
    p.ZIndex = 7
    p.Parent = rightCol
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 5)
    layout.Parent = p
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 8)
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = p
    pages[name] = p
    return p
end

local combatPage  = makePage("Combat")
local espPage     = makePage("ESP")
local chamsPage   = makePage("Chams")
local hitboxPage  = makePage("Hitbox")
local weaponPage  = makePage("Weapon")
local settingsPage = makePage("Settings")

local function showCategory(name)
    S.ActiveCategory = name
    for n, p in pairs(pages) do p.Visible = n == name end
    for n, b in pairs(catButtons) do
        b.BackgroundColor3 = n == name and COL.Accent or COL.Panel2
        b.TextColor3 = n == name and COL.White or COL.Muted
    end
end

for name, b in pairs(catButtons) do
    b.Activated:Connect(function() showCategory(name) end)
end

-- Widget builders
local function sectionLabel(parent, text)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 20)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = COL.Accent
    l.TextSize = 10
    l.Font = Enum.Font.GothamBold
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.ZIndex = 8
    l.Parent = parent
end

local function toggle(parent, label, key)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 38)
    row.BackgroundColor3 = COL.Panel2
    row.ZIndex = 8
    row.Parent = parent
    corner(row, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -54, 1, 0)
    lbl.Position = UDim2.fromOffset(10, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = COL.Text
    lbl.TextSize = 11
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 9
    lbl.Parent = row

    local pill = Instance.new("TextButton")
    pill.Size = UDim2.fromOffset(44, 24)
    pill.Position = UDim2.new(1, -50, 0.5, -12)
    pill.BackgroundColor3 = S[key] and COL.ON or COL.OFF
    pill.Text = S[key] and "ON" or "OFF"
    pill.TextColor3 = COL.White
    pill.TextSize = 9
    pill.Font = Enum.Font.GothamBold
    pill.ZIndex = 9
    pill.Parent = row
    corner(pill, 12)

    pill.Activated:Connect(function()
        S[key] = not S[key]
        pill.BackgroundColor3 = S[key] and COL.ON or COL.OFF
        pill.Text = S[key] and "ON" or "OFF"
    end)
    return row
end

local function cycle(parent, label, key, values)
    local idx = 1
    for i, v in ipairs(values) do if v == S[key] then idx = i end end
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 38)
    row.BackgroundColor3 = COL.Panel2
    row.ZIndex = 8
    row.Parent = parent
    corner(row, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -100, 1, 0)
    lbl.Position = UDim2.fromOffset(10, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = COL.Text
    lbl.TextSize = 11
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 9
    lbl.Parent = row

    local val = Instance.new("TextButton")
    val.Size = UDim2.fromOffset(90, 26)
    val.Position = UDim2.new(1, -94, 0.5, -13)
    val.BackgroundColor3 = COL.Accent
    val.Text = tostring(S[key])
    val.TextColor3 = COL.White
    val.TextSize = 10
    val.Font = Enum.Font.GothamSemibold
    val.ZIndex = 9
    val.Parent = row
    corner(val, 8)

    val.Activated:Connect(function()
        idx = idx % #values + 1
        S[key] = values[idx]
        val.Text = tostring(S[key])
    end)
    return row
end

local function slider(parent, label, key, mn, mx, step)
    local hold = Instance.new("Frame")
    hold.Size = UDim2.new(1, 0, 0, 54)
    hold.BackgroundColor3 = COL.Panel2
    hold.ZIndex = 8
    hold.Parent = parent
    corner(hold, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -10, 0, 20)
    lbl.Position = UDim2.fromOffset(10, 6)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = COL.Text
    lbl.TextSize = 11
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 9
    lbl.Text = label .. "   " .. tostring(S[key])
    lbl.Parent = hold

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -16, 0, 7)
    bar.Position = UDim2.fromOffset(8, 34)
    bar.BackgroundColor3 = COL.BG
    bar.ZIndex = 9
    bar.Parent = hold
    corner(bar, 7)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = COL.Accent
    fill.ZIndex = 10
    fill.Parent = bar
    corner(fill, 7)

    local q0 = math.clamp((S[key] - mn) / (mx - mn), 0, 1)
    fill.Size = UDim2.new(q0, 0, 1, 0)

    local dragging = false
    local function update(x)
        local q = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        local v = math.floor((mn + (mx - mn) * q) / step + 0.5) * step
        S[key] = v
        fill.Size = UDim2.new(q, 0, 1, 0)
        lbl.Text = label .. "   " .. tostring(v)
    end

    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; update(i.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            update(i.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    return hold
end

-- Combat page
sectionLabel(combatPage, "AIMBOT")
toggle(combatPage, "⚔  Aimbot", "Aim")
cycle(combatPage, "🎯  Target part", "AimPart", {"Head", "Torso", "Root"})
toggle(combatPage, "🧱  Through walls", "AimWalls")
slider(combatPage, "FOV radius", "AimFOV", 20, 360, 5)
slider(combatPage, "Smooth speed", "AimSmooth", 1, 100, 1)
slider(combatPage, "Max distance", "AimDistance", 50, 2000, 25)
sectionLabel(combatPage, "SILENT AIM")
toggle(combatPage, "🔇  Silent Aim", "SilentAim")
sectionLabel(combatPage, "FOV CIRCLE")
toggle(combatPage, "🔵  Show FOV", "FOVVisible")
slider(combatPage, "FOV size", "FOVSize", 20, 400, 5)

-- ESP page
sectionLabel(espPage, "PLAYER ESP")
toggle(espPage, "👁  ESP", "ESP")
toggle(espPage, "📦  Boxes", "ESPBoxes")
toggle(espPage, "📏  Lines", "ESPLines")
toggle(espPage, "❤  Health bar", "ESPHealth")
toggle(espPage, "🤝  Team check", "TeamCheck")
slider(espPage, "ESP distance", "ESPDistance", 50, 3000, 25)

-- Chams page
sectionLabel(chamsPage, "CHAMS")
toggle(chamsPage, "✨  Chams", "Chams")
toggle(chamsPage, "🌈  Rainbow", "ChamsRainbow")
toggle(chamsPage, "🤝  Team check (Chams)", "TeamCheck")

-- Hitbox page
sectionLabel(hitboxPage, "HITBOX")
toggle(hitboxPage, "📐  Hitbox", "Hitbox")
toggle(hitboxPage, "👀  Show hitboxes", "HitboxVisible")
slider(hitboxPage, "Width", "HitboxW", 2, 20, 1)
slider(hitboxPage, "Height", "HitboxH", 2, 20, 1)

-- Weapon page
sectionLabel(weaponPage, "WEAPON MODS")
toggle(weaponPage, "🔋  Ammo Mod", "AmmoMod")
toggle(weaponPage, "⬇  Recoil Mod", "RecoilMod")

-- Settings page
sectionLabel(settingsPage, "INTERFACE")
sectionLabel(settingsPage, "Team Check is shared across tabs.")

-- Drag logic
local function makeDraggable(frame, handle)
    local dragging = false
    local offset
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            offset = Vector2.new(i.Position.X - frame.AbsolutePosition.X, i.Position.Y - frame.AbsolutePosition.Y)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            frame.Position = UDim2.fromOffset(i.Position.X - offset.X, i.Position.Y - offset.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

makeDraggable(main, topBar)
makeDraggable(orb, orb)

-- Button logic
orb.Activated:Connect(function()
    S.MenuOpen = not S.MenuOpen
    main.Visible = S.MenuOpen
end)

minBtn.Activated:Connect(function()
    S.MenuOpen = false
    main.Visible = false
end)

closeBtn.Activated:Connect(function()
    popup.Visible = true
end)

cancelBtn.Activated:Connect(function()
    popup.Visible = false
end)

confirmCloseBtn.Activated:Connect(function()
    S.Aim = false
    S.ESP = false
    S.Chams = false
    S.Hitbox = false
    S.AmmoMod = false
    S.RecoilMod = false
    S.SilentAim = false
    restoreHitboxes()
    clearESP()
    clearChams()
    gui:Destroy()
end)

showCategory("Combat")

-- Main loop
local timers = {esp = 0, chams = 0, hitbox = 0, ammo = 0}

RunService.RenderStepped:Connect(function(dt)
    if not gui.Parent then return end

    -- FOV circle
    local vp = Camera.ViewportSize
    fovFrame.Position = UDim2.fromOffset(vp.X / 2, vp.Y / 2)
    fovFrame.Size = UDim2.fromOffset(S.FOVSize * 2, S.FOVSize * 2)
    corner(fovFrame, S.FOVSize)
    fovFrame.Visible = S.FOVVisible and S.Aim
    fovStroke.Color = COL.Accent

    -- Aimbot
    if S.Aim then
        local t = getBestTarget()
        if t then doAim(t) end
    else
        lockedTarget = nil
    end

    -- Rainbow hue
    rainbowHue = (rainbowHue + dt * 0.3) % 1

    -- ESP
    timers.esp = timers.esp + dt
    if timers.esp >= 0.1 then
        timers.esp = 0
        renderESP()
    end

    -- Chams
    timers.chams = timers.chams + dt
    if timers.chams >= 0.15 then
        timers.chams = 0
        if S.Chams then
            if S.ChamsRainbow then
                for _, h in ipairs(chamsObjects) do
                    local col = Color3.fromHSV(rainbowHue, 1, 1)
                    h.FillColor = col
                    h.OutlineColor = col
                end
            end
            renderChams()
        else
            clearChams()
        end
    end

    -- Hitbox
    timers.hitbox = timers.hitbox + dt
    if timers.hitbox >= 0.15 then
        timers.hitbox = 0
        if S.Hitbox then
            for _, p in ipairs(Players:GetPlayers()) do
                applyHitbox(p)
            end
        else
            restoreHitboxes()
        end
    end

    -- Ammo + Recoil
    timers.ammo = timers.ammo + dt
    if timers.ammo >= 0.25 then
        timers.ammo = 0
        applyAmmoMod()
        applyRecoilMod()
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.2)
    Camera = workspace.CurrentCamera
    lockedTarget = nil
end)

Players.PlayerRemoving:Connect(function(p)
    if espObjects[p] then
        for _, obj in pairs(espObjects[p]) do
            pcall(function() obj:Destroy() end)
        end
        espObjects[p] = nil
    end
end)
