local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")

local S = {
    Aim = false, Priority = "Crosshair", Mode = "Smooth",
    FOV = 180, Speed = 12, Distance = 1000, TeamCheck = true,
    ESP = false, HP = true, Dist = true, ESPDistance = 1500,
    Hitbox = false, HitboxVisible = true, HitboxSize = 8, HeadOnly = false,
    Triggerbot = false, TriggerDistance = 10000, TriggerDelay = 0.08,
    Optimizer = true, Theme = "Purple", Snow = true, Menu = true
}

local Themes = {
    Purple = {A=Color3.fromRGB(145,85,255),B=Color3.fromRGB(75,35,150),Panel=Color3.fromRGB(19,15,38),Panel2=Color3.fromRGB(30,23,58),Button=Color3.fromRGB(39,30,70),Text=Color3.fromRGB(245,242,255),Muted=Color3.fromRGB(170,150,220)},
    Blue   = {A=Color3.fromRGB(65,145,255),B=Color3.fromRGB(25,75,170),Panel=Color3.fromRGB(13,21,40),Panel2=Color3.fromRGB(21,34,62),Button=Color3.fromRGB(28,48,82),Text=Color3.fromRGB(240,248,255),Muted=Color3.fromRGB(145,180,230)},
    Pink   = {A=Color3.fromRGB(255,80,175),B=Color3.fromRGB(150,35,100),Panel=Color3.fromRGB(40,14,32),Panel2=Color3.fromRGB(63,20,48),Button=Color3.fromRGB(76,28,59),Text=Color3.fromRGB(255,240,250),Muted=Color3.fromRGB(230,150,195)},
    Ice    = {A=Color3.fromRGB(125,225,255),B=Color3.fromRGB(50,125,190),Panel=Color3.fromRGB(10,24,32),Panel2=Color3.fromRGB(17,42,55),Button=Color3.fromRGB(25,58,73),Text=Color3.fromRGB(235,252,255),Muted=Color3.fromRGB(145,205,225)},
    Red    = {A=Color3.fromRGB(255,70,80),B=Color3.fromRGB(150,25,35),Panel=Color3.fromRGB(38,13,16),Panel2=Color3.fromRGB(62,20,24),Button=Color3.fromRGB(76,28,32),Text=Color3.fromRGB(255,240,240),Muted=Color3.fromRGB(230,150,155)}
}
local function T() return Themes[S.Theme] end

local function alive(p)
    local c=p.Character; local h=c and c:FindFirstChildOfClass("Humanoid")
    local r=c and c:FindFirstChild("HumanoidRootPart")
    return c and h and r and h.Health > 0
end
local function enemy(p)
    if p == LocalPlayer or not alive(p) then return false end
    if S.TeamCheck and LocalPlayer.Team and p.Team and LocalPlayer.Team == p.Team then return false end
    return true
end
local function root(p) return p.Character and p.Character:FindFirstChild("HumanoidRootPart") end
local function aimPart(p)
    local c = p.Character
    return c and (c:FindFirstChild("Head") or c:FindFirstChild("UpperTorso") or c:FindFirstChild("HumanoidRootPart"))
end
local function visible(part)
    if not part then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    local hit = workspace:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, params)
    return not hit or hit.Instance:IsDescendantOf(part.Parent)
end

local lockedTarget = nil
local function getTarget()
    if lockedTarget and enemy(lockedTarget) then
        local part = aimPart(lockedTarget)
        if part then
            local pos, on = Camera:WorldToViewportPoint(part.Position)
            local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
            if on and (Vector2.new(pos.X,pos.Y)-center).Magnitude <= S.FOV and visible(part) then
                return lockedTarget
            end
        end
    end
    lockedTarget = nil
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local best, score
    for _,p in ipairs(Players:GetPlayers()) do
        if enemy(p) then
            local part = aimPart(p); local r = root(p)
            if part and r then
                local dist = (r.Position - Camera.CFrame.Position).Magnitude
                if dist <= S.Distance and visible(part) then
                    local pos, on = Camera:WorldToViewportPoint(part.Position)
                    if on then
                        local sd = (Vector2.new(pos.X,pos.Y)-center).Magnitude
                        if sd <= S.FOV then
                            local v
                            if S.Priority == "Distance" then v = dist
                            elseif S.Priority == "LowHP" then
                                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                                v = hum and hum.Health or math.huge
                            else v = sd end
                            if not score or v < score then score = v; best = p end
                        end
                    end
                end
            end
        end
    end
    if best then lockedTarget = best end
    return best
end

local function aimAt(p)
    local part = aimPart(p); if not part then return end
    local cam = Camera.CFrame
    local goal = CFrame.lookAt(cam.Position, part.Position)
    if S.Mode == "Instant" or S.Mode == "Hold" then
        Camera.CFrame = goal
    else
        Camera.CFrame = cam:Lerp(goal, math.clamp(S.Speed/100, 0.01, 1))
    end
end

local esp = {}; local oldHitboxes = {}
local function makeESP(p)
    if esp[p] then return esp[p] end
    local box = Instance.new("Highlight")
    box.Name = "BarrageESP"
    box.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    box.FillTransparency = 0.78; box.OutlineTransparency = 0
    box.FillColor = T().A; box.OutlineColor = T().A
    box.Enabled = false; box.Parent = CoreGui
    esp[p] = box; return box
end
local function updateESP()
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local box = makeESP(p)
            if S.ESP and enemy(p) and p.Character then
                local r = root(p)
                local d = r and (r.Position - Camera.CFrame.Position).Magnitude or math.huge
                box.Adornee = p.Character; box.Enabled = d <= S.ESPDistance
                box.FillColor = T().A; box.OutlineColor = T().A
            else box.Adornee = nil; box.Enabled = false end
        end
    end
end
local function bindPlayer(p)
    if p == LocalPlayer then return end; makeESP(p)
    p.CharacterAdded:Connect(function(c)
        task.wait(0.15); local box = makeESP(p); box.Adornee = c
        if S.ESP and enemy(p) then box.Enabled = true end
    end)
    p.CharacterRemoving:Connect(function()
        if esp[p] then esp[p].Adornee = nil; esp[p].Enabled = false end
    end)
end
for _,p in ipairs(Players:GetPlayers()) do bindPlayer(p) end
Players.PlayerAdded:Connect(bindPlayer)
Players.PlayerRemoving:Connect(function(p)
    if esp[p] then esp[p]:Destroy(); esp[p] = nil end
end)

local function applyHitbox(p)
    if not enemy(p) then return end
    local c = p.Character; if not c then return end
    local parts = {}
    if S.HeadOnly then
        local h = c:FindFirstChild("Head"); if h then parts = {h} end
    else
        local h = c:FindFirstChild("Head")
        local r = c:FindFirstChild("HumanoidRootPart")
        local t = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")
        if h then table.insert(parts,h) end
        if r then table.insert(parts,r) end
        if t then table.insert(parts,t) end
    end
    for _,part in ipairs(parts) do
        if part:IsA("BasePart") then
            if not oldHitboxes[part] then
                oldHitboxes[part] = {Size=part.Size,Transparency=part.Transparency,LocalTransparencyModifier=part.LocalTransparencyModifier,CanCollide=part.CanCollide}
            end
            part.Size = Vector3.new(S.HitboxSize, S.HitboxSize, S.HitboxSize)
            part.CanCollide = false
            part.LocalTransparencyModifier = S.HitboxVisible and 0.35 or 1
        end
    end
end
local function restoreHitboxes()
    for part,data in pairs(oldHitboxes) do
        if part and part.Parent then
            part.Size = data.Size; part.Transparency = data.Transparency
            part.LocalTransparencyModifier = data.LocalTransparencyModifier
            part.CanCollide = data.CanCollide
        end
        oldHitboxes[part] = nil
    end
end

local function triggerTarget()
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local best, bestD = nil, math.huge
    for _,p in ipairs(Players:GetPlayers()) do
        if enemy(p) then
            local part = aimPart(p); local r = root(p)
            if part and r and (r.Position-Camera.CFrame.Position).Magnitude <= S.TriggerDistance then
                local pos, on = Camera:WorldToViewportPoint(part.Position)
                if on then
                    local sd = (Vector2.new(pos.X,pos.Y)-center).Magnitude
                    if sd <= S.FOV and sd < bestD and visible(part) then
                        best = p; bestD = sd
                    end
                end
            end
        end
    end
    return best
end
local lastShot = 0
local function triggerFire()
    local now = os.clock()
    if now - lastShot < S.TriggerDelay then return end
    lastShot = now
    pcall(function()
        VIM:SendMouseButtonEvent(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2, 0, true, game, 0)
        task.wait(0.02)
        VIM:SendMouseButtonEvent(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2, 0, false, game, 0)
    end)
end

local gui = Instance.new("ScreenGui")
gui.Name = "Barrage"; gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true; gui.Parent = CoreGui

local function corner(o,n) local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,n); c.Parent=o end
local function gradient(o)
    local g=Instance.new("UIGradient")
    g.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,T().A),ColorSequenceKeypoint.new(1,T().B)})
    g.Rotation=45; g.Parent=o; return g
end
local function stroke(o)
    local s=Instance.new("UIStroke"); s.Color=T().A
    s.Thickness=1.5; s.Transparency=0.15; s.Parent=o; return s
end

local orb = Instance.new("TextButton")
orb.Size=UDim2.fromOffset(58,58); orb.Position=UDim2.fromOffset(24,200)
orb.Text="B"; orb.TextSize=24; orb.Font=Enum.Font.GothamBold
orb.TextColor3=Color3.new(1,1,1); orb.BackgroundColor3=T().A; orb.Parent=gui
corner(orb,58); stroke(orb); gradient(orb)

local main = Instance.new("Frame")
main.Size=UDim2.fromOffset(620,390)
main.Position=UDim2.new(0.5,-310,0.5,-195)
main.BackgroundColor3=T().Panel; main.Parent=gui
main:SetAttribute("ThemePanel",true); corner(main,16); stroke(main)

local top = Instance.new("Frame")
top.Size=UDim2.new(1,0,0,58); top.BackgroundColor3=T().Panel2
top.Parent=main; top:SetAttribute("ThemePanel2",true); corner(top,16)

local title = Instance.new("TextLabel")
title.Size=UDim2.new(1,-120,1,0); title.Position=UDim2.fromOffset(18,0)
title.BackgroundTransparency=1; title.Text="BARRAGE"
title.TextColor3=T().Text; title.TextSize=20; title.Font=Enum.Font.GothamBold
title.TextXAlignment=Enum.TextXAlignment.Left; title.Parent=top

local sub = Instance.new("TextLabel")
sub.Size=UDim2.new(1,-120,0,18); sub.Position=UDim2.fromOffset(19,34)
sub.BackgroundTransparency=1; sub.Text="Combat interface"
sub.TextColor3=T().Muted; sub.TextSize=10; sub.Font=Enum.Font.Gotham
sub.TextXAlignment=Enum.TextXAlignment.Left; sub.Parent=top

local close = Instance.new("TextButton")
close.Size=UDim2.fromOffset(38,34); close.Position=UDim2.new(1,-48,0,12)
close.Text="×"; close.TextSize=22; close.Font=Enum.Font.GothamBold
close.TextColor3=T().Text; close.BackgroundColor3=T().Button
close.Parent=top; corner(close,9)

local tabs = Instance.new("Frame")
tabs.Size=UDim2.fromOffset(130,318); tabs.Position=UDim2.fromOffset(10,66)
tabs.BackgroundColor3=T().Panel2; tabs.Parent=main
tabs:SetAttribute("ThemePanel2",true); corner(tabs,12)

local content = Instance.new("Frame")
content.Size=UDim2.new(1,-150,1,-76)
content.Position=UDim2.fromOffset(145,66)
content.BackgroundTransparency=1; content.Parent=main

local pages = {}
local function createPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Name=name; page.Size=UDim2.fromScale(1,1)
    page.BackgroundTransparency=1; page.BorderSizePixel=0
    page.ScrollBarThickness=2; page.AutomaticCanvasSize=Enum.AutomaticSize.Y
    page.CanvasSize=UDim2.new(); page.Visible=false; page.Parent=content
    local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,7); layout.Parent=page
    pages[name]=page; return page
end
local aimPage    = createPage("Aimbot")
local espPage    = createPage("ESP")
local hitPage    = createPage("Hitbox")
local visualPage = createPage("Visual")
local settingsPage = createPage("Settings")

local tabButtons = {}
for i,name in ipairs({"Aimbot","ESP","Hitbox","Visual","Settings"}) do
    local b = Instance.new("TextButton")
    b.Size=UDim2.new(1,-12,0,42); b.Position=UDim2.fromOffset(6,6+(i-1)*48)
    b.BackgroundColor3=T().Button; b.Text=name; b.TextColor3=T().Muted
    b.TextSize=12; b.Font=Enum.Font.GothamSemibold; b.Parent=tabs; corner(b,9)
    tabButtons[name] = b
end

local function showPage(name)
    for n,page in pairs(pages) do page.Visible = n == name end
    for n,b in pairs(tabButtons) do
        b.BackgroundColor3 = n==name and T().A or T().Button
        b.TextColor3 = n==name and Color3.new(1,1,1) or T().Muted
    end
end
for name,b in pairs(tabButtons) do
    b.Activated:Connect(function() showPage(name) end)
end

local function label(parent,text)
    local x=Instance.new("TextLabel"); x.Size=UDim2.new(1,-5,0,25)
    x.BackgroundTransparency=1; x.Text=text; x.TextColor3=T().Muted
    x.TextSize=14; x.Font=Enum.Font.GothamBold
    x.TextXAlignment=Enum.TextXAlignment.Left; x.Parent=parent
end
local function btn(parent,text,cb)
    local b=Instance.new("TextButton"); b.Size=UDim2.new(1,-5,0,36)
    b.BackgroundColor3=T().Button; b.Text=text; b.TextColor3=T().Text
    b.TextSize=12; b.Font=Enum.Font.GothamSemibold; b.Parent=parent
    corner(b,9); b.Activated:Connect(cb); return b
end
local function toggle(parent,name,key)
    local b
    local function ref()
        b.Text = name.."     "..(S[key] and "ON" or "OFF")
        b.BackgroundColor3 = S[key] and T().A or T().Button
    end
    b = btn(parent,"",function() S[key]=not S[key]; ref() end)
    ref(); return b
end

local fovStroke
local function cycle(parent,name,key,values)
    local idx=1
    for i,v in ipairs(values) do if v==S[key] then idx=i end end
    local b = btn(parent, name.."     "..tostring(S[key]), function()
        idx = idx % #values + 1
        S[key] = values[idx]
        b.Text = name.."     "..tostring(S[key])
        if key == "Theme" then
            task.defer(function()
                for _,obj in ipairs(gui:GetDescendants()) do
                    if obj:IsA("Frame") then
                        if obj:GetAttribute("ThemePanel") then
                            obj.BackgroundColor3 = T().Panel
                        elseif obj:GetAttribute("ThemePanel2") then
                            obj.BackgroundColor3 = T().Panel2
                        end
                    elseif obj:IsA("TextButton") then
                        obj.BackgroundColor3 = T().Button
                        obj.TextColor3 = T().Text
                    elseif obj:IsA("TextLabel") then
                        obj.TextColor3 = T().Text
                    elseif obj:IsA("UIStroke") then
                        obj.Color = T().A
                    elseif obj:IsA("UIGradient") then
                        obj.Color = ColorSequence.new({
                            ColorSequenceKeypoint.new(0,T().A),
                            ColorSequenceKeypoint.new(1,T().B)
                        })
                    end
                end
                orb.BackgroundColor3 = T().A
                if fovStroke then fovStroke.Color = T().A end
                for _,box in pairs(esp) do
                    box.FillColor = T().A; box.OutlineColor = T().A
                end
                showPage("Settings")
            end)
        end
    end)
    return b
end

local function slider(parent,name,key,mn,mx,step)
    local holder=Instance.new("Frame"); holder.Size=UDim2.new(1,-5,0,52)
    holder.BackgroundTransparency=1; holder.Parent=parent
    local text=Instance.new("TextLabel"); text.Size=UDim2.new(1,0,0,20)
    text.BackgroundTransparency=1; text.TextColor3=T().Text; text.TextSize=11
    text.Font=Enum.Font.Gotham; text.TextXAlignment=Enum.TextXAlignment.Left; text.Parent=holder
    local bar=Instance.new("Frame"); bar.Size=UDim2.new(1,0,0,7)
    bar.Position=UDim2.fromOffset(0,29); bar.BackgroundColor3=T().Button; bar.Parent=holder; corner(bar,7)
    local fill=Instance.new("Frame"); fill.BackgroundColor3=T().A; fill.Parent=bar; corner(fill,7)
    local drag=false
    local function upd(x)
        local q=math.clamp((x-bar.AbsolutePosition.X)/math.max(bar.AbsoluteSize.X,1),0,1)
        local v=math.floor((mn+(mx-mn)*q)/step+0.5)*step
        S[key]=v; fill.Size=UDim2.new(q,0,1,0); text.Text=name.."     "..tostring(v)
    end
    local q0=math.clamp((S[key]-mn)/(mx-mn),0,1)
    fill.Size=UDim2.new(q0,0,1,0); text.Text=name.."     "..tostring(S[key])
    bar.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            drag=true; upd(i.Position.X) end end)
    UIS.InputChanged:Connect(function(i)
        if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            upd(i.Position.X) end end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            drag=false end end)
    return holder
end

label(aimPage,"AIMBOT")
toggle(aimPage,"Aimbot","Aim")
cycle(aimPage,"Target","Priority",{"Crosshair","Distance","LowHP"})
cycle(aimPage,"Mode","Mode",{"Instant","Smooth","Hold"})
toggle(aimPage,"Team check","TeamCheck")
slider(aimPage,"FOV","FOV",20,360,5)
slider(aimPage,"Aim speed","Speed",1,100,1)
slider(aimPage,"Detection distance","Distance",50,2000,25)
label(aimPage,"TRIGGER")
toggle(aimPage,"Triggerbot","Triggerbot")
slider(aimPage,"Trigger distance","TriggerDistance",100,10000,100)
slider(aimPage,"Trigger delay","TriggerDelay",0.01,0.5,0.01)

label(espPage,"PLAYER ESP")
toggle(espPage,"ESP","ESP")
toggle(espPage,"Show HP","HP")
toggle(espPage,"Show distance","Dist")
slider(espPage,"ESP distance","ESPDistance",50,3000,25)

label(hitPage,"HITBOX")
toggle(hitPage,"Hitbox","Hitbox")
toggle(hitPage,"Show hitboxes","HitboxVisible")
toggle(hitPage,"Head only","HeadOnly")
slider(hitPage,"Hitbox size","HitboxSize",2,15,1)

label(visualPage,"VISUAL")
toggle(visualPage,"Snow effect","Snow")

label(settingsPage,"INTERFACE")
cycle(settingsPage,"Theme","Theme",{"Purple","Blue","Pink","Ice","Red"})
toggle(settingsPage,"Optimizer","Optimizer")

local fovCircle = Instance.new("Frame")
fovCircle.Name="FOVCircle"; fovCircle.AnchorPoint=Vector2.new(0.5,0.5)
fovCircle.Position=UDim2.fromScale(0.5,0.5)
fovCircle.Size=UDim2.fromOffset(S.FOV*2,S.FOV*2)
fovCircle.BackgroundTransparency=1; fovCircle.Parent=gui
corner(fovCircle, S.FOV)

fovStroke = Instance.new("UIStroke")
fovStroke.Color=T().A; fovStroke.Thickness=2
fovStroke.Transparency=0.15; fovStroke.Parent=fovCircle

local snowHolder = Instance.new("Frame")
snowHolder.Size=UDim2.fromScale(1,1); snowHolder.BackgroundTransparency=1
snowHolder.ClipsDescendants=true; snowHolder.ZIndex=20; snowHolder.Parent=gui

local snowflakes = {}
for i=1,35 do
    local f=Instance.new("TextLabel"); f.BackgroundTransparency=1
    f.Text="•"; f.TextColor3=Color3.new(1,1,1)
    f.TextTransparency=math.random(20,60)/100; f.TextSize=math.random(7,14)
    f.Position=UDim2.fromScale(math.random(),math.random())
    f.Size=UDim2.fromOffset(20,20); f.ZIndex=21; f.Parent=snowHolder
    table.insert(snowflakes,{Object=f,Speed=math.random(10,30)/100,Drift=math.random(-10,10)/100})
end

local function dragFrame(frame,handle)
    local drag=false; local off
    handle.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            drag=true
            off=Vector2.new(i.Position.X-frame.AbsolutePosition.X, i.Position.Y-frame.AbsolutePosition.Y)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            frame.Position=UDim2.fromOffset(i.Position.X-off.X, i.Position.Y-off.Y)
        end
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            drag=false
        end
    end)
end

local resize=Instance.new("TextButton")
resize.Size=UDim2.fromOffset(22,22); resize.Position=UDim2.new(1,-25,1,-25)
resize.BackgroundTransparency=1; resize.Text="◢"; resize.TextColor3=T().Muted
resize.TextSize=13; resize.ZIndex=30; resize.Parent=main
local resizing=false; local resizeStart; local resizeSize
resize.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        resizing=true; resizeStart=i.Position; resizeSize=main.AbsoluteSize
    end
end)
UIS.InputChanged:Connect(function(i)
    if resizing and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
        local d=i.Position-resizeStart
        main.Size=UDim2.fromOffset(
            math.clamp(resizeSize.X+d.X,500,900),
            math.clamp(resizeSize.Y+d.Y,330,650)
        )
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        resizing=false
    end
end)

dragFrame(main,top); dragFrame(orb,orb)
orb.Activated:Connect(function() S.Menu=not S.Menu; main.Visible=S.Menu end)
close.Activated:Connect(function() S.Menu=false; main.Visible=false end)
showPage("Aimbot")

local timers={esp=0,hit=0,trig=0,snow=0}
RunService.RenderStepped:Connect(function(dt)
    local vp=Camera.ViewportSize
    fovCircle.Position=UDim2.fromOffset(vp.X/2,vp.Y/2)
    fovCircle.Size=UDim2.fromOffset(S.FOV*2,S.FOV*2)
    fovCircle.Visible=S.Aim
    if S.Aim then
        local t=getTarget(); if t then aimAt(t) end
    else lockedTarget=nil end
    timers.trig+=dt
    if timers.trig>=0.025 then
        timers.trig=0
        if S.Triggerbot then local t=triggerTarget(); if t then triggerFire() end end
    end
    timers.esp+=dt
    if timers.esp>=(S.Optimizer and 0.12 or 0.04) then
        timers.esp=0; if S.ESP then updateESP() end
    end
    timers.hit+=dt
    if timers.hit>=(S.Optimizer and 0.18 or 0.07) then
        timers.hit=0
        if S.Hitbox then
            for _,p in ipairs(Players:GetPlayers()) do applyHitbox(p) end
        else restoreHitboxes() end
    end
    timers.snow+=dt
    if timers.snow>=0.03 then
        timers.snow=0; snowHolder.Visible=S.Snow
        if S.Snow then
            for _,d in ipairs(snowflakes) do
                local o=d.Object; local pos=o.Position
                local y=pos.Y.Scale+d.Speed*0.03
                local x=pos.X.Scale+d.Drift*0.003
                if y>1.05 then y=-0.05; x=math.random() end
                o.Position=UDim2.fromScale(x,y)
            end
        end
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.2); Camera=workspace.CurrentCamera
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer then
            local box=makeESP(p)
            if S.ESP and p.Character and enemy(p) then
                box.Adornee=p.Character; box.Enabled=true
            end
        end
    end
end)
