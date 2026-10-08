local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local S = {
    Aim = false,
    Priority = "Crosshair",
    Mode = "Smooth",
    FOV = 180,
    Speed = 12,
    Distance = 1000,
    TeamCheck = true,
    ESP = false,
    ESPColor = Color3.fromRGB(150, 90, 255),
    HP = true,
    Dist = true,
    ESPDistance = 1500,
    Hitbox = false,
    HitboxSize = 8,
    HeadOnly = false,
    Menu = true
}

local function alive(p)
    local c = p.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    local r = c and c:FindFirstChild("HumanoidRootPart")
    return c and h and r and h.Health > 0
end

local function enemy(p)
    if p == LocalPlayer or not alive(p) then return false end
    if S.TeamCheck and LocalPlayer.Team and p.Team and LocalPlayer.Team == p.Team then return false end
    return true
end

local function root(p)
    return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end

local function aimPart(p)
    local c = p.Character
    return c and (c:FindFirstChild("Head") or c:FindFirstChild("UpperTorso") or c:FindFirstChild("HumanoidRootPart"))
end

local function visible(part)
    if not part then return false end
    local origin = Camera.CFrame.Position
    local direction = part.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    local hit = workspace:Raycast(origin, direction, params)
    return not hit or hit.Instance:IsDescendantOf(part.Parent)
end

local function getTarget()
    local mouse = UIS:GetMouseLocation()
    local best, score
    local center = Vector2.new(mouse.X, mouse.Y)

    for _, p in ipairs(Players:GetPlayers()) do
        if enemy(p) then
            local part = aimPart(p)
            local r = root(p)
            if part and r then
                local distance = (r.Position - Camera.CFrame.Position).Magnitude
                if distance <= S.Distance and visible(part) then
                    local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local screenDistance = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                        if screenDistance <= S.FOV then
                            local v
                            if S.Priority == "Distance" then
                                v = distance
                            elseif S.Priority == "LowHP" then
                                v = p.Character:FindFirstChildOfClass("Humanoid").Health
                            else
                                v = screenDistance
                            end
                            if not score or v < score then
                                score = v
                                best = p
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

local function aimAt(p)
    local part = aimPart(p)
    if not part then return end
    local cam = Camera.CFrame
    local goal = CFrame.lookAt(cam.Position, part.Position)
    if S.Mode == "Instant" then
        Camera.CFrame = goal
    elseif S.Mode == "Hold" then
        Camera.CFrame = goal
    else
        local a = math.clamp(S.Speed / 100, 0.01, 1)
        Camera.CFrame = cam:Lerp(goal, a)
    end
end

local esp = {}
local oldHitboxes = {}

local function makeESP(p)
    if esp[p] then return esp[p] end
    local box = Instance.new("Highlight")
    box.Name = "BarrageESP"
    box.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    box.FillTransparency = 0.78
    box.OutlineTransparency = 0
    box.FillColor = S.ESPColor
    box.OutlineColor = S.ESPColor
    box.Enabled = false
    box.Parent = game:GetService("CoreGui")
    esp[p] = box
    return box
end

local function updateESP()
    for p, box in pairs(esp) do
        if not p.Parent then
            box:Destroy()
            esp[p] = nil
        elseif S.ESP and enemy(p) and p.Character then
            local r = root(p)
            local d = r and (r.Position - Camera.CFrame.Position).Magnitude or math.huge
            box.Enabled = d <= S.ESPDistance
            box.Adornee = p.Character
            box.FillColor = S.ESPColor
            box.OutlineColor = S.ESPColor
        else
            box.Enabled = false
            box.Adornee = nil
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then makeESP(p) end
    end
end

local function applyHitbox(p)
    if not enemy(p) then return end
    local c = p.Character
    if not c then return end
    local parts = {}
    if S.HeadOnly then
        local h = c:FindFirstChild("Head")
        if h then parts = {h} end
    else
        local h = c:FindFirstChild("Head")
        local r = c:FindFirstChild("HumanoidRootPart")
        local t = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")
        if h then table.insert(parts, h) end
        if r then table.insert(parts, r) end
        if t then table.insert(parts, t) end
    end
    for _, part in ipairs(parts) do
        if part:IsA("BasePart") then
            if not oldHitboxes[part] then
                oldHitboxes[part] = {Size = part.Size, Transparency = part.Transparency, CanCollide = part.CanCollide}
            end
            part.Size = Vector3.new(S.HitboxSize, S.HitboxSize, S.HitboxSize)
            part.Transparency = 0.65
            part.CanCollide = false
        end
    end
end

local function restoreHitboxes()
    for part, v in pairs(oldHitboxes) do
        if part and part.Parent then
            part.Size = v.Size
            part.Transparency = v.Transparency
            part.CanCollide = v.CanCollide
        end
        oldHitboxes[part] = nil
    end
end

local gui = Instance.new("ScreenGui")
gui.Name = "Barrage"
gui.ResetOnSpawn = false
gui.Parent = game:GetService("CoreGui")

local function corner(o, n)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, n)
    c.Parent = o
end

local function stroke(o)
    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(125, 85, 255)
    s.Thickness = 2
    s.Transparency = 0.2
    s.Parent = o
end

local orb = Instance.new("TextButton")
orb.Size = UDim2.fromOffset(64,64)
orb.Position = UDim2.fromOffset(25,180)
orb.Text = "B"
orb.TextSize = 25
orb.Font = Enum.Font.GothamBold
orb.TextColor3 = Color3.new(1,1,1)
orb.BackgroundColor3 = Color3.fromRGB(68,38,125)
orb.Parent = gui
corner(orb,64)
stroke(orb)

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(430,540)
panel.Position = UDim2.new(.5,-215,.5,-270)
panel.BackgroundColor3 = Color3.fromRGB(21,16,43)
panel.Parent = gui
corner(panel,18)
stroke(panel)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,-65,0,48)
title.Position = UDim2.fromOffset(18,4)
title.BackgroundTransparency = 1
title.Text = "BARRAGE  •  KEY SYSTEM"
title.TextColor3 = Color3.fromRGB(240,235,255)
title.TextSize = 19
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(42,36)
close.Position = UDim2.new(1,-53,0,9)
close.Text = "✕"
close.TextSize = 20
close.Font = Enum.Font.GothamBold
close.TextColor3 = Color3.new(1,1,1)
close.BackgroundColor3 = Color3.fromRGB(92,45,145)
close.Parent = panel
corner(close,10)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1,-20,1,-60)
scroll.Position = UDim2.fromOffset(10,55)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 4
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new()
scroll.Parent = panel

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0,6)
list.Parent = scroll

local function label(t)
    local x = Instance.new("TextLabel")
    x.Size = UDim2.new(1,-5,0,27)
    x.BackgroundTransparency = 1
    x.Text = t
    x.TextColor3 = Color3.fromRGB(180,150,255)
    x.TextSize = 15
    x.Font = Enum.Font.GothamBold
    x.TextXAlignment = Enum.TextXAlignment.Left
    x.Parent = scroll
end

local function button(t, f)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,-5,0,36)
    b.BackgroundColor3 = Color3.fromRGB(38,29,67)
    b.Text = t
    b.TextColor3 = Color3.new(1,1,1)
    b.TextSize = 13
    b.Font = Enum.Font.GothamSemibold
    b.Parent = scroll
    corner(b,9)
    b.Activated:Connect(f)
    return b
end

local function toggle(name, key)
    local b
    local function refresh()
        b.Text = name .. "  •  " .. (S[key] and "ON" or "OFF")
    end
    b = button("", function()
        S[key] = not S[key]
        refresh()
    end)
    refresh()
end

local function cycle(name, key, values)
    local i = 1
    for n,v in ipairs(values) do if v == S[key] then i=n end end
    local b
    b = button(name .. ": " .. S[key], function()
        i = i % #values + 1
        S[key] = values[i]
        b.Text = name .. ": " .. S[key]
    end)
end

local function slider(name, key, min, max, step)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1,-5,0,55)
    holder.BackgroundTransparency = 1
    holder.Parent = scroll

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1,0,0,23)
    txt.BackgroundTransparency = 1
    txt.TextColor3 = Color3.new(1,1,1)
    txt.TextSize = 13
    txt.Font = Enum.Font.Gotham
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.Parent = holder

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1,0,0,8)
    bar.Position = UDim2.fromOffset(0,32)
    bar.BackgroundColor3 = Color3.fromRGB(52,42,80)
    bar.Parent = holder
    corner(bar,8)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = Color3.fromRGB(125,85,255)
    fill.Parent = bar
    corner(fill,8)

    local drag = false
    local function update(x)
        local q = math.clamp((x-bar.AbsolutePosition.X)/bar.AbsoluteSize.X,0,1)
        local raw = min+(max-min)*q
        local val = math.floor(raw/step+0.5)*step
        S[key] = val
        fill.Size = UDim2.new(q,0,1,0)
        txt.Text = name .. ": " .. tostring(val)
    end

    txt.Text = name .. ": " .. tostring(S[key])
    fill.Size = UDim2.new((S[key]-min)/(max-min),0,1,0)

    bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = true
            update(i.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            update(i.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag=false end
    end)
end

label("AIMBOT")
toggle("Aimbot", "Aim")
cycle("Target", "Priority", {"Crosshair","Distance","LowHP"})
cycle("Mode", "Mode", {"Instant","Smooth","Hold"})
toggle("Team check", "TeamCheck")
slider("FOV", "FOV", 20, 360, 5)
slider("Aim speed", "Speed", 1, 100, 1)
slider("Detection distance", "Distance", 50, 2000, 25)

label("ESP")
toggle("ESP", "ESP")
toggle("Show HP", "HP")
toggle("Show distance", "Dist")
slider("ESP distance", "ESPDistance", 50, 2000, 25)

label("HITBOX")
toggle("Hitbox", "Hitbox")
toggle("Head only", "HeadOnly")
slider("Hitbox size", "HitboxSize", 2, 15, 1)


local fovCircle = Instance.new("Frame")
fovCircle.Name = "FOVCircle"
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.Position = UDim2.fromScale(0.5, 0.5)
fovCircle.Size = UDim2.fromOffset(S.FOV * 2, S.FOV * 2)
fovCircle.BackgroundTransparency = 1
fovCircle.Parent = gui

local fovCorner = Instance.new("UICorner")
fovCorner.CornerRadius = UDim.new(1, 0)
fovCorner.Parent = fovCircle

local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Color3.fromRGB(150, 90, 255)
fovStroke.Thickness = 2
fovStroke.Transparency = 0.15
fovStroke.Parent = fovCircle

local function dragFrame(frame, handle)
    local down = false
    local offset
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            down = true
            offset = i.Position-frame.AbsolutePosition
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if down and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            frame.Position = UDim2.fromOffset(i.Position.X-offset.X,i.Position.Y-offset.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then down=false end
    end)
end

dragFrame(panel,title)
dragFrame(orb,orb)

orb.Activated:Connect(function()
    S.Menu = not S.Menu
    panel.Visible = S.Menu
end)

close.Activated:Connect(function()
    S.Menu = false
    panel.Visible = false
end)

local espTimer = 0
local hitTimer = 0

RunService.RenderStepped:Connect(function(dt)
    local viewport = Camera.ViewportSize
    fovCircle.Position = UDim2.fromOffset(viewport.X / 2, viewport.Y / 2)
    fovCircle.Size = UDim2.fromOffset(S.FOV * 2, S.FOV * 2)
    fovCircle.Visible = S.Aim

    if S.Aim then
        local t = getTarget()
        if t then aimAt(t) end
    end

    espTimer += dt
    if espTimer >= 0.08 then
        espTimer = 0
        updateESP()
    end

    hitTimer += dt
    if hitTimer >= 0.15 then
        hitTimer = 0
        if S.Hitbox then
            for _,p in ipairs(Players:GetPlayers()) do
                applyHitbox(p)
            end
        else
            restoreHitboxes()
        end
    end
end)

Players.PlayerRemoving:Connect(function(p)
    if esp[p] then
        esp[p]:Destroy()
        esp[p] = nil
    end
end)
