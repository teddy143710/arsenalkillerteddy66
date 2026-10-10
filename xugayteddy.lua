local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local VIM = game:GetService("VirtualInputManager")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")

local S = {
    AimEnabled = false,
    AimFOV = 120,
    AimSmooth = 5,
    AimWalls = false,
    AimPart = "Head",
    SilentAim = false,
    TriggerEnabled = false,
    TriggerDelay = 0.08,
    TeamCheck = true,
    CheckVisibility = true,
    ESPEnabled = false,
    ESPBoxes = true,
    ESPLines = false,
    ESPHealth = true,
    ESPNames = true,
    ESPDistance = 1500,
    ChamsEnabled = false,
    ChamsRainbow = false,
    HitboxEnabled = false,
    HitboxVisible = true,
    HitboxW = 8,
    HitboxH = 8,
    AmmoMod = false,
    RecoilMod = false,
    FOVVisible = true,
    MenuOpen = true,
    ActiveTab = "COMBAT",
}

local COL = {
    BG        = Color3.fromRGB(8, 11, 20),
    Panel     = Color3.fromRGB(13, 17, 30),
    Panel2    = Color3.fromRGB(18, 24, 42),
    Sidebar   = Color3.fromRGB(10, 14, 26),
    Accent    = Color3.fromRGB(0, 185, 255),
    AccentDim = Color3.fromRGB(0, 100, 160),
    Text      = Color3.fromRGB(220, 235, 255),
    Muted     = Color3.fromRGB(100, 130, 170),
    White     = Color3.fromRGB(255, 255, 255),
    Black     = Color3.fromRGB(0, 0, 0),
    Green     = Color3.fromRGB(50, 210, 100),
    Yellow    = Color3.fromRGB(255, 200, 50),
    Red       = Color3.fromRGB(255, 65, 75),
    ON        = Color3.fromRGB(0, 185, 255),
    OFF       = Color3.fromRGB(30, 38, 60),
    Border    = Color3.fromRGB(0, 80, 130),
}

local espObjs = {}
local chamsObjs = {}
local oldHitboxes = {}
local lockedTarget = nil
local rainbowHue = 0
local lastTrigger = 0

local function corner(o, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = o
    return c
end

local function mkStroke(o, col, thick)
    local s = Instance.new("UIStroke")
    s.Color = col or COL.Border
    s.Thickness = thick or 1
    s.Transparency = 0
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
    if S.TeamCheck then
        if LocalPlayer.Team and p.Team and LocalPlayer.Team == p.Team then return false end
    end
    return true
end

local function getRoot(p)
    return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end

local function getHead(p)
    return p.Character and p.Character:FindFirstChild("Head")
end

local function getAimTarget(p)
    local c = p.Character
    if not c then return nil end
    if S.AimPart == "Head" then
        return c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart")
    elseif S.AimPart == "Torso" then
        return c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso") or c:FindFirstChild("HumanoidRootPart")
    end
    return c:FindFirstChild("HumanoidRootPart")
end

local function isVisible(part)
    if not part then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local char = LocalPlayer.Character
    params.FilterDescendantsInstances = char and {char} or {}
    local origin = Camera.CFrame.Position
    local dir = part.Position - origin
    local result = workspace:Raycast(origin, dir, params)
    return not result or result.Instance:IsDescendantOf(part.Parent)
end

local function screenPos(part)
    if not part then return nil, false end
    local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
    return Vector2.new(sp.X, sp.Y), onScreen, sp.Z
end

local function inFOV(part)
    local sp, on = screenPos(part)
    if not on or not sp then return false end
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    return (sp - center).Magnitude <= S.AimFOV
end

local function getBest()
    if lockedTarget and isEnemy(lockedTarget) then
        local part = getAimTarget(lockedTarget)
        if part and inFOV(part) and (not S.CheckVisibility or isVisible(part)) then
            return lockedTarget
        end
    end
    lockedTarget = nil
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local best, bestD = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if isEnemy(p) then
            local part = getAimTarget(p)
            local r = getRoot(p)
            if part and r then
                local dist = (r.Position - Camera.CFrame.Position).Magnitude
                if dist <= S.AimDistance or true then
                    if not S.CheckVisibility or isVisible(part) then
                        local sp, on = screenPos(part)
                        if on and sp then
                            local d = (sp - center).Magnitude
                            if d <= S.AimFOV and d < bestD then
                                bestD = d
                                best = p
                            end
                        end
                    end
                end
            end
        end
    end
    lockedTarget = best
    return best
end

local function doAim(p)
    local part = getAimTarget(p)
    if not part then return end
    local cam = Camera.CFrame
    local goal = CFrame.lookAt(cam.Position, part.Position)
    local alpha = math.clamp(S.AimSmooth / 50, 0.02, 1)
    Camera.CFrame = cam:Lerp(goal, alpha)
end

local function clearESP()
    for _, group in pairs(espObjs) do
        for _, obj in pairs(group) do
            pcall(function() obj:Destroy() end)
        end
    end
    espObjs = {}
end

local function clearChams()
    for _, h in pairs(chamsObjs) do
        pcall(function() h:Destroy() end)
    end
    chamsObjs = {}
end

local function renderESP()
    clearESP()
    if not S.ESPEnabled then return end
    if not Drawing then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if not isEnemy(p) then continue end
        local c = p.Character
        if not c then continue end
        local root = c:FindFirstChild("HumanoidRootPart")
        local head = c:FindFirstChild("Head")
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not root or not head or not hum then continue end
        local dist = (root.Position - Camera.CFrame.Position).Magnitude
        if dist > S.ESPDistance then continue end
        local _, cf, sz
        pcall(function() _, cf, sz = c:GetBoundingBox() end)
        if not cf or not sz then continue end
        local verts = {
            cf * Vector3.new( sz.X/2,  sz.Y/2,  sz.Z/2),
            cf * Vector3.new(-sz.X/2,  sz.Y/2,  sz.Z/2),
            cf * Vector3.new( sz.X/2, -sz.Y/2,  sz.Z/2),
            cf * Vector3.new(-sz.X/2, -sz.Y/2,  sz.Z/2),
            cf * Vector3.new( sz.X/2,  sz.Y/2, -sz.Z/2),
            cf * Vector3.new(-sz.X/2,  sz.Y/2, -sz.Z/2),
            cf * Vector3.new( sz.X/2, -sz.Y/2, -sz.Z/2),
            cf * Vector3.new(-sz.X/2, -sz.Y/2, -sz.Z/2),
        }
        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
        local anyOn = false
        for _, v in ipairs(verts) do
            local sp, on = Camera:WorldToViewportPoint(v)
            if on then anyOn = true end
            if sp.X < minX then minX = sp.X end
            if sp.Y < minY then minY = sp.Y end
            if sp.X > maxX then maxX = sp.X end
            if sp.Y > maxY then maxY = sp.Y end
        end
        if not anyOn then continue end
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
            local hp = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
            local hcol = hp > 0.6 and COL.Green or hp > 0.3 and COL.Yellow or COL.Red
            local bH = maxY - minY
            local bX = minX - 5
            local bg = Drawing.new("Square")
            bg.Visible = true
            bg.Position = Vector2.new(bX - 1, minY - 1)
            bg.Size = Vector2.new(4, bH + 2)
            bg.Color = Color3.fromRGB(0,0,0)
            bg.Filled = true
            bg.Thickness = 1
            table.insert(objs, bg)
            local bar = Drawing.new("Square")
            bar.Visible = true
            bar.Position = Vector2.new(bX, minY + bH * (1 - hp))
            bar.Size = Vector2.new(3, bH * hp)
            bar.Color = hcol
            bar.Filled = true
            bar.Thickness = 1
            table.insert(objs, bar)
        end
        if S.ESPNames then
            local hp2, on2 = Camera:WorldToViewportPoint(head.Position + Vector3.new(0,0.6,0))
            if on2 then
                local txt = Drawing.new("Text")
                txt.Visible = true
                txt.Text = p.Name
                txt.Position = Vector2.new(hp2.X, hp2.Y)
                txt.Color = COL.Accent
                txt.Size = 13
                txt.Center = true
                txt.Outline = true
                txt.OutlineColor = Color3.fromRGB(0,0,0)
                table.insert(objs, txt)
            end
        end
        if S.ESPLines then
            local rp, on3 = Camera:WorldToViewportPoint(root.Position)
            if on3 then
                local ln = Drawing.new("Line")
                ln.Visible = true
                ln.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                ln.To = Vector2.new(rp.X, rp.Y)
                ln.Color = COL.Accent
                ln.Thickness = 1
                table.insert(objs, ln)
            end
        end
        espObjs[p] = objs
    end
end

local function renderChams()
    clearChams()
    if not S.ChamsEnabled then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if not isEnemy(p) or not p.Character then continue end
        local hi = Instance.new("Highlight")
        hi.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hi.FillTransparency = 0.45
        hi.OutlineTransparency = 0
        local col = S.ChamsRainbow and Color3.fromHSV(rainbowHue, 1, 1) or COL.Accent
        hi.FillColor = col
        hi.OutlineColor = col
        hi.Adornee = p.Character
        hi.Parent = CoreGui
        table.insert(chamsObjs, hi)
    end
end

local function applyHitbox(p)
    if not isEnemy(p) then return end
    local c = p.Character
    if not c then return end
    local targets = {}
    local head = c:FindFirstChild("Head")
    local torso = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")
    local root = c:FindFirstChild("HumanoidRootPart")
    if head then table.insert(targets, head) end
    if torso then table.insert(targets, torso) end
    if root then table.insert(targets, root) end
    for _, part in ipairs(targets) do
        if part:IsA("BasePart") then
            if not oldHitboxes[part] then
                oldHitboxes[part] = {
                    Size = part.Size,
                    LocalTransparencyModifier = part.LocalTransparencyModifier,
                    CanCollide = part.CanCollide,
                }
            end
            part.Size = Vector3.new(S.HitboxW, S.HitboxH, S.HitboxW)
            part.CanCollide = false
            part.LocalTransparencyModifier = S.HitboxVisible and 0.35 or 1
        end
    end
end

local function restoreHitboxes()
    for part, data in pairs(oldHitboxes) do
        if part and part.Parent then
            part.Size = data.Size
            part.LocalTransparencyModifier = data.LocalTransparencyModifier
            part.CanCollide = data.CanCollide
        end
    end
    oldHitboxes = {}
end

local function triggerFire()
    local now = os.clock()
    if now - lastTrigger < S.TriggerDelay then return end
    lastTrigger = now
    pcall(function()
        local cx = Camera.ViewportSize.X / 2
        local cy = Camera.ViewportSize.Y / 2
        VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
        task.wait(0.025)
        VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
    end)
end

local function checkTrigger()
    if not S.TriggerEnabled then return end
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    for _, p in ipairs(Players:GetPlayers()) do
        if isEnemy(p) then
            local part = getAimTarget(p)
            local r = getRoot(p)
            if part and r then
                if not S.CheckVisibility or isVisible(part) then
                    local sp, on = screenPos(part)
                    if on and sp and (sp - center).Magnitude <= S.AimFOV then
                        triggerFire()
                        return
                    end
                end
            end
        end
    end
end

local function ammoMod()
    if not S.AmmoMod then return end
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
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

local function recoilMod()
    if not S.RecoilMod then return end
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
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

-- ===================== GUI =====================
local prev = CoreGui:FindFirstChild("KrovotokUI")
if prev then prev:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "KrovotokUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = CoreGui

-- FOV Circle
local fovCircle = Instance.new("Frame")
fovCircle.Name = "FOV"
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.Position = UDim2.fromScale(0.5, 0.5)
fovCircle.Size = UDim2.fromOffset(S.AimFOV * 2, S.AimFOV * 2)
fovCircle.BackgroundTransparency = 1
fovCircle.ZIndex = 2
fovCircle.Parent = gui
corner(fovCircle, S.AimFOV)
local fovSt = Instance.new("UIStroke")
fovSt.Color = COL.Accent
fovSt.Thickness = 1.5
fovSt.Transparency = 0.1
fovSt.Parent = fovCircle

-- Orb
local orb = Instance.new("TextButton")
orb.Size = UDim2.fromOffset(68, 68)
orb.Position = UDim2.fromOffset(16, 200)
orb.BackgroundColor3 = COL.BG
orb.Text = ""
orb.ZIndex = 15
orb.Parent = gui
corner(orb, 68)
mkStroke(orb, COL.Accent, 2)

local orbInner = Instance.new("Frame")
orbInner.Size = UDim2.new(1, -6, 1, -6)
orbInner.Position = UDim2.fromOffset(3, 3)
orbInner.BackgroundColor3 = COL.Accent
orbInner.ZIndex = 16
orbInner.Parent = orb
corner(orbInner, 64)

local orbTxt = Instance.new("TextLabel")
orbTxt.Size = UDim2.fromScale(1, 1)
orbTxt.BackgroundTransparency = 1
orbTxt.Text = "K"
orbTxt.TextColor3 = COL.Black
orbTxt.TextSize = 22
orbTxt.Font = Enum.Font.GothamBold
orbTxt.ZIndex = 17
orbTxt.Parent = orbInner

-- Main window
local main = Instance.new("Frame")
main.Name = "Main"
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.fromScale(0.5, 0.5)
main.Size = UDim2.fromScale(0.88, 0.46)
main.BackgroundColor3 = COL.BG
main.ZIndex = 10
main.ClipsDescendants = true
main.Parent = gui
corner(main, 12)
mkStroke(main, COL.Border, 1)

-- Top bar
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 44)
topBar.BackgroundColor3 = COL.Panel
topBar.ZIndex = 11
topBar.Parent = main
corner(topBar, 12)

-- FPS/PING labels
local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.fromOffset(60, 18)
fpsLabel.Position = UDim2.new(1, -130, 0, 6)
fpsLabel.BackgroundTransparency = 1
fpsLabel.Text = "FPS 0"
fpsLabel.TextColor3 = COL.Accent
fpsLabel.TextSize = 9
fpsLabel.Font = Enum.Font.GothamBold
fpsLabel.ZIndex = 12
fpsLabel.Parent = topBar

local pingLabel = Instance.new("TextLabel")
pingLabel.Size = UDim2.fromOffset(60, 18)
pingLabel.Position = UDim2.new(1, -68, 0, 6)
pingLabel.BackgroundTransparency = 1
pingLabel.Text = "PING 0"
pingLabel.TextColor3 = COL.Muted
pingLabel.TextSize = 9
pingLabel.Font = Enum.Font.GothamBold
pingLabel.ZIndex = 12
pingLabel.Parent = topBar

local currentTabLabel = Instance.new("TextLabel")
currentTabLabel.Size = UDim2.new(0.5, 0, 0, 20)
currentTabLabel.Position = UDim2.fromOffset(220, 12)
currentTabLabel.BackgroundTransparency = 1
currentTabLabel.Text = "CURRENT TAB: " .. S.ActiveTab
currentTabLabel.TextColor3 = COL.Muted
currentTabLabel.TextSize = 10
currentTabLabel.Font = Enum.Font.GothamBold
currentTabLabel.TextXAlignment = Enum.TextXAlignment.Left
currentTabLabel.ZIndex = 12
currentTabLabel.Parent = topBar

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.fromOffset(28, 24)
minBtn.Position = UDim2.new(0, 6, 0.5, -12)
minBtn.BackgroundColor3 = COL.Panel2
minBtn.Text = "−"
minBtn.TextColor3 = COL.Text
minBtn.TextSize = 16
minBtn.Font = Enum.Font.GothamBold
minBtn.ZIndex = 12
minBtn.Parent = topBar
corner(minBtn, 6)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(28, 24)
closeBtn.Position = UDim2.new(0, 38, 0.5, -12)
closeBtn.BackgroundColor3 = Color3.fromRGB(160, 35, 45)
closeBtn.Text = "×"
closeBtn.TextColor3 = COL.White
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.GothamBold
closeBtn.ZIndex = 12
closeBtn.Parent = topBar
corner(closeBtn, 6)

-- Popup
local popup = Instance.new("Frame")
popup.Size = UDim2.fromOffset(260, 110)
popup.AnchorPoint = Vector2.new(0.5, 0.5)
popup.Position = UDim2.fromScale(0.5, 0.5)
popup.BackgroundColor3 = COL.Panel
popup.Visible = false
popup.ZIndex = 50
popup.Parent = gui
corner(popup, 10)
mkStroke(popup, COL.Accent, 1.5)

local popupTxt = Instance.new("TextLabel")
popupTxt.Size = UDim2.new(1, -16, 0, 44)
popupTxt.Position = UDim2.fromOffset(8, 10)
popupTxt.BackgroundTransparency = 1
popupTxt.Text = "Вы уверены, что хотите\nзакрыть чит полностью?"
popupTxt.TextColor3 = COL.Text
popupTxt.TextSize = 12
popupTxt.Font = Enum.Font.Gotham
popupTxt.TextWrapped = true
popupTxt.ZIndex = 51
popupTxt.Parent = popup

local popCancel = Instance.new("TextButton")
popCancel.Size = UDim2.fromOffset(104, 30)
popCancel.Position = UDim2.fromOffset(8, 70)
popCancel.BackgroundColor3 = COL.Panel2
popCancel.Text = "Отменить"
popCancel.TextColor3 = COL.Text
popCancel.TextSize = 11
popCancel.Font = Enum.Font.GothamSemibold
popCancel.ZIndex = 52
popCancel.Parent = popup
corner(popCancel, 6)

local popConfirm = Instance.new("TextButton")
popConfirm.Size = UDim2.fromOffset(104, 30)
popConfirm.Position = UDim2.fromOffset(148, 70)
popConfirm.BackgroundColor3 = Color3.fromRGB(160, 35, 45)
popConfirm.Text = "Да, закрыть"
popConfirm.TextColor3 = COL.White
popConfirm.TextSize = 11
popConfirm.Font = Enum.Font.GothamSemibold
popConfirm.ZIndex = 52
popConfirm.Parent = popup
corner(popConfirm, 6)

-- Body
local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 1, -44)
body.Position = UDim2.fromOffset(0, 44)
body.BackgroundTransparency = 1
body.ZIndex = 11
body.Parent = main

-- Sidebar
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.fromOffset(180, 10000)
sidebar.BackgroundColor3 = COL.Sidebar
sidebar.ZIndex = 11
sidebar.Parent = body
mkStroke(sidebar, COL.Border, 1)

local sideLayout = Instance.new("UIListLayout")
sideLayout.Padding = UDim.new(0, 2)
sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
sideLayout.Parent = sidebar

local sidePad = Instance.new("UIPadding")
sidePad.PaddingTop = UDim.new(0, 10)
sidePad.PaddingLeft = UDim.new(0, 8)
sidePad.PaddingRight = UDim.new(0, 8)
sidePad.Parent = sidebar

-- Player info at bottom of sidebar
local playerBox = Instance.new("Frame")
playerBox.Size = UDim2.new(1, -4, 0, 44)
playerBox.BackgroundColor3 = COL.Panel2
playerBox.ZIndex = 12
playerBox.Parent = sidebar
corner(playerBox, 8)

local playerIcon = Instance.new("Frame")
playerIcon.Size = UDim2.fromOffset(28, 28)
playerIcon.Position = UDim2.fromOffset(6, 8)
playerIcon.BackgroundColor3 = COL.Accent
playerIcon.ZIndex = 13
playerIcon.Parent = playerBox
corner(playerIcon, 28)

local playerIconTxt = Instance.new("TextLabel")
playerIconTxt.Size = UDim2.fromScale(1,1)
playerIconTxt.BackgroundTransparency = 1
playerIconTxt.Text = string.sub(LocalPlayer.Name,1,1):upper()
playerIconTxt.TextColor3 = COL.Black
playerIconTxt.TextSize = 12
playerIconTxt.Font = Enum.Font.GothamBold
playerIconTxt.ZIndex = 14
playerIconTxt.Parent = playerIcon

local playerName = Instance.new("TextLabel")
playerName.Size = UDim2.new(1,-46,0,16)
playerName.Position = UDim2.fromOffset(40,6)
playerName.BackgroundTransparency = 1
playerName.Text = LocalPlayer.Name
playerName.TextColor3 = COL.Text
playerName.TextSize = 10
playerName.Font = Enum.Font.GothamSemibold
playerName.TextXAlignment = Enum.TextXAlignment.Left
playerName.TextTruncate = Enum.TextTruncate.AtEnd
playerName.ZIndex = 13
playerName.Parent = playerBox

local playerSub = Instance.new("TextLabel")
playerSub.Size = UDim2.new(1,-46,0,14)
playerSub.Position = UDim2.fromOffset(40,22)
playerSub.BackgroundTransparency = 1
playerSub.Text = "● ACTIVE"
playerSub.TextColor3 = COL.Accent
playerSub.TextSize = 8
playerSub.Font = Enum.Font.GothamBold
playerSub.TextXAlignment = Enum.TextXAlignment.Left
playerSub.ZIndex = 13
playerSub.Parent = playerBox

-- Content area
local contentArea = Instance.new("Frame")
contentArea.Size = UDim2.new(1, -180, 1, 0)
contentArea.Position = UDim2.fromOffset(180, 0)
contentArea.BackgroundTransparency = 1
contentArea.ZIndex = 11
contentArea.Parent = body

-- Tab definitions
local tabs = {
    {name = "COMBAT",   icon = "⚔"},
    {name = "VISUALS",  icon = "👁"},
    {name = "HITBOX",   icon = "+"},
    {name = "MISC",     icon = "✦"},
    {name = "SETTINGS", icon = "⚙"},
}

local tabBtns = {}
local pages = {}

local function makePage(name)
    local scroll = Instance.new("ScrollingFrame")
    scroll.Name = name
    scroll.Size = UDim2.fromScale(1, 1)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 2
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.new()
    scroll.Visible = false
    scroll.ZIndex = 12
    scroll.Parent = contentArea
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = scroll
    -- Two-column grid
    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0.5, -6, 0, 160)
    grid.CellPadding = UDim2.fromOffset(6, 6)
    grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
    grid.Parent = scroll
    pages[name] = scroll
    return scroll, grid
end

-- Tab buttons
for _, tab in ipairs(tabs) do
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 38)
    b.BackgroundColor3 = COL.Panel2
    b.ZIndex = 12
    b.Parent = sidebar
    corner(b, 8)

    local rowFrame = Instance.new("Frame")
    rowFrame.Size = UDim2.fromScale(1,1)
    rowFrame.BackgroundTransparency = 1
    rowFrame.ZIndex = 13
    rowFrame.Parent = b

    local iconL = Instance.new("TextLabel")
    iconL.Size = UDim2.fromOffset(22, 38)
    iconL.Position = UDim2.fromOffset(8, 0)
    iconL.BackgroundTransparency = 1
    iconL.Text = tab.icon
    iconL.TextColor3 = COL.Muted
    iconL.TextSize = 13
    iconL.Font = Enum.Font.GothamBold
    iconL.ZIndex = 14
    iconL.Parent = rowFrame

    local nameL = Instance.new("TextLabel")
    nameL.Size = UDim2.new(1,-36,1,0)
    nameL.Position = UDim2.fromOffset(32,0)
    nameL.BackgroundTransparency = 1
    nameL.Text = tab.name
    nameL.TextColor3 = COL.Muted
    nameL.TextSize = 11
    nameL.Font = Enum.Font.GothamSemibold
    nameL.TextXAlignment = Enum.TextXAlignment.Left
    nameL.ZIndex = 14
    nameL.Parent = rowFrame

    tabBtns[tab.name] = {btn=b, icon=iconL, nameL=nameL}
    makePage(tab.name)
end

-- Spacer before playerBox in sidebar
local sidespacer = Instance.new("Frame")
sidespacer.Size = UDim2.new(1,-4,0,8)
sidespacer.BackgroundTransparency = 1
sidespacer.LayoutOrder = 99
sidespacer.Parent = sidebar

playerBox.LayoutOrder = 100

local function showTab(name)
    S.ActiveTab = name
    currentTabLabel.Text = "CURRENT TAB:  " .. name
    for n, p in pairs(pages) do p.Visible = n == name end
    for n, data in pairs(tabBtns) do
        local active = n == name
        data.btn.BackgroundColor3 = active and COL.Accent or COL.Panel2
        data.icon.TextColor3 = active and COL.Black or COL.Muted
        data.nameL.TextColor3 = active and COL.Black or COL.Muted
    end
end

for _, tab in ipairs(tabs) do
    local data = tabBtns[tab.name]
    data.btn.Activated:Connect(function() showTab(tab.name) end)
end

-- Widget builders
local function makeCard(parent, title)
    local card = Instance.new("Frame")
    card.BackgroundColor3 = COL.Panel
    card.ZIndex = 13
    card.Parent = parent
    corner(card, 8)
    mkStroke(card, COL.Border, 1)

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1,0,0,28)
    titleBar.BackgroundColor3 = COL.Panel2
    titleBar.ZIndex = 14
    titleBar.Parent = card
    corner(titleBar, 8)

    local titleDot = Instance.new("Frame")
    titleDot.Size = UDim2.fromOffset(6,6)
    titleDot.Position = UDim2.fromOffset(10,11)
    titleDot.BackgroundColor3 = COL.Accent
    titleDot.ZIndex = 15
    titleDot.Parent = titleBar
    corner(titleDot, 6)

    local titleTxt = Instance.new("TextLabel")
    titleTxt.Size = UDim2.new(1,-26,1,0)
    titleTxt.Position = UDim2.fromOffset(22,0)
    titleTxt.BackgroundTransparency = 1
    titleTxt.Text = title
    titleTxt.TextColor3 = COL.Accent
    titleTxt.TextSize = 9
    titleTxt.Font = Enum.Font.GothamBold
    titleTxt.TextXAlignment = Enum.TextXAlignment.Left
    titleTxt.ZIndex = 15
    titleTxt.Parent = titleBar

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1,-12,1,-36)
    content.Position = UDim2.fromOffset(6,32)
    content.BackgroundTransparency = 1
    content.ZIndex = 14
    content.Parent = card

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0,5)
    layout.Parent = content

    return card, content
end

local function mkToggle(parent, label, desc, key)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,42)
    row.BackgroundTransparency = 1
    row.ZIndex = 15
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-52,0,18)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = COL.Text
    lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 16
    lbl.Parent = row

    if desc ~= "" then
        local sub = Instance.new("TextLabel")
        sub.Size = UDim2.new(1,-52,0,14)
        sub.Position = UDim2.fromOffset(0,18)
        sub.BackgroundTransparency = 1
        sub.Text = desc
        sub.TextColor3 = COL.Muted
        sub.TextSize = 8
        sub.Font = Enum.Font.Gotham
        sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.ZIndex = 16
        sub.Parent = row
    end

    local pill = Instance.new("TextButton")
    pill.Size = UDim2.fromOffset(46, 24)
    pill.Position = UDim2.new(1,-48,0,9)
    pill.BackgroundColor3 = S[key] and COL.ON or COL.OFF
    pill.Text = ""
    pill.ZIndex = 16
    pill.Parent = row
    corner(pill, 12)

    local dot = Instance.new("Frame")
    dot.Size = UDim2.fromOffset(18,18)
    dot.Position = S[key] and UDim2.fromOffset(25,3) or UDim2.fromOffset(3,3)
    dot.BackgroundColor3 = COL.White
    dot.ZIndex = 17
    dot.Parent = pill
    corner(dot, 18)

    pill.Activated:Connect(function()
        S[key] = not S[key]
        pill.BackgroundColor3 = S[key] and COL.ON or COL.OFF
        dot.Position = S[key] and UDim2.fromOffset(25,3) or UDim2.fromOffset(3,3)
    end)
    return row
end

local function mkSlider(parent, label, key, mn, mx, step)
    local hold = Instance.new("Frame")
    hold.Size = UDim2.new(1,0,0,38)
    hold.BackgroundTransparency = 1
    hold.ZIndex = 15
    hold.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,0,0,16)
    lbl.BackgroundTransparency = 1
    lbl.Text = label .. "  " .. tostring(S[key])
    lbl.TextColor3 = COL.Text
    lbl.TextSize = 10
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 16
    lbl.Parent = hold

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1,0,0,6)
    track.Position = UDim2.fromOffset(0,22)
    track.BackgroundColor3 = COL.OFF
    track.ZIndex = 16
    track.Parent = hold
    corner(track, 6)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = COL.Accent
    fill.ZIndex = 17
    fill.Parent = track
    corner(fill, 6)

    local q0 = math.clamp((S[key]-mn)/(mx-mn),0,1)
    fill.Size = UDim2.new(q0,0,1,0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(12,12)
    knob.AnchorPoint = Vector2.new(0.5,0.5)
    knob.Position = UDim2.new(q0,0,0.5,0)
    knob.BackgroundColor3 = COL.Accent
    knob.ZIndex = 18
    knob.Parent = track
    corner(knob,12)

    local dragging = false
    local function update(x)
        local q = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X,1),0,1)
        local v = math.floor((mn+(mx-mn)*q)/step+0.5)*step
        S[key] = v
        fill.Size = UDim2.new(q,0,1,0)
        knob.Position = UDim2.new(q,0,0.5,0)
        lbl.Text = label .. "  " .. tostring(v)
    end
    track.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true; update(i.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            update(i.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=false
        end
    end)
    return hold
end

local function mkCycle(parent, label, key, values)
    local idx=1
    for i,v in ipairs(values) do if v==S[key] then idx=i end end
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,28)
    row.BackgroundTransparency = 1
    row.ZIndex = 15
    row.Parent = parent

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-90,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = COL.Text
    lbl.TextSize = 10
    lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 16
    lbl.Parent = row

    local val = Instance.new("TextButton")
    val.Size = UDim2.fromOffset(80,22)
    val.Position = UDim2.new(1,-82,0.5,-11)
    val.BackgroundColor3 = COL.Accent
    val.Text = tostring(S[key])
    val.TextColor3 = COL.Black
    val.TextSize = 9
    val.Font = Enum.Font.GothamBold
    val.ZIndex = 16
    val.Parent = row
    corner(val,6)

    val.Activated:Connect(function()
        idx = idx%#values+1
        S[key] = values[idx]
        val.Text = tostring(S[key])
    end)
    return row
end

-- Fill pages
-- COMBAT
local combatPage = pages["COMBAT"]
local c1, c1c = makeCard(combatPage, "AIMBOT CONFIGURATION")
mkToggle(c1c, "Enabled", "Automatically aims onto enemies", "AimEnabled")
mkToggle(c1c, "Silent Aim", "Bypasses aim without aiming", "SilentAim")
mkToggle(c1c, "Check Visibility", "Only aim at visible players", "CheckVisibility")
mkSlider(c1c, "Aimbot FOV", "AimFOV", 10, 360, 5)
mkSlider(c1c, "Smoothing", "AimSmooth", 1, 50, 1)

local c2, c2c = makeCard(combatPage, "TRIGGER BOT")
mkToggle(c2c, "Trigger Enabled", "Auto shoots when target is in crosshair", "TriggerEnabled")
mkSlider(c2c, "Trigger Delay", "TriggerDelay", 0.01, 0.5, 0.01)

local c3, c3c = makeCard(combatPage, "COMBAT INFO")
local infoTarget = Instance.new("TextLabel")
infoTarget.Size = UDim2.new(1,0,0,16)
infoTarget.BackgroundTransparency=1
infoTarget.Text = "Current Target:  none"
infoTarget.TextColor3=COL.Muted; infoTarget.TextSize=9
infoTarget.Font=Enum.Font.Gotham
infoTarget.TextXAlignment=Enum.TextXAlignment.Left
infoTarget.ZIndex=16; infoTarget.Parent=c3c
local infoDist = Instance.new("TextLabel")
infoDist.Size = UDim2.new(1,0,0,16)
infoDist.BackgroundTransparency=1
infoDist.Text = "Distance:  —"
infoDist.TextColor3=COL.Muted; infoDist.TextSize=9
infoDist.Font=Enum.Font.Gotham
infoDist.TextXAlignment=Enum.TextXAlignment.Left
infoDist.ZIndex=16; infoDist.Parent=c3c

local c4, c4c = makeCard(combatPage, "TARGET FILTERS")
mkToggle(c4c, "Friends", "Exclude friends", "TeamCheck")
mkCycle(c4c, "Aim Part", "AimPart", {"Head","Torso","Root"})

-- VISUALS
local visualPage = pages["VISUALS"]
local v1, v1c = makeCard(visualPage, "PLAYER ESP")
mkToggle(v1c, "ESP", "Show enemy outlines", "ESPEnabled")
mkToggle(v1c, "Boxes", "Draw bounding boxes", "ESPBoxes")
mkToggle(v1c, "Health Bar", "Show HP bar", "ESPHealth")
mkToggle(v1c, "Names", "Show player names", "ESPNames")
mkSlider(v1c, "ESP Distance", "ESPDistance", 50, 3000, 50)

local v2, v2c = makeCard(visualPage, "CHAMS")
mkToggle(v2c, "Chams", "Highlight enemies through walls", "ChamsEnabled")
mkToggle(v2c, "Rainbow", "Animated rainbow color", "ChamsRainbow")

local v3, v3c = makeCard(visualPage, "FOV CIRCLE")
mkToggle(v3c, "Show FOV", "Display FOV indicator", "FOVVisible")
mkSlider(v3c, "FOV Size", "AimFOV", 10, 360, 5)

-- HITBOX
local hitboxPage = pages["HITBOX"]
local h1, h1c = makeCard(hitboxPage, "HITBOX CONFIG")
mkToggle(h1c, "Hitbox", "Expand player hitboxes", "HitboxEnabled")
mkToggle(h1c, "Show Hitboxes", "Make hitboxes visible", "HitboxVisible")
mkSlider(h1c, "Width", "HitboxW", 2, 20, 1)
mkSlider(h1c, "Height", "HitboxH", 2, 20, 1)

-- MISC
local miscPage = pages["MISC"]
local m1, m1c = makeCard(miscPage, "WEAPON MODS")
mkToggle(m1c, "Ammo Mod", "Infinite ammo (local)", "AmmoMod")
mkToggle(m1c, "Recoil Mod", "Remove recoil/spread", "RecoilMod")

-- SETTINGS
local settingsPage2 = pages["SETTINGS"]
local s1, s1c = makeCard(settingsPage2, "TEAM CHECK")
mkToggle(s1c, "Team Check", "Skip teammates in all features", "TeamCheck")

-- Dragging
local function makeDraggable(frame, handle)
    local drag = false
    local off
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = true
            off = Vector2.new(i.Position.X - frame.AbsolutePosition.X, i.Position.Y - frame.AbsolutePosition.Y)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            frame.Position = UDim2.fromOffset(i.Position.X - off.X, i.Position.Y - off.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = false
        end
    end)
end

makeDraggable(main, topBar)
makeDraggable(orb, orb)

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
popCancel.Activated:Connect(function()
    popup.Visible = false
end)
popConfirm.Activated:Connect(function()
    S.AimEnabled = false
    S.ESPEnabled = false
    S.ChamsEnabled = false
    S.HitboxEnabled = false
    S.AmmoMod = false
    S.RecoilMod = false
    S.TriggerEnabled = false
    S.SilentAim = false
    restoreHitboxes()
    clearESP()
    clearChams()
    gui:Destroy()
end)

showTab("COMBAT")

-- Loop
local timers = {esp=0, chams=0, hitbox=0, misc=0, fps=0, info=0}
local frameCount = 0

RunService.RenderStepped:Connect(function(dt)
    if not gui.Parent then return end

    frameCount = frameCount + 1
    timers.fps = timers.fps + dt
    if timers.fps >= 1 then
        local fps = math.floor(frameCount / timers.fps)
        fpsLabel.Text = "FPS  " .. fps
        frameCount = 0
        timers.fps = 0
        pcall(function()
            pingLabel.Text = "PING  " .. math.floor(LocalPlayer:GetNetworkPing() * 1000) .. "ms"
        end)
    end

    rainbowHue = (rainbowHue + dt * 0.25) % 1

    local vp = Camera.ViewportSize
    fovCircle.Position = UDim2.fromOffset(vp.X/2, vp.Y/2)
    fovCircle.Size = UDim2.fromOffset(S.AimFOV*2, S.AimFOV*2)
    corner(fovCircle, S.AimFOV)
    fovCircle.Visible = S.FOVVisible and S.AimEnabled

    if S.AimEnabled then
        local t = getBest()
        if t then doAim(t) end
    else
        lockedTarget = nil
    end

    checkTrigger()

    timers.esp = timers.esp + dt
    if timers.esp >= 0.08 then
        timers.esp = 0
        renderESP()
    end

    timers.chams = timers.chams + dt
    if timers.chams >= 0.12 then
        timers.chams = 0
        if S.ChamsEnabled then
            if S.ChamsRainbow then
                local col = Color3.fromHSV(rainbowHue,1,1)
                for _, h in ipairs(chamsObjs) do
                    h.FillColor = col; h.OutlineColor = col
                end
            end
            renderChams()
        else
            clearChams()
        end
    end

    timers.hitbox = timers.hitbox + dt
    if timers.hitbox >= 0.12 then
        timers.hitbox = 0
        if S.HitboxEnabled then
            for _, p in ipairs(Players:GetPlayers()) do applyHitbox(p) end
        else
            restoreHitboxes()
        end
    end

    timers.misc = timers.misc + dt
    if timers.misc >= 0.25 then
        timers.misc = 0
        ammoMod()
        recoilMod()
    end

    timers.info = timers.info + dt
    if timers.info >= 0.2 then
        timers.info = 0
        local t = lockedTarget
        if t and t.Parent then
            local r = getRoot(t)
            local dist = r and math.floor((r.Position - Camera.CFrame.Position).Magnitude) or 0
            infoTarget.Text = "Current Target:  " .. t.Name
            infoDist.Text = "Distance:  " .. dist .. " st"
        else
            infoTarget.Text = "Current Target:  none"
            infoDist.Text = "Distance:  —"
        end
    end
end)

Players.PlayerRemoving:Connect(function(p)
    if espObjs[p] then
        for _, obj in pairs(espObjs[p]) do pcall(function() obj:Destroy() end) end
        espObjs[p] = nil
    end
    if lockedTarget == p then lockedTarget = nil end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.3)
    Camera = workspace.CurrentCamera
    lockedTarget = nil
    restoreHitboxes()
end)
