-- Booga Booga Mobile FPS Booster v2 (Delta / Android)
-- Каждый переключатель реально меняет настройки и показывает в статусе,
-- сколько объектов/настроек изменено и сколько заблокировано executor'ом.
-- Всё обратимо: выключение возвращает оригинальные значения.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local UIS = game:GetService("UserInputService")
local Stats = game:GetService("Stats")

local player = Players.LocalPlayer
if not player then
    warn("[FPS Booster] LocalPlayer unavailable")
    return
end

local function getParent()
    if typeof(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok and result then return result end
    end
    local ok, result = pcall(function() return player:WaitForChild("PlayerGui", 5) end)
    if ok and result then return result end
    return CoreGui
end

local uiParent = getParent()
local old = uiParent:FindFirstChild("BoogaFPSBooster")
if old then old:Destroy() end

------------------------------------------------------------------
-- Ядро
------------------------------------------------------------------
local WEAK = {__mode = "k"}
local function weak() return setmetatable({}, WEAK) end

local features, order, connections = {}, {}, {}
local alive = true
local nApply = 0            -- сколько активных функций обрабатывают объекты
local jobs = {}             -- фоновые проходы по существующим объектам
local newQ, qi, qTail = {}, 1, 0   -- очередь только что загруженных объектов
local statusLabel, refreshMaster

local function setStatus(t)
    if statusLabel then statusLabel.Text = t end
end

local function E(name, item)
    local ok, v = pcall(function() return Enum[name][item] end)
    return ok and v or nil
end

-- сохранить оригинал свойства объекта и записать новое значение
local function set(f, obj, prop, val)
    local s = f.saved[obj]
    if not s then s = {}; f.saved[obj] = s; f.count += 1 end
    if s[prop] == nil then s[prop] = obj[prop] end
    obj[prop] = val
end

-- глобальная настройка (Lighting, settings(), Terrain...) с проверкой результата
local function gset(f, target, prop, val)
    if val == nil then f.fail += 1 return end
    local ok, prev = pcall(function() return target[prop] end)
    if ok and pcall(function() target[prop] = val end) then
        f.globals[#f.globals + 1] = {target, prop, prev, false}
        local _, same = pcall(function() return target[prop] == val end)
        if same then f.okc += 1 else f.fail += 1 end
    else
        f.fail += 1
    end
end

-- скрытое свойство (нужна поддержка executor'а)
local function hset(f, target, prop, val)
    if val == nil or typeof(sethiddenproperty) ~= "function"
        or typeof(gethiddenproperty) ~= "function" then
        f.fail += 1
        return
    end
    local ok, prev = pcall(gethiddenproperty, target, prop)
    if ok and pcall(sethiddenproperty, target, prop, val) then
        f.globals[#f.globals + 1] = {target, prop, prev, true}
        f.okc += 1
    else
        f.fail += 1
    end
end

local function inCharacter(obj)
    local m = obj:FindFirstAncestorOfClass("Model")
    return m ~= nil and m:FindFirstChildOfClass("Humanoid") ~= nil
end

local function isPost(o)
    return o:IsA("BloomEffect") or o:IsA("BlurEffect") or o:IsA("SunRaysEffect")
        or o:IsA("DepthOfFieldEffect") or o:IsA("ColorCorrectionEffect")
end

local function isEmitter(o)
    return o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Beam")
        or o:IsA("Fire") or o:IsA("Smoke") or o:IsA("Sparkles")
end

local function newFeature(key, title, desc, def)
    def.key, def.title, def.desc = key, title, desc
    def.active, def.gen = false, 0
    def.saved, def.globals = weak(), {}
    def.okc, def.fail, def.count, def.nextTick = 0, 0, 0, 0
    features[key] = def
    order[#order + 1] = def
    return def
end

local function summary(f)
    local p = {}
    if f.count > 0 then p[#p + 1] = f.count .. " объектов" end
    if f.okc > 0 then p[#p + 1] = f.okc .. " настроек" end
    if f.fail > 0 then p[#p + 1] = f.fail .. " заблокировано" end
    if f.note then p[#p + 1] = f.note end
    return f.title .. ": " .. (#p > 0 and table.concat(p, ", ") or "менять нечего")
end

local function restore(f)
    for i = #f.globals, 1, -1 do
        local g = f.globals[i]
        pcall(function()
            if g[4] then sethiddenproperty(g[1], g[2], g[3]) else g[1][g[2]] = g[3] end
        end)
    end
    f.globals = {}
    local saved = f.saved
    f.saved = weak()
    for obj, props in pairs(saved) do
        for prop, v in pairs(props) do
            pcall(function() obj[prop] = v end)
        end
    end
end

local function collectAll()
    local list = Workspace:GetDescendants()
    for _, o in ipairs(Lighting:GetDescendants()) do list[#list + 1] = o end
    return list
end

local function setFeature(f, on)
    if f.active == on then return end
    f.active = on
    f.gen += 1
    if f.apply then nApply += on and 1 or -1 end
    if on then
        f.saved, f.globals = weak(), {}
        f.okc, f.fail, f.count, f.note, f.nextTick = 0, 0, 0, nil, 0
        if f.on then pcall(f.on, f) end
        if f.apply then
            jobs[#jobs + 1] = {f = f, gen = f.gen, i = 1, list = collectAll()}
            setStatus(f.title .. ": применяю...")
        else
            setStatus(summary(f))
        end
    else
        if f.off then pcall(f.off, f) end
        restore(f)
        setStatus(f.title .. ": восстановлено")
    end
    if f.refresh then f.refresh() end
    if refreshMaster then refreshMaster() end
end

------------------------------------------------------------------
-- Функции
------------------------------------------------------------------

-- 1. Тени
newFeature("shadows", "Тени", "GlobalShadows + тени у каждой детали и света", {
    on = function(f)
        gset(f, Lighting, "GlobalShadows", false)
        gset(f, Lighting, "ShadowSoftness", 0)
    end,
    apply = function(f, obj)
        if obj:IsA("BasePart") then
            if obj.CastShadow then set(f, obj, "CastShadow", false) end
        elseif obj:IsA("Light") and obj.Shadows then
            set(f, obj, "Shadows", false)
        end
    end,
})

-- 2. Постэффекты
newFeature("post", "Постэффекты", "Bloom, Blur, SunRays, DoF, ColorCorrection", {
    apply = function(f, obj)
        if isPost(obj) and obj.Enabled then set(f, obj, "Enabled", false) end
    end,
})

-- 3. Частицы
newFeature("particles", "Частицы", "Эмиттеры, трейлы, лучи, огонь, дым, взрывы", {
    apply = function(f, obj)
        if isEmitter(obj) then
            if obj.Enabled then set(f, obj, "Enabled", false) end
        elseif obj:IsA("Explosion") then
            set(f, obj, "Visible", false)
        end
    end,
})

-- 4. Текстуры / декали (лица персонажей не трогаем)
newFeature("textures", "Декали", "Скрыть Decal/Texture на карте", {
    apply = function(f, obj)
        if obj:IsA("Decal") and obj.Transparency < 1 and not inCharacter(obj) then
            set(f, obj, "Transparency", 1)
        end
    end,
})

-- 5. Туман / атмосфера
newFeature("fog", "Туман / небо", "Atmosphere, Clouds, FogEnd", {
    on = function(f) gset(f, Lighting, "FogEnd", 1000000) end,
    apply = function(f, obj)
        if obj:IsA("Atmosphere") then
            set(f, obj, "Density", 0)
            set(f, obj, "Haze", 0)
            set(f, obj, "Glare", 0)
        elseif obj:IsA("Clouds") and obj.Enabled then
            set(f, obj, "Enabled", false)
        end
    end,
})

-- 6. Нагрузка на CPU
local animators, farSet, frozen = weak(), weak(), weak()

local function tracksOf(an)
    local ok, t = pcall(an.GetPlayingAnimationTracks, an)
    return ok and t or {}
end
local function freezeAnim(an)
    for _, t in ipairs(tracksOf(an)) do
        if frozen[t] == nil then
            frozen[t] = t.Speed
            pcall(t.AdjustSpeed, t, 0)
        end
    end
end
local function unfreezeAnim(an)
    for _, t in ipairs(tracksOf(an)) do
        local sp = frozen[t]
        if sp ~= nil then
            frozen[t] = nil
            pcall(t.AdjustSpeed, t, sp)
        end
    end
end

newFeature("cpu", "CPU", "Физика-throttle + заморозка анимаций дальше 150 studs", {
    interval = 0.5,
    on = function(f)
        local ph = settings().Physics
        gset(f, ph, "PhysicsEnvironmentalThrottle", E("EnvironmentalPhysicsThrottle", "Always"))
        gset(f, ph, "AllowSleep", true)
        gset(f, Workspace, "InterpolationThrottling", E("InterpolationThrottlingMode", "Enabled"))
    end,
    apply = function(f, obj)
        if obj:IsA("Animator") then
            animators[obj] = true
            f.count += 1
        end
    end,
    tick = function(f)
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local cpos, mine = cam.CFrame.Position, player.Character
        for an in pairs(animators) do
            if not an.Parent then
                animators[an] = nil
            elseif not (mine and an:IsDescendantOf(mine)) then
                local m = an:FindFirstAncestorOfClass("Model")
                local root = m and (m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart)
                if root then
                    if (root.Position - cpos).Magnitude > 150 then
                        farSet[an] = true
                        freezeAnim(an)
                    elseif farSet[an] then
                        farSet[an] = nil
                        unfreezeAnim(an)
                    end
                end
            end
        end
    end,
    off = function()
        for an in pairs(animators) do unfreezeAnim(an) end
        farSet = weak()
    end,
})

-- 7. Прямая оптимизация GPU
newFeature("gpu", "GPU", "Quality Level 1, меш-детали, отражения, вода, Compatibility", {
    on = function(f)
        local r = settings().Rendering
        gset(f, r, "QualityLevel", E("QualityLevel", "Level01"))
        gset(f, r, "MeshPartDetailLevel", E("MeshPartDetailLevel", "Level04"))
        gset(f, Lighting, "EnvironmentDiffuseScale", 0)
        gset(f, Lighting, "EnvironmentSpecularScale", 0)
        hset(f, Lighting, "Technology", E("Technology", "Compatibility"))
        local t = Workspace.Terrain
        gset(f, t, "WaterWaveSize", 0)
        gset(f, t, "WaterWaveSpeed", 0)
        gset(f, t, "WaterReflectance", 0)
        hset(f, t, "Decoration", false)
    end,
    apply = function(f, obj)
        if obj:IsA("BasePart") then
            if obj.Reflectance > 0 then set(f, obj, "Reflectance", 0) end
        elseif obj:IsA("Highlight") and obj.Enabled then
            set(f, obj, "Enabled", false)
        end
    end,
})

-- 8. Управление памятью
local function collect()
    local ok1, before = pcall(collectgarbage, "count")
    local ok2 = pcall(collectgarbage, "collect")
    local ok3, after = pcall(collectgarbage, "count")
    return ok1 and ok2 and ok3, before, after
end

-- Выгрузка текстур далёких объектов: реально освобождает память движка.
-- Дальше 250 studs ссылки на текстуры обнуляются, ближе 180 возвращаются.
local texList, texCursor = {}, 1
local texState = weak()
local texUnloaded = 0
local TEX_PROPS = {
    Decal = {"Texture"},
    MeshPart = {"TextureID"},
    SurfaceAppearance = {"ColorMap", "NormalMap", "MetalnessMap", "RoughnessMap"},
}
local function texClass(o)
    if o:IsA("Decal") then return "Decal" end
    if o:IsA("MeshPart") then return "MeshPart" end
    if o:IsA("SurfaceAppearance") then return "SurfaceAppearance" end
end
local function texAnchor(o)
    if o:IsA("BasePart") then return o end
    local p = o.Parent
    return p and p:IsA("BasePart") and p or nil
end
local function setTex(o, unload)
    local st = texState[o]
    if not st or st.far == unload then return end
    st.far = unload
    texUnloaded += unload and 1 or -1
    for _, prop in ipairs(st.props) do
        pcall(function() o[prop] = unload and "" or st.orig[prop] end)
    end
end

newFeature("memory", "Память", "GC + выгрузка текстур далёких объектов", {
    interval = 2,
    on = function(f)
        f.gcAt = os.clock() + 20
        local ok, b, a = collect()
        if ok then
            f.okc += 1
            f.note = ("GC освободил %.1f MB"):format((b - a) / 1024)
        else
            f.fail += 1
            f.note = "GC закрыт executor'ом"
        end
    end,
    apply = function(f, obj)
        local cls = texClass(obj)
        if cls and not texState[obj] and not inCharacter(obj) then
            local orig, any = {}, false
            for _, p in ipairs(TEX_PROPS[cls]) do
                local v = obj[p]
                orig[p] = v
                if v ~= "" then any = true end
            end
            if any then
                texState[obj] = {props = TEX_PROPS[cls], orig = orig, far = false}
                texList[#texList + 1] = obj
                f.count += 1
            end
        end
    end,
    tick = function(f)
        local now = os.clock()
        if now >= (f.gcAt or 0) then
            f.gcAt = now + 20
            collect()
        end
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local cpos = cam.CFrame.Position
        for _ = 1, math.min(#texList, 300) do
            if texCursor > #texList then texCursor = 1 end
            local o = texList[texCursor]
            if not o then break end
            if not o.Parent then
                texState[o] = nil
                texList[texCursor] = texList[#texList]
                texList[#texList] = nil
            else
                local a = texAnchor(o)
                if a then
                    local d = (a.Position - cpos).Magnitude
                    if d > 250 then setTex(o, true) elseif d < 180 then setTex(o, false) end
                end
                texCursor += 1
            end
        end
    end,
    off = function()
        for _, o in ipairs(texList) do setTex(o, false) end
        texList, texCursor, texState, texUnloaded = {}, 1, weak(), 0
    end,
})

-- 9. Загрузка чанков
newFeature("chunks", "Чанки", "Подгрузка по частям + предзагрузка по ходу движения", {
    interval = 0.75,
    on = function(f)
        if Workspace.StreamingEnabled then
            f.okc += 1
        else
            f.note = "StreamingEnabled выкл. в игре: работает только раздача нагрузки"
        end
    end,
    tick = function(f)
        if not Workspace.StreamingEnabled or f.busy then return end
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local v = root.AssemblyLinearVelocity
        local target = root.Position + Vector3.new(v.X, 0, v.Z) * 1.5
        if f.last and (target - f.last).Magnitude < 35 then return end
        f.last = target
        f.busy = true
        task.spawn(function()
            pcall(function() player:RequestStreamAroundAsync(target, 0.4) end)
            f.busy = false
        end)
    end,
    off = function(f) f.last, f.busy = nil, false end,
})

-- 10. Рендерер: упрощённая геометрия и материалы
local PERF = E("RenderFidelity", "Performance")
local SMOOTH = E("Material", "SmoothPlastic")
newFeature("renderer", "Рендерер", "RenderFidelity=Performance + плоские материалы", {
    apply = function(f, obj)
        if obj:IsA("BasePart") and not obj:IsA("Terrain") then
            if PERF and obj:IsA("TriangleMeshPart") and obj.RenderFidelity ~= PERF then
                set(f, obj, "RenderFidelity", PERF)
            end
            if SMOOTH and obj.Material ~= SMOOTH
                and obj.Material ~= Enum.Material.Neon
                and obj.Material ~= Enum.Material.ForceField then
                set(f, obj, "Material", SMOOTH)
            end
        end
    end,
})

------------------------------------------------------------------
-- Главный цикл: новые объекты порциями + проходы по существующим + FPS
------------------------------------------------------------------
local function onAdded(obj)
    if nApply > 0 then
        qTail += 1
        newQ[qTail] = obj
    end
end
connections[#connections + 1] = Workspace.DescendantAdded:Connect(onAdded)
connections[#connections + 1] = Lighting.DescendantAdded:Connect(onAdded)

local hudLabel
local fpsAcc, fpsN, nextHud = 0, 0, 0

connections[#connections + 1] = RunService.Heartbeat:Connect(function(dt)
    local t0 = os.clock()

    -- новые объекты (при активных "Чанках" бюджет меньше, чтобы не было лагов)
    local budget = features.chunks.active and 0.0012 or 0.004
    while qi <= qTail and os.clock() - t0 < budget do
        local obj = newQ[qi]
        newQ[qi] = nil
        qi += 1
        if obj.Parent then
            for _, f in ipairs(order) do
                if f.active and f.apply then pcall(f.apply, f, obj) end
            end
        end
    end
    if qi > qTail then qi, qTail = 1, 0 end

    -- проходы по уже существующим объектам
    local t1 = os.clock()
    while jobs[1] and os.clock() - t1 < 0.004 do
        local j = jobs[1]
        if j.gen ~= j.f.gen or not j.f.active then
            table.remove(jobs, 1)
        else
            local last = math.min(j.i + 99, #j.list)
            for i = j.i, last do
                local o = j.list[i]
                if o.Parent then pcall(j.f.apply, j.f, o) end
            end
            j.i = last + 1
            if j.i > #j.list then
                table.remove(jobs, 1)
                setStatus(summary(j.f))
            end
        end
    end

    -- FPS / память
    fpsAcc += dt
    fpsN += 1
    if t0 >= nextHud and hudLabel then
        nextHud = t0 + 0.5
        hudLabel.Text = ("FPS %.0f  |  %.0f MB"):format(fpsN / fpsAcc, Stats:GetTotalMemoryUsageMb())
            .. (texUnloaded > 0 and ("  |  выгружено: " .. texUnloaded) or "")
        fpsAcc, fpsN = 0, 0
    end
end)

-- периодические задачи функций
task.spawn(function()
    while alive do
        local now = os.clock()
        for _, f in ipairs(order) do
            if f.active and f.tick and now >= f.nextTick then
                f.nextTick = now + (f.interval or 1)
                pcall(f.tick, f)
            end
        end
        task.wait(0.25)
    end
end)

------------------------------------------------------------------
-- Мобильный HUD
------------------------------------------------------------------
local palette = {
    bg = Color3.fromRGB(20, 24, 32),
    row = Color3.fromRGB(38, 44, 56),
    text = Color3.fromRGB(245, 247, 250),
    muted = Color3.fromRGB(165, 175, 190),
    accent = Color3.fromRGB(75, 165, 255),
    off = Color3.fromRGB(69, 77, 91),
}

local function make(className, props, parent)
    local obj = Instance.new(className)
    for k, v in pairs(props) do obj[k] = v end
    obj.Parent = parent
    return obj
end

local gui = make("ScreenGui", {
    Name = "BoogaFPSBooster",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999999,
}, uiParent)

local open = make("TextButton", {
    Size = UDim2.fromOffset(46, 46),
    Position = UDim2.new(1, -58, 0.54, -23),
    BackgroundColor3 = palette.bg,
    Text = "FPS",
    TextColor3 = palette.text,
    TextSize = 13,
    Font = Enum.Font.GothamBold,
}, gui)
make("UICorner", {CornerRadius = UDim.new(1, 0)}, open)
make("UIStroke", {Color = palette.accent, Thickness = 1.5}, open)

local panel = make("Frame", {
    AnchorPoint = Vector2.new(1, 0.5),
    Size = UDim2.new(0, 270, 0.92, 0),
    Position = UDim2.new(1, -66, 0.5, 0),
    BackgroundColor3 = palette.bg,
    BorderSizePixel = 0,
    Visible = false,
}, gui)
make("UICorner", {CornerRadius = UDim.new(0, 12)}, panel)
make("UIStroke", {Color = Color3.fromRGB(58, 68, 86), Thickness = 1}, panel)

make("TextLabel", {
    Size = UDim2.new(1, -48, 0, 28),
    Position = UDim2.fromOffset(12, 6),
    BackgroundTransparency = 1,
    Text = "MOBILE FPS BOOST",
    TextColor3 = palette.text,
    TextSize = 13,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamBold,
}, panel)

local close = make("TextButton", {
    Size = UDim2.fromOffset(28, 28),
    Position = UDim2.new(1, -36, 0, 6),
    BackgroundColor3 = palette.row,
    Text = "×",
    TextColor3 = palette.text,
    TextSize = 19,
}, panel)
make("UICorner", {CornerRadius = UDim.new(0, 7)}, close)

hudLabel = make("TextLabel", {
    Size = UDim2.new(1, -24, 0, 16),
    Position = UDim2.fromOffset(12, 34),
    BackgroundTransparency = 1,
    Text = "FPS --",
    TextColor3 = palette.accent,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamBold,
}, panel)

statusLabel = make("TextLabel", {
    Size = UDim2.new(1, -24, 0, 28),
    Position = UDim2.fromOffset(12, 51),
    BackgroundTransparency = 1,
    Text = "Всё выключено",
    TextColor3 = palette.muted,
    TextSize = 10,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    Font = Enum.Font.Gotham,
}, panel)

local scroll = make("ScrollingFrame", {
    Size = UDim2.new(1, -12, 1, -86),
    Position = UDim2.fromOffset(6, 80),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    CanvasSize = UDim2.fromOffset(0, 400),
}, panel)
local layout = make("UIListLayout", {
    Padding = UDim.new(0, 6),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, scroll)
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scroll.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 6)
end)

local function addRow(title, desc, order_, isOn, onToggle)
    local row = make("Frame", {
        Size = UDim2.new(1, -8, 0, 48),
        BackgroundColor3 = palette.row,
        BorderSizePixel = 0,
        LayoutOrder = order_,
    }, scroll)
    make("UICorner", {CornerRadius = UDim.new(0, 8)}, row)
    make("TextLabel", {
        Size = UDim2.new(1, -78, 0, 20),
        Position = UDim2.fromOffset(9, 4),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = palette.text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.GothamSemibold,
    }, row)
    make("TextLabel", {
        Size = UDim2.new(1, -78, 0, 16),
        Position = UDim2.fromOffset(9, 25),
        BackgroundTransparency = 1,
        Text = desc,
        TextColor3 = palette.muted,
        TextSize = 9,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Font = Enum.Font.Gotham,
    }, row)
    local btn = make("TextButton", {
        Size = UDim2.fromOffset(54, 28),
        Position = UDim2.new(1, -62, 0.5, -14),
        BackgroundColor3 = palette.off,
        Text = "OFF",
        TextColor3 = palette.text,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
    }, row)
    make("UICorner", {CornerRadius = UDim.new(0, 7)}, btn)
    btn.Activated:Connect(function() onToggle(not isOn()) end)
    return function()
        local on = isOn()
        btn.Text = on and "ON" or "OFF"
        btn.BackgroundColor3 = on and palette.accent or palette.off
    end
end

local function allActive()
    for _, f in ipairs(order) do
        if not f.active then return false end
    end
    return true
end

local refreshMasterBtn = addRow("Всё сразу", "Включить / выключить все функции", 0, allActive, function(on)
    for _, f in ipairs(order) do setFeature(f, on) end
end)
refreshMaster = function() pcall(refreshMasterBtn) end

for i, f in ipairs(order) do
    f.refresh = addRow(f.title, f.desc, i, function() return f.active end, function(on)
        setFeature(f, on)
    end)
end

-- перетаскиваемая кнопка открытия
local dragging, moved, dragStart, startPos = false, false, nil, nil
open.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging, moved = true, false
        dragStart, startPos = input.Position, open.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
connections[#connections + 1] = UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local d = input.Position - dragStart
        if d.Magnitude > 8 then moved = true end
        if moved then
            open.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end
end)
open.Activated:Connect(function()
    if moved then moved = false return end
    panel.Visible = not panel.Visible
end)
close.Activated:Connect(function() panel.Visible = false end)

------------------------------------------------------------------
-- Полное восстановление при закрытии GUI
------------------------------------------------------------------
gui.Destroying:Connect(function()
    if not alive then return end
    for _, f in ipairs(order) do pcall(setFeature, f, false) end
    alive = false
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
end)

print("[Mobile FPS Booster v2] Loaded. Open the FPS button.")
