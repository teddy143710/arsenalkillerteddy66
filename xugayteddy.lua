-- Booga Booga FPS Booster v5 + CzxstyleUI HUD
-- Delta / Samsung Galaxy A06. Меню: круглая кнопка CZX. Клавиатура не нужна.
-- Каждая функция показывает в уведомлении, что именно изменила,
-- и всё возвращается обратно при выключении или "Выгрузить".

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local UIS = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local TweenService = game:GetService("TweenService")

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
for _, n in ipairs({"CzxBoogaFPS", "BoogaFPSBooster"}) do
    local o = uiParent:FindFirstChild(n)
    if o then o:Destroy() end
end

------------------------------------------------------------------
-- Ядро
------------------------------------------------------------------
local WEAK = {__mode = "k"}
local function weak() return setmetatable({}, WEAK) end

local features, order, connections = {}, {}, {}
local alive = true
local nApply = 0
local jobs = {}
local newQ, qi, qTail = {}, 1, 0
local notify, refreshMaster
local fpsValue = 60

local function setStatus(t)
    if notify then notify(t, true) end
end

local function E(name, item)
    local ok, v = pcall(function() return Enum[name][item] end)
    return ok and v or nil
end

local function set(f, obj, prop, val)
    local s = f.saved[obj]
    if not s then s = {}; f.saved[obj] = s; f.count += 1 end
    if s[prop] == nil then s[prop] = obj[prop] end
    obj[prop] = val
end

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
    if f.classes then
        local c = {}
        for k, v in pairs(f.classes) do c[#c + 1] = k .. "×" .. v end
        if #c > 0 then
            p[#p + 1] = table.concat(c, ", ")
        else
            p[#p + 1] = "такой подсветки пока не найдено"
        end
    end
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
    local pg = player:FindFirstChildOfClass("PlayerGui")
    if pg then
        for _, o in ipairs(pg:GetDescendants()) do list[#list + 1] = o end
    end
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
        else
            setStatus(summary(f))
        end
    else
        if f.off then pcall(f.off, f) end
        restore(f)
    end
    if f.refresh then f.refresh() end
    if refreshMaster then refreshMaster() end
end

------------------------------------------------------------------
-- Профиль Samsung Galaxy A06 (Helio G85, Mali-G52 MC2, 4 GB RAM, 720p)
------------------------------------------------------------------
local CFG = {
    cullHide = 220, cullShow = 190, cullMaxPart = 40,
    animFar = 120,
    texFar = 200, texNear = 150,
    gcEvery = 15,
    fpsCap = 999,
}
local HLCFG = {byName = true}

-- Снять лимит FPS
newFeature("fpscap", "Лимит FPS", "setfpscap + TaskSchedulerTargetFps", {
    on = function(f)
        if typeof(setfpscap) == "function" then
            if pcall(setfpscap, CFG.fpsCap) then f.okc += 1 else f.fail += 1 end
        else
            f.fail += 1
            f.note = "setfpscap нет в Delta"
        end
        if typeof(setfflag) == "function" then
            if pcall(setfflag, "TaskSchedulerTargetFps", tostring(CFG.fpsCap)) then
                f.okc += 1
            else
                f.fail += 1
            end
        end
    end,
    off = function()
        if typeof(setfpscap) == "function" then pcall(setfpscap, 60) end
        if typeof(setfflag) == "function" then pcall(setfflag, "TaskSchedulerTargetFps", "60") end
    end,
})

-- Дальность прорисовки
local cullList, cullCursor, cullSeen, cullHidden = {}, 1, weak(), weak()
local cullN = 0
newFeature("cull", "Дальность", "Не рисовать детали далеко", {
    apply = function(f, obj)
        if obj:IsA("BasePart") and not obj:IsA("Terrain") and not cullSeen[obj] then
            local s = obj.Size
            if math.max(s.X, s.Y, s.Z) <= CFG.cullMaxPart and not inCharacter(obj) then
                cullSeen[obj] = true
                cullList[#cullList + 1] = obj
                f.count += 1
            end
        end
    end,
    tick = function()
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local cpos = cam.CFrame.Position
        for _ = 1, math.min(#cullList, 800) do
            if cullCursor > #cullList then cullCursor = 1 end
            local o = cullList[cullCursor]
            if not o then break end
            if not o.Parent then
                if cullHidden[o] then cullN -= 1 end
                cullHidden[o], cullSeen[o] = nil, nil
                cullList[cullCursor] = cullList[#cullList]
                cullList[#cullList] = nil
            else
                local d = (o.Position - cpos).Magnitude
                if d > CFG.cullHide then
                    if not cullHidden[o] then
                        cullHidden[o] = true
                        cullN += 1
                        pcall(function() o.LocalTransparencyModifier = 1 end)
                    end
                elseif d < CFG.cullShow and cullHidden[o] then
                    cullHidden[o] = nil
                    cullN -= 1
                    pcall(function() o.LocalTransparencyModifier = 0 end)
                end
                cullCursor += 1
            end
        end
    end,
    interval = 0.25,
    off = function()
        for _, o in ipairs(cullList) do
            if cullHidden[o] then pcall(function() o.LocalTransparencyModifier = 0 end) end
        end
        cullList, cullCursor, cullSeen, cullHidden, cullN = {}, 1, weak(), weak(), 0
    end,
})

-- Подсветка предметов (зелёное свечение)
local hlConns = weak()
local function looksLikeHighlight(obj)
    local n = obj.Name:lower()
    return n:find("highlight", 1, true) or n:find("hover", 1, true) or n:find("outline", 1, true)
end
newFeature("highlight", "Подсветка", "Убрать зелёное свечение предметов", {
    on = function(f) f.classes = {} end,
    apply = function(f, obj)
        local prop, label
        if obj:IsA("Highlight") then
            prop = "Enabled"
        elseif obj:IsA("GuiBase3d") then
            prop = "Visible"
        elseif HLCFG.byName and (obj:IsA("BasePart") or obj:IsA("BillboardGui") or obj:IsA("SurfaceGui"))
            and looksLikeHighlight(obj) and obj:IsDescendantOf(Workspace) then
            if obj:IsA("BasePart") then
                if obj.LocalTransparencyModifier < 1 then
                    set(f, obj, "LocalTransparencyModifier", 1)
                    f.classes["по имени"] = (f.classes["по имени"] or 0) + 1
                end
                return
            end
            prop, label = "Enabled", "по имени"
        end
        if not prop then return end
        local key = label or obj.ClassName
        f.classes[key] = (f.classes[key] or 0) + 1
        if obj[prop] then set(f, obj, prop, false) end
        if not hlConns[obj] then
            hlConns[obj] = obj:GetPropertyChangedSignal(prop):Connect(function()
                if f.active and obj[prop] then obj[prop] = false end
            end)
        end
    end,
    off = function()
        for _, c in pairs(hlConns) do pcall(function() c:Disconnect() end) end
        hlConns = weak()
    end,
})

-- Тени
newFeature("shadows", "Тени", "GlobalShadows + тени деталей и света", {
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

-- Постэффекты
newFeature("post", "Постэффекты", "Bloom, Blur, SunRays, DoF, цветокор", {
    apply = function(f, obj)
        if isPost(obj) and obj.Enabled then set(f, obj, "Enabled", false) end
    end,
})

-- Частицы
newFeature("particles", "Частицы", "Эмиттеры, трейлы, огонь, дым, взрывы", {
    apply = function(f, obj)
        if isEmitter(obj) then
            if obj.Enabled then set(f, obj, "Enabled", false) end
        elseif obj:IsA("Explosion") then
            set(f, obj, "Visible", false)
        end
    end,
})

-- Декали
newFeature("textures", "Декали", "Скрыть Decal/Texture на карте", {
    apply = function(f, obj)
        if obj:IsA("Decal") and obj.Transparency < 1 and not inCharacter(obj) then
            set(f, obj, "Transparency", 1)
        end
    end,
})

-- Туман / небо
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

-- CPU
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

newFeature("cpu", "CPU", "Физика-throttle + заморозка далёких анимаций", {
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
    tick = function()
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
                    if (root.Position - cpos).Magnitude > CFG.animFar then
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

-- GPU
newFeature("gpu", "GPU", "Quality 1, меши, отражения, вода", {
    on = function(f)
        local r = settings().Rendering
        local okS, ugs = pcall(function() return UserSettings():GetService("UserGameSettings") end)
        if okS then
            gset(f, ugs, "SavedQualityLevel", E("SavedQualityLevel", "QualityLevel1"))
            gset(f, ugs, "GraphicsQualityLevel", 1)
        end
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

-- Рендерер
local PERF = E("RenderFidelity", "Performance")
local SMOOTH = E("Material", "SmoothPlastic")
newFeature("renderer", "Рендерер", "Простые меши и плоские материалы", {
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

-- Память
local function collect()
    local ok1, before = pcall(collectgarbage, "count")
    local ok2 = pcall(collectgarbage, "collect")
    local ok3, after = pcall(collectgarbage, "count")
    return ok1 and ok2 and ok3, before, after
end

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

newFeature("memory", "Память", "GC + выгрузка далёких текстур", {
    interval = 2,
    on = function(f)
        f.gcAt = os.clock() + CFG.gcEvery
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
            f.gcAt = now + CFG.gcEvery
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
                    if d > CFG.texFar then setTex(o, true) elseif d < CFG.texNear then setTex(o, false) end
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

-- Чанки
newFeature("chunks", "Чанки", "Подгрузка порциями + предзагрузка", {
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
do
    local pg = player:FindFirstChildOfClass("PlayerGui")
    if pg then connections[#connections + 1] = pg.DescendantAdded:Connect(onAdded) end
end

local fpsAcc, fpsN, fpsNext = 0, 0, 0

connections[#connections + 1] = RunService.Heartbeat:Connect(function(dt)
    local t0 = os.clock()

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

    fpsAcc += dt
    fpsN += 1
    if t0 >= fpsNext then
        fpsNext = t0 + 0.5
        fpsValue = fpsN / math.max(fpsAcc, 0.001)
        fpsAcc, fpsN = 0, 0
    end
end)

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
-- Авто-клик (круг) и авто-хил (только когда здоровье падает)
------------------------------------------------------------------
local VIM
do
    local ok, v = pcall(function() return game:GetService("VirtualInputManager") end)
    if ok then VIM = v end
end

local ac = {on = false, mode = VIM and "TOUCH" or "TOOL", cps = 8, show = true}
local hl = {
    on = false, item = "2", weapon = "1", threshold = 1.0,
    lastDmg = 0, lastEat = 0, holding = false,
}
local MODES = {"TOUCH", "MOUSE", "TOOL"}
local TOUCH_ID = 9
local KEYS = {[0] = "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"}

local circle   -- создаётся в интерфейсе
local setAC    -- задаётся в интерфейсе

local function currentHumanoid()
    local c = player.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function doClick()
    local mode = ac.mode
    if mode == "TOOL" or not VIM then
        local c = player.Character
        local tool = c and c:FindFirstChildOfClass("Tool")
        if tool then
            tool:Activate()
            return
        end
        if not VIM then return end
        mode = "TOUCH"   -- нет Tool в руке: касание в круг
    end
    if not circle then return end
    local p = circle.AbsolutePosition + circle.AbsoluteSize / 2
    local x, y = p.X, p.Y
    if mode == "TOUCH" then
        VIM:SendTouchEvent(TOUCH_ID, 0, x, y)
        task.delay(0.02, function() pcall(VIM.SendTouchEvent, VIM, TOUCH_ID, 2, x, y) end)
    else
        VIM:SendMouseButtonEvent(x, y, 0, true, game, 1)
        task.delay(0.02, function() pcall(VIM.SendMouseButtonEvent, VIM, x, y, 0, false, game, 1) end)
    end
end

local acFails = 0
task.spawn(function()
    while alive do
        if ac.on then
            if pcall(doClick) then
                acFails = 0
            else
                acFails += 1
                if acFails >= 3 then
                    acFails = 0
                    if ac.mode ~= "TOOL" then
                        ac.mode = "TOOL"
                        if notify then notify("Режим клика недоступен в Delta, переключил на TOOL", false) end
                    end
                end
            end
            task.wait(1 / ac.cps)
        else
            task.wait(0.15)
        end
    end
end)

-- здоровье: Humanoid, а если в игре своя полоска "здоровье", то она
local hpLabel, hpNextScan = nil, 0
local function findHpLabel()
    local pg = player:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil end
    for _, o in ipairs(pg:GetDescendants()) do
        if o:IsA("TextLabel") then
            local t = o.Text:lower()
            if (t == "здоровье" or t == "health") and o.Parent then
                for _, sib in ipairs(o.Parent:GetChildren()) do
                    if sib ~= o and sib:IsA("TextLabel") and tonumber(sib.Text) then return sib end
                end
            end
        end
    end
    return nil
end

local function readGuiHealth()
    if not (hpLabel and hpLabel.Parent) then
        if os.clock() < hpNextScan then return nil end
        hpNextScan = os.clock() + 3
        hpLabel = findHpLabel()
        if not hpLabel then return nil end
    end
    return tonumber(hpLabel.Text)
end

local function getHealth()
    local hum = currentHumanoid()
    local g = readGuiHealth()
    if g then
        hl.maxSeen = math.max(hl.maxSeen or 0, g, 100)
        return g, hl.maxSeen, hum
    end
    if hum then return hum.Health, hum.MaxHealth, hum end
    return nil
end

local function findTool(name)
    name = name:lower()
    for _, cont in ipairs({player.Character, player:FindFirstChildOfClass("Backpack")}) do
        if cont then
            for _, t in ipairs(cont:GetChildren()) do
                if t:IsA("Tool") and t.Name:lower():find(name, 1, true) then return t end
            end
        end
    end
    return nil
end

local function pressSlot(n)
    if not VIM then return false end
    local kc = E("KeyCode", KEYS[n])
    if not kc then return false end
    pcall(function() VIM:SendKeyEvent(true, kc, false, game) end)
    task.wait(0.04)
    pcall(function() VIM:SendKeyEvent(false, kc, false, game) end)
    return true
end

local function eatOnce(hum, hp)
    local now = os.clock()
    if now - hl.lastEat < 0.35 then return end
    hl.lastEat = now
    local slot = tonumber(hl.item)
    if slot then
        if not hl.holding then
            if not pressSlot(slot) then
                if notify then notify("Хил: не удалось нажать слот (нет VirtualInputManager)", false) end
                return
            end
            hl.holding = true
            if notify then notify(("Авто-хил: HP %.0f, ем слот %d"):format(hp, slot), true) end
            task.wait(0.12)
        end
        doClick()
    else
        local tool = findTool(hl.item)
        if not tool or not hum then
            if notify then notify("Хил: '" .. hl.item .. "' не найден в Tools. Впишите номер слота", false) end
            return
        end
        if not hl.holding then
            local c = player.Character
            hl.prevTool = c and c:FindFirstChildOfClass("Tool")
            hum:EquipTool(tool)
            hl.holding = true
            if notify then notify(("Авто-хил: HP %.0f, ем %s"):format(hp, tool.Name), true) end
            task.wait(0.1)
        end
        tool:Activate()
    end
end

local function restoreWeapon(hum)
    hl.holding = false
    if tonumber(hl.item) then
        pressSlot(tonumber(hl.weapon) or 1)
    else
        local prev = hl.prevTool
        if prev and prev.Parent and hum then hum:EquipTool(prev) end
        hl.prevTool = nil
    end
end

task.spawn(function()
    local lastHp
    while alive do
        task.wait(0.1)
        pcall(function()
            local hp, mx, hum = getHealth()
            if not hp then lastHp = nil return end
            if lastHp and hp < lastHp - 0.01 then hl.lastDmg = os.clock() end
            lastHp = hp
            if not hl.on then return end
            local recent = os.clock() - hl.lastDmg < 3
            if hp > 0 and hp < mx * hl.threshold - 0.01 and recent then
                eatOnce(hum, hp)
            elseif hl.holding then
                restoreWeapon(hum)
            end
        end)
    end
end)

------------------------------------------------------------------
-- Интерфейс в стиле CzxstyleUI (под сенсорный экран)
------------------------------------------------------------------
local COL = {
    bg = Color3.fromRGB(24, 24, 27),
    main = Color3.fromRGB(52, 52, 58),
    settings = Color3.fromRGB(28, 28, 32),
    border = Color3.fromRGB(85, 85, 92),
    btn = Color3.fromRGB(45, 45, 51),
    accent = Color3.fromRGB(200, 200, 208),
    off = Color3.fromRGB(120, 120, 128),
    on = Color3.fromRGB(235, 235, 240),
    row = Color3.fromRGB(38, 38, 43),
    muted = Color3.fromRGB(160, 160, 166),
    white = Color3.fromRGB(255, 255, 255),
}
local FONT = Enum.Font.GothamBold
local CLIENT_NAME = "CzxstyleUI"
local HUD_ICON = "rbxassetid://139961945073558"
local TARGET_RANGE = 50

local function make(className, props, parent)
    local obj = Instance.new(className)
    for k, v in pairs(props) do obj[k] = v end
    obj.Parent = parent
    return obj
end
local function Corner(p, r) return make("UICorner", {CornerRadius = UDim.new(0, r)}, p) end
local function Stroke(p, color, th, tr)
    return make("UIStroke", {Color = color, Thickness = th or 1, Transparency = tr or 0}, p)
end
local function label(parent, text, size, pos, textSize, color, align)
    return make("TextLabel", {
        BackgroundTransparency = 1, Size = size, Position = pos,
        Font = FONT, Text = text, TextSize = textSize,
        TextColor3 = color or COL.white,
        TextXAlignment = align or Enum.TextXAlignment.Left,
        ZIndex = parent.ZIndex + 1,
    }, parent)
end

local root = make("ScreenGui", {
    Name = "CzxBoogaFPS",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, uiParent)

-- масштаб под экран (A06: 1600x720 -> крупный интерфейс)
local function viewport()
    local cam = Workspace.CurrentCamera
    return cam and cam.ViewportSize or Vector2.new(1600, 720)
end
local scaleObjs = {}
local function addScale(obj, fn)
    local s = make("UIScale", {Scale = fn()}, obj)
    scaleObjs[#scaleObjs + 1] = {s, fn}
    return s
end
local function rescale()
    for _, e in ipairs(scaleObjs) do e[1].Scale = e[2]() end
end
local function hudScale() return math.clamp(viewport().Y / 480, 1, 1.8) end
do
    local cam = Workspace.CurrentCamera
    if cam then connections[#connections + 1] = cam:GetPropertyChangedSignal("ViewportSize"):Connect(rescale) end
end

-- перетаскивание одним пальцем (камера другим пальцем не мешает)
local function makeDraggable(obj, onTap, canDrag)
    obj.InputBegan:Connect(function(input)
        local t = input.UserInputType
        if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then return end
        if canDrag and not canDrag() then return end
        local startIn, startPos, moved = input.Position, obj.Position, false
        local posConn, endConn
        posConn = input:GetPropertyChangedSignal("Position"):Connect(function()
            local d = input.Position - startIn
            if d.Magnitude > 8 then moved = true end
            if moved then
                obj.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                    startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
        endConn = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                posConn:Disconnect()
                endConn:Disconnect()
                if not moved and onTap then onTap() end
            end
        end)
    end)
end

------------------------------------------------------------------
-- Уведомления
------------------------------------------------------------------
local notifHolder = make("Frame", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 118),
    Size = UDim2.fromOffset(300, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    ZIndex = 40,
}, root)
make("UIListLayout", {
    Padding = UDim.new(0, 6),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
}, notifHolder)
addScale(notifHolder, hudScale)

local notifList, notifId, lastMsg, lastMsgT = {}, 0, nil, 0
notify = function(msg, good)
    if not alive then return end
    local now = os.clock()
    if msg == lastMsg and now - lastMsgT < 1 then return end
    lastMsg, lastMsgT = msg, now
    notifId += 1
    while #notifList >= 4 do
        local old = table.remove(notifList, 1)
        if old.Parent then old:Destroy() end
    end
    local fr = make("Frame", {
        Size = UDim2.fromOffset(300, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Color3.fromRGB(26, 26, 30),
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        LayoutOrder = notifId,
        ZIndex = 41,
    }, notifHolder)
    Corner(fr, 6)
    Stroke(fr, COL.border, 1, 0.4)
    make("UIPadding", {
        PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
        PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7),
    }, fr)
    local safe = tostring(msg):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    local dot = good and "#4cff6a" or "#ff5a5a"
    local txt = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        RichText = true,
        Text = ("<font color=\"%s\">●</font>  %s"):format(dot, safe),
        TextColor3 = COL.white,
        Font = FONT,
        TextSize = 13,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 42,
    }, fr)
    notifList[#notifList + 1] = fr
    task.delay(2.6, function()
        if not fr.Parent then return end
        TweenService:Create(fr, TweenInfo.new(0.25), {BackgroundTransparency = 1}):Play()
        TweenService:Create(txt, TweenInfo.new(0.25), {TextTransparency = 1}):Play()
        task.wait(0.27)
        local i = table.find(notifList, fr)
        if i then table.remove(notifList, i) end
        if fr.Parent then fr:Destroy() end
    end)
end

------------------------------------------------------------------
-- HUD (Watermark, TargetHUD, Active, Inventory)
------------------------------------------------------------------
local hud = {on = true}
local hudVals = {Watermark = true, TargetHUD = true, Active = true, Inventory = false}

local function hudPanel(name, size, pos)
    local p = make("Frame", {
        Name = name, Size = size, Position = pos,
        BackgroundColor3 = Color3.fromRGB(20, 20, 23),
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 2,
    }, root)
    Corner(p, 6)
    Stroke(p, COL.border, 1, 0.4)
    addScale(p, hudScale)
    makeDraggable(p)
    return p
end

local S0 = hudScale()
local HX = 110

-- Watermark
local Watermark = hudPanel("Watermark", UDim2.fromOffset(0, 22), UDim2.fromOffset(HX, 118))
Watermark.AutomaticSize = Enum.AutomaticSize.X
local wmFps, wmMem
do
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
    }, Watermark)
    make("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, Watermark)
    make("ImageLabel", {
        BackgroundTransparency = 1, Size = UDim2.fromOffset(14, 14),
        Image = HUD_ICON, ImageColor3 = COL.accent, LayoutOrder = 1, ZIndex = 3,
    }, Watermark)
    local function part(text, ord, color)
        return make("TextLabel", {
            BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0), Font = FONT, TextSize = 12, Text = text,
            TextColor3 = color or COL.white, LayoutOrder = ord, ZIndex = 3,
        }, Watermark)
    end
    part(CLIENT_NAME, 2, COL.accent)
    part(player.Name, 3)
    part("FPS", 4, Color3.fromRGB(170, 170, 178))
    wmFps = part("60", 5)
    part("MB", 6, Color3.fromRGB(170, 170, 178))
    wmMem = part("0", 7)
end

-- TargetHUD
local TargetPanel = hudPanel("TargetHUD", UDim2.fromOffset(175, 42), UDim2.fromOffset(HX, 118 + 32 * S0))
local headImg = make("ImageLabel", {
    BackgroundColor3 = Color3.fromRGB(35, 35, 40),
    Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(6, 6), ZIndex = 3,
}, TargetPanel)
Corner(headImg, 5)
local nameLbl = label(TargetPanel, "", UDim2.fromOffset(128, 14), UDim2.fromOffset(42, 5), 13)
local hpLbl = label(TargetPanel, "", UDim2.fromOffset(128, 12), UDim2.fromOffset(42, 18), 11,
    Color3.fromRGB(190, 190, 196))
local barBg = make("Frame", {
    Size = UDim2.fromOffset(124, 5), Position = UDim2.fromOffset(42, 32),
    BackgroundColor3 = Color3.fromRGB(40, 40, 45), BorderSizePixel = 0, ZIndex = 3,
}, TargetPanel)
Corner(barBg, 2)
local barFill = make("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = COL.accent, BorderSizePixel = 0, ZIndex = 4,
}, barBg)
Corner(barFill, 2)

-- Inventory
local InventoryPanel = hudPanel("Inventory", UDim2.fromOffset(86, 24),
    UDim2.fromOffset(HX, 118 + 32 * S0 + 52 * S0))
local invSlots = {}
for i = 1, 4 do
    local s = make("ImageLabel", {
        BackgroundTransparency = 1, Size = UDim2.fromOffset(16, 16),
        Position = UDim2.fromOffset(5 + (i - 1) * 20, 4), Visible = false, ZIndex = 3,
    }, InventoryPanel)
    local letter = label(s, "", UDim2.fromScale(1, 1), UDim2.new(), 12, COL.accent, Enum.TextXAlignment.Center)
    letter.Name = "Letter"
    invSlots[i] = s
end

-- Active (замена панели биндов: на телефоне нет клавиатуры)
local ActivePanel = hudPanel("Active", UDim2.fromOffset(170, 0),
    UDim2.fromOffset(HX, 118 + 32 * S0 + 52 * S0 + 34 * S0))
ActivePanel.AutomaticSize = Enum.AutomaticSize.Y
make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2)}, ActivePanel)
make("UIPadding", {
    PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
    PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 6),
}, ActivePanel)
do
    local t = make("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = "●  ACTIVE",
        TextColor3 = COL.accent, Font = Enum.Font.GothamBlack, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 0, ZIndex = 3,
    }, ActivePanel)
end

local hudPanels = {
    Watermark = Watermark, TargetHUD = TargetPanel,
    Active = ActivePanel, Inventory = InventoryPanel,
}
local function applyHUD()
    for k, p in pairs(hudPanels) do
        p.Visible = hud.on and hudVals[k] == true
    end
end

local thumbCache, currentTargetId = {}, nil
local function findTarget()
    local char = player.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return player, char end
    local best, bestDist, bestChar = nil, TARGET_RANGE, nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local r = p.Character:FindFirstChild("HumanoidRootPart")
            local h = p.Character:FindFirstChildOfClass("Humanoid")
            if r and h and h.Health > 0 then
                local d = (r.Position - rootPart.Position).Magnitude
                if d < bestDist then best, bestDist, bestChar = p, d, p.Character end
            end
        end
    end
    if best then return best, bestChar end
    return player, char
end

local function updateTarget()
    local tPlayer, tChar = findTarget()
    local hum = tChar and tChar:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if currentTargetId ~= tPlayer.UserId then
        currentTargetId = tPlayer.UserId
        local uid = tPlayer.UserId
        if thumbCache[uid] then
            headImg.Image = thumbCache[uid]
        else
            task.spawn(function()
                local ok, img = pcall(function()
                    return (Players:GetUserThumbnailAsync(uid, Enum.ThumbnailType.HeadShot,
                        Enum.ThumbnailSize.Size100x100))
                end)
                thumbCache[uid] = ok and img or ""
                if currentTargetId == uid then headImg.Image = thumbCache[uid] end
            end)
        end
    end
    local name = tPlayer.Name
    if #name > 12 then name = name:sub(1, 12) end
    nameLbl.Text = name
    barFill.Size = UDim2.fromScale(math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1), 1)
    hpLbl.Text = math.floor(hum.Health) .. " HP"
end

local function updateInventory()
    local items = {}
    local char = player.Character
    local bp = player:FindFirstChildOfClass("Backpack")
    if char then for _, t in ipairs(char:GetChildren()) do if t:IsA("Tool") then items[#items + 1] = t end end end
    if bp then for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then items[#items + 1] = t end end end
    for i, s in ipairs(invSlots) do
        local tool = items[i]
        if tool then
            s.Image = tool.TextureId
            s.Letter.Text = (tool.TextureId == "") and tool.Name:sub(1, 1):upper() or ""
            s.Visible = true
        else
            s.Visible = false
        end
    end
end

task.spawn(function()
    local n = 0
    while alive do
        task.wait(0.25)
        n += 1
        if hud.on then
            if hudVals.Watermark and n % 2 == 0 then
                wmFps.Text = ("%.0f"):format(fpsValue)
                wmMem.Text = ("%.0f"):format(Stats:GetTotalMemoryUsageMb())
            end
            if hudVals.TargetHUD then pcall(updateTarget) end
            if hudVals.Inventory and n % 2 == 0 then pcall(updateInventory) end
        end
    end
end)

------------------------------------------------------------------
-- Круг для авто-клика и быстрая кнопка AC
------------------------------------------------------------------
circle = make("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Size = UDim2.fromOffset(52, 52),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    BackgroundColor3 = COL.accent,
    BackgroundTransparency = 0.75,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 5,
}, root)
Corner(circle, 26)
Stroke(circle, COL.accent, 2)
addScale(circle, hudScale)
makeDraggable(circle, nil, function() return not ac.on end)

local function updateCircle() circle.Visible = ac.on or ac.show end
updateCircle()

local acBtn = make("TextButton", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Size = UDim2.fromOffset(40, 40),
    Position = UDim2.new(0, 150, 0.62, 0),
    BackgroundColor3 = COL.bg,
    Text = "AC",
    TextColor3 = COL.on,
    TextSize = 13,
    Font = FONT,
    ZIndex = 45,
}, root)
Corner(acBtn, 20)
Stroke(acBtn, COL.accent, 1.5)
addScale(acBtn, hudScale)

------------------------------------------------------------------
-- Элементы меню
------------------------------------------------------------------
local ITEMS = {}
local COLUMNS = {
    {name = "Графика", items = {"shadows", "post", "particles", "textures", "fog", "highlight"}},
    {name = "Скорость", items = {"fpscap", "cull", "cpu", "gpu", "renderer", "memory", "chunks"}},
    {name = "Бой", items = {"autoclick", "autoheal"}},
    {name = "Прочее", items = {"hud", "boost", "unload"}},
}

local refreshItem, refreshActive
local activeRows = {}

local function engineItem(key, settings)
    local f = features[key]
    ITEMS[key] = {
        name = key, label = f.title, desc = f.desc,
        get = function() return f.active end,
        set = function(on) setFeature(f, on) end,
        settings = settings,
    }
end

engineItem("shadows")
engineItem("post")
engineItem("particles")
engineItem("textures")
engineItem("fog")
engineItem("highlight", {
    {type = "toggle", label = "Скрывать по имени (highlight / hover / outline)",
        get = function() return HLCFG.byName end,
        set = function(v) HLCFG.byName = v end},
})
engineItem("fpscap")
engineItem("cull", {
    {type = "stepper", label = "Дальность, studs", min = 100, max = 600, step = 20,
        get = function() return CFG.cullHide end,
        set = function(v) CFG.cullHide = v; CFG.cullShow = v - 30 end},
})
engineItem("cpu")
engineItem("gpu")
engineItem("renderer")
engineItem("memory")
engineItem("chunks")

local function allEngineActive()
    for _, f in ipairs(order) do
        if not f.active then return false end
    end
    return true
end

ITEMS.autoclick = {
    name = "autoclick", label = "Авто-клик", desc = "Клики в круг, камера свободна",
    get = function() return ac.on end,
    set = function(on) setAC(on) end,
    settings = {
        {type = "toggle", label = "Показывать круг",
            get = function() return ac.show end,
            set = function(v) ac.show = v; updateCircle() end},
        {type = "choice", label = "Режим клика", options = MODES,
            get = function() return ac.mode end,
            set = function(v) ac.mode = v end},
        {type = "stepper", label = "Кликов в секунду", min = 1, max = 25, step = 1,
            get = function() return ac.cps end,
            set = function(v) ac.cps = v end},
    },
}

ITEMS.autoheal = {
    name = "autoheal", label = "Авто-хил", desc = "Только когда здоровье падает",
    get = function() return hl.on end,
    set = function(on)
        hl.on = on
        if on then
            notify(("Авто-хил ON. Хил: %s, оружие: %s"):format(hl.item, hl.weapon), true)
        elseif hl.holding then
            restoreWeapon(currentHumanoid())
        end
    end,
    settings = {
        {type = "text", label = "Слот (цифра) или имя Tool",
            get = function() return hl.item end,
            set = function(v) hl.item = v end},
        {type = "text", label = "Слот оружия (цифра)",
            get = function() return hl.weapon end,
            set = function(v) hl.weapon = v end},
        {type = "stepper", label = "Хилить при HP ниже, %", min = 10, max = 100, step = 10,
            get = function() return math.floor(hl.threshold * 100 + 0.5) end,
            set = function(v) hl.threshold = v / 100 end},
    },
}

ITEMS.hud = {
    name = "hud", label = "HUD", desc = "Панели FPS, цель, активные",
    get = function() return hud.on end,
    set = function(on) hud.on = on; applyHUD() end,
    settings = {
        {type = "toggle", label = "Watermark", get = function() return hudVals.Watermark end,
            set = function(v) hudVals.Watermark = v; applyHUD() end},
        {type = "toggle", label = "TargetHUD", get = function() return hudVals.TargetHUD end,
            set = function(v) hudVals.TargetHUD = v; applyHUD() end},
        {type = "toggle", label = "Active (включённые функции)", get = function() return hudVals.Active end,
            set = function(v) hudVals.Active = v; applyHUD() end},
        {type = "toggle", label = "Inventory (Tools)", get = function() return hudVals.Inventory end,
            set = function(v) hudVals.Inventory = v; applyHUD() end},
    },
}

ITEMS.boost = {
    name = "boost", label = "A06 Boost", desc = "Все функции графики и FPS",
    get = allEngineActive,
    set = function(on)
        for _, f in ipairs(order) do setFeature(f, on) end
    end,
}

local Unload
ITEMS.unload = {
    name = "unload", label = "Выгрузить", desc = "Вернуть всё и закрыть скрипт",
    instant = true,
    set = function() Unload() end,
}

refreshItem = function(name)
    local it = ITEMS[name]
    if not (it and it.ui) or it.instant then return end
    local on = it.get()
    it.ui.status.Text = on and "On" or "Off"
    it.ui.status.TextColor3 = on and COL.on or COL.off
    it.ui.name.TextColor3 = on and COL.white or Color3.fromRGB(205, 205, 210)
    it.ui.btn.BackgroundTransparency = on and 0.1 or 1
end

refreshActive = function()
    for _, r in ipairs(activeRows) do r:Destroy() end
    activeRows = {}
    local n = 0
    for _, col in ipairs(COLUMNS) do
        for _, name in ipairs(col.items) do
            local it = ITEMS[name]
            if it and not it.instant and name ~= "hud" and name ~= "boost" and it.get() then
                n += 1
                activeRows[#activeRows + 1] = make("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 17), BackgroundTransparency = 1,
                    Text = "●  " .. it.label, TextColor3 = COL.white, Font = FONT, TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = n, ZIndex = 3,
                }, ActivePanel)
            end
        end
    end
    if n == 0 then
        activeRows[1] = make("TextLabel", {
            Size = UDim2.new(1, 0, 0, 17), BackgroundTransparency = 1,
            Text = "нет активных", TextColor3 = Color3.fromRGB(110, 110, 116), Font = FONT,
            TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, ZIndex = 3,
        }, ActivePanel)
    end
end

for key, f in pairs(features) do
    f.refresh = function()
        refreshItem(key)
        refreshActive()
    end
end
refreshMaster = function() refreshItem("boost") end

------------------------------------------------------------------
-- Меню: колонки и всплывающие настройки
------------------------------------------------------------------
local COLW, GAP, TOP, PITCH, ROWH = 236, 10, 38, 50, 44
local maxRows = 0
for _, c in ipairs(COLUMNS) do maxRows = math.max(maxRows, #c.items) end
local MW = #COLUMNS * COLW + (#COLUMNS + 1) * GAP
local function colHeight(n) return 41 + n * PITCH + 4 end
local MH = TOP + colHeight(maxRows) + 6

local MainFrame = make("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.fromOffset(MW, MH),
    BackgroundTransparency = 1,
    Visible = false,
    ZIndex = 20,
}, root)
local menuScale = addScale(MainFrame, function()
    local vp = viewport()
    return math.clamp(math.min((vp.X - 20) / MW, (vp.Y - 20) / MH), 0.5, 1.8)
end)

local popup, popupName
local function closePopup()
    if popup then popup:Destroy() end
    popup, popupName = nil, nil
end

local menuOpen = false
local function setMenu(open)
    menuOpen = open
    MainFrame.Visible = open
    if not open then closePopup() end
end

-- заголовок
do
    local header = make("Frame", {
        Position = UDim2.fromOffset(GAP, 0), Size = UDim2.fromOffset(MW - 2 * GAP, 32),
        BackgroundColor3 = COL.bg, BackgroundTransparency = 0.1, BorderSizePixel = 0, ZIndex = 21,
    }, MainFrame)
    Corner(header, 8)
    Stroke(header, COL.border, 1)
    label(header, CLIENT_NAME .. "  ·  Booga FPS  ·  Galaxy A06", UDim2.new(1, -60, 1, 0),
        UDim2.fromOffset(12, 0), 14)
    local closeBtn = make("TextButton", {
        Size = UDim2.fromOffset(40, 24), Position = UDim2.new(1, -46, 0.5, -12),
        BackgroundColor3 = COL.main, Text = "×", TextColor3 = COL.white,
        Font = FONT, TextSize = 18, AutoButtonColor = false, ZIndex = 22,
    }, header)
    Corner(closeBtn, 5)
    closeBtn.Activated:Connect(function() setMenu(false) end)
end

-- виджеты настроек
local function rowFrame(parent, h, ord)
    local r = make("Frame", {
        Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = COL.row,
        BorderSizePixel = 0, LayoutOrder = ord, ZIndex = 32,
    }, parent)
    Corner(r, 4)
    return r
end

local function wToggle(parent, d, ord)
    local r = rowFrame(parent, 34, ord)
    local l = label(r, d.label, UDim2.new(1, -36, 1, 0), UDim2.fromOffset(8, 0), 11, Color3.fromRGB(230, 230, 235))
    l.TextWrapped = true
    local box = make("Frame", {
        Size = UDim2.fromOffset(16, 16), Position = UDim2.new(1, -24, 0.5, -8),
        BorderSizePixel = 0, ZIndex = 33,
    }, r)
    Corner(box, 3)
    Stroke(box, Color3.fromRGB(120, 120, 128), 1)
    local function paint() box.BackgroundColor3 = d.get() and COL.on or Color3.fromRGB(30, 30, 35) end
    paint()
    local b = make("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 34,
    }, r)
    b.Activated:Connect(function()
        d.set(not d.get())
        paint()
    end)
end

local function smallBtn(parent, text, pos, size)
    local b = make("TextButton", {
        Size = size, Position = pos, BackgroundColor3 = COL.btn, Text = text,
        TextColor3 = COL.white, Font = FONT, TextSize = 14, AutoButtonColor = false, ZIndex = 34,
    }, parent)
    Corner(b, 5)
    return b
end

local function wStepper(parent, d, ord)
    local r = rowFrame(parent, 34, ord)
    local l = label(r, d.label, UDim2.fromOffset(104, 34), UDim2.fromOffset(8, 0), 11, Color3.fromRGB(230, 230, 235))
    l.TextWrapped = true
    local minus = smallBtn(r, "-", UDim2.fromOffset(116, 4), UDim2.fromOffset(26, 26))
    local val = label(r, "", UDim2.fromOffset(40, 34), UDim2.fromOffset(144, 0), 12, COL.white, Enum.TextXAlignment.Center)
    local plus = smallBtn(r, "+", UDim2.fromOffset(188, 4), UDim2.fromOffset(26, 26))
    local function show() val.Text = tostring(d.get()) end
    show()
    local function change(dir)
        d.set(math.clamp(d.get() + dir * d.step, d.min, d.max))
        show()
    end
    minus.Activated:Connect(function() change(-1) end)
    plus.Activated:Connect(function() change(1) end)
end

local function wChoice(parent, d, ord)
    local r = rowFrame(parent, 34, ord)
    label(r, d.label, UDim2.fromOffset(92, 34), UDim2.fromOffset(8, 0), 11, Color3.fromRGB(230, 230, 235))
    local b = smallBtn(r, d.get(), UDim2.fromOffset(104, 4), UDim2.fromOffset(108, 26))
    b.TextSize = 12
    b.Activated:Connect(function()
        local i = table.find(d.options, d.get()) or 1
        i = i % #d.options + 1
        d.set(d.options[i])
        b.Text = d.get()
    end)
end

local function wText(parent, d, ord)
    local r = rowFrame(parent, 54, ord)
    label(r, d.label, UDim2.new(1, -16, 0, 16), UDim2.fromOffset(8, 4), 11, Color3.fromRGB(160, 160, 166))
    local tb = make("TextBox", {
        Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(8, 24),
        BackgroundColor3 = COL.bg, BorderSizePixel = 0, Text = d.get(),
        TextColor3 = Color3.fromRGB(230, 230, 235), Font = FONT, TextSize = 13,
        ClearTextOnFocus = false, ZIndex = 34,
    }, r)
    Corner(tb, 4)
    Stroke(tb, Color3.fromRGB(70, 70, 78), 1, 0.4)
    tb.FocusLost:Connect(function()
        local t = tb.Text:gsub("^%s+", ""):gsub("%s+$", "")
        if t == "" then t = d.get() end
        d.set(t)
        tb.Text = t
    end)
end

local function openPopup(item, colIdx, rowIdx)
    if popupName == item.name then closePopup() return end
    closePopup()
    local pf = make("Frame", {
        Size = UDim2.fromOffset(232, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = COL.settings, BorderSizePixel = 0, ZIndex = 30,
    }, MainFrame)
    Corner(pf, 6)
    Stroke(pf, COL.border, 1, 0.3)
    make("UIPadding", {
        PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
    }, pf)
    make("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, pf)
    local title = label(pf, item.label .. " · настройки", UDim2.new(1, 0, 0, 16), UDim2.new(), 12,
        Color3.fromRGB(180, 180, 186))
    title.LayoutOrder = 0
    for i, d in ipairs(item.settings) do
        if d.type == "toggle" then wToggle(pf, d, i)
        elseif d.type == "stepper" then wStepper(pf, d, i)
        elseif d.type == "choice" then wChoice(pf, d, i)
        elseif d.type == "text" then wText(pf, d, i) end
    end
    local colX = GAP + (colIdx - 1) * (COLW + GAP)
    local x = colIdx <= 2 and (colX + COLW + 6) or (colX - 232 - 6)
    local y = TOP + 41 + (rowIdx - 1) * PITCH
    pf.Position = UDim2.fromOffset(x, y)
    popup, popupName = pf, item.name
    task.defer(function()
        if pf.Parent then
            local h = pf.AbsoluteSize.Y / menuScale.Scale
            if y + h > MH then pf.Position = UDim2.fromOffset(x, math.max(0, MH - h)) end
        end
    end)
end

-- кнопки функций
local function buildItem(container, item, rowIdx, colIdx)
    local hasGear = item.settings ~= nil
    local btn = make("TextButton", {
        Size = UDim2.new(1, -4, 0, ROWH), Position = UDim2.new(0, 2, 0, (rowIdx - 1) * PITCH),
        BackgroundColor3 = COL.btn, BackgroundTransparency = 1, BorderSizePixel = 0,
        AutoButtonColor = false, Text = "", ZIndex = 22,
    }, container)
    Corner(btn, 4)
    local rightPad = hasGear and 92 or 62
    local nameL = label(btn, item.label, UDim2.new(1, -rightPad, 0, 22), UDim2.fromOffset(10, 3), 14,
        Color3.fromRGB(205, 205, 210))
    label(btn, item.desc or "", UDim2.new(1, -rightPad, 0, 16), UDim2.fromOffset(10, 25), 10, COL.off).TextTruncate =
        Enum.TextTruncate.AtEnd
    local status = label(btn, item.instant and "→" or "Off", UDim2.fromOffset(46, ROWH),
        UDim2.new(1, hasGear and -80 or -52, 0, 0), 13, item.instant and COL.accent or COL.off,
        Enum.TextXAlignment.Right)
    item.ui = {btn = btn, status = status, name = nameL}

    btn.Activated:Connect(function()
        closePopup()
        if item.instant then
            item.set()
        else
            local new = not item.get()
            item.set(new)
            if not new then notify(item.label .. ": OFF", false) end
        end
    end)

    if hasGear then
        local gear = make("TextButton", {
            Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -34, 0.5, -14),
            BackgroundColor3 = COL.main, Text = "…", TextColor3 = COL.white, Font = FONT,
            TextSize = 16, AutoButtonColor = false, ZIndex = 24,
        }, btn)
        Corner(gear, 5)
        gear.Activated:Connect(function() openPopup(item, colIdx, rowIdx) end)
    end
    refreshItem(item.name)
end

for colIdx, col in ipairs(COLUMNS) do
    local cw = make("Frame", {
        Name = col.name,
        Position = UDim2.fromOffset(GAP + (colIdx - 1) * (COLW + GAP), TOP),
        Size = UDim2.fromOffset(COLW, colHeight(#col.items)),
        BackgroundColor3 = COL.bg, BackgroundTransparency = 0.1, BorderSizePixel = 0, ZIndex = 21,
    }, MainFrame)
    Corner(cw, 8)
    Stroke(cw, COL.border, 1)
    local tf = make("Frame", {
        Size = UDim2.new(1, 0, 0, 35), BackgroundColor3 = COL.main, BorderSizePixel = 0, ZIndex = 22,
    }, cw)
    Corner(tf, 8)
    make("Frame", {
        Size = UDim2.new(1, 0, 0, 8), Position = UDim2.new(0, 0, 1, -8),
        BackgroundColor3 = COL.main, BorderSizePixel = 0, ZIndex = 22,
    }, tf)
    local tl = label(tf, col.name, UDim2.new(1, -10, 1, 0), UDim2.fromOffset(10, 0), 14)
    tl.Font = Enum.Font.GothamBlack
    tl.ZIndex = 24
    local fc = make("Frame", {
        Size = UDim2.new(1, -12, 1, -47), Position = UDim2.fromOffset(6, 41),
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 22,
    }, cw)
    for rowIdx, name in ipairs(col.items) do
        buildItem(fc, ITEMS[name], rowIdx, colIdx)
    end
end

------------------------------------------------------------------
-- Кнопки управления
------------------------------------------------------------------
setAC = function(on)
    ac.on = on
    circle.Interactable = not on   -- во время работы круг не перехватывает касания
    circle.Active = not on
    updateCircle()
    acBtn.BackgroundColor3 = on and COL.accent or COL.bg
    acBtn.TextColor3 = on and COL.bg or COL.on
    refreshItem("autoclick")
    refreshActive()
    notify(on and ("Авто-клик ON: " .. ac.mode .. ", " .. ac.cps .. " кл/с") or "Авто-клик OFF", on)
end
makeDraggable(acBtn, function() setAC(not ac.on) end)

local openBtn = make("TextButton", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Size = UDim2.fromOffset(46, 46),
    Position = UDim2.new(0, 150, 0.62, 90),
    BackgroundColor3 = COL.bg,
    Text = "CZX",
    TextColor3 = COL.white,
    TextSize = 13,
    Font = FONT,
    ZIndex = 45,
}, root)
Corner(openBtn, 23)
Stroke(openBtn, COL.accent, 1.5)
addScale(openBtn, hudScale)
makeDraggable(openBtn, function() setMenu(not menuOpen) end)

------------------------------------------------------------------
-- Выгрузка
------------------------------------------------------------------
Unload = function()
    if not alive then return end
    for _, f in ipairs(order) do pcall(setFeature, f, false) end
    ac.on, hl.on = false, false
    if hl.holding then pcall(restoreWeapon, currentHumanoid()) end
    alive = false
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    pcall(function() root:Destroy() end)
end
root.Destroying:Connect(Unload)

applyHUD()
refreshActive()
refreshMaster()
notify("CzxstyleUI загружен. Кнопка CZX открывает меню", true)
print("[Booga FPS v5] Loaded. CZX button = menu, AC button = auto click.")
