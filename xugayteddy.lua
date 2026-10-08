local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")

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
    Triggerbot = false,
    Menu = true,
    Theme = "Purple",
    Snow = true
}

local Themes = {
    Purple = {
        A = Color3.fromRGB(126, 76, 255),
        B = Color3.fromRGB(65, 95, 255),
        Panel = Color3.fromRGB(22, 17, 48),
        Panel2 = Color3.fromRGB(31, 24, 66),
        Text = Color3.fromRGB(245, 242, 255),
        Muted = Color3.fromRGB(165, 157, 195)
    },
    Blue = {
        A = Color3.fromRGB(50, 130, 255),
        B = Color3.fromRGB(65, 220, 255),
        Panel = Color3.fromRGB(12, 24, 48),
        Panel2 = Color3.fromRGB(20, 42, 70),
        Text = Color3.fromRGB(240, 248, 255),
        Muted = Color3.fromRGB(150, 180, 205)
    },
    Pink = {
        A = Color3.fromRGB(255, 70, 180),
        B = Color3.fromRGB(145, 70, 255),
        Panel = Color3.fromRGB(42, 14, 39),
        Panel2 = Color3.fromRGB(64, 20, 61),
        Text = Color3.fromRGB(255, 242, 250),
        Muted = Color3.fromRGB(205, 155, 190)
    },
    Ice = {
        A = Color3.fromRGB(110, 220, 255),
        B = Color3.fromRGB(105, 130, 255),
        Panel = Color3.fromRGB(14, 25, 45),
        Panel2 = Color3.fromRGB(22, 42, 68),
        Text = Color3.fromRGB(240, 250, 255),
        Muted = Color3.fromRGB(155, 190, 215)
    }
}

local function T()
    return Themes[S.Theme]
end

local function alive(p)
    local c = p.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    local r = c and c:FindFirstChild("HumanoidRootPart")
    return c and h and r and h.Health > 0
end

local function enemy(p)
    if p == LocalPlayer or not alive(p) then
        return false
    end
    if S.TeamCheck and LocalPlayer.Team and p.Team and LocalPlayer.Team == p.Team then
        return false
    end
    return true
end

local function root(p)
    return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end

local function aimPart(p)
    local c = p.Character
    return c and (
        c:FindFirstChild("Head")
        or c:FindFirstChild("UpperTorso")
        or c:FindFirstChild("HumanoidRootPart")
    )
end

local function visible(part)
    if not part then
        return false
    end

    local origin = Camera.CFrame.Position
    local direction = part.Position - origin

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {
        LocalPlayer.Character
    }

    local hit = workspace:Raycast(origin, direction, params)

    return not hit or hit.Instance:IsDescendantOf(part.Parent)
end

local lockedTarget = nil

local function getTarget()
    if lockedTarget and enemy(lockedTarget) then
        local lp = aimPart(lockedTarget)
        local lr = root(lockedTarget)

        if lp and lr then
            local distance = (lr.Position - Camera.CFrame.Position).Magnitude
            local screen, onScreen = Camera:WorldToViewportPoint(lp.Position)

            if distance <= S.Distance and onScreen and visible(lp) then
                local center = Vector2.new(
                    Camera.ViewportSize.X / 2,
                    Camera.ViewportSize.Y / 2
                )

                local screenDistance = (
                    Vector2.new(screen.X, screen.Y) - center
                ).Magnitude

                if screenDistance <= S.FOV then
                    return lockedTarget
                end
            end
        end
    end

    lockedTarget = nil

    local best
    local score
    local center = Vector2.new(
        Camera.ViewportSize.X / 2,
        Camera.ViewportSize.Y / 2
    )

    for _, p in ipairs(Players:GetPlayers()) do
        if enemy(p) then
            local part = aimPart(p)
            local r = root(p)

            if part and r then
                local distance = (
                    r.Position - Camera.CFrame.Position
                ).Magnitude

                if distance <= S.Distance and visible(part) then
                    local pos, onScreen =
                        Camera:WorldToViewportPoint(part.Position)

                    if onScreen then
                        local screenDistance = (
                            Vector2.new(pos.X, pos.Y) - center
                        ).Magnitude

                        if screenDistance <= S.FOV then
                            local v

                            if S.Priority == "Distance" then
                                v = distance
                            elseif S.Priority == "LowHP" then
                                local h =
                                    p.Character:FindFirstChildOfClass("Humanoid")
                                v = h and h.Health or math.huge
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

    lockedTarget = best
    return best
end

local function aimAt(p)
    local part = aimPart(p)

    if not part then
        return
    end

    local cam = Camera.CFrame
    local goal = CFrame.lookAt(cam.Position, part.Position)

    if S.Mode == "Instant" or S.Mode == "Hold" then
        Camera.CFrame = goal
    else
        local a = math.clamp(S.Speed / 100, 0.01, 1)
        Camera.CFrame = cam:Lerp(goal, a)
    end
end

local esp = {}
local oldHitboxes = {}

local function makeESP(p)
    if esp[p] then
        return esp[p]
    end

    local box = Instance.new("Highlight")
    box.Name = "BarrageESP"
    box.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    box.FillTransparency = 0.78
    box.OutlineTransparency = 0
    box.FillColor = S.ESPColor
    box.OutlineColor = S.ESPColor
    box.Enabled = false
    box.Parent = CoreGui

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
            local d = r and (
                r.Position - Camera.CFrame.Position
            ).Magnitude or math.huge

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
        if p ~= LocalPlayer then
            makeESP(p)
        end
    end
end

local function applyHitbox(p)
    if not enemy(p) then
        return
    end

    local c = p.Character

    if not c then
        return
    end

    local parts = {}

    if S.HeadOnly then
        local h = c:FindFirstChild("Head")
        if h then
            parts = {h}
        end
    else
        local h = c:FindFirstChild("Head")
        local r = c:FindFirstChild("HumanoidRootPart")
        local t =
            c:FindFirstChild("UpperTorso")
            or c:FindFirstChild("Torso")

        if h then
            table.insert(parts, h)
        end

        if r then
            table.insert(parts, r)
        end

        if t then
            table.insert(parts, t)
        end
    end

    for _, part in ipairs(parts) do
        if part:IsA("BasePart") then
            if not oldHitboxes[part] then
                oldHitboxes[part] = {
                    Size = part.Size,
                    Transparency = part.Transparency,
                    CanCollide = part.CanCollide
                }
            end

            part.Size = Vector3.new(
                S.HitboxSize,
                S.HitboxSize,
                S.HitboxSize
            )

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
gui.IgnoreGuiInset = true
gui.Parent = CoreGui

local function corner(o, n)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, n)
    c.Parent = o
    return c
end

local function gradient(o)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, T().A),
        ColorSequenceKeypoint.new(1, T().B)
    })
    g.Rotation = 35
    g.Parent = o
    return g
end

local function glow(o, thickness)
    local s = Instance.new("UIStroke")
    s.Color = T().A
    s.Thickness = thickness or 1
    s.Transparency = 0.25
    s.Parent = o
    return s
end

local function text(parent, value, size, position, font)
    local x = Instance.new("TextLabel")
    x.BackgroundTransparency = 1
    x.Text = value
    x.TextColor3 = T().Text
    x.TextSize = size
    x.Font = font or Enum.Font.GothamSemibold
    x.Position = position
    x.Size = UDim2.new(1, -20, 0, 25)
    x.TextXAlignment = Enum.TextXAlignment.Left
    x.Parent = parent
    return x
end

local function button(parent, value, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -12, 0, 42)
    b.BackgroundColor3 = T().Panel2
    b.Text = value
    b.TextColor3 = T().Text
    b.TextSize = 13
    b.Font = Enum.Font.GothamSemibold
    b.AutoButtonColor = false
    b.Parent = parent

    corner(b, 10)
    glow(b, 1)

    b.MouseEnter:Connect(function()
        TweenService:Create(
            b,
            TweenInfo.new(.15),
            {BackgroundColor3 = T().A}
        ):Play()
    end)

    b.MouseLeave:Connect(function()
        TweenService:Create(
            b,
            TweenInfo.new(.15),
            {BackgroundColor3 = T().Panel2}
        ):Play()
    end)

    b.Activated:Connect(callback)

    return b
end

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(760, 480)
main.Position = UDim2.new(.5, -380, .5, -240)
main.BackgroundColor3 = T().Panel
main.BackgroundTransparency = .06
main.Parent = gui

corner(main, 18)
glow(main, 2)
gradient(main)

local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = T().Panel
overlay.BackgroundTransparency = .22
overlay.Parent = main
corner(overlay, 18)

local header = Instance.new("Frame")
header.Size = UDim2.new(1, -20, 0, 65)
header.Position = UDim2.fromOffset(10, 10)
header.BackgroundColor3 = T().Panel2
header.Parent = main

corner(header, 14)
glow(header, 1)

local logo = Instance.new("TextLabel")
logo.Size = UDim2.fromOffset(48, 48)
logo.Position = UDim2.fromOffset(8, 8)
logo.BackgroundColor3 = T().A
logo.Text = "B"
logo.TextColor3 = Color3.new(1, 1, 1)
logo.TextSize = 25
logo.Font = Enum.Font.GothamBlack
logo.Parent = header

corner(logo, 13)
gradient(logo)

local title = text(
    header,
    "BARRAGE",
    20,
    UDim2.fromOffset(68, 7),
    Enum.Font.GothamBlack
)

local subtitle = text(
    header,
    "KEY SYSTEM  •  VERSION 6.0",
    11,
    UDim2.fromOffset(69, 34),
    Enum.Font.GothamSemibold
)

subtitle.TextColor3 = T().Muted

local status = Instance.new("TextLabel")
status.Size = UDim2.fromOffset(150, 34)
status.Position = UDim2.new(1, -195, 0, 15)
status.BackgroundColor3 = Color3.fromRGB(18, 16, 32)
status.Text = "●  ONLINE"
status.TextColor3 = T().A
status.TextSize = 12
status.Font = Enum.Font.GothamBold
status.Parent = header

corner(status, 9)
glow(status, 1)

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(35, 35)
close.Position = UDim2.new(1, -43, 0, 15)
close.Text = "×"
close.TextSize = 22
close.Font = Enum.Font.GothamBold
close.TextColor3 = T().Text
close.BackgroundColor3 = Color3.fromRGB(65, 39, 105)
close.Parent = header

corner(close, 9)

local navigation = Instance.new("Frame")
navigation.Size = UDim2.fromOffset(190, 385)
navigation.Position = UDim2.fromOffset(10, 85)
navigation.BackgroundColor3 = T().Panel2
navigation.Parent = main

corner(navigation, 14)
glow(navigation, 1)

local navTitle = text(
    navigation,
    "CONTROL",
    11,
    UDim2.fromOffset(14, 12),
    Enum.Font.GothamBold
)

navTitle.TextColor3 = T().Muted

local navContainer = Instance.new("Frame")
navContainer.Size = UDim2.new(1, -16, 1, -50)
navContainer.Position = UDim2.fromOffset(8, 40)
navContainer.BackgroundTransparency = 1
navContainer.Parent = navigation

local navLayout = Instance.new("UIListLayout")
navLayout.Padding = UDim.new(0, 7)
navLayout.Parent = navContainer

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -210, 1, -85)
content.Position = UDim2.fromOffset(200, 85)
content.BackgroundColor3 = T().Panel2
content.Parent = main

corner(content, 14)
glow(content, 1)

local pages = {}

local function createPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name = name
    page.Size = UDim2.new(1, -18, 1, -18)
    page.Position = UDim2.fromOffset(9, 9)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new()
    page.Visible = false
    page.Parent = content

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.Parent = page

    pages[name] = page

    return page
end

local aimPage = createPage("AIMBOT")
local espPage = createPage("ESP")
local hitboxPage = createPage("HITBOX")
local visualPage = createPage("VISUALS")
local settingsPage = createPage("SETTINGS")

local currentPage

local function selectPage(name)
    for n, page in pairs(pages) do
        page.Visible = n == name
    end

    currentPage = name
end

local navButtons = {}

local function navButton(name, icon, page)
    local b = button(
        navContainer,
        icon .. "   " .. name,
        function()
            selectPage(page)

            for _, x in pairs(navButtons) do
                x.BackgroundColor3 = T().Panel2
            end

            b.BackgroundColor3 = T().A
        end
    )

    navButtons[name] = b

    return b
end

navButton("AIMBOT", "◈", "AIMBOT")
navButton("ESP", "◎", "ESP")
navButton("HITBOX", "◇", "HITBOX")
navButton("VISUALS", "✦", "VISUALS")
navButton("SETTINGS", "⚙", "SETTINGS")

local function section(parent, value)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -5, 0, 30)
    holder.BackgroundTransparency = 1
    holder.Parent = parent

    local line = Instance.new("Frame")
    line.Size = UDim2.fromOffset(4, 19)
    line.Position = UDim2.fromOffset(2, 5)
    line.BackgroundColor3 = T().A
    line.Parent = holder

    corner(line, 3)

    local l = text(
        holder,
        value,
        13,
        UDim2.fromOffset(15, 1),
        Enum.Font.GothamBold
    )

    return holder
end

local function option(parent, name, value)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -5, 0, 48)
    holder.BackgroundColor3 = T().Panel
    holder.Parent = parent

    corner(holder, 10)
    glow(holder, 1)

    local a = text(
        holder,
        name,
        12,
        UDim2.fromOffset(13, 2),
        Enum.Font.GothamSemibold
    )

    local b = text(
        holder,
        tostring(value),
        11,
        UDim2.fromOffset(13, 25),
        Enum.Font.Gotham
    )

    b.TextColor3 = T().Muted

    return holder
end

local function cycle(parent, name, key, values)
    local index = 1

    for i, v in ipairs(values) do
        if v == S[key] then
            index = i
        end
    end

    local b

    b = button(
        parent,
        name .. "  •  " .. tostring(S[key]),
        function()
            index = index % #values + 1
            S[key] = values[index]
            b.Text = name .. "  •  " .. tostring(S[key])
        end
    )

    return b
end

local function toggle(parent, name, key)
    local b

    local function refresh()
        b.Text = name .. "  •  " .. (S[key] and "ON" or "OFF")
    end

    b = button(parent, "", function()
        S[key] = not S[key]
        refresh()
    end)

    refresh()

    return b
end

local function slider(parent, name, key, min, max, step)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -5, 0, 65)
    holder.BackgroundColor3 = T().Panel
    holder.Parent = parent

    corner(holder, 10)
    glow(holder, 1)

    local label = text(
        holder,
        name .. "  •  " .. tostring(S[key]),
        12,
        UDim2.fromOffset(12, 4),
        Enum.Font.GothamSemibold
    )

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -24, 0, 7)
    bar.Position = UDim2.fromOffset(12, 43)
    bar.BackgroundColor3 = Color3.fromRGB(50, 42, 75)
    bar.Parent = holder

    corner(bar, 8)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = T().A
    fill.Parent = bar

    corner(fill, 8)

    local q = math.clamp(
        (S[key] - min) / (max - min),
        0,
        1
    )

    fill.Size = UDim2.new(q, 0, 1, 0)

    local dragging = false

    local function update(x)
        local pos = math.clamp(
            (x - bar.AbsolutePosition.X) /
            bar.AbsoluteSize.X,
            0,
            1
        )

        local raw = min + (max - min) * pos
        local value = math.floor(raw / step + .5) * step

        S[key] = value

        fill.Size = UDim2.new(pos, 0, 1, 0)
        label.Text = name .. "  •  " .. tostring(value)
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            dragging = true
            update(input.Position.X)
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        ) then
            update(input.Position.X)
        end
    end)

    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return holder
end

section(aimPage, "TARGETING")

toggle(aimPage, "Aimbot", "Aim")
toggle(aimPage, "Team check", "TeamCheck")
toggle(aimPage, "Triggerbot", "Triggerbot")
cycle(
    aimPage,
    "Priority",
    "Priority",
    {"Crosshair", "Distance", "LowHP"}
)

cycle(
    aimPage,
    "Mode",
    "Mode",
    {"Instant", "Smooth", "Hold"}
)

slider(aimPage, "FOV", "FOV", 20, 360, 5)
slider(aimPage, "Aim speed", "Speed", 1, 100, 1)
slider(aimPage, "Detection distance", "Distance", 50, 2000, 25)

section(espPage, "PLAYER ESP")

toggle(espPage, "ESP", "ESP")
toggle(espPage, "Health", "HP")
toggle(espPage, "Distance", "Dist")
slider(
    espPage,
    "ESP distance",
    "ESPDistance",
    50,
    2000,
    25
)

section(hitboxPage, "HITBOX")

toggle(hitboxPage, "Hitbox", "Hitbox")
toggle(hitboxPage, "Head only", "HeadOnly")
slider(
    hitboxPage,
    "Hitbox size",
    "HitboxSize",
    2,
    15,
    1
)

section(visualPage, "VISUAL STYLE")

cycle(
    visualPage,
    "Theme",
    "Theme",
    {"Purple", "Blue", "Pink", "Ice"}
)

toggle(visualPage, "Snow effect", "Snow")

local fovCircle = Instance.new("Frame")
fovCircle.Name = "FOVCircle"
fovCircle.AnchorPoint = Vector2.new(.5, .5)
fovCircle.BackgroundTransparency = 1
fovCircle.Parent = gui

corner(fovCircle, 999)

local fovStroke = Instance.new("UIStroke")
fovStroke.Color = T().A
fovStroke.Thickness = 2
fovStroke.Transparency = .1
fovStroke.Parent = fovCircle

section(settingsPage, "SYSTEM")

option(settingsPage, "Interface", "BARRAGE")
option(settingsPage, "Version", "6.0")
option(
    settingsPage,
    "Device",
    UIS.TouchEnabled and "Mobile" or "Desktop"
)

local infoBox = Instance.new("Frame")
infoBox.Size = UDim2.new(1, -5, 0, 65)
infoBox.BackgroundColor3 = T().Panel
infoBox.Parent = settingsPage

corner(infoBox, 10)
glow(infoBox, 1)

local infoText = text(
    infoBox,
    "BARRAGE • Advanced Interface",
    13,
    UDim2.fromOffset(13, 9),
    Enum.Font.GothamBold
)

local infoSub = text(
    infoBox,
    "Glass UI / Neon Purple / Responsive HUD",
    11,
    UDim2.fromOffset(13, 34),
    Enum.Font.Gotham
)

infoSub.TextColor3 = T().Muted

local function createSnow()
    local snowLayer = Instance.new("Frame")
    snowLayer.Name = "Snow"
    snowLayer.Size = UDim2.fromScale(1, 1)
    snowLayer.BackgroundTransparency = 1
    snowLayer.ClipsDescendants = true
    snowLayer.ZIndex = 20
    snowLayer.Parent = gui

    task.spawn(function()
        while snowLayer.Parent do
            if S.Snow then
                local flake = Instance.new("TextLabel")
                flake.BackgroundTransparency = 1
                flake.Text = "•"
                flake.TextColor3 = Color3.fromRGB(
                    220,
                    225,
                    255
                )
                flake.TextTransparency = math.random(0, 35) / 100
                flake.TextSize = math.random(8, 16)
                flake.Size = UDim2.fromOffset(20, 20)
                flake.Position = UDim2.new(
                    math.random(),
                    0,
                    -0.05,
                    0
                )
                flake.ZIndex = 20
                flake.Parent = snowLayer

                local duration = math.random(35, 70) / 10

                TweenService:Create(
                    flake,
                    TweenInfo.new(
                        duration,
                        Enum.EasingStyle.Linear
                    ),
                    {
                        Position = UDim2.new(
                            math.random(),
                            0,
                            1.05,
                            0
                        ),
                        Rotation = math.random(-180, 180)
                    }
                ):Play()

                task.delay(duration, function()
                    if flake then
                        flake:Destroy()
                    end
                end)
            end

            task.wait(.15)
        end
    end)
end

createSnow()

local orb = Instance.new("TextButton")
orb.Size = UDim2.fromOffset(64, 64)
orb.Position = UDim2.fromOffset(25, 170)
orb.Text = "B"
orb.TextSize = 25
orb.Font = Enum.Font.GothamBlack
orb.TextColor3 = Color3.new(1, 1, 1)
orb.BackgroundColor3 = T().A
orb.Parent = gui
orb.ZIndex = 30

corner(orb, 18)
glow(orb, 2)
gradient(orb)

local function dragFrame(frame, handle)
    local dragging = false
    local start
    local original

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            dragging = true
            start = input.Position
            original = frame.Position
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if not dragging then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then

            local delta = input.Position - start

            frame.Position = UDim2.new(
                original.X.Scale,
                original.X.Offset + delta.X,
                original.Y.Scale,
                original.Y.Offset + delta.Y
            )
        end
    end)

    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

dragFrame(main, header)
dragFrame(orb, orb)

orb.Activated:Connect(function()
    S.Menu = not S.Menu
    main.Visible = S.Menu
end)

close.Activated:Connect(function()
    S.Menu = false
    main.Visible = false
end)

selectPage("AIMBOT")

if navButtons["AIMBOT"] then
    navButtons["AIMBOT"].BackgroundColor3 = T().A
end

local espTimer = 0
local hitTimer = 0

RunService.RenderStepped:Connect(function(dt)
    local viewport = Camera.ViewportSize

    fovCircle.Position = UDim2.fromOffset(
        viewport.X / 2,
        viewport.Y / 2
    )

    fovCircle.Size = UDim2.fromOffset(
        S.FOV * 2,
        S.FOV * 2
    )

    fovCircle.Visible = S.Aim

    if S.Aim then
        local target = getTarget()

        if target then
            aimAt(target)
        end
    else
        lockedTarget = nil
    end

    espTimer += dt

    if espTimer >= .08 then
        espTimer = 0
        updateESP()
    end

    hitTimer += dt

    if hitTimer >= .15 then
        hitTimer = 0

        if S.Hitbox then
            for _, p in ipairs(Players:GetPlayers()) do
                applyHitbox(p)
            end
        else
            restoreHitboxes()
        end
    end
end)

Players.PlayerRemoving:Connect(function(p)
    if lockedTarget == p then
        lockedTarget = nil
    end

    if esp[p] then
        esp[p]:Destroy()
        esp[p] = nil
    end
end)
