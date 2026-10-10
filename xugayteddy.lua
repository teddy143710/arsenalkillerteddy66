local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")

local S = {
    AimEnabled=false, AimFOV=120, AimSmooth=5, AimWalls=false, AimPart="Head",
    SilentAim=false,
    TriggerEnabled=false, TriggerDelay=0.08,
    TeamCheck=true, CheckVis=true,
    ESPEnabled=false, ESPBoxes=true, ESPHealth=true, ESPNames=true, ESPLines=false, ESPDist=1500,
    ChamsEnabled=false, ChamsRainbow=false,
    HitboxEnabled=false, HitboxVisible=true, HitboxW=8, HitboxH=8,
    AmmoMod=false, RecoilMod=false,
    FOVVisible=true,
    Optimizer=true,
    MenuOpen=true, ActiveTab="COMBAT",
}

local C = {
    BG=Color3.fromRGB(8,10,18), Panel=Color3.fromRGB(13,16,28),
    Panel2=Color3.fromRGB(18,22,38), Side=Color3.fromRGB(10,13,22),
    Acc=Color3.fromRGB(0,180,255), AccDim=Color3.fromRGB(0,80,130),
    Txt=Color3.fromRGB(215,230,255), Muted=Color3.fromRGB(90,115,160),
    ON=Color3.fromRGB(0,180,255), OFF=Color3.fromRGB(25,32,55),
    Green=Color3.fromRGB(50,205,90), Yellow=Color3.fromRGB(255,200,50), Red=Color3.fromRGB(255,60,70),
    White=Color3.fromRGB(255,255,255), Black=Color3.fromRGB(0,0,0),
    Border=Color3.fromRGB(0,60,110),
}

local espHL = {}
local espBB = {}
local chamsHL = {}
local oldHB = {}
local locked = nil
local lastTrig = 0
local rwHue = 0

local function cr(o,r) local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,r or 6) c.Parent=o return c end
local function st(o,col,th) local s=Instance.new("UIStroke") s.Color=col or C.Border s.Thickness=th or 1 s.Parent=o return s end

local function alive(p)
    local c=p.Character
    local h=c and c:FindFirstChildOfClass("Humanoid")
    local r=c and c:FindFirstChild("HumanoidRootPart")
    return c and h and r and h.Health>0
end
local function enemy(p)
    if p==LocalPlayer then return false end
    if not alive(p) then return false end
    if S.TeamCheck and LocalPlayer.Team and p.Team and LocalPlayer.Team==p.Team then return false end
    return true
end
local function getRoot(p) return p.Character and p.Character:FindFirstChild("HumanoidRootPart") end
local function getHead(p) return p.Character and p.Character:FindFirstChild("Head") end
local function getAimPart(p)
    local c=p.Character; if not c then return nil end
    if S.AimPart=="Head" then return c:FindFirstChild("Head") or c:FindFirstChild("HumanoidRootPart")
    elseif S.AimPart=="Torso" then return c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso") or c:FindFirstChild("HumanoidRootPart")
    end return c:FindFirstChild("HumanoidRootPart")
end
local function isVis(part)
    if not part then return false end
    local p=RaycastParams.new()
    p.FilterType=Enum.RaycastFilterType.Exclude
    local ch=LocalPlayer.Character
    p.FilterDescendantsInstances=ch and {ch} or {}
    local res=workspace:Raycast(Camera.CFrame.Position,part.Position-Camera.CFrame.Position,p)
    return not res or res.Instance:IsDescendantOf(part.Parent)
end
local function inFOV(part)
    if not part then return false end
    local sp,on=Camera:WorldToViewportPoint(part.Position)
    if not on then return false end
    local ctr=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
    return (Vector2.new(sp.X,sp.Y)-ctr).Magnitude<=S.AimFOV
end

local function getBest()
    if locked and enemy(locked) then
        local pt=getAimPart(locked)
        if pt and inFOV(pt) and (S.AimWalls or isVis(pt)) then return locked end
    end
    locked=nil
    local ctr=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
    local best,bd=nil,math.huge
    for _,p in ipairs(Players:GetPlayers()) do
        if enemy(p) then
            local pt=getAimPart(p)
            if pt and (S.AimWalls or not S.CheckVis or isVis(pt)) then
                local sp,on=Camera:WorldToViewportPoint(pt.Position)
                if on then
                    local d=(Vector2.new(sp.X,sp.Y)-ctr).Magnitude
                    if d<=S.AimFOV and d<bd then bd=d; best=p end
                end
            end
        end
    end
    locked=best; return best
end
local function doAim(p)
    local pt=getAimPart(p); if not pt then return end
    local g=CFrame.lookAt(Camera.CFrame.Position,pt.Position)
    Camera.CFrame=Camera.CFrame:Lerp(g,math.clamp(S.AimSmooth/50,0.02,1))
end

-- ESP via Highlight + BillboardGui (mobile safe)
local function clearESP()
    for _,t in pairs(espHL) do pcall(function() t:Destroy() end) end
    for _,t in pairs(espBB) do pcall(function() t:Destroy() end) end
    espHL={}; espBB={}
end

local function buildESP(p)
    if espHL[p] then pcall(function() espHL[p]:Destroy() end) end
    if espBB[p] then pcall(function() espBB[p]:Destroy() end) end
    if not enemy(p) or not p.Character then return end
    local r=getRoot(p); if not r then return end
    local dist=(r.Position-Camera.CFrame.Position).Magnitude
    if dist>S.ESPDist then return end

    if S.ESPBoxes then
        local hi=Instance.new("Highlight")
        hi.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
        hi.FillTransparency=0.85
        hi.OutlineTransparency=0
        hi.FillColor=C.Acc
        hi.OutlineColor=C.Acc
        hi.Adornee=p.Character
        hi.Parent=CoreGui
        espHL[p]=hi
    end

    if S.ESPNames or S.ESPHealth then
        local head=getHead(p)
        if not head then return end
        local bb=Instance.new("BillboardGui")
        bb.Name="KESP"
        bb.Size=UDim2.fromOffset(100,40)
        bb.StudsOffset=Vector3.new(0,2.5,0)
        bb.AlwaysOnTop=true
        bb.Adornee=head
        bb.Parent=CoreGui

        if S.ESPNames then
            local nl=Instance.new("TextLabel")
            nl.Size=UDim2.new(1,0,0,18)
            nl.BackgroundTransparency=1
            nl.Text=p.Name
            nl.TextColor3=C.Acc
            nl.TextSize=11
            nl.Font=Enum.Font.GothamBold
            nl.TextStrokeTransparency=0
            nl.TextStrokeColor3=C.Black
            nl.Parent=bb
        end

        if S.ESPHealth then
            local hum=p.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                local hp=math.clamp(hum.Health/math.max(hum.MaxHealth,1),0,1)
                local hcol=hp>0.6 and C.Green or hp>0.3 and C.Yellow or C.Red
                local bg=Instance.new("Frame")
                bg.Size=UDim2.new(1,0,0,5)
                bg.Position=UDim2.fromOffset(0,22)
                bg.BackgroundColor3=C.OFF
                bg.Parent=bb
                cr(bg,3)
                local bar=Instance.new("Frame")
                bar.Size=UDim2.new(hp,0,1,0)
                bar.BackgroundColor3=hcol
                bar.Parent=bg
                cr(bar,3)
            end
        end
        espBB[p]=bb
    end
end

local function renderESP()
    if not S.ESPEnabled then clearESP(); return end
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer then buildESP(p) end
    end
    -- cleanup left players
    for p,_ in pairs(espHL) do
        if not p.Parent or not enemy(p) then
            pcall(function() espHL[p]:Destroy() end); espHL[p]=nil
        end
    end
    for p,_ in pairs(espBB) do
        if not p.Parent or not enemy(p) then
            pcall(function() espBB[p]:Destroy() end); espBB[p]=nil
        end
    end
end

local function clearChams()
    for _,h in pairs(chamsHL) do pcall(function() h:Destroy() end) end
    chamsHL={}
end
local function renderChams()
    clearChams()
    if not S.ChamsEnabled then return end
    for _,p in ipairs(Players:GetPlayers()) do
        if enemy(p) and p.Character then
            local hi=Instance.new("Highlight")
            hi.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
            hi.FillTransparency=0.4
            hi.OutlineTransparency=0
            local col=S.ChamsRainbow and Color3.fromHSV(rwHue,1,1) or C.Acc
            hi.FillColor=col; hi.OutlineColor=col
            hi.Adornee=p.Character
            hi.Parent=CoreGui
            table.insert(chamsHL,hi)
        end
    end
end

local function applyHB(p)
    if not enemy(p) then return end
    local c=p.Character; if not c then return end
    local parts={}
    local head=c:FindFirstChild("Head")
    local torso=c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")
    local root=c:FindFirstChild("HumanoidRootPart")
    if head then table.insert(parts,head) end
    if torso then table.insert(parts,torso) end
    if root then table.insert(parts,root) end
    for _,pt in ipairs(parts) do
        if pt:IsA("BasePart") then
            if not oldHB[pt] then
                oldHB[pt]={Size=pt.Size,LTM=pt.LocalTransparencyModifier,CC=pt.CanCollide}
            end
            pt.Size=Vector3.new(S.HitboxW,S.HitboxH,S.HitboxW)
            pt.CanCollide=false
            pt.LocalTransparencyModifier=S.HitboxVisible and 0.35 or 1
        end
    end
end
local function restoreHB()
    for pt,d in pairs(oldHB) do
        if pt and pt.Parent then
            pt.Size=d.Size; pt.LocalTransparencyModifier=d.LTM; pt.CanCollide=d.CC
        end
    end; oldHB={}
end

local function trigCheck()
    if not S.TriggerEnabled then return end
    local now=os.clock()
    if now-lastTrig<S.TriggerDelay then return end
    local ctr=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
    for _,p in ipairs(Players:GetPlayers()) do
        if enemy(p) then
            local pt=getAimPart(p)
            if pt and (not S.CheckVis or isVis(pt)) then
                local sp,on=Camera:WorldToViewportPoint(pt.Position)
                if on and (Vector2.new(sp.X,sp.Y)-ctr).Magnitude<=S.AimFOV then
                    lastTrig=now
                    pcall(function()
                        VIM:SendMouseButtonEvent(ctr.X,ctr.Y,0,true,game,0)
                        task.wait(0.02)
                        VIM:SendMouseButtonEvent(ctr.X,ctr.Y,0,false,game,0)
                    end)
                    return
                end
            end
        end
    end
end

local function ammoMod()
    if not S.AmmoMod then return end
    pcall(function()
        local ch=LocalPlayer.Character; if not ch then return end
        local tool=ch:FindFirstChildOfClass("Tool"); if not tool then return end
        for _,v in ipairs(tool:GetDescendants()) do
            if (v:IsA("IntValue") or v:IsA("NumberValue")) then
                local n=v.Name:lower()
                if n:find("ammo") or n:find("mag") or n:find("clip") or n:find("bullet") then v.Value=9999 end
            end
        end
    end)
end
local function recoilMod()
    if not S.RecoilMod then return end
    pcall(function()
        local ch=LocalPlayer.Character; if not ch then return end
        local tool=ch:FindFirstChildOfClass("Tool"); if not tool then return end
        for _,v in ipairs(tool:GetDescendants()) do
            if v:IsA("NumberValue") or v:IsA("Vector3Value") then
                local n=v.Name:lower()
                if n:find("recoil") or n:find("spread") or n:find("kick") then
                    if v:IsA("NumberValue") then v.Value=0
                    elseif v:IsA("Vector3Value") then v.Value=Vector3.zero end
                end
            end
        end
    end)
end

-- GUI
local prev=CoreGui:FindFirstChild("KUI"); if prev then prev:Destroy() end
local gui=Instance.new("ScreenGui")
gui.Name="KUI"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; gui.Parent=CoreGui

-- FOV circle
local fovF=Instance.new("Frame")
fovF.AnchorPoint=Vector2.new(0.5,0.5); fovF.BackgroundTransparency=1; fovF.ZIndex=2; fovF.Parent=gui
cr(fovF,200)
local fovSt=st(fovF,C.Acc,1.5); fovSt.Transparency=0.1

-- Orb
local orb=Instance.new("TextButton")
orb.Size=UDim2.fromOffset(62,62); orb.Position=UDim2.fromOffset(14,180)
orb.BackgroundColor3=C.BG; orb.Text=""; orb.ZIndex=15; orb.Parent=gui
cr(orb,62); st(orb,C.Acc,2)
local orbIn=Instance.new("Frame")
orbIn.Size=UDim2.new(1,-8,1,-8); orbIn.Position=UDim2.fromOffset(4,4)
orbIn.BackgroundColor3=C.Acc; orbIn.ZIndex=16; orbIn.Parent=orb; cr(orbIn,62)
local orbT=Instance.new("TextLabel")
orbT.Size=UDim2.fromScale(1,1); orbT.BackgroundTransparency=1
orbT.Text="K"; orbT.TextColor3=C.Black; orbT.TextSize=20; orbT.Font=Enum.Font.GothamBold
orbT.ZIndex=17; orbT.Parent=orbIn

-- Main
local main=Instance.new("Frame")
main.Name="Main"; main.AnchorPoint=Vector2.new(0.5,0.5)
main.Position=UDim2.fromScale(0.5,0.5); main.Size=UDim2.fromScale(0.92,0.52)
main.BackgroundColor3=C.BG; main.ZIndex=10; main.ClipsDescendants=true; main.Parent=gui
cr(main,10); st(main,C.Border,1)

-- Topbar
local top=Instance.new("Frame")
top.Size=UDim2.new(1,0,0,40); top.BackgroundColor3=C.Panel; top.ZIndex=11; top.Parent=main; cr(top,10)

local minB=Instance.new("TextButton")
minB.Size=UDim2.fromOffset(26,22); minB.Position=UDim2.fromOffset(8,9)
minB.BackgroundColor3=C.Panel2; minB.Text="−"; minB.TextColor3=C.Txt
minB.TextSize=15; minB.Font=Enum.Font.GothamBold; minB.ZIndex=12; minB.Parent=top; cr(minB,5)

local closeB=Instance.new("TextButton")
closeB.Size=UDim2.fromOffset(26,22); closeB.Position=UDim2.fromOffset(38,9)
closeB.BackgroundColor3=Color3.fromRGB(150,30,40); closeB.Text="×"
closeB.TextColor3=C.White; closeB.TextSize=13; closeB.Font=Enum.Font.GothamBold
closeB.ZIndex=12; closeB.Parent=top; cr(closeB,5)

local tabLabel=Instance.new("TextLabel")
tabLabel.Size=UDim2.new(0.5,0,1,0); tabLabel.Position=UDim2.fromOffset(72,0)
tabLabel.BackgroundTransparency=1; tabLabel.Text="CURRENT TAB:  COMBAT"
tabLabel.TextColor3=C.Muted; tabLabel.TextSize=9; tabLabel.Font=Enum.Font.GothamBold
tabLabel.TextXAlignment=Enum.TextXAlignment.Left; tabLabel.ZIndex=12; tabLabel.Parent=top

local fpsL=Instance.new("TextLabel")
fpsL.Size=UDim2.fromOffset(55,18); fpsL.Position=UDim2.new(1,-118,0,5)
fpsL.BackgroundTransparency=1; fpsL.Text="FPS 0"; fpsL.TextColor3=C.Acc
fpsL.TextSize=8; fpsL.Font=Enum.Font.GothamBold; fpsL.ZIndex=12; fpsL.Parent=top

local pingL=Instance.new("TextLabel")
pingL.Size=UDim2.fromOffset(55,18); pingL.Position=UDim2.new(1,-60,0,5)
pingL.BackgroundTransparency=1; pingL.Text="PING 0ms"; pingL.TextColor3=C.Muted
pingL.TextSize=8; pingL.Font=Enum.Font.GothamBold; pingL.ZIndex=12; pingL.Parent=top

local fpsL2=Instance.new("TextLabel")
fpsL2.Size=UDim2.fromOffset(55,12); fpsL2.Position=UDim2.new(1,-118,0,22)
fpsL2.BackgroundTransparency=1; fpsL2.Text="144"; fpsL2.TextColor3=C.Acc
fpsL2.TextSize=14; fpsL2.Font=Enum.Font.GothamBold; fpsL2.ZIndex=12; fpsL2.Parent=top

local pingL2=Instance.new("TextLabel")
pingL2.Size=UDim2.fromOffset(55,12); pingL2.Position=UDim2.new(1,-60,0,22)
pingL2.BackgroundTransparency=1; pingL2.Text="12ms"; pingL2.TextColor3=C.Muted
pingL2.TextSize=14; pingL2.Font=Enum.Font.GothamBold; pingL2.ZIndex=12; pingL2.Parent=top

-- Popup
local popup=Instance.new("Frame")
popup.Size=UDim2.fromOffset(240,100); popup.AnchorPoint=Vector2.new(0.5,0.5)
popup.Position=UDim2.fromScale(0.5,0.5); popup.BackgroundColor3=C.Panel
popup.Visible=false; popup.ZIndex=50; popup.Parent=gui; cr(popup,8); st(popup,C.Acc,1.5)
local popTxt=Instance.new("TextLabel")
popTxt.Size=UDim2.new(1,-12,0,40); popTxt.Position=UDim2.fromOffset(6,8)
popTxt.BackgroundTransparency=1; popTxt.Text="Вы уверены, что хотите\nзакрыть чит полностью?"
popTxt.TextColor3=C.Txt; popTxt.TextSize=11; popTxt.Font=Enum.Font.Gotham
popTxt.TextWrapped=true; popTxt.ZIndex=51; popTxt.Parent=popup
local popNo=Instance.new("TextButton")
popNo.Size=UDim2.fromOffset(96,28); popNo.Position=UDim2.fromOffset(6,64)
popNo.BackgroundColor3=C.Panel2; popNo.Text="Отменить"; popNo.TextColor3=C.Txt
popNo.TextSize=10; popNo.Font=Enum.Font.GothamSemibold; popNo.ZIndex=52; popNo.Parent=popup; cr(popNo,6)
local popYes=Instance.new("TextButton")
popYes.Size=UDim2.fromOffset(96,28); popYes.Position=UDim2.fromOffset(138,64)
popYes.BackgroundColor3=Color3.fromRGB(150,30,40); popYes.Text="Да, закрыть"
popYes.TextColor3=C.White; popYes.TextSize=10; popYes.Font=Enum.Font.GothamSemibold
popYes.ZIndex=52; popYes.Parent=popup; cr(popYes,6)

-- Body
local body=Instance.new("Frame")
body.Size=UDim2.new(1,0,1,-40); body.Position=UDim2.fromOffset(0,40)
body.BackgroundTransparency=1; body.ZIndex=11; body.Parent=main

-- Sidebar
local side=Instance.new("Frame")
side.Size=UDim2.fromOffset(160,10000); side.BackgroundColor3=C.Side; side.ZIndex=11; side.Parent=body
st(side,C.Border,1)
local sideL=Instance.new("UIListLayout")
sideL.Padding=UDim.new(0,2); sideL.HorizontalAlignment=Enum.HorizontalAlignment.Center; sideL.Parent=side
local sidePad=Instance.new("UIPadding")
sidePad.PaddingTop=UDim.new(0,8); sidePad.PaddingLeft=UDim.new(0,6); sidePad.PaddingRight=UDim.new(0,6); sidePad.Parent=side

-- Player block
local plrBox=Instance.new("Frame")
plrBox.Size=UDim2.new(1,-4,0,42); plrBox.BackgroundColor3=C.Panel2; plrBox.ZIndex=12
plrBox.LayoutOrder=100; plrBox.Parent=side; cr(plrBox,7)
local plrIcon=Instance.new("Frame")
plrIcon.Size=UDim2.fromOffset(26,26); plrIcon.Position=UDim2.fromOffset(6,8)
plrIcon.BackgroundColor3=C.Acc; plrIcon.ZIndex=13; plrIcon.Parent=plrBox; cr(plrIcon,26)
local plrIconT=Instance.new("TextLabel")
plrIconT.Size=UDim2.fromScale(1,1); plrIconT.BackgroundTransparency=1
plrIconT.Text=string.sub(LocalPlayer.Name,1,1):upper()
plrIconT.TextColor3=C.Black; plrIconT.TextSize=11; plrIconT.Font=Enum.Font.GothamBold
plrIconT.ZIndex=14; plrIconT.Parent=plrIcon
local plrName=Instance.new("TextLabel")
plrName.Size=UDim2.new(1,-40,0,15); plrName.Position=UDim2.fromOffset(36,6)
plrName.BackgroundTransparency=1; plrName.Text=LocalPlayer.Name
plrName.TextColor3=C.Txt; plrName.TextSize=9; plrName.Font=Enum.Font.GothamSemibold
plrName.TextXAlignment=Enum.TextXAlignment.Left; plrName.TextTruncate=Enum.TextTruncate.AtEnd
plrName.ZIndex=13; plrName.Parent=plrBox
local plrSub=Instance.new("TextLabel")
plrSub.Size=UDim2.new(1,-40,0,13); plrSub.Position=UDim2.fromOffset(36,21)
plrSub.BackgroundTransparency=1; plrSub.Text="● ACTIVE"
plrSub.TextColor3=C.Acc; plrSub.TextSize=8; plrSub.Font=Enum.Font.GothamBold
plrSub.TextXAlignment=Enum.TextXAlignment.Left; plrSub.ZIndex=13; plrSub.Parent=plrBox

-- Content
local cont=Instance.new("Frame")
cont.Size=UDim2.new(1,-160,1,0); cont.Position=UDim2.fromOffset(160,0)
cont.BackgroundTransparency=1; cont.ZIndex=11; cont.Parent=body

-- Pages
local pages={}
local function mkPage(name)
    local s=Instance.new("ScrollingFrame")
    s.Name=name; s.Size=UDim2.fromScale(1,1); s.BackgroundTransparency=1
    s.BorderSizePixel=0; s.ScrollBarThickness=2
    s.AutomaticCanvasSize=Enum.AutomaticSize.Y; s.CanvasSize=UDim2.new()
    s.Visible=false; s.ZIndex=12; s.Parent=cont
    local pad=Instance.new("UIPadding")
    pad.PaddingTop=UDim.new(0,6); pad.PaddingBottom=UDim.new(0,6)
    pad.PaddingLeft=UDim.new(0,6); pad.PaddingRight=UDim.new(0,6); pad.Parent=s
    local grid=Instance.new("UIGridLayout")
    grid.CellSize=UDim2.new(0.5,-4,0,148); grid.CellPadding=UDim2.fromOffset(4,4)
    grid.HorizontalAlignment=Enum.HorizontalAlignment.Left; grid.Parent=s
    pages[name]=s; return s
end

local TABS={
    {n="COMBAT",i="⚔"},{n="VISUALS",i="👁"},{n="HITBOX",i="+"},{n="MISC",i="✦"},{n="SETTINGS",i="⚙"}
}
local tabBtns={}
for _,t in ipairs(TABS) do
    local b=Instance.new("TextButton")
    b.Size=UDim2.new(1,0,0,36); b.BackgroundColor3=C.Panel2; b.ZIndex=12; b.Parent=side; cr(b,7)
    local il=Instance.new("TextLabel")
    il.Size=UDim2.fromOffset(20,36); il.Position=UDim2.fromOffset(8,0)
    il.BackgroundTransparency=1; il.Text=t.i; il.TextColor3=C.Muted
    il.TextSize=12; il.Font=Enum.Font.GothamBold; il.ZIndex=13; il.Parent=b
    local nl=Instance.new("TextLabel")
    nl.Size=UDim2.new(1,-32,1,0); nl.Position=UDim2.fromOffset(28,0)
    nl.BackgroundTransparency=1; nl.Text=t.n; nl.TextColor3=C.Muted
    nl.TextSize=10; nl.Font=Enum.Font.GothamSemibold
    nl.TextXAlignment=Enum.TextXAlignment.Left; nl.ZIndex=13; nl.Parent=b
    tabBtns[t.n]={b=b,il=il,nl=nl}
    mkPage(t.n)
end

local function showTab(name)
    S.ActiveTab=name; tabLabel.Text="CURRENT TAB:  "..name
    for n,p in pairs(pages) do p.Visible=n==name end
    for n,d in pairs(tabBtns) do
        local a=n==name
        d.b.BackgroundColor3=a and C.Acc or C.Panel2
        d.il.TextColor3=a and C.Black or C.Muted
        d.nl.TextColor3=a and C.Black or C.Muted
    end
end
for _,t in ipairs(TABS) do
    tabBtns[t.n].b.Activated:Connect(function() showTab(t.n) end)
end

-- Card builder
local function mkCard(parent,title)
    local card=Instance.new("Frame")
    card.BackgroundColor3=C.Panel; card.ZIndex=13; card.Parent=parent; cr(card,7); st(card,C.Border,1)
    local tbar=Instance.new("Frame")
    tbar.Size=UDim2.new(1,0,0,24); tbar.BackgroundColor3=C.Panel2; tbar.ZIndex=14; tbar.Parent=card; cr(tbar,7)
    local dot=Instance.new("Frame")
    dot.Size=UDim2.fromOffset(5,5); dot.Position=UDim2.fromOffset(8,9.5)
    dot.BackgroundColor3=C.Acc; dot.ZIndex=15; dot.Parent=tbar; cr(dot,5)
    local ttxt=Instance.new("TextLabel")
    ttxt.Size=UDim2.new(1,-20,1,0); ttxt.Position=UDim2.fromOffset(18,0)
    ttxt.BackgroundTransparency=1; ttxt.Text=title; ttxt.TextColor3=C.Acc
    ttxt.TextSize=8; ttxt.Font=Enum.Font.GothamBold
    ttxt.TextXAlignment=Enum.TextXAlignment.Left; ttxt.ZIndex=15; ttxt.Parent=tbar
    local body2=Instance.new("Frame")
    body2.Size=UDim2.new(1,-8,1,-30); body2.Position=UDim2.fromOffset(4,26)
    body2.BackgroundTransparency=1; body2.ZIndex=14; body2.Parent=card
    local ll=Instance.new("UIListLayout"); ll.Padding=UDim.new(0,4); ll.Parent=body2
    return card,body2
end

local function mkToggle(parent,label,desc,key)
    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,38); row.BackgroundTransparency=1; row.ZIndex=15; row.Parent=parent
    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-50,0,16); lbl.BackgroundTransparency=1; lbl.Text=label
    lbl.TextColor3=C.Txt; lbl.TextSize=10; lbl.Font=Enum.Font.GothamSemibold
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=16; lbl.Parent=row
    if desc~="" then
        local sl=Instance.new("TextLabel")
        sl.Size=UDim2.new(1,-50,0,13); sl.Position=UDim2.fromOffset(0,17)
        sl.BackgroundTransparency=1; sl.Text=desc; sl.TextColor3=C.Muted
        sl.TextSize=8; sl.Font=Enum.Font.Gotham
        sl.TextXAlignment=Enum.TextXAlignment.Left; sl.ZIndex=16; sl.Parent=row
    end
    local pill=Instance.new("TextButton")
    pill.Size=UDim2.fromOffset(42,22); pill.Position=UDim2.new(1,-44,0,8)
    pill.BackgroundColor3=S[key] and C.ON or C.OFF; pill.Text=""; pill.ZIndex=16; pill.Parent=row; cr(pill,11)
    local dot2=Instance.new("Frame")
    dot2.Size=UDim2.fromOffset(16,16); dot2.Position=S[key] and UDim2.fromOffset(23,3) or UDim2.fromOffset(3,3)
    dot2.BackgroundColor3=C.White; dot2.ZIndex=17; dot2.Parent=pill; cr(dot2,16)
    pill.Activated:Connect(function()
        S[key]=not S[key]
        pill.BackgroundColor3=S[key] and C.ON or C.OFF
        dot2.Position=S[key] and UDim2.fromOffset(23,3) or UDim2.fromOffset(3,3)
    end)
end

local function mkSlider(parent,label,key,mn,mx,step)
    local hold=Instance.new("Frame")
    hold.Size=UDim2.new(1,0,0,34); hold.BackgroundTransparency=1; hold.ZIndex=15; hold.Parent=parent
    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,0,0,14); lbl.BackgroundTransparency=1
    lbl.Text=label.."  "..tostring(S[key]); lbl.TextColor3=C.Txt; lbl.TextSize=9
    lbl.Font=Enum.Font.Gotham; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=16; lbl.Parent=hold
    local track=Instance.new("Frame")
    track.Size=UDim2.new(1,0,0,5); track.Position=UDim2.fromOffset(0,18)
    track.BackgroundColor3=C.OFF; track.ZIndex=16; track.Parent=hold; cr(track,5)
    local fill=Instance.new("Frame")
    fill.BackgroundColor3=C.Acc; fill.ZIndex=17; fill.Parent=track; cr(fill,5)
    local knob=Instance.new("Frame")
    knob.Size=UDim2.fromOffset(11,11); knob.AnchorPoint=Vector2.new(0.5,0.5)
    knob.BackgroundColor3=C.Acc; knob.ZIndex=18; knob.Parent=track; cr(knob,11)
    local q0=math.clamp((S[key]-mn)/(mx-mn),0,1)
    fill.Size=UDim2.new(q0,0,1,0); knob.Position=UDim2.new(q0,0,0.5,0)
    local drag=false
    local function upd(x)
        local q=math.clamp((x-track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1),0,1)
        local v=math.floor((mn+(mx-mn)*q)/step+0.5)*step
        S[key]=v; fill.Size=UDim2.new(q,0,1,0); knob.Position=UDim2.new(q,0,0.5,0)
        lbl.Text=label.."  "..tostring(v)
    end
    track.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            drag=true; upd(i.Position.X) end end)
    UIS.InputChanged:Connect(function(i)
        if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            upd(i.Position.X) end end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            drag=false end end)
end

local function mkCycle(parent,label,key,vals)
    local idx=1
    for i,v in ipairs(vals) do if v==S[key] then idx=i end end
    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,0,0,26); row.BackgroundTransparency=1; row.ZIndex=15; row.Parent=parent
    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-86,1,0); lbl.BackgroundTransparency=1; lbl.Text=label
    lbl.TextColor3=C.Txt; lbl.TextSize=9; lbl.Font=Enum.Font.Gotham
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=16; lbl.Parent=row
    local vb=Instance.new("TextButton")
    vb.Size=UDim2.fromOffset(78,20); vb.Position=UDim2.new(1,-80,0.5,-10)
    vb.BackgroundColor3=C.Acc; vb.Text=tostring(S[key]); vb.TextColor3=C.Black
    vb.TextSize=8; vb.Font=Enum.Font.GothamBold; vb.ZIndex=16; vb.Parent=row; cr(vb,5)
    vb.Activated:Connect(function()
        idx=idx%#vals+1; S[key]=vals[idx]; vb.Text=tostring(S[key])
    end)
end

-- Combat page
local cp=pages["COMBAT"]
local c1,c1b=mkCard(cp,"AIMBOT CONFIGURATION")
mkToggle(c1b,"Enabled","Automatically aims onto enemies","AimEnabled")
mkToggle(c1b,"Silent Aim","Bypasses aim without aiming","SilentAim")
mkToggle(c1b,"Check Visibility","Only aim visible players","CheckVis")
mkSlider(c1b,"Aimbot FOV","AimFOV",10,360,5)
mkSlider(c1b,"Smoothing","AimSmooth",1,50,1)
local c2,c2b=mkCard(cp,"TRIGGER BOT")
mkToggle(c2b,"Trigger Enabled","Auto shoots when in crosshair","TriggerEnabled")
mkSlider(c2b,"Trigger Delay","TriggerDelay",0.01,0.5,0.01)
local c3,c3b=mkCard(cp,"TARGET FILTERS")
mkToggle(c3b,"Team Check","Skip teammates","TeamCheck")
mkCycle(c3b,"Aim Part","AimPart",{"Head","Torso","Root"})
local c4,c4b=mkCard(cp,"COMBAT INFO")
local infoTgt=Instance.new("TextLabel")
infoTgt.Size=UDim2.new(1,0,0,14); infoTgt.BackgroundTransparency=1
infoTgt.Text="Target:  none"; infoTgt.TextColor3=C.Muted; infoTgt.TextSize=9
infoTgt.Font=Enum.Font.Gotham; infoTgt.TextXAlignment=Enum.TextXAlignment.Left
infoTgt.ZIndex=16; infoTgt.Parent=c4b
local infoDst=Instance.new("TextLabel")
infoDst.Size=UDim2.new(1,0,0,14); infoDst.BackgroundTransparency=1
infoDst.Text="Distance:  —"; infoDst.TextColor3=C.Muted; infoDst.TextSize=9
infoDst.Font=Enum.Font.Gotham; infoDst.TextXAlignment=Enum.TextXAlignment.Left
infoDst.ZIndex=16; infoDst.Parent=c4b

-- Visuals page
local vp=pages["VISUALS"]
local v1,v1b=mkCard(vp,"PLAYER ESP")
mkToggle(v1b,"ESP","Show enemy ESP","ESPEnabled")
mkToggle(v1b,"Boxes","Bounding box highlight","ESPBoxes")
mkToggle(v1b,"Health Bar","Show HP bar","ESPHealth")
mkToggle(v1b,"Names","Show player names","ESPNames")
mkSlider(v1b,"ESP Distance","ESPDist",50,3000,50)
local v2,v2b=mkCard(vp,"CHAMS")
mkToggle(v2b,"Chams","Enemies visible through walls","ChamsEnabled")
mkToggle(v2b,"Rainbow","Animated rainbow color","ChamsRainbow")
local v3,v3b=mkCard(vp,"FOV CIRCLE")
mkToggle(v3b,"Show FOV","Display aim FOV ring","FOVVisible")
mkSlider(v3b,"FOV Size","AimFOV",10,360,5)

-- Hitbox page
local hp2=pages["HITBOX"]
local h1,h1b=mkCard(hp2,"HITBOX CONFIG")
mkToggle(h1b,"Hitbox","Expand hitboxes","HitboxEnabled")
mkToggle(h1b,"Show Hitboxes","Visible hitbox expansion","HitboxVisible")
mkSlider(h1b,"Width","HitboxW",2,20,1)
mkSlider(h1b,"Height","HitboxH",2,20,1)

-- Misc page
local mp=pages["MISC"]
local m1,m1b=mkCard(mp,"WEAPON MODS")
mkToggle(m1b,"Ammo Mod","Infinite ammo (local)","AmmoMod")
mkToggle(m1b,"Recoil Mod","Remove recoil & spread","RecoilMod")

-- Settings page
local sp2=pages["SETTINGS"]
local s1,s1b=mkCard(sp2,"OPTIMIZER")
mkToggle(s1b,"Optimizer","Reduce render frequency","Optimizer")
local s2,s2b=mkCard(sp2,"GENERAL")
mkToggle(s2b,"Team Check","Global team filter","TeamCheck")

-- Drag
local function drag(frame,handle)
    local d=false; local off
    handle.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            d=true; off=Vector2.new(i.Position.X-frame.AbsolutePosition.X,i.Position.Y-frame.AbsolutePosition.Y)
        end end)
    UIS.InputChanged:Connect(function(i)
        if d and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            frame.Position=UDim2.fromOffset(i.Position.X-off.X,i.Position.Y-off.Y) end end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            d=false end end)
end
drag(main,top); drag(orb,orb)

orb.Activated:Connect(function() S.MenuOpen=not S.MenuOpen; main.Visible=S.MenuOpen end)
minB.Activated:Connect(function() S.MenuOpen=false; main.Visible=false end)
closeB.Activated:Connect(function() popup.Visible=true end)
popNo.Activated:Connect(function() popup.Visible=false end)
popYes.Activated:Connect(function()
    S.AimEnabled=false; S.ESPEnabled=false; S.ChamsEnabled=false
    S.HitboxEnabled=false; S.AmmoMod=false; S.RecoilMod=false; S.TriggerEnabled=false
    restoreHB(); clearESP(); clearChams(); gui:Destroy()
end)

showTab("COMBAT")

-- Main loop
local T={esp=0,chams=0,hb=0,misc=0,fps=0,info=0}
local fc=0

RunService.RenderStepped:Connect(function(dt)
    if not gui.Parent then return end
    fc=fc+1; T.fps=T.fps+dt
    if T.fps>=1 then
        fpsL.Text="FPS"; fpsL2.Text=tostring(math.floor(fc/T.fps))
        pcall(function()
            local ping=math.floor(LocalPlayer:GetNetworkPing()*1000)
            pingL.Text="PING"; pingL2.Text=ping.."ms"
        end)
        fc=0; T.fps=0
    end

    rwHue=(rwHue+dt*0.25)%1

    local vp2=Camera.ViewportSize
    fovF.Position=UDim2.fromOffset(vp2.X/2,vp2.Y/2)
    fovF.Size=UDim2.fromOffset(S.AimFOV*2,S.AimFOV*2)
    cr(fovF,S.AimFOV)
    fovF.Visible=S.FOVVisible and S.AimEnabled

    if S.AimEnabled then
        local t=getBest(); if t then doAim(t) end
    else locked=nil end

    trigCheck()

    local rate=S.Optimizer and 0.12 or 0.05
    T.esp=T.esp+dt
    if T.esp>=rate then T.esp=0; renderESP() end

    T.chams=T.chams+dt
    if T.chams>=(S.Optimizer and 0.18 or 0.08) then
        T.chams=0
        if S.ChamsEnabled then
            if S.ChamsRainbow then
                local col=Color3.fromHSV(rwHue,1,1)
                for _,h in ipairs(chamsHL) do h.FillColor=col; h.OutlineColor=col end
            end
            renderChams()
        else clearChams() end
    end

    T.hb=T.hb+dt
    if T.hb>=(S.Optimizer and 0.15 or 0.07) then
        T.hb=0
        if S.HitboxEnabled then
            for _,p in ipairs(Players:GetPlayers()) do applyHB(p) end
        else restoreHB() end
    end

    T.misc=T.misc+dt
    if T.misc>=0.25 then T.misc=0; ammoMod(); recoilMod() end

    T.info=T.info+dt
    if T.info>=0.2 then
        T.info=0
        if locked and locked.Parent then
            local r=getRoot(locked)
            local d=r and math.floor((r.Position-Camera.CFrame.Position).Magnitude) or 0
            infoTgt.Text="Target:  "..locked.Name
            infoDst.Text="Distance:  "..d.." st"
        else
            infoTgt.Text="Target:  none"; infoDst.Text="Distance:  —"
        end
    end
end)

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.2)
        if S.ESPEnabled then buildESP(p) end
    end)
end)
Players.PlayerRemoving:Connect(function(p)
    if espHL[p] then pcall(function() espHL[p]:Destroy() end); espHL[p]=nil end
    if espBB[p] then pcall(function() espBB[p]:Destroy() end); espBB[p]=nil end
    if locked==p then locked=nil end
end)
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.3); Camera=workspace.CurrentCamera; locked=nil; restoreHB()
end)
