local gui = Instance.new("ScreenGui")
gui.Name = "Barrage"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = game:GetService("CoreGui")

local Theme = {
    Background = Color3.fromRGB(12, 9, 28),
    Panel = Color3.fromRGB(25, 19, 55),
    Panel2 = Color3.fromRGB(31, 23, 70),
    Accent = Color3.fromRGB(120, 75, 255),
    Accent2 = Color3.fromRGB(75, 110, 255),
    Text = Color3.fromRGB(245, 242, 255),
    Muted = Color3.fromRGB(165, 157, 190)
}

local function corner(o, n)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, n)
    c.Parent = o
    return c
end

local function stroke(o, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Accent
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.Parent = o
    return s
end

local function gradient(o)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Theme.Accent),
        ColorSequenceKeypoint.new(1, Theme.Accent2)
    })
    g.Rotation = 35
    g.Parent = o
    return g
end

local function createLabel(parent, text, size, color)
    local x = Instance.new("TextLabel")
    x.BackgroundTransparency = 1
    x.Size = size
    x.Text = text
    x.TextColor3 = color or Theme.Text
    x.Font = Enum.Font.GothamSemibold
    x.TextSize = 13
    x.TextXAlignment = Enum.TextXAlignment.Left
    x.Parent = parent
    return x
end

local function createButton(parent, text, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -12, 0, 42)
    b.BackgroundColor3 = Theme.Panel2
    b.Text = text
    b.TextColor3 = Theme.Text
    b.TextSize = 13
    b.Font = Enum.Font.GothamSemibold
    b.AutoButtonColor = false
    b.Parent = parent
    corner(b, 10)
    stroke(b, Theme.Accent, 1, .65)

    b.MouseEnter:Connect(function()
        b.BackgroundColor3 = Color3.fromRGB(42, 31, 88)
    end)

    b.MouseLeave:Connect(function()
        b.BackgroundColor3 = Theme.Panel2
    end)

    b.Activated:Connect(callback)
    return b
end

local root = Instance.new("Frame")
root.Size = UDim2.fromOffset(760, 470)
root.Position = UDim2.new(.5, -380, .5, -235)
root.BackgroundColor3 = Theme.Background
root.BackgroundTransparency = .08
root.Parent = gui
corner(root, 18)
stroke(root, Theme.Accent, 2, .25)

local rootGradient = gradient(root)

local top = Instance.new("Frame")
top.Size = UDim2.new(1, -18, 0, 62)
top.Position = UDim2.fromOffset(9, 9)
top.BackgroundColor3 = Theme.Panel
top.Parent = root
corner(top, 14)
stroke(top, Theme.Accent, 1, .55)

createLabel(
    top,
    "BARRAGE",
    UDim2.new(0, 180, 0, 28),
    Theme.Text
).Position = UDim2.fromOffset(20, 8)

local sub = createLabel(
    top,
    "KEY SYSTEM  •  v6.0",
    UDim2.new(0, 220, 0, 20),
    Theme.Muted
)
sub.Position = UDim2.fromOffset(21, 34)

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(40, 40)
close.Position = UDim2.new(1, -50, 0, 11)
close.Text = "×"
close.TextSize = 24
close.Font = Enum.Font.GothamBold
close.TextColor3 = Theme.Text
close.BackgroundColor3 = Color3.fromRGB(70, 40, 120)
close.Parent = top
corner(close, 10)

local navigation = Instance.new("Frame")
navigation.Size = UDim2.fromOffset(175, 385)
navigation.Position = UDim2.fromOffset(9, 80)
navigation.BackgroundColor3 = Theme.Panel
navigation.Parent = root
corner(navigation, 14)
stroke(navigation, Theme.Accent, 1, .65)

local navList = Instance.new("UIListLayout")
navList.Padding = UDim.new(0, 7)
navList.HorizontalAlignment = Enum.HorizontalAlignment.Center
navList.Parent = navigation

local navPadding = Instance.new("UIPadding")
navPadding.PaddingTop = UDim.new(0, 14)
navPadding.PaddingLeft = UDim.new(0, 8)
navPadding.PaddingRight = UDim.new(0, 8)
navPadding.Parent = navigation

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -194, 1, -80)
content.Position = UDim2.fromOffset(185, 80)
content.BackgroundColor3 = Theme.Panel
content.Parent = root
corner(content, 14)
stroke(content, Theme.Accent, 1, .65)

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

local aimPage = createPage("AIM")
local espPage = createPage("ESP")
local visualPage = createPage("VISUALS")
local settingsPage = createPage("SETTINGS")

local currentPage

local function selectPage(name)
    for n, page in pairs(pages) do
        page.Visible = n == name
    end
    currentPage = name
end

local function navButton(text, page)
    local b = createButton(navigation, text, function()
        selectPage(page)
    end)
    b.Size = UDim2.new(1, -16, 0, 42)
    return b
end

navButton("◈  AIM", "AIM")
navButton("◉  ESP", "ESP")
navButton("✦  VISUALS", "VISUALS")
navButton("⚙  SETTINGS", "SETTINGS")

local function section(parent, text)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -4, 0, 34)
    holder.BackgroundTransparency = 1
    holder.Parent = parent

    local line = Instance.new("Frame")
    line.Size = UDim2.fromOffset(4, 20)
    line.Position = UDim2.fromOffset(0, 7)
    line.BackgroundColor3 = Theme.Accent
    line.Parent = holder
    corner(line, 3)

    local l = createLabel(
        holder,
        text,
        UDim2.new(1, -14, 1, 0),
        Theme.Text
    )
    l.Position = UDim2.fromOffset(13, 0)

    return holder
end

local function info(parent, title, value)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -4, 0, 54)
    holder.BackgroundColor3 = Theme.Panel2
    holder.Parent = parent
    corner(holder, 10)
    stroke(holder, Theme.Accent, 1, .8)

    local a = createLabel(
        holder,
        title,
        UDim2.new(.6, 0, 1, 0),
        Theme.Muted
    )
    a.Position = UDim2.fromOffset(14, 0)

    local b = createLabel(
        holder,
        tostring(value),
        UDim2.new(.4, -14, 1, 0),
        Theme.Text
    )
    b.Position = UDim2.new(.6, 0, 0, 0)
    b.TextXAlignment = Enum.TextXAlignment.Right

    return holder
end

section(aimPage, "AIM CONFIGURATION")
info(aimPage, "Aimbot", S.Aim and "ON" or "OFF")
info(aimPage, "Target priority", S.Priority)
info(aimPage, "Mode", S.Mode)
info(aimPage, "FOV", S.FOV)
info(aimPage, "Detection distance", S.Distance)

section(espPage, "ESP CONFIGURATION")
info(espPage, "ESP", S.ESP and "ON" or "OFF")
info(espPage, "ESP distance", S.ESPDistance)
info(espPage, "Health display", S.HP and "ON" or "OFF")
info(espPage, "Distance display", S.Dist and "ON" or "OFF")

section(visualPage, "VISUAL THEME")
info(visualPage, "Accent", "Purple")
info(visualPage, "Style", "Glass")
info(visualPage, "Effects", "Snow / Glow")

section(settingsPage, "SYSTEM")
info(settingsPage, "Interface", "BARRAGE")
info(settingsPage, "Version", "6.0")
info(settingsPage, "Device", UIS.TouchEnabled and "Mobile" or "PC")

selectPage("AIM")

local orb = Instance.new("TextButton")
orb.Size = UDim2.fromOffset(58, 58)
orb.Position = UDim2.fromOffset(22, 160)
orb.Text = "B"
orb.TextSize = 24
orb.Font = Enum.Font.GothamBold
orb.TextColor3 = Theme.Text
orb.BackgroundColor3 = Theme.Panel
orb.Parent = gui
corner(orb, 18)
stroke(orb, Theme.Accent, 2, .15)
gradient(orb)

local fovCircle = Instance.new("Frame")
fovCircle.Name = "FOVCircle"
fovCircle.AnchorPoint = Vector2.new(.5, .5)
fovCircle.BackgroundTransparency = 1
fovCircle.Parent = gui

corner(fovCircle, 999)

local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Theme.Accent
fovStroke.Thickness = 2
fovStroke.Transparency = .15
fovStroke.Parent = fovCircle

local function updateFOV()
    local viewport = Camera.ViewportSize
    local centerX = viewport.X * .5
    local centerY = viewport.Y * .5

    fovCircle.Position = UDim2.fromOffset(centerX, centerY)
    fovCircle.Size = UDim2.fromOffset(S.FOV * 2, S.FOV * 2)
    fovCircle.Visible = S.Aim
end

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
        if not dragging then return end

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

dragFrame(root, top)
dragFrame(orb, orb)

orb.Activated:Connect(function()
    root.Visible = not root.Visible
end)

close.Activated:Connect(function()
    root.Visible = false
end)

RunService.RenderStepped:Connect(function()
    updateFOV()
end)
