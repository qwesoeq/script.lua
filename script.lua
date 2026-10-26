local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local InsertService = game:GetService("InsertService")
local Lighting = game:GetService("Lighting")

local me = Players.LocalPlayer

-- ╔══════════════════════════════════════════╗
-- ║   ТВОЙ FIREBASE URL                      ║
-- ╚══════════════════════════════════════════╝
local BACKEND_URL = "https://femboyhubchat-default-rtdb.firebaseio.com"

-- Правильное определение HTTP-функции (некоторые инжекторы отдают userdata вместо функции)
local httpFn
if typeof(request) == "function" then
    httpFn = request
elseif typeof(http_request) == "function" then
    httpFn = http_request
elseif syn and typeof(syn.request) == "function" then
    httpFn = syn.request
elseif http and typeof(http.request) == "function" then
    httpFn = http.request
end

if not httpFn then
    warn("[Femboy Hub] HTTP-функция не найдена. Users/Chat работать не будут.")
end

local function safeEncode(t) local s,r = pcall(function() return HttpService:JSONEncode(t) end) return s and r or "{}" end
local function safeDecode(t) local s,r = pcall(function() return HttpService:JSONDecode(t) end) return s and r or {} end

-- ==== Система сохранений ====
local configPath = "FemboyHub_Settings.json"

local customWalkSpeed = 16
local customJumpPower = 50
local autoClickCPS = 40
local autoClickX = 0
local autoClickY = 0

local flyEnabled = false
local noclipEnabled = false
local infJumpEnabled = false
local autoAim = false
local killAuraEnabled = false
local hitboxEnabled = false
local antiFling = false
local espEnabled = false
local keyEspEnabled = false
local autoClickEnabled = false
local optimizationEnabled = false
local fakeHeadlessEnabled = false
local fakeKorbloxEnabled = false
local chineseHatEnabled = false
local antiAFK = false
local chineseHatId = 6201695834
local cameraClipEnabled = false
local candyFarmEnabled = false

local function saveConfig()
    if writefile then
        local data = {
            customWalkSpeed = customWalkSpeed, customJumpPower = customJumpPower,
            autoClickCPS = autoClickCPS, autoClickX = autoClickX, autoClickY = autoClickY,
            flyEnabled = flyEnabled, noclipEnabled = noclipEnabled, infJumpEnabled = infJumpEnabled,
            autoAim = autoAim, killAuraEnabled = killAuraEnabled, hitboxEnabled = hitboxEnabled,
            antiFling = antiFling, espEnabled = espEnabled, keyEspEnabled = keyEspEnabled,
            autoClickEnabled = autoClickEnabled, optimizationEnabled = optimizationEnabled,
            fakeHeadlessEnabled = fakeHeadlessEnabled, fakeKorbloxEnabled = fakeKorbloxEnabled,
            chineseHatEnabled = chineseHatEnabled, antiAFK = antiAFK,
            chineseHatId = chineseHatId, cameraClipEnabled = cameraClipEnabled
        }
        pcall(function() writefile(configPath, HttpService:JSONEncode(data)) end)
    end
end

local function loadConfig()
    if isfile and isfile(configPath) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(configPath)) end)
        if ok and type(data) == "table" then
            customWalkSpeed = data.customWalkSpeed or 16
            customJumpPower = data.customJumpPower or 50
            autoClickCPS = data.autoClickCPS or 40
            autoClickX = data.autoClickX or 0
            autoClickY = data.autoClickY or 0
            flyEnabled = data.flyEnabled or false
            noclipEnabled = data.noclipEnabled or false
            infJumpEnabled = data.infJumpEnabled or false
            autoAim = data.autoAim or false
            killAuraEnabled = data.killAuraEnabled or false
            hitboxEnabled = data.hitboxEnabled or false
            antiFling = data.antiFling or false
            espEnabled = data.espEnabled or false
            keyEspEnabled = data.keyEspEnabled or false
            autoClickEnabled = data.autoClickEnabled or false
            optimizationEnabled = data.optimizationEnabled or false
            fakeHeadlessEnabled = data.fakeHeadlessEnabled or false
            fakeKorbloxEnabled = data.fakeKorbloxEnabled or false
            chineseHatEnabled = data.chineseHatEnabled or false
            antiAFK = data.antiAFK or false
            chineseHatId = data.chineseHatId or 6201695834
            cameraClipEnabled = data.cameraClipEnabled or false
        end
    end
end

loadConfig()

-- ==== Координаты ====
local FARM_COORDS = Vector3.new(-94, 52, -89)
local ASTRAL_PORTAL_CFRAME = CFrame.new(-90, 18, 125) + Vector3.new(0, 2, 0)

-- ==== Поиск ремоута ====
local punchRemote
task.spawn(function()
    local pkg = ReplicatedStorage:WaitForChild("ReplicatedStorage Package", 10)
    if pkg then
        local re = pkg:FindFirstChild("Remote Events")
        if re then punchRemote = re:FindFirstChild("Punch") end
    end
end)

-- ==== Настройки ====
local TELEPORT_OFFSET        = CFrame.new(0, 0, 2.5)
local TARGET_SWITCH_TIME     = 1.0
local ANTI_FLING_THRESHOLD   = 50
local FLY_SPEED              = 50
local HITBOX_SIZE            = 15
local KILLAURA_RADIUS        = 8
local KILLAURA_COOLDOWN      = 0.2
local CANDY_TELEPORT_DELAY   = 0.2
local CANDY_SEARCH_RADIUS    = 600

-- ==== Морфы / Утилиты ====
local HEADLESS_MESH_ID = "rbxassetid://1095708"
local KORBLOX_MESH_ID  = "rbxassetid://101851696"
local GREY_COLOR       = Color3.fromRGB(128, 128, 128)

local savedHeadState      = nil
local savedLegState       = nil
local savedLightingState  = {}
local autoClickThread     = nil
local currentHat          = nil
local autoClickDot        = nil
local originalQueries     = {}

local optimizeBtn, autoClickBtn, hatBtn, headlessBtn, korbloxBtn
local keyEspBtn, keyEspBtn2, espBtn, cameraClipBtn, candyBtn

-- ==== Сетевые переменные ====
local chatMessages = {}
local activeUsers = {}
local scriptUserTags = {}
local lastChatCheck = 0
local lastUsersCheck = 0
local lastPresenceSend = 0
local lastRenderedChatCount = 0
local chatScroll, usersScroll, usersHeader

-- ==== Переменные ====
local logLabels = {}
local keyEspObjects = {}
local savedPos = nil
local walkFarmEnabled = false
local lastWalkUpdate = 0
local stuckTimer = 0
local isTeleporting = false
local lastFarmTeleport = 0
local farmTeleportAttempts = 0
local walkToPortalMode = false
local lastCandyTeleport = 0

-- ==== Палитра ====
local COLORS = {
    bg         = Color3.fromRGB(15, 15, 18),
    sidebar    = Color3.fromRGB(20, 20, 24),
    topbar     = Color3.fromRGB(18, 18, 22),
    activeTab  = Color3.fromRGB(35, 35, 45),
    text       = Color3.fromRGB(240, 240, 240),
    textDim    = Color3.fromRGB(130, 130, 140),
    accent     = Color3.fromRGB(80, 110, 220),
    stroke     = Color3.fromRGB(40, 40, 45),
    green      = Color3.fromRGB(60, 180, 100),
    yellow     = Color3.fromRGB(255, 215, 0),
    red        = Color3.fromRGB(200, 60, 60),
    msgBg      = Color3.fromRGB(30, 30, 36),
    blue       = Color3.fromRGB(50, 150, 255),
    pulse      = Color3.fromRGB(255, 140, 50)
}

-- ==== Состояние ====
local farming        = false
local lastAuraHit    = 0
local targetPlayer   = nil
local currentTarget  = nil
local lastSwitch     = 0
local espObjects     = {}
local flyBV, flyBG   = nil, nil

-- ==== Трекинг реальных персонажей (для отсева клонов/ботов) ====
local realCharacters = {}

local function watchPlayerForRealCharacter(plr)
    if plr.Character then
        realCharacters[plr] = plr.Character
    end
    plr.CharacterAdded:Connect(function(char)
        realCharacters[plr] = char
    end)
end

for _, plr in ipairs(Players:GetPlayers()) do
    watchPlayerForRealCharacter(plr)
end
Players.PlayerAdded:Connect(watchPlayerForRealCharacter)
Players.PlayerRemoving:Connect(function(plr)
    realCharacters[plr] = nil
end)

-- ==== Хелперы ====
local function getAlive(player)
    local char = player.Character
    if not char or not char.Parent then return end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root or hum.Health <= 0 then return end
    return char, hum, root
end

local function getRealTarget(p)
    if not p or p == me then return end
    if not p.Parent or p.Parent ~= Players then return end

    local char = p.Character
    if not char or not char.Parent then return end
    if char.Parent ~= workspace then return end

    if realCharacters[p] ~= char then return end
    if Players:GetPlayerFromCharacter(char) ~= p then return end
    if char.Name ~= p.Name then return end
    if not char:FindFirstChild("Animate") then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if hum.Health <= 0 then return end
    if hum.MaxHealth == math.huge then return end
    if hum:GetState() == Enum.HumanoidStateType.Dead then return end

    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if not root:FindFirstChildOfClass("Motor6D") then return end

    if p:GetAttribute("Spectating") or p:GetAttribute("IsSpectator") or p:GetAttribute("Spectator") or p:GetAttribute("Dead") then return end
    if char:GetAttribute("Spectating") or char:GetAttribute("IsSpectator") or char:GetAttribute("Spectator") then return end

    if p.Team then
        local tn = string.lower(p.Team.Name)
        if tn:find("spectat") or tn:find("dead") or tn:find("ghost") or tn:find("observ") then return end
    end

    return char, hum, root
end

local function hasForceField()
    local char = me.Character
    if not char then return true end
    return char:FindFirstChildOfClass("ForceField") ~= nil
end

local function setAutoRotate(enabled)
    local _, hum = getAlive(me)
    if hum then pcall(function() hum.AutoRotate = enabled end) end
end

local function faceTarget(targetRoot)
    local _, _, myRoot = getAlive(me)
    if not myRoot or not targetRoot then return end
    local myPos = myRoot.Position
    local tp = targetRoot.Position
    local dir = Vector3.new(tp.X - myPos.X, 0, tp.Z - myPos.Z)
    if dir.Magnitude < 0.05 then return end
    pcall(function() myRoot.CFrame = CFrame.lookAt(myPos, myPos + dir) end)
end

local function distToFarm(myRoot)
    if not myRoot then return math.huge end
    return (myRoot.Position - FARM_COORDS).Magnitude
end

local function findPlayerByName(name)
    if not name or name == "" then return nil end
    local lower = string.lower(name)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= me and (string.lower(plr.Name) == lower or string.lower(plr.DisplayName) == lower) then
            return plr
        end
    end
    return nil
end

local function applyHitbox()
    local char, hum, root = getAlive(me)
    if not char or not root then return end
    if hitboxEnabled then
        root.Size = Vector3.new(HITBOX_SIZE, HITBOX_SIZE, HITBOX_SIZE)
        root.Transparency = 0.5
        root.CanCollide = false
    else
        root.Size = Vector3.new(2, 2, 1)
        root.Transparency = 1
        root.CanCollide = true
    end
end

-- ==========================================
-- СЕТЬ И БЕЙДЖИ
-- ==========================================
local function addTag(p)
    if scriptUserTags[p] or not p.Character then return end
    local h = p.Character:FindFirstChild("Head")
    if not h then return end
    local bb = Instance.new("BillboardGui", h)
    bb.Name = "FemboyTag"; bb.Size = UDim2.new(0, 160, 0, 24); bb.StudsOffset = Vector3.new(0, 2.5, 0); bb.AlwaysOnTop = true
    local t = Instance.new("TextLabel", bb)
    t.Size = UDim2.new(1, 0, 1, 0); t.BackgroundTransparency = 1; t.Text = "Femboy user"
    t.TextColor3 = COLORS.pulse; t.Font = Enum.Font.GothamBold; t.TextSize = 14; t.TextStrokeTransparency = 0
    scriptUserTags[p] = bb
end

local function remTag(p)
    if scriptUserTags[p] then pcall(function() scriptUserTags[p]:Destroy() end); scriptUserTags[p] = nil end
end

local function refreshTags()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= me then
            if activeUsers[tostring(p.UserId)] and p.Character then addTag(p) else remTag(p) end
        end
    end
end

local function sendPresence()
    if not httpFn then return end
    local body = safeEncode({
        userId = me.UserId, name = me.Name, displayName = me.DisplayName,
        placeId = game.PlaceId, jobId = game.JobId, lastSeen = os.time()
    })
    local ok, r = pcall(function()
        return httpFn({
            Url = BACKEND_URL .. "/presence/" .. me.UserId .. ".json",
            Method = "PUT",
            Headers = {["Content-Type"] = "application/json"},
            Body = body
        })
    end)
    if not ok then
        warn("[Presence] Ошибка запроса: " .. tostring(r))
    elseif r and r.StatusCode and r.StatusCode >= 400 then
        warn("[Presence] Firebase ответил кодом " .. tostring(r.StatusCode))
    end
end

local function fetchUsers()
    if not httpFn then return end
    local ok, r = pcall(function()
        return httpFn({Url = BACKEND_URL .. "/presence.json", Method = "GET"})
    end)
    if not ok or not r or not r.Body then return end
    local d = safeDecode(r.Body)
    if type(d) ~= "table" then return end
    local n = os.time()
    local f = {}
    for uid, i in pairs(d) do
        if type(i) == "table" and i.lastSeen and (n - i.lastSeen) < 120 then
            f[tostring(uid)] = i
        end
    end
    activeUsers = f
end

local function sendChat(txt)
    if not httpFn or txt == "" then return end
    local body = safeEncode({
        userId = me.UserId, name = me.Name, displayName = me.DisplayName,
        text = txt, time = os.time()
    })
    local ok, r = pcall(function()
        return httpFn({
            Url = BACKEND_URL .. "/chat.json",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = body
        })
    end)
    if not ok then
        warn("[Chat] Ошибка отправки: " .. tostring(r))
    elseif r and r.StatusCode and r.StatusCode >= 400 then
        warn("[Chat] Firebase ответил кодом " .. tostring(r.StatusCode))
    end
end

local function fetchChat()
    if not httpFn then return end
    local ok, r = pcall(function()
        return httpFn({Url = BACKEND_URL .. "/chat.json", Method = "GET"})
    end)
    if not ok or not r or not r.Body then return end
    local d = safeDecode(r.Body)
    if type(d) ~= "table" then return end
    local m = {}
    for _, x in pairs(d) do
        if type(x) == "table" and x.text and x.time then
            table.insert(m, x)
        end
    end
    table.sort(m, function(a, b) return a.time < b.time end)
    while #m > 50 do table.remove(m, 1) end
    chatMessages = m
end

-- ==========================================
-- 📷 CAMERA CLIP
-- ==========================================
local function toggleCameraClip()
    cameraClipEnabled = not cameraClipEnabled

    if cameraClipEnabled then
        task.spawn(function()
            for _, v in ipairs(workspace:GetDescendants()) do
                if v:IsA("BasePart") and v.CanQuery then
                    local isPlayerPart = false
                    local parent = v.Parent
                    while parent do
                        if parent:IsA("Model") then
                            local plr = Players:GetPlayerFromCharacter(parent)
                            if plr then
                                isPlayerPart = true
                                break
                            end
                        end
                        parent = parent.Parent
                    end

                    if not isPlayerPart then
                        originalQueries[v] = true
                        v.CanQuery = false
                    end
                end
            end
        end)
        setBadgeLog("Camera Clip ON")
    else
        task.spawn(function()
            for v, _ in pairs(originalQueries) do
                if v and v.Parent then
                    v.CanQuery = true
                end
            end
            originalQueries = {}
        end)
        setBadgeLog("Camera Clip OFF")
    end

    if cameraClipBtn then
        cameraClipBtn.Text = "Camera Clip: " .. (cameraClipEnabled and "ON" or "OFF")
        cameraClipBtn.BackgroundColor3 = cameraClipEnabled and COLORS.green or COLORS.activeTab
    end
    saveConfig()
end

-- ==========================================
-- 💀 FAKE HEADLESS / 🦵 FAKE KORBLOX
-- ==========================================
local function setBadgeLog(text)
    for _, lbl in ipairs(logLabels) do
        if lbl and lbl.Parent then lbl.Text = "🤖 " .. tostring(text) end
    end
end

local function applyHeadless()
    local char = me.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    if not savedHeadState then
        local face = head:FindFirstChild("face")
        savedHeadState = {
            transparency = head.Transparency,
            canCollide = head.CanCollide,
            faceTexture = (face and face:IsA("Decal")) and face.Texture or "rbxasset://textures/face.png",
        }
        if face then pcall(function() face:Destroy() end) end
    end

    head.Transparency = 1
    head.CanCollide = false

    local old = head:FindFirstChild("FakeHeadlessMesh")
    if old then old:Destroy() end

    local mesh = Instance.new("SpecialMesh")
    mesh.Name = "FakeHeadlessMesh"
    mesh.MeshType = Enum.MeshType.FileMesh
    mesh.MeshId = HEADLESS_MESH_ID
    mesh.Scale = Vector3.new(0.001, 0.001, 0.001)
    mesh.Parent = head
end

local function removeHeadless()
    local char = me.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    local mesh = head:FindFirstChild("FakeHeadlessMesh")
    if mesh then mesh:Destroy() end

    if savedHeadState then
        head.Transparency = savedHeadState.transparency or 0
        head.CanCollide = savedHeadState.canCollide
        if not head:FindFirstChild("face") then
            local face = Instance.new("Decal")
            face.Name = "face"
            face.Texture = savedHeadState.faceTexture or "rbxasset://textures/face.png"
            face.Parent = head
        end
        savedHeadState = nil
    else
        head.Transparency = 0
    end
end

local function applyKorblox()
    local char = me.Character
    if not char then return end
    local leg = char:FindFirstChild("Right Leg") or char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("RightLowerLeg")
    if not leg then return end

    if not savedLegState then
        savedLegState = { brickColor = leg.BrickColor, color = leg.Color }
    end

    leg.BrickColor = BrickColor.new(GREY_COLOR)
    if leg:IsA("MeshPart") then leg.Color = GREY_COLOR end

    local old = leg:FindFirstChild("FakeKorbloxMesh")
    if old then old:Destroy() end

    local mesh = Instance.new("SpecialMesh")
    mesh.Name = "FakeKorbloxMesh"
    mesh.MeshType = Enum.MeshType.FileMesh
    mesh.MeshId = KORBLOX_MESH_ID
    mesh.Scale = Vector3.new(1, 1, 1)
    mesh.Parent = leg
end

local function removeKorblox()
    local char = me.Character
    if not char then return end
    local leg = char:FindFirstChild("Right Leg") or char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("RightLowerLeg")
    if not leg then return end

    local mesh = leg:FindFirstChild("FakeKorbloxMesh")
    if mesh then mesh:Destroy() end

    if savedLegState then
        if savedLegState.brickColor then leg.BrickColor = savedLegState.brickColor end
        if savedLegState.color and leg:IsA("MeshPart") then leg.Color = savedLegState.color end
        savedLegState = nil
    end
end

-- ==========================================
-- ⚡ OPTIMIZATION
-- ==========================================
local function toggleOptimization()
    optimizationEnabled = not optimizationEnabled
    if optimizationEnabled then
        savedLightingState = {
            GlobalShadows = Lighting.GlobalShadows,
            FogEnd = Lighting.FogEnd,
            Brightness = Lighting.Brightness,
            EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
            EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale
        }
        pcall(function()
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 100000
            Lighting.Brightness = 1
            Lighting.EnvironmentDiffuseScale = 0
            Lighting.EnvironmentSpecularScale = 0
            for _, v in pairs(Lighting:GetChildren()) do
                if v:IsA("PostEffect") or v:IsA("Sky") or v:IsA("Atmosphere") or v:IsA("Clouds") then
                    v.Enabled = false
                end
            end
        end)
    else
        pcall(function()
            Lighting.GlobalShadows = savedLightingState.GlobalShadows
            Lighting.FogEnd = savedLightingState.FogEnd
            Lighting.Brightness = savedLightingState.Brightness
            Lighting.EnvironmentDiffuseScale = savedLightingState.EnvironmentDiffuseScale
            Lighting.EnvironmentSpecularScale = savedLightingState.EnvironmentSpecularScale
            for _, v in pairs(Lighting:GetChildren()) do
                if v:IsA("PostEffect") or v:IsA("Sky") or v:IsA("Atmosphere") or v:IsA("Clouds") then
                    v.Enabled = true
                end
            end
        end)
    end

    if optimizeBtn then
        optimizeBtn.Text = "Optimize: " .. (optimizationEnabled and "ON" or "OFF")
        optimizeBtn.BackgroundColor3 = optimizationEnabled and COLORS.green or COLORS.activeTab
    end
    saveConfig()
end

-- ==========================================
-- 🖱️ AUTO CLICKER
-- ==========================================
local function createClickDot()
    if autoClickDot then autoClickDot:Destroy() end
    autoClickDot = Instance.new("Frame")
    autoClickDot.Name = "AutoClickDot"
    autoClickDot.Size = UDim2.new(0, 20, 0, 20)
    autoClickDot.BackgroundColor3 = COLORS.red
    autoClickDot.BackgroundTransparency = 0.5
    autoClickDot.BorderSizePixel = 2
    autoClickDot.BorderColor3 = Color3.new(1, 1, 1)
    autoClickDot.AnchorPoint = Vector2.new(0.5, 0.5)

    if autoClickX == 0 and autoClickY == 0 then
        autoClickX = workspace.CurrentCamera.ViewportSize.X / 2
        autoClickY = workspace.CurrentCamera.ViewportSize.Y / 2
    end
    autoClickDot.Position = UDim2.new(0, autoClickX, 0, autoClickY)

    autoClickDot.Parent = gethui and gethui() or game:GetService("CoreGui")

    local dragging, dragStart, startPos
    autoClickDot.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = autoClickDot.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            local newX = startPos.X.Offset + delta.X
            local newY = startPos.Y.Offset + delta.Y
            autoClickDot.Position = UDim2.new(0, newX, 0, newY)
            autoClickX = newX
            autoClickY = newY
            saveConfig()
        end
    end)
end

local function startAutoClicker()
    if autoClickThread then task.cancel(autoClickThread) end
    autoClickThread = task.spawn(function()
        while autoClickEnabled do
            local delayTime = 1 / math.max(1, autoClickCPS)
            pcall(function()
                if type(VirtualInputManager) == "Instance" then
                    VirtualInputManager:SendMouseButtonEvent(autoClickX, autoClickY, 0, true, game, 1)
                    task.wait(0.005)
                    VirtualInputManager:SendMouseButtonEvent(autoClickX, autoClickY, 0, false, game, 1)
                elseif type(VirtualUser) == "Instance" then
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton1(Vector2.new(autoClickX, autoClickY))
                end
            end)
            task.wait(delayTime)
        end
    end)
end

local function stopAutoClicker()
    if autoClickThread then
        pcall(function() task.cancel(autoClickThread) end)
        autoClickThread = nil
    end
end

local function toggleAutoClicker()
    autoClickEnabled = not autoClickEnabled
    if autoClickEnabled then
        createClickDot()
        startAutoClicker()
    else
        if autoClickDot then autoClickDot:Destroy(); autoClickDot = nil end
        stopAutoClicker()
    end

    if autoClickBtn then
        autoClickBtn.Text = "Auto Click: " .. (autoClickEnabled and "ON" or "OFF")
        autoClickBtn.BackgroundColor3 = autoClickEnabled and COLORS.green or COLORS.activeTab
    end
    saveConfig()
end

-- ==========================================
-- 🎩 CHINESE HAT
-- ==========================================
local function loadHat(hatId)
    local success, model = pcall(function()
        return InsertService:LoadAsset(tonumber(hatId))
    end)
    if not success or not model then
        success, model = pcall(function()
            return game:GetObjects("rbxassetid://" .. tostring(hatId))[1]
        end)
    end
    return success and model or nil
end

local function toggleChineseHat()
    chineseHatEnabled = not chineseHatEnabled

    if chineseHatEnabled then
        local model = loadHat(chineseHatId)
        if model then
            local hat = model:FindFirstChildOfClass("Accessory") or model:FindFirstChildWhichIsA("Accessory", true)
            if hat then
                hat.Parent = me.Character
                currentHat = hat
                local hum = me.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum:AddAccessory(hat) end
            end
            model:Destroy()
        end
    else
        if currentHat then
            pcall(function() currentHat:Destroy() end)
            currentHat = nil
        end
        for _, v in ipairs(me.Character:GetChildren()) do
            if v:IsA("Accessory") and v.Name:lower():find("hat") then
                v:Destroy()
            end
        end
    end

    if hatBtn then
        hatBtn.Text = "Chinese Hat: " .. (chineseHatEnabled and "ON" or "OFF")
        hatBtn.BackgroundColor3 = chineseHatEnabled and COLORS.accent or COLORS.activeTab
    end
    saveConfig()
end

-- ==========================================
-- 🚶 ХОДЬБА / WALK FARM
-- ==========================================
local function walkToArenaPortal()
    local myChar, myHum, myRoot = getAlive(me)
    if not myChar or not myHum or not myRoot then return end
    local targetPos = Vector3.new(-90, 18, 125)
    local portals = workspace:FindFirstChild("Portals")
    if portals then
        local af = portals:FindFirstChild("Arena Frame")
        local portal = af and af:FindFirstChild("Portal")
        if portal then targetPos = portal.Position end
    end
    myHum:MoveTo(targetPos + Vector3.new(0, 1, 0))
    if (myRoot.Position - targetPos).Magnitude < 10 then
        if myHum.FloorMaterial ~= Enum.Material.Air then myHum.Jump = true end
    end
    if myHum.MoveDirection.Magnitude > 0.1 and myRoot.AssemblyLinearVelocity.Magnitude < 2.5 then
        if myHum.FloorMaterial ~= Enum.Material.Air then myHum.Jump = true end
    end
end

local function updateWalkFarm()
    if not walkFarmEnabled then return end
    local myChar, myHum, myRoot = getAlive(me)
    if not myChar or not myHum or not myRoot then return end
    local now = tick()
    if now - lastWalkUpdate < 0.15 then return end
    lastWalkUpdate = now

    local target, minDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= me then
            local tChar, _, tRoot = getRealTarget(plr)
            if tChar and tRoot then
                local d = (tRoot.Position - myRoot.Position).Magnitude
                if d < minDist then minDist = d; target = tRoot end
            end
        end
    end

    if not target then myHum:MoveTo(myRoot.Position); return end
    if minDist <= 4 then myHum:MoveTo(myRoot.Position); return end

    local dir = target.Position - myRoot.Position
    local flatDir = Vector3.new(dir.X, 0, dir.Z)
    if flatDir.Magnitude < 0.1 then return end
    flatDir = flatDir.Unit

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {myChar}

    local function isBlocked(origin, direction, distance)
        local ray = workspace:Raycast(origin, direction * distance, rayParams)
        if ray then
            if ray.Instance and ray.Instance.Parent then
                local model = ray.Instance:FindFirstAncestorOfClass("Model")
                if model and Players:GetPlayerFromCharacter(model) then return false end
            end
            return true
        end
        return false
    end

    local origin = myRoot.Position + Vector3.new(0, 1, 0)
    local blockedFwd = isBlocked(origin, flatDir, 6)
    local blockedFwdHigh = isBlocked(origin + Vector3.new(0, 4, 0), flatDir, 6)

    if not blockedFwd then
        myHum:MoveTo(target.Position)
    elseif not blockedFwdHigh then
        if myHum.FloorMaterial ~= Enum.Material.Air then myHum.Jump = true end
        myHum:MoveTo(target.Position)
    else
        local leftDir = Vector3.new(-flatDir.Z, 0, flatDir.X)
        local rightDir = Vector3.new(flatDir.Z, 0, -flatDir.X)
        if not isBlocked(origin, leftDir, 6) then
            myHum:MoveTo(myRoot.Position + leftDir * 15)
        elseif not isBlocked(origin, rightDir, 6) then
            myHum:MoveTo(myRoot.Position + rightDir * 15)
        else
            if myHum.FloorMaterial ~= Enum.Material.Air then myHum.Jump = true end
            myHum:MoveTo(target.Position)
        end
    end

    if myHum.MoveDirection.Magnitude > 0.1 and myRoot.AssemblyLinearVelocity.Magnitude < 2.5 then
        stuckTimer = stuckTimer + 0.15
        if stuckTimer > 0.4 then
            if myHum.FloorMaterial ~= Enum.Material.Air then myHum.Jump = true end
            stuckTimer = 0
        end
    else
        stuckTimer = 0
    end
end

-- ==========================================
-- 🍬 CANDY FARM
-- ==========================================
local function findNearestCandy(myRoot)
    if not myRoot then return nil end
    local bestPart, bestDist = nil, math.huge
    local myPos = myRoot.Position

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Parent then
            local name = string.lower(obj.Name)
            if name:find("candy") and not name:find("candycane") then
                local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                if part and part.Parent then
                    local isPlayerPart = false
                    local p = part.Parent
                    while p do
                        if p:IsA("Model") and Players:GetPlayerFromCharacter(p) then
                            isPlayerPart = true
                            break
                        end
                        p = p.Parent
                    end
                    if not isPlayerPart then
                        local d = (part.Position - myPos).Magnitude
                        if d < bestDist and d <= CANDY_SEARCH_RADIUS then
                            bestDist = d
                            bestPart = part
                        end
                    end
                end
            end
        end
    end
    return bestPart
end

local function updateCandyFarm()
    if not candyFarmEnabled then return end
    local _, hum, root = getAlive(me)
    if not hum or not root then return end

    local now = tick()
    if now - lastCandyTeleport < CANDY_TELEPORT_DELAY then return end

    local candy = findNearestCandy(root)
    if candy then
        lastCandyTeleport = now
        isTeleporting = true
        pcall(function()
            root.CFrame = candy.CFrame + Vector3.new(0, 3, 0)
        end)
        task.delay(0.1, function() isTeleporting = false end)
    end
end

-- ==== Kill Aura ====
local function runKillAura()
    if not killAuraEnabled or not punchRemote then return end
    if tick() - lastAuraHit < KILLAURA_COOLDOWN then return end
    local char, hum, root = getAlive(me)
    if not char or not root or hasForceField() then return end
    local myPos = root.Position
    local bestTarget, bestRoot = nil, nil
    local lowestDist = KILLAURA_RADIUS

    if targetPlayer then
        local tc, _, tr = getRealTarget(targetPlayer)
        if tc and tr then
            local d = (tr.Position - myPos).Magnitude
            if d <= lowestDist then lowestDist = d; bestTarget = tc; bestRoot = tr end
        end
    end

    if not bestTarget then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= me then
                local tChar, _, tRoot = getRealTarget(plr)
                if tChar and tRoot then
                    local dist = (tRoot.Position - myPos).Magnitude
                    if dist <= lowestDist then lowestDist = dist; bestTarget = tChar; bestRoot = tRoot end
                end
            end
        end
    end

    if bestTarget and bestRoot then
        faceTarget(bestRoot)
        local args = { bestTarget, bestRoot.Position, 2.444483757019043,
            bestTarget:FindFirstChild("Right Arm") or bestTarget:FindFirstChild("RightHand") }
        pcall(function() punchRemote:FireServer(unpack(args)) end)
        lastAuraHit = tick()
    end
end

-- ==== KEY ESP ====
local function clearKeyESP()
    for obj, data in pairs(keyEspObjects) do
        if data.highlight then pcall(function() data.highlight:Destroy() end) end
        if data.billboard then pcall(function() data.billboard:Destroy() end) end
    end
    keyEspObjects = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "FemboyKeyHighlight" or obj.Name == "FemboyKeyBB" then
            pcall(function() obj:Destroy() end)
        end
    end
end

local function updateKeyESP()
    if not keyEspEnabled then return end
    local currentKeys = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        local name = string.lower(obj.Name)
        if name:find("key") and not name:find("monkey") and not name:find("turkey") then
            if obj:IsA("Model") or obj:IsA("BasePart") or obj:IsA("Tool") then
                local targetPart = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                if targetPart and not targetPart:IsDescendantOf(me.Character) then
                    currentKeys[obj] = targetPart
                end
            end
        end
    end
    for obj, data in pairs(keyEspObjects) do
        if not currentKeys[obj] then
            if data.highlight then pcall(function() data.highlight:Destroy() end) end
            if data.billboard then pcall(function() data.billboard:Destroy() end) end
            keyEspObjects[obj] = nil
        end
    end
    for obj, targetPart in pairs(currentKeys) do
        if not keyEspObjects[obj] then
            local hl = Instance.new("Highlight")
            hl.Name = "FemboyKeyHighlight"
            hl.Parent = obj:IsA("Model") and obj or targetPart
            hl.FillColor = COLORS.yellow
            hl.OutlineColor = COLORS.yellow
            hl.FillTransparency = 0.5

            local bb = Instance.new("BillboardGui")
            bb.Name = "FemboyKeyBB"
            bb.Adornee = targetPart
            bb.Size = UDim2.new(0, 100, 0, 50)
            bb.StudsOffset = Vector3.new(0, 2.5, 0)
            bb.AlwaysOnTop = true
            bb.Parent = targetPart

            local txt = Instance.new("TextLabel")
            txt.Size = UDim2.new(1,0,1,0)
            txt.BackgroundTransparency = 1
            txt.Text = "🔑 ASTRA KEY"
            txt.TextColor3 = COLORS.yellow
            txt.Font = Enum.Font.GothamBold
            txt.TextSize = 14
            txt.TextStrokeTransparency = 0
            txt.Parent = bb

            keyEspObjects[obj] = {highlight = hl, billboard = bb}
        end
    end
end

-- ==== Телепорты ====
local function teleportToAstralFixed()
    local _, _, root = getAlive(me)
    if root then
        root.CFrame = ASTRAL_PORTAL_CFRAME
        setBadgeLog("🚀 ТП на -90, 18, 125!")
    else setBadgeLog("❌ Нет персонажа") end
end

local function saveCurrentPosition()
    local _, _, root = getAlive(me)
    if root then
        savedPos = root.CFrame
        setBadgeLog("✅ Сохранено!")
    else setBadgeLog("❌ Нет персонажа") end
end

local function teleportToSaved()
    if not savedPos then setBadgeLog("❌ Сначала нажми Save This Spot!"); return end
    local _, _, root = getAlive(me)
    if root then root.CFrame = savedPos; setBadgeLog("🚀 ТП в сохраненную точку!") end
end

local function teleportToBackrooms()
    setBadgeLog("Ищу The Backrooms...")
    task.spawn(function()
        local targetPart = nil
        for _, obj in ipairs(workspace:GetDescendants()) do
            local name = string.lower(obj.Name)
            if name:find("backroom") or name:find("yellow room") or name:find("liminal") then
                if obj:IsA("SpawnLocation") then targetPart = obj; break
                elseif obj:IsA("BasePart") and obj.Size.Magnitude > 100 then targetPart = obj; break
                elseif not targetPart and obj:IsA("BasePart") and obj.Position.Magnitude > 10 then targetPart = obj end
            end
        end
        if targetPart then
            local _, _, myRoot = getAlive(me)
            if myRoot then myRoot.CFrame = targetPart.CFrame + Vector3.new(0, 5, 0); setBadgeLog("✅ ТП в The Backrooms.") end
        else setBadgeLog("❌ Закулисье не найдено.") end
    end)
end

-- ==== ESP ====
local function destroyESP(char)
    local data = espObjects[char]
    if not data then return end
    for _, obj in pairs(data) do pcall(function() obj:Destroy() end) end
    espObjects[char] = nil
end

local function destroyAllESP()
    for char in pairs(espObjects) do destroyESP(char) end
    espObjects = {}
end

local function applyESP(character)
    if not character or not character.Parent or espObjects[character] then return end
    local head = character:FindFirstChild("Head")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local highlight = Instance.new("Highlight")
    highlight.Parent = character
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 0
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)

    local billboard = Instance.new("BillboardGui")
    billboard.Parent = character
    billboard.Adornee = head or root
    billboard.Size = UDim2.new(0, 220, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true

    local textLabel = Instance.new("TextLabel")
    textLabel.Parent = billboard
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextSize = 13
    textLabel.TextStrokeTransparency = 0.5

    espObjects[character] = {highlight, billboard, textLabel}
end

local function refreshESP()
    destroyAllESP()
    if not espEnabled then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= me and plr.Character then applyESP(plr.Character) end
    end
end

local function updateESP()
    if not espEnabled then return end
    local _, _, myRoot = getAlive(me)
    if not myRoot then return end
    for char, data in pairs(espObjects) do
        if not char.Parent then
            destroyESP(char)
        else
            local plr = Players:GetPlayerFromCharacter(char)
            if plr then
                local hum = char:FindFirstChildOfClass("Humanoid")
                local root = char:FindFirstChild("HumanoidRootPart")
                if hum and root then
                    local dist = (root.Position - myRoot.Position).Magnitude
                    data[3].Text = string.format("%.1fm | %d HP | %s", dist, math.floor(hum.Health), plr.Name)
                else destroyESP(char) end
            else destroyESP(char) end
        end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= me and plr.Character and not espObjects[plr.Character] then
            applyESP(plr.Character)
        end
    end
end

-- ==== Anti-Fling ====
local function applyAntiFling()
    if not antiFling or isTeleporting then return end
    local _, _, myRoot = getAlive(me)
    if not myRoot then return end
    if myRoot.AssemblyLinearVelocity.Magnitude > ANTI_FLING_THRESHOLD then
        pcall(function()
            myRoot.AssemblyLinearVelocity = Vector3.zero
            myRoot.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

-- ==== Спавн ====
local function onSpawn()
    currentTarget  = nil
    isTeleporting = false
    lastFarmTeleport = 0
    farmTeleportAttempts = 0
    walkToPortalMode = false
    savedHeadState = nil
    savedLegState = nil
    currentHat = nil
    if flyEnabled then
        flyEnabled = false
        if flyBV then flyBV:Destroy(); flyBV = nil end
        if flyBG then flyBG:Destroy(); flyBG = nil end
    end
    task.spawn(function()
        task.wait(1)
        setAutoRotate(not autoAim)
        if espEnabled then refreshESP() end
        if hitboxEnabled then applyHitbox() end
        local _, hum = getAlive(me)
        if hum then
            hum.WalkSpeed = customWalkSpeed
            hum.JumpPower = customJumpPower
            hum.UseJumpPower = true
        end
        if fakeHeadlessEnabled then applyHeadless() end
        if fakeKorbloxEnabled then applyKorblox() end
        refreshTags()
        if chineseHatEnabled then
            chineseHatEnabled = false
            toggleChineseHat()
        end
    end)
end
if me.Character then task.spawn(onSpawn) end
me.CharacterAdded:Connect(onSpawn)

Players.PlayerRemoving:Connect(function(plr)
    if plr.Character then destroyESP(plr.Character) end
    remTag(plr)
    if plr == targetPlayer then targetPlayer = nil end
end)

-- ==== Движение ====
local function getMoveVector()
    local playerScripts = me:FindFirstChild("PlayerScripts")
    if playerScripts then
        local playerModule = playerScripts:FindFirstChild("PlayerModule")
        if playerModule then
            local ok, controls = pcall(function() return require(playerModule):GetControls() end)
            if ok and controls then
                local vec = controls:GetMoveVector()
                if vec then return vec end
            end
        end
    end
    local _, hum = getAlive(me)
    if hum then
        local md = hum.MoveDirection
        return Vector3.new(md.X, 0, md.Z)
    end
    return Vector3.zero
end

local function toggleFly()
    local char, hum, root = getAlive(me)
    if not root or not hum then return end
    if flyEnabled then
        flyBV = Instance.new("BodyVelocity")
        flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        flyBV.Velocity = Vector3.new(0, 0, 0)
        flyBV.Parent = root
        flyBG = Instance.new("BodyGyro")
        flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        flyBG.P = 10000
        flyBG.D = 1000
        flyBG.CFrame = root.CFrame
        flyBG.Parent = root
        hum.PlatformStand = true
    else
        if flyBV then flyBV:Destroy(); flyBV = nil end
        if flyBG then flyBG:Destroy(); flyBG = nil end
        hum.PlatformStand = false
    end
end

RunService.RenderStepped:Connect(function()
    if flyEnabled and flyBV and flyBV.Parent then
        local char, hum, root = getAlive(me)
        if not hum or not root then
            flyEnabled = false
            if flyBV then flyBV:Destroy(); flyBV = nil end
            if flyBG then flyBG:Destroy(); flyBG = nil end
            return
        end
        local cam = workspace.CurrentCamera
        local dir = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
        local moveVec = getMoveVector()
        if moveVec.Magnitude > 0.01 then
            dir += cam.CFrame.LookVector * -moveVec.Z + cam.CFrame.RightVector * moveVec.X
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.new(0, 1, 0) end
        flyBV.Velocity = dir * FLY_SPEED
        flyBG.CFrame = cam.CFrame
        hum.PlatformStand = true
    end
end)

RunService.Stepped:Connect(function()
    if noclipEnabled and me.Character then
        for _, v in pairs(me.Character:GetDescendants()) do
            if v:IsA("BasePart") and v.CanCollide then
                v.CanCollide = false
            end
        end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if infJumpEnabled then
        local _, hum = getAlive(me)
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- ==========================================
-- UI
-- ==========================================
local function buildUI()
    local parent = gethui and gethui() or game:GetService("CoreGui")
    local gui = Instance.new("ScreenGui")
    gui.Name = "HeadShotStyleUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = parent

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 480, 0, 400)
    main.Position = UDim2.new(0.5, -240, 0.5, -200)
    main.BackgroundColor3 = COLORS.bg
    main.BorderSizePixel = 0
    main.Parent = gui
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", main)
    stroke.Color = COLORS.stroke
    stroke.Thickness = 1

    local miniBtn = Instance.new("TextButton")
    miniBtn.Size = UDim2.new(0, 45, 0, 45)
    miniBtn.Position = UDim2.new(0, 50, 0, 50)
    miniBtn.BackgroundColor3 = COLORS.bg
    miniBtn.BorderSizePixel = 0
    miniBtn.Text = "F"
    miniBtn.TextColor3 = COLORS.accent
    miniBtn.Font = Enum.Font.GothamBold
    miniBtn.TextSize = 20
    miniBtn.Visible = false
    miniBtn.Active = true
    miniBtn.Parent = gui
    Instance.new("UICorner", miniBtn).CornerRadius = UDim.new(0, 8)
    local miniStroke = Instance.new("UIStroke", miniBtn)
    miniStroke.Color = COLORS.accent
    miniStroke.Thickness = 2

    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 36)
    topBar.BackgroundColor3 = COLORS.topbar
    topBar.BorderSizePixel = 0
    topBar.Parent = main
    Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 6)
    local topBarFix = Instance.new("Frame")
    topBarFix.Size = UDim2.new(1, 0, 6, 0)
    topBarFix.Position = UDim2.new(0, 0, 1, -6)
    topBarFix.BackgroundColor3 = COLORS.topbar
    topBarFix.BorderSizePixel = 0
    topBarFix.Parent = topBar

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0, 200, 0, 20)
    title.Position = UDim2.new(0, 12, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "Femboy Hub"
    title.TextColor3 = COLORS.accent
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = topBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 20, 0, 20)
    closeBtn.Position = UDim2.new(1, -28, 0, 8)
    closeBtn.BackgroundTransparency = 1
    closeBtn.Text = "×"
    closeBtn.TextColor3 = COLORS.textDim
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.Parent = topBar
    closeBtn.MouseButton1Click:Connect(function() gui.Enabled = false end)

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 20, 0, 20)
    minBtn.Position = UDim2.new(1, -50, 0, 8)
    minBtn.BackgroundTransparency = 1
    minBtn.Text = "—"
    minBtn.TextColor3 = COLORS.textDim
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 14
    minBtn.Parent = topBar
    minBtn.MouseButton1Click:Connect(function()
        main.Visible = false
        miniBtn.Visible = true
    end)

    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, 130, 1, -36)
    sidebar.Position = UDim2.new(0, 0, 0, 36)
    sidebar.BackgroundColor3 = COLORS.sidebar
    sidebar.BorderSizePixel = 0
    sidebar.Parent = main

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -130, 1, -36)
    content.Position = UDim2.new(0, 130, 0, 36)
    content.BackgroundTransparency = 1
    content.Parent = main

    local function createTab(text, icon, y, pageName)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -10, 0, 26)
        btn.Position = UDim2.new(0, 5, 0, y)
        btn.BackgroundColor3 = COLORS.sidebar
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Parent = sidebar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        local iconLbl = Instance.new("TextLabel")
        iconLbl.Size = UDim2.new(0, 20, 0, 20)
        iconLbl.Position = UDim2.new(0, 6, 0, 3)
        iconLbl.BackgroundTransparency = 1
        iconLbl.Text = icon
        iconLbl.TextColor3 = COLORS.textDim
        iconLbl.TextSize = 12
        iconLbl.Parent = btn
        local txtLbl = Instance.new("TextLabel")
        txtLbl.Size = UDim2.new(1, -30, 1, 0)
        txtLbl.Position = UDim2.new(0, 28, 0, 0)
        txtLbl.BackgroundTransparency = 1
        txtLbl.Text = text
        txtLbl.TextColor3 = COLORS.textDim
        txtLbl.Font = Enum.Font.GothamBold
        txtLbl.TextSize = 11
        txtLbl.TextXAlignment = Enum.TextXAlignment.Left
        txtLbl.Parent = btn
        return {btn = btn, icon = iconLbl, txt = txtLbl, page = pageName}
    end

    local pages = {}
    local function createPage(name)
        local p = Instance.new("Frame")
        p.Size = UDim2.new(1, -20, 1, -20)
        p.Position = UDim2.new(0, 10, 0, 10)
        p.BackgroundTransparency = 1
        p.Visible = false
        p.Name = name
        p.Parent = content
        pages[name] = p
        return p
    end

    local pageMain    = createPage("Main")
    local pagePlayer  = createPage("Player")
    local pageCombat  = createPage("Combat")
    local pageBadges  = createPage("Badges")
    local pageFake    = createPage("Fake")
    local pageChat    = createPage("Chat")
    local pageUsers   = createPage("Users")
    local pageMisc    = createPage("Misc")
    local pageFling   = createPage("Fling")
    local pageESP     = createPage("ESP")
    local pageCandy   = createPage("Candy")

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(1, 0, 0, 30)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = "Status: Waiting..."
    statusLbl.TextColor3 = COLORS.accent
    statusLbl.Font = Enum.Font.GothamBold
    statusLbl.TextSize = 12
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left
    statusLbl.Parent = pageMain

    local function createBtn(text, parent, y)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 30)
        b.Position = UDim2.new(0, 0, 0, y)
        b.BackgroundColor3 = COLORS.activeTab
        b.Text = text
        b.TextColor3 = COLORS.text
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        b.Parent = parent
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        return b
    end

    local startBtn = createBtn("Start TP Farm", pageMain, 40)
    local walkBtn  = createBtn("Start Walk Farm", pageMain, 80)
    local stopBtn  = createBtn("Stop All", pageMain, 120)

    local afkBtn = createBtn("Anti-AFK: " .. (antiAFK and "ON" or "OFF"), pagePlayer, 0)
    afkBtn.BackgroundColor3 = antiAFK and COLORS.accent or COLORS.activeTab
    local flyBtn = createBtn("Fly: " .. (flyEnabled and "ON" or "OFF"), pagePlayer, 35)
    flyBtn.BackgroundColor3 = flyEnabled and COLORS.accent or COLORS.activeTab
    local noclipBtn = createBtn("Noclip: " .. (noclipEnabled and "ON" or "OFF"), pagePlayer, 70)
    noclipBtn.BackgroundColor3 = noclipEnabled and COLORS.accent or COLORS.activeTab
    local infJumpBtn = createBtn("Infinite Jump: " .. (infJumpEnabled and "ON" or "OFF"), pagePlayer, 105)
    infJumpBtn.BackgroundColor3 = infJumpEnabled and COLORS.accent or COLORS.activeTab

    local speedLbl = Instance.new("TextLabel")
    speedLbl.Size = UDim2.new(0.45, 0, 0, 26)
    speedLbl.Position = UDim2.new(0, 0, 0, 145)
    speedLbl.BackgroundTransparency = 1
    speedLbl.Text = "Speed:"
    speedLbl.TextColor3 = COLORS.text
    speedLbl.Font = Enum.Font.GothamBold
    speedLbl.TextSize = 12
    speedLbl.TextXAlignment = Enum.TextXAlignment.Left
    speedLbl.Parent = pagePlayer

    local speedBox = Instance.new("TextBox")
    speedBox.Size = UDim2.new(0.5, 0, 0, 26)
    speedBox.Position = UDim2.new(0.5, 0, 0, 145)
    speedBox.BackgroundColor3 = COLORS.sidebar
    speedBox.Text = tostring(customWalkSpeed)
    speedBox.TextColor3 = COLORS.text
    speedBox.Font = Enum.Font.Gotham
    speedBox.TextSize = 12
    speedBox.Parent = pagePlayer
    Instance.new("UICorner", speedBox).CornerRadius = UDim.new(0, 4)

    local jumpLbl = Instance.new("TextLabel")
    jumpLbl.Size = UDim2.new(0.45, 0, 0, 26)
    jumpLbl.Position = UDim2.new(0, 0, 0, 180)
    jumpLbl.BackgroundTransparency = 1
    jumpLbl.Text = "Jump Power:"
    jumpLbl.TextColor3 = COLORS.text
    jumpLbl.Font = Enum.Font.GothamBold
    jumpLbl.TextSize = 12
    jumpLbl.TextXAlignment = Enum.TextXAlignment.Left
    jumpLbl.Parent = pagePlayer

    local jumpBox = Instance.new("TextBox")
    jumpBox.Size = UDim2.new(0.5, 0, 0, 26)
    jumpBox.Position = UDim2.new(0.5, 0, 0, 180)
    jumpBox.BackgroundColor3 = COLORS.sidebar
    jumpBox.Text = tostring(customJumpPower)
    jumpBox.TextColor3 = COLORS.text
    jumpBox.Font = Enum.Font.Gotham
    jumpBox.TextSize = 12
    jumpBox.Parent = pagePlayer
    Instance.new("UICorner", jumpBox).CornerRadius = UDim.new(0, 4)

    local targetLbl = Instance.new("TextLabel")
    targetLbl.Size = UDim2.new(1, 0, 0, 20)
    targetLbl.BackgroundTransparency = 1
    targetLbl.Text = "Target Player Name:"
    targetLbl.TextColor3 = COLORS.textDim
    targetLbl.Font = Enum.Font.GothamBold
    targetLbl.TextSize = 11
    targetLbl.TextXAlignment = Enum.TextXAlignment.Left
    targetLbl.Parent = pageCombat

    local targetBox = Instance.new("TextBox")
    targetBox.Size = UDim2.new(0.55, 0, 0, 26)
    targetBox.Position = UDim2.new(0, 0, 0, 25)
    targetBox.BackgroundColor3 = COLORS.sidebar
    targetBox.PlaceholderText = "Ник..."
    targetBox.TextColor3 = COLORS.text
    targetBox.Font = Enum.Font.Gotham
    targetBox.TextSize = 11
    targetBox.Parent = pageCombat
    Instance.new("UICorner", targetBox).CornerRadius = UDim.new(0, 4)

    local setBtn = Instance.new("TextButton")
    setBtn.Size = UDim2.new(0.2, -2, 0, 26)
    setBtn.Position = UDim2.new(0.55, 2, 0, 25)
    setBtn.BackgroundColor3 = COLORS.accent
    setBtn.Text = "Set"
    setBtn.TextColor3 = COLORS.text
    setBtn.Font = Enum.Font.GothamBold
    setBtn.TextSize = 11
    setBtn.Parent = pageCombat
    Instance.new("UICorner", setBtn).CornerRadius = UDim.new(0, 4)

    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0.25, -2, 0, 26)
    clearBtn.Position = UDim2.new(0.75, 2, 0, 25)
    clearBtn.BackgroundColor3 = COLORS.red
    clearBtn.Text = "Clear"
    clearBtn.TextColor3 = COLORS.text
    clearBtn.Font = Enum.Font.GothamBold
    clearBtn.TextSize = 11
    clearBtn.Parent = pageCombat
    Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0, 4)

    local playerListFrame = Instance.new("ScrollingFrame")
    playerListFrame.Size = UDim2.new(1, 0, 0, 100)
    playerListFrame.Position = UDim2.new(0, 0, 0, 60)
    playerListFrame.BackgroundColor3 = COLORS.bg
    playerListFrame.BorderSizePixel = 0
    playerListFrame.ScrollBarThickness = 6
    playerListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    playerListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    playerListFrame.Parent = pageCombat
    Instance.new("UICorner", playerListFrame).CornerRadius = UDim.new(0, 4)

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 2)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = playerListFrame

    local function updatePlayerList()
        for _, child in ipairs(playerListFrame:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        local index = 1
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= me then
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, -4, 0, 24)
                btn.BackgroundColor3 = COLORS.activeTab
                btn.Text = plr.Name
                btn.TextColor3 = COLORS.text
                btn.Font = Enum.Font.Gotham
                btn.TextSize = 11
                btn.LayoutOrder = index
                btn.Parent = playerListFrame
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
                btn.MouseButton1Click:Connect(function()
                    targetPlayer = plr
                    targetBox.Text = plr.Name
                end)
                index = index + 1
            end
        end
    end
    task.spawn(updatePlayerList)
    Players.PlayerAdded:Connect(function() task.wait(1); updatePlayerList() end)
    Players.PlayerRemoving:Connect(function() task.wait(1); updatePlayerList() end)

    local autoAimBtn = createBtn("Auto Aim: " .. (autoAim and "ON" or "OFF"), pageCombat, 165)
    autoAimBtn.BackgroundColor3 = autoAim and COLORS.accent or COLORS.activeTab
    local killAuraBtn = createBtn("Kill Aura: " .. (killAuraEnabled and "ON" or "OFF"), pageCombat, 205)
    killAuraBtn.BackgroundColor3 = killAuraEnabled and COLORS.accent or COLORS.activeTab
    local hitboxBtn = createBtn("Hitbox: " .. (hitboxEnabled and "ON" or "OFF"), pageCombat, 245)
    hitboxBtn.BackgroundColor3 = hitboxEnabled and COLORS.accent or COLORS.activeTab

    local badgeTitle = Instance.new("TextLabel")
    badgeTitle.Size = UDim2.new(1, 0, 0, 20)
    badgeTitle.BackgroundTransparency = 1
    badgeTitle.Text = "Телепорт по Измерениям"
    badgeTitle.TextColor3 = COLORS.text
    badgeTitle.Font = Enum.Font.GothamBold
    badgeTitle.TextSize = 12
    badgeTitle.TextXAlignment = Enum.TextXAlignment.Left
    badgeTitle.Parent = pageBadges

    local function createBadgeItem(name, desc, y, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -10, 0, 30)
        b.Position = UDim2.new(0, 0, 0, y)
        b.BackgroundColor3 = color
        b.Text = name
        b.TextColor3 = COLORS.text
        b.Font = Enum.Font.GothamBold
        b.TextSize = 12
        b.Parent = pageBadges
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        if desc then
            local d = Instance.new("TextLabel")
            d.Size = UDim2.new(1, -10, 0, 15)
            d.Position = UDim2.new(0, 0, 0, y + 32)
            d.BackgroundTransparency = 1
            d.Text = desc
            d.TextColor3 = COLORS.textDim
            d.Font = Enum.Font.Gotham
            d.TextSize = 10
            d.TextXAlignment = Enum.TextXAlignment.Left
            d.TextWrapped = true
            d.Parent = pageBadges
        end
        return b
    end

    local astralFixedBtn = createBadgeItem("Astral Portal (FIXED)", "ТП на -90, 18, 125", 30, Color3.fromRGB(100, 80, 200))
    keyEspBtn = createBadgeItem("Key ESP: " .. (keyEspEnabled and "ON" or "OFF"), "Подсветить Астральный ключ", 90, keyEspEnabled and COLORS.yellow or COLORS.activeTab)
    local saveBtn = createBadgeItem("Save This Spot", "Сохранить текущую позицию", 150, COLORS.activeTab)
    local tpsaveBtn = createBadgeItem("TP To Saved Spot", "Вернуться в сохраненную точку", 210, COLORS.activeTab)
    local backroomsBtn = createBadgeItem("The Backrooms", "Мгновенный ТП в желтые комнаты", 270, Color3.fromRGB(180, 160, 60))

    local badgeLogLabel = Instance.new("TextLabel")
    badgeLogLabel.Size = UDim2.new(1, -10, 0, 40)
    badgeLogLabel.Position = UDim2.new(0, 0, 0, 330)
    badgeLogLabel.BackgroundColor3 = COLORS.sidebar
    badgeLogLabel.Text = "🤖 Статус: Ожидание"
    badgeLogLabel.TextColor3 = COLORS.text
    badgeLogLabel.Font = Enum.Font.GothamBold
    badgeLogLabel.TextSize = 11
    badgeLogLabel.TextXAlignment = Enum.TextXAlignment.Left
    badgeLogLabel.TextWrapped = true
    badgeLogLabel.Parent = pageBadges
    Instance.new("UICorner", badgeLogLabel).CornerRadius = UDim.new(0, 4)
    table.insert(logLabels, badgeLogLabel)

    astralFixedBtn.MouseButton1Click:Connect(function() teleportToAstralFixed() end)
    keyEspBtn.MouseButton1Click:Connect(function()
        keyEspEnabled = not keyEspEnabled
        keyEspBtn.Text = "Key ESP: " .. (keyEspEnabled and "ON" or "OFF")
        keyEspBtn.BackgroundColor3 = keyEspEnabled and COLORS.yellow or COLORS.activeTab
        keyEspBtn.TextColor3 = keyEspEnabled and Color3.fromRGB(0,0,0) or COLORS.text
        if keyEspBtn2 then
            keyEspBtn2.Text = "Key ESP: " .. (keyEspEnabled and "ON" or "OFF")
            keyEspBtn2.BackgroundColor3 = keyEspEnabled and COLORS.yellow or COLORS.activeTab
            keyEspBtn2.TextColor3 = keyEspEnabled and Color3.fromRGB(0,0,0) or COLORS.text
        end
        if not keyEspEnabled then clearKeyESP() end
        saveConfig()
    end)
    saveBtn.MouseButton1Click:Connect(function() saveCurrentPosition() end)
    tpsaveBtn.MouseButton1Click:Connect(function() teleportToSaved() end)
    backroomsBtn.MouseButton1Click:Connect(function() teleportToBackrooms() end)

    local fakeTitle = Instance.new("TextLabel")
    fakeTitle.Size = UDim2.new(1, 0, 0, 20)
    fakeTitle.BackgroundTransparency = 1
    fakeTitle.Text = "Фейковые эффекты"
    fakeTitle.TextColor3 = COLORS.text
    fakeTitle.Font = Enum.Font.GothamBold
    fakeTitle.TextSize = 12
    fakeTitle.TextXAlignment = Enum.TextXAlignment.Left
    fakeTitle.Parent = pageFake

    headlessBtn = createBtn("💀 Fake Headless: " .. (fakeHeadlessEnabled and "ON" or "OFF"), pageFake, 40)
    headlessBtn.BackgroundColor3 = fakeHeadlessEnabled and COLORS.accent or COLORS.activeTab
    korbloxBtn  = createBtn("🦵 Fake Korblox: " .. (fakeKorbloxEnabled and "ON" or "OFF"), pageFake, 80)
    korbloxBtn.BackgroundColor3 = fakeKorbloxEnabled and COLORS.accent or COLORS.activeTab

    local fakeLog = Instance.new("TextLabel")
    fakeLog.Size = UDim2.new(1, -10, 0, 50)
    fakeLog.Position = UDim2.new(0, 0, 0, 140)
    fakeLog.BackgroundColor3 = COLORS.sidebar
    fakeLog.Text = "🤖 Готов"
    fakeLog.TextColor3 = COLORS.text
    fakeLog.Font = Enum.Font.GothamBold
    fakeLog.TextSize = 11
    fakeLog.TextXAlignment = Enum.TextXAlignment.Left
    fakeLog.TextWrapped = true
    fakeLog.Parent = pageFake
    Instance.new("UICorner", fakeLog).CornerRadius = UDim.new(0, 4)
    table.insert(logLabels, fakeLog)

    headlessBtn.MouseButton1Click:Connect(function()
        fakeHeadlessEnabled = not fakeHeadlessEnabled
        headlessBtn.Text = "💀 Fake Headless: " .. (fakeHeadlessEnabled and "ON" or "OFF")
        headlessBtn.BackgroundColor3 = fakeHeadlessEnabled and COLORS.accent or COLORS.activeTab
        if fakeHeadlessEnabled then applyHeadless() else removeHeadless() end
        saveConfig()
    end)

    korbloxBtn.MouseButton1Click:Connect(function()
        fakeKorbloxEnabled = not fakeKorbloxEnabled
        korbloxBtn.Text = "🦵 Fake Korblox: " .. (fakeKorbloxEnabled and "ON" or "OFF")
        korbloxBtn.BackgroundColor3 = fakeKorbloxEnabled and COLORS.accent or COLORS.activeTab
        if fakeKorbloxEnabled then applyKorblox() else removeKorblox() end
        saveConfig()
    end)

    local miscTitle = Instance.new("TextLabel")
    miscTitle.Size = UDim2.new(1, 0, 0, 20)
    miscTitle.BackgroundTransparency = 1
    miscTitle.Text = "Утилиты"
    miscTitle.TextColor3 = COLORS.text
    miscTitle.Font = Enum.Font.GothamBold
    miscTitle.TextSize = 12
    miscTitle.TextXAlignment = Enum.TextXAlignment.Left
    miscTitle.Parent = pageMisc

    optimizeBtn = createBtn("Optimize: " .. (optimizationEnabled and "ON" or "OFF"), pageMisc, 25)
    optimizeBtn.BackgroundColor3 = optimizationEnabled and COLORS.green or COLORS.activeTab
    optimizeBtn.MouseButton1Click:Connect(function() toggleOptimization() end)

    autoClickBtn = createBtn("Auto Click: " .. (autoClickEnabled and "ON" or "OFF"), pageMisc, 60)
    autoClickBtn.BackgroundColor3 = autoClickEnabled and COLORS.green or COLORS.activeTab
    autoClickBtn.MouseButton1Click:Connect(function() toggleAutoClicker() end)

    cameraClipBtn = createBtn("Camera Clip: " .. (cameraClipEnabled and "ON" or "OFF"), pageMisc, 95)
    cameraClipBtn.BackgroundColor3 = cameraClipEnabled and COLORS.green or COLORS.activeTab
    cameraClipBtn.MouseButton1Click:Connect(function() toggleCameraClip() end)

    local cpsLbl = Instance.new("TextLabel")
    cpsLbl.Size = UDim2.new(0.4, 0, 0, 26)
    cpsLbl.Position = UDim2.new(0, 0, 0, 135)
    cpsLbl.BackgroundTransparency = 1
    cpsLbl.Text = "CPS (1-100):"
    cpsLbl.TextColor3 = COLORS.textDim
    cpsLbl.Font = Enum.Font.GothamBold
    cpsLbl.TextSize = 11
    cpsLbl.TextXAlignment = Enum.TextXAlignment.Left
    cpsLbl.Parent = pageMisc

    local cpsBox = Instance.new("TextBox")
    cpsBox.Size = UDim2.new(0.5, 0, 0, 26)
    cpsBox.Position = UDim2.new(0.45, 0, 0, 135)
    cpsBox.BackgroundColor3 = COLORS.sidebar
    cpsBox.Text = tostring(autoClickCPS)
    cpsBox.TextColor3 = COLORS.text
    cpsBox.Font = Enum.Font.Gotham
    cpsBox.TextSize = 12
    cpsBox.Parent = pageMisc
    Instance.new("UICorner", cpsBox).CornerRadius = UDim.new(0, 4)
    cpsBox.FocusLost:Connect(function()
        local val = tonumber(cpsBox.Text)
        if val and val >= 1 and val <= 100 then
            autoClickCPS = val
            saveConfig()
            if autoClickEnabled then startAutoClicker() end
        else
            cpsBox.Text = tostring(autoClickCPS)
        end
    end)

    local hatIdBox = Instance.new("TextBox")
    hatIdBox.Size = UDim2.new(0.4, 0, 0, 26)
    hatIdBox.Position = UDim2.new(0, 0, 0, 200)
    hatIdBox.BackgroundColor3 = COLORS.sidebar
    hatIdBox.Text = tostring(chineseHatId)
    hatIdBox.TextColor3 = COLORS.text
    hatIdBox.Font = Enum.Font.Gotham
    hatIdBox.TextSize = 12
    hatIdBox.Parent = pageMisc
    Instance.new("UICorner", hatIdBox).CornerRadius = UDim.new(0, 4)

    hatBtn = createBtn("Chinese Hat: " .. (chineseHatEnabled and "ON" or "OFF"), pageMisc, 165)
    hatBtn.BackgroundColor3 = chineseHatEnabled and COLORS.accent or COLORS.activeTab
    hatBtn.MouseButton1Click:Connect(function()
        chineseHatId = tonumber(hatIdBox.Text) or chineseHatId
        toggleChineseHat()
    end)

    local miscLog = Instance.new("TextLabel")
    miscLog.Size = UDim2.new(1, -10, 0, 40)
    miscLog.Position = UDim2.new(0, 0, 0, 240)
    miscLog.BackgroundColor3 = COLORS.sidebar
    miscLog.Text = "Статус утилит"
    miscLog.TextColor3 = COLORS.textDim
    miscLog.Font = Enum.Font.Gotham
    miscLog.TextSize = 10
    miscLog.TextXAlignment = Enum.TextXAlignment.Left
    miscLog.TextWrapped = true
    miscLog.Parent = pageMisc
    Instance.new("UICorner", miscLog).CornerRadius = UDim.new(0, 4)
    table.insert(logLabels, miscLog)

    -- CANDY
    local candyTitle = Instance.new("TextLabel")
    candyTitle.Size = UDim2.new(1, 0, 0, 20)
    candyTitle.BackgroundTransparency = 1
    candyTitle.Text = "🍬 Candy Farm"
    candyTitle.TextColor3 = COLORS.text
    candyTitle.Font = Enum.Font.GothamBold
    candyTitle.TextSize = 13
    candyTitle.TextXAlignment = Enum.TextXAlignment.Left
    candyTitle.Parent = pageCandy

    local candyDesc = Instance.new("TextLabel")
    candyDesc.Size = UDim2.new(1, 0, 0, 40)
    candyDesc.Position = UDim2.new(0, 0, 0, 25)
    candyDesc.BackgroundTransparency = 1
    candyDesc.Text = "Автоматически телепортируется к каждой падающей конфете. Работает во время события Конфетный Фарм."
    candyDesc.TextColor3 = COLORS.textDim
    candyDesc.Font = Enum.Font.Gotham
    candyDesc.TextSize = 10
    candyDesc.TextXAlignment = Enum.TextXAlignment.Left
    candyDesc.TextWrapped = true
    candyDesc.Parent = pageCandy

    candyBtn = createBtn("Candy Farm: " .. (candyFarmEnabled and "ON" or "OFF"), pageCandy, 75)
    candyBtn.BackgroundColor3 = candyFarmEnabled and COLORS.green or COLORS.activeTab
    candyBtn.MouseButton1Click:Connect(function()
        candyFarmEnabled = not candyFarmEnabled
        candyBtn.Text = "Candy Farm: " .. (candyFarmEnabled and "ON" or "OFF")
        candyBtn.BackgroundColor3 = candyFarmEnabled and COLORS.green or COLORS.activeTab
    end)

    local candyLog = Instance.new("TextLabel")
    candyLog.Size = UDim2.new(1, -10, 0, 40)
    candyLog.Position = UDim2.new(0, 0, 0, 130)
    candyLog.BackgroundColor3 = COLORS.sidebar
    candyLog.Text = "Готов к сбору конфет"
    candyLog.TextColor3 = COLORS.textDim
    candyLog.Font = Enum.Font.Gotham
    candyLog.TextSize = 10
    candyLog.TextXAlignment = Enum.TextXAlignment.Left
    candyLog.TextWrapped = true
    candyLog.Parent = pageCandy
    Instance.new("UICorner", candyLog).CornerRadius = UDim.new(0, 4)

    -- CHAT
    local chatHeader = Instance.new("Frame", pageChat)
    chatHeader.Size = UDim2.new(1, -10, 0, 45); chatHeader.BackgroundColor3 = COLORS.bg; chatHeader.BorderSizePixel = 0
    Instance.new("UICorner", chatHeader).CornerRadius = UDim.new(0, 6)

    local chatIcon = Instance.new("Frame", chatHeader)
    chatIcon.Size = UDim2.new(0, 32, 0, 32); chatIcon.Position = UDim2.new(0, 8, 0, 6); chatIcon.BackgroundColor3 = COLORS.pulse
    Instance.new("UICorner", chatIcon).CornerRadius = UDim.new(0, 6)
    local chatIconTxt = Instance.new("TextLabel", chatIcon); chatIconTxt.Size = UDim2.new(1,0,1,0); chatIconTxt.BackgroundTransparency = 1; chatIconTxt.Text = "F"; chatIconTxt.TextColor3 = Color3.new(1,1,1); chatIconTxt.Font = Enum.Font.GothamBlack; chatIconTxt.TextSize = 18

    local chatTitle = Instance.new("TextLabel", chatHeader)
    chatTitle.Size = UDim2.new(0, 120, 0, 16); chatTitle.Position = UDim2.new(0, 48, 0, 8); chatTitle.BackgroundTransparency = 1
    chatTitle.Text = "Femboy Chat"; chatTitle.TextColor3 = COLORS.text; chatTitle.Font = Enum.Font.GothamBold; chatTitle.TextSize = 14; chatTitle.TextXAlignment = Enum.TextXAlignment.Left

    local onlineLbl = Instance.new("TextLabel", chatHeader)
    onlineLbl.Size = UDim2.new(0, 100, 0, 12); onlineLbl.Position = UDim2.new(0, 48, 0, 24); onlineLbl.BackgroundTransparency = 1
    onlineLbl.Text = "0 messages"; onlineLbl.TextColor3 = COLORS.green; onlineLbl.Font = Enum.Font.Gotham; onlineLbl.TextSize = 10; onlineLbl.TextXAlignment = Enum.TextXAlignment.Left

    chatScroll = Instance.new("ScrollingFrame", pageChat)
    chatScroll.Size = UDim2.new(1, -10, 0, 220); chatScroll.Position = UDim2.new(0, 0, 0, 50); chatScroll.BackgroundTransparency = 1; chatScroll.BorderSizePixel = 0; chatScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y; chatScroll.ScrollBarThickness = 3; chatScroll.ScrollBarImageColor3 = COLORS.textDim
    local chatLayout = Instance.new("UIListLayout", chatScroll); chatLayout.Padding = UDim.new(0, 8)

    local inputBg = Instance.new("Frame", pageChat)
    inputBg.Size = UDim2.new(1, -10, 0, 36); inputBg.Position = UDim2.new(0, 0, 0, 280); inputBg.BackgroundColor3 = COLORS.msgBg
    Instance.new("UICorner", inputBg).CornerRadius = UDim.new(1, 0)

    local chatInput = Instance.new("TextBox", inputBg); chatInput.Size = UDim2.new(1, -50, 1, 0); chatInput.Position = UDim2.new(0, 15, 0, 0); chatInput.BackgroundTransparency = 1; chatInput.Text = ""; chatInput.PlaceholderText = "Message..."; chatInput.TextColor3 = COLORS.text; chatInput.Font = Enum.Font.Gotham; chatInput.TextSize = 12; chatInput.ClearTextOnFocus = false; chatInput.TextXAlignment = Enum.TextXAlignment.Left

    local sendBtn = Instance.new("TextButton", inputBg); sendBtn.Size = UDim2.new(0, 30, 0, 30); sendBtn.Position = UDim2.new(1, -34, 0, 3); sendBtn.BackgroundColor3 = COLORS.pulse; sendBtn.Text = ">"; sendBtn.TextColor3 = Color3.new(1,1,1); sendBtn.Font = Enum.Font.GothamBold; sendBtn.TextSize = 14
    Instance.new("UICorner", sendBtn).CornerRadius = UDim.new(1, 0)

    local function renderChat()
        for _, c in ipairs(chatScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
        onlineLbl.Text = tostring(#chatMessages) .. " messages"

        for i, msg in ipairs(chatMessages) do
            local card = Instance.new("Frame", chatScroll)
            card.Size = UDim2.new(1, -5, 0, 60); card.BackgroundColor3 = COLORS.msgBg; card.BorderSizePixel = 0
            Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
            card.AutomaticSize = Enum.AutomaticSize.Y

            local avatar = Instance.new("ImageLabel", card)
            avatar.Size = UDim2.new(0, 36, 0, 36); avatar.Position = UDim2.new(0, 8, 0, 8); avatar.BackgroundColor3 = COLORS.activeTab
            avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(msg.userId) .. "&w=150&h=150"
            Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)

            local nameLbl = Instance.new("TextLabel", card)
            nameLbl.Size = UDim2.new(1, -60, 0, 16); nameLbl.Position = UDim2.new(0, 52, 0, 8); nameLbl.BackgroundTransparency = 1
            nameLbl.Text = msg.displayName or msg.name; nameLbl.TextColor3 = (msg.userId == me.UserId) and COLORS.pulse or COLORS.blue
            nameLbl.Font = Enum.Font.GothamBold; nameLbl.TextSize = 12; nameLbl.TextXAlignment = Enum.TextXAlignment.Left

            local tagLbl = Instance.new("TextLabel", card)
            tagLbl.Size = UDim2.new(0, 100, 0, 16); tagLbl.Position = UDim2.new(1, -110, 0, 8); tagLbl.BackgroundTransparency = 1
            tagLbl.Text = "@" .. msg.name; tagLbl.TextColor3 = COLORS.textDim; tagLbl.Font = Enum.Font.Gotham; tagLbl.TextSize = 10; tagLbl.TextXAlignment = Enum.TextXAlignment.Right

            local msgLbl = Instance.new("TextLabel", card)
            msgLbl.Size = UDim2.new(1, -60, 0, 0); msgLbl.Position = UDim2.new(0, 52, 0, 26); msgLbl.BackgroundTransparency = 1
            msgLbl.Text = msg.text; msgLbl.TextColor3 = COLORS.text; msgLbl.Font = Enum.Font.Gotham; msgLbl.TextSize = 12; msgLbl.TextXAlignment = Enum.TextXAlignment.Left; msgLbl.TextWrapped = true; msgLbl.AutomaticSize = Enum.AutomaticSize.Y

            local timeLbl = Instance.new("TextLabel", card)
            timeLbl.Size = UDim2.new(0, 50, 0, 12); timeLbl.Position = UDim2.new(1, -55, 0, 26); timeLbl.BackgroundTransparency = 1
            timeLbl.Text = os.date("%H:%M", msg.time); timeLbl.TextColor3 = COLORS.textDim; timeLbl.Font = Enum.Font.Gotham; timeLbl.TextSize = 10; timeLbl.TextXAlignment = Enum.TextXAlignment.Right

            local padding = Instance.new("UIPadding", card); padding.PaddingBottom = UDim.new(0, 8)
        end

        task.defer(function()
            if chatScroll then
                chatScroll.CanvasPosition = Vector2.new(0, 999999)
            end
        end)
    end
    sendBtn.MouseButton1Click:Connect(function() if chatInput.Text ~= "" then sendChat(chatInput.Text); chatInput.Text = ""; task.wait(0.3); fetchChat(); renderChat() end end)
    chatInput.FocusLost:Connect(function(enter) if enter then sendBtn:Fire("MouseButton1Click") end end)
    _G.renderChatUI = renderChat

    usersHeader = Instance.new("TextLabel", pageUsers)
    usersHeader.Size = UDim2.new(1, -10, 0, 30)
    usersHeader.BackgroundColor3 = COLORS.msgBg
    usersHeader.Text = "Femboy Users: 0 online"
    usersHeader.TextColor3 = COLORS.green
    usersHeader.Font = Enum.Font.GothamBold
    usersHeader.TextSize = 12
    Instance.new("UICorner", usersHeader).CornerRadius = UDim.new(0, 6)

    usersScroll = Instance.new("ScrollingFrame", pageUsers)
    usersScroll.Size = UDim2.new(1, -10, 0, 255); usersScroll.Position = UDim2.new(0, 0, 0, 35); usersScroll.BackgroundTransparency = 1; usersScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    local usersLayout = Instance.new("UIListLayout", usersScroll); usersLayout.Padding = UDim.new(0, 4)

    local function renderUsers()
        for _, c in ipairs(usersScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end

        local count = 0
        for _ in pairs(activeUsers) do count = count + 1 end
        usersHeader.Text = "Femboy Users: " .. count .. " online"

        for uid, info in pairs(activeUsers) do
            local row = Instance.new("Frame", usersScroll)
            row.Size = UDim2.new(1, -5, 0, 40); row.BackgroundColor3 = COLORS.msgBg
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

            local av = Instance.new("ImageLabel", row)
            av.Size = UDim2.new(0, 28, 0, 28); av.Position = UDim2.new(0, 6, 0, 6); av.BackgroundColor3 = COLORS.activeTab
            av.Image = "rbxthumb://type=AvatarHeadShot&id=" .. uid .. "&w=150&h=150"
            Instance.new("UICorner", av).CornerRadius = UDim.new(1, 0)

            local n = Instance.new("TextLabel", row); n.Size = UDim2.new(1, -110, 1, 0); n.Position = UDim2.new(0, 42, 0, 0); n.BackgroundTransparency = 1; n.Text = info.displayName or info.name; n.TextColor3 = COLORS.text; n.Font = Enum.Font.GothamBold; n.TextSize = 12; n.TextXAlignment = Enum.TextXAlignment.Left

            if tostring(uid) ~= tostring(me.UserId) then
                local j = Instance.new("TextButton", row); j.Size = UDim2.new(0, 60, 0, 24); j.Position = UDim2.new(1, -64, 0, 8); j.BackgroundColor3 = COLORS.accent; j.Text = "Join"; j.TextSize = 11; j.TextColor3 = Color3.new(1,1,1); j.Font = Enum.Font.GothamBold
                Instance.new("UICorner", j).CornerRadius = UDim.new(0, 4)
                j.MouseButton1Click:Connect(function() pcall(function() TeleportService:TeleportToPlaceInstance(tonumber(info.placeId), info.jobId, me) end) end)
            end
        end
    end
    _G.renderUsersUI = renderUsers

    local flingBtn = createBtn("Anti-Fling: " .. (antiFling and "ON" or "OFF"), pageFling, 0)
    flingBtn.BackgroundColor3 = antiFling and COLORS.accent or COLORS.activeTab
    espBtn = createBtn("ESP: " .. (espEnabled and "ON" or "OFF"), pageESP, 0)
    espBtn.BackgroundColor3 = espEnabled and COLORS.accent or COLORS.activeTab
    keyEspBtn2 = createBtn("Key ESP: " .. (keyEspEnabled and "ON" or "OFF"), pageESP, 35)
    keyEspBtn2.BackgroundColor3 = keyEspEnabled and COLORS.yellow or COLORS.activeTab

    local tMain    = createTab("Main", "📊", 5, "Main")
    local tPlayer  = createTab("Player", "👤", 33, "Player")
    local tCombat  = createTab("Combat", "🛡️", 61, "Combat")
    local tBadges  = createTab("Teleports", "🌌", 89, "Badges")
    local tFake    = createTab("Fake", "💀", 117, "Fake")
    local tMisc    = createTab("Misc", "⚡", 145, "Misc")
    local tCandy   = createTab("Candy", "🍬", 173, "Candy")
    local tChat    = createTab("Chat", "💬", 201, "Chat")
    local tUsers   = createTab("Users", "👥", 229, "Users")
    local tFling   = createTab("Fling", "✈️", 257, "Fling")
    local tESP     = createTab("ESP", "👁️", 285, "ESP")

    local tabs = {tMain, tPlayer, tCombat, tBadges, tFake, tMisc, tCandy, tChat, tUsers, tFling, tESP}
    local activeTab = nil
    local function switchTab(tab)
        if activeTab then
            activeTab.btn.BackgroundTransparency = 1
            activeTab.txt.TextColor3 = COLORS.textDim
            activeTab.icon.TextColor3 = COLORS.textDim
            pages[activeTab.page].Visible = false
        end
        tab.btn.BackgroundTransparency = 0
        tab.btn.BackgroundColor3 = COLORS.activeTab
        tab.txt.TextColor3 = COLORS.text
        tab.icon.TextColor3 = COLORS.accent
        pages[tab.page].Visible = true
        activeTab = tab
    end
    for _, t in ipairs(tabs) do
        t.btn.MouseButton1Click:Connect(function() switchTab(t) end)
    end
    switchTab(tMain)

    local dragging, dragStart, startPos
    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)

    local draggingMini, dragStartMini, startPosMini
    miniBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingMini = true; dragStartMini = input.Position; startPosMini = miniBtn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then draggingMini = false end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                local delta = input.Position - dragStart
                main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            elseif draggingMini then
                local delta = input.Position - dragStartMini
                miniBtn.Position = UDim2.new(startPosMini.X.Scale, startPosMini.X.Offset + delta.X, startPosMini.Y.Scale, startPosMini.Y.Offset + delta.Y)
            end
        end
    end)

    miniBtn.MouseButton1Click:Connect(function()
        miniBtn.Visible = false
        main.Visible = true
    end)

    speedBox.FocusLost:Connect(function()
        local val = tonumber(speedBox.Text)
        if val then customWalkSpeed = val; saveConfig() end
    end)

    jumpBox.FocusLost:Connect(function()
        local val = tonumber(jumpBox.Text)
        if val then customJumpPower = val; saveConfig() end
    end)

    startBtn.MouseButton1Click:Connect(function()
        farming = true
        walkFarmEnabled = false
        farmTeleportAttempts = 0
        lastFarmTeleport = 0
        walkToPortalMode = false
        startBtn.Text = "TP Farm: ON"
        startBtn.BackgroundColor3 = COLORS.green
        walkBtn.Text = "Start Walk Farm"
        walkBtn.BackgroundColor3 = COLORS.activeTab
        local _, _, root = getAlive(me)
        if root then root.CFrame = CFrame.new(FARM_COORDS) + Vector3.new(0, 3, 0) end
    end)

    walkBtn.MouseButton1Click:Connect(function()
        walkFarmEnabled = true
        farming = false
        farmTeleportAttempts = 0
        lastFarmTeleport = 0
        walkToPortalMode = false
        walkBtn.Text = "Walk Farm: ON"
        walkBtn.BackgroundColor3 = COLORS.green
        startBtn.Text = "Start TP Farm"
        startBtn.BackgroundColor3 = COLORS.activeTab
        local _, _, root = getAlive(me)
        if root then root.CFrame = CFrame.new(FARM_COORDS) + Vector3.new(0, 3, 0) end
    end)

    stopBtn.MouseButton1Click:Connect(function()
        farming = false
        walkFarmEnabled = false
        currentTarget = nil
        walkToPortalMode = false
        startBtn.Text = "Start TP Farm"
        startBtn.BackgroundColor3 = COLORS.activeTab
        walkBtn.Text = "Start Walk Farm"
        walkBtn.BackgroundColor3 = COLORS.activeTab
        local _, hum = getAlive(me)
        if hum and hum.RootPart then hum:MoveTo(hum.RootPart.Position) end
    end)

    setBtn.MouseButton1Click:Connect(function()
        local found = findPlayerByName(targetBox.Text)
        if found then targetPlayer = found end
    end)

    clearBtn.MouseButton1Click:Connect(function()
        targetPlayer = nil
        currentTarget = nil
        targetBox.Text = ""
    end)

    autoAimBtn.MouseButton1Click:Connect(function()
        autoAim = not autoAim
        autoAimBtn.Text = "Auto Aim: " .. (autoAim and "ON" or "OFF")
        autoAimBtn.BackgroundColor3 = autoAim and COLORS.accent or COLORS.activeTab
        setAutoRotate(not autoAim)
        saveConfig()
    end)

    killAuraBtn.MouseButton1Click:Connect(function()
        killAuraEnabled = not killAuraEnabled
        killAuraBtn.Text = "Kill Aura: " .. (killAuraEnabled and "ON" or "OFF")
        killAuraBtn.BackgroundColor3 = killAuraEnabled and COLORS.accent or COLORS.activeTab
        saveConfig()
    end)

    hitboxBtn.MouseButton1Click:Connect(function()
        hitboxEnabled = not hitboxEnabled
        hitboxBtn.Text = "Hitbox: " .. (hitboxEnabled and "ON" or "OFF")
        hitboxBtn.BackgroundColor3 = hitboxEnabled and COLORS.accent or COLORS.activeTab
        applyHitbox()
        saveConfig()
    end)

    afkBtn.MouseButton1Click:Connect(function()
        antiAFK = not antiAFK
        afkBtn.Text = "Anti-AFK: " .. (antiAFK and "ON" or "OFF")
        afkBtn.BackgroundColor3 = antiAFK and COLORS.accent or COLORS.activeTab
        saveConfig()
    end)

    flyBtn.MouseButton1Click:Connect(function()
        flyEnabled = not flyEnabled
        flyBtn.Text = "Fly: " .. (flyEnabled and "ON" or "OFF")
        flyBtn.BackgroundColor3 = flyEnabled and COLORS.accent or COLORS.activeTab
        toggleFly()
        saveConfig()
    end)

    noclipBtn.MouseButton1Click:Connect(function()
        noclipEnabled = not noclipEnabled
        noclipBtn.Text = "Noclip: " .. (noclipEnabled and "ON" or "OFF")
        noclipBtn.BackgroundColor3 = noclipEnabled and COLORS.accent or COLORS.activeTab
        saveConfig()
    end)

    infJumpBtn.MouseButton1Click:Connect(function()
        infJumpEnabled = not infJumpEnabled
        infJumpBtn.Text = "Infinite Jump: " .. (infJumpEnabled and "ON" or "OFF")
        infJumpBtn.BackgroundColor3 = infJumpEnabled and COLORS.accent or COLORS.activeTab
        saveConfig()
    end)

    flingBtn.MouseButton1Click:Connect(function()
        antiFling = not antiFling
        flingBtn.Text = "Anti-Fling: " .. (antiFling and "ON" or "OFF")
        flingBtn.BackgroundColor3 = antiFling and COLORS.accent or COLORS.activeTab
        saveConfig()
    end)

    espBtn.MouseButton1Click:Connect(function()
        espEnabled = not espEnabled
        espBtn.Text = "ESP: " .. (espEnabled and "ON" or "OFF")
        espBtn.BackgroundColor3 = espEnabled and COLORS.accent or COLORS.activeTab
        if espEnabled then refreshESP() else destroyAllESP() end
        saveConfig()
    end)

    keyEspBtn2.MouseButton1Click:Connect(function()
        keyEspEnabled = not keyEspEnabled
        keyEspBtn2.Text = "Key ESP: " .. (keyEspEnabled and "ON" or "OFF")
        keyEspBtn2.BackgroundColor3 = keyEspEnabled and COLORS.yellow or COLORS.activeTab
        keyEspBtn2.TextColor3 = keyEspEnabled and Color3.fromRGB(0,0,0) or COLORS.text
        if keyEspBtn then
            keyEspBtn.Text = "Key ESP: " .. (keyEspEnabled and "ON" or "OFF")
            keyEspBtn.BackgroundColor3 = keyEspEnabled and COLORS.yellow or COLORS.activeTab
            keyEspBtn.TextColor3 = keyEspEnabled and Color3.fromRGB(0,0,0) or COLORS.text
        end
        if not keyEspEnabled then clearKeyESP() end
        saveConfig()
    end)

    me.Idled:Connect(function()
        if not antiAFK then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
            task.wait(0.1)
            VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        end)
    end)

    return statusLbl
end

local statusLabel = buildUI()

if optimizationEnabled then toggleOptimization() end
if autoClickEnabled then toggleAutoClicker() end
if cameraClipEnabled then toggleCameraClip() end

-- ==== Главный цикл ====
while true do
    local myChar, myHum, myRoot = getAlive(me)
    local distFarm = distToFarm(myRoot)
    local inArena = (distFarm < 250)

    if myHum then
        myHum.WalkSpeed = customWalkSpeed
        if myHum.UseJumpPower then myHum.JumpPower = customJumpPower end
        if autoAim or killAuraEnabled then myHum.AutoRotate = false end
    end

    if keyEspEnabled then updateKeyESP() end
    if antiFling then applyAntiFling() end

    if hitboxEnabled and myRoot then
        if myRoot.Size.X < HITBOX_SIZE then
            myRoot.Size = Vector3.new(HITBOX_SIZE, HITBOX_SIZE, HITBOX_SIZE)
            myRoot.Transparency = 0.5
            myRoot.CanCollide = false
        end
    end

    if killAuraEnabled then runKillAura() end
    if candyFarmEnabled then updateCandyFarm() end

    if httpFn then
        if (tick() - lastPresenceSend) > 15 then
            lastPresenceSend = tick()
            task.spawn(sendPresence)
        end
        if (tick() - lastUsersCheck) > 10 then
            lastUsersCheck = tick()
            task.spawn(function()
                fetchUsers()
                refreshTags()
                if _G.renderUsersUI then pcall(_G.renderUsersUI) end
            end)
        end
        if (tick() - lastChatCheck) > 3 then
            lastChatCheck = tick()
            task.spawn(function()
                fetchChat()
                if #chatMessages ~= lastRenderedChatCount then
                    lastRenderedChatCount = #chatMessages
                    if _G.renderChatUI then pcall(_G.renderChatUI) end
                end
            end)
        end
    end

    if (farming or walkFarmEnabled) and myChar and myHum and myRoot and myHum.Health > 0 then
        if not inArena then
            if walkFarmEnabled or walkToPortalMode then
                walkToArenaPortal()
            else
                if (tick() - lastFarmTeleport) > 0.3 then
                    lastFarmTeleport = tick()
                    farmTeleportAttempts = farmTeleportAttempts + 1
                    isTeleporting = true
                    pcall(function() myRoot.CFrame = CFrame.new(FARM_COORDS) + Vector3.new(0, 3, 0) end)
                    task.delay(0.1, function() isTeleporting = false end)
                    if farmTeleportAttempts >= 5 then
                        walkToPortalMode = true
                        farmTeleportAttempts = 0
                    end
                end
            end
        else
            farmTeleportAttempts = 0
            walkToPortalMode = false
        end
    end

    if farming and myChar and myHum and myRoot and inArena then
        local now = tick()
        local targetRoot = nil

        if targetPlayer then
            local _, _, tr = getRealTarget(targetPlayer)
            targetRoot = tr
        end

        if not targetRoot then
            if currentTarget and currentTarget.Parent == Players then
                local _, _, tr = getRealTarget(currentTarget)
                if tr then targetRoot = tr end
            end
            if not targetRoot or (now - lastSwitch) > TARGET_SWITCH_TIME then
                local bestRoot, bestDist = nil, math.huge
                for _, pl in ipairs(Players:GetPlayers()) do
                    if pl ~= me then
                        local _, _, tr = getRealTarget(pl)
                        if tr then
                            local d = (tr.Position - myRoot.Position).Magnitude
                            if d < bestDist then bestDist = d; bestRoot = tr end
                        end
                    end
                end
                if bestRoot then
                    targetRoot = bestRoot
                    currentTarget = Players:GetPlayerFromCharacter(bestRoot.Parent)
                    lastSwitch = now
                end
            end
        end

        if targetRoot then
            isTeleporting = true
            pcall(function() myRoot.CFrame = targetRoot.CFrame * TELEPORT_OFFSET end)
            task.delay(0.05, function() isTeleporting = false end)
        end
    end

    if walkFarmEnabled and myChar and myHum and myRoot and inArena then
        updateWalkFarm()
    end

    if autoAim and myRoot then
        local aimRoot = nil
        if targetPlayer then
            local _, _, tr = getRealTarget(targetPlayer)
            aimRoot = tr
        end
        if not aimRoot then
            local bestDist = math.huge
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= me then
                    local _, _, tr = getRealTarget(pl)
                    if tr then
                        local d = (tr.Position - myRoot.Position).Magnitude
                        if d < bestDist then bestDist = d; aimRoot = tr end
                    end
                end
            end
        end
        if aimRoot then faceTarget(aimRoot) end
    end

    if espEnabled then updateESP() end

    if statusLabel then
        if candyFarmEnabled then
            statusLabel.Text = "Status: Candy Farm Active!"
        elseif killAuraEnabled then
            statusLabel.Text = "Status: Kill Aura Active!"
        elseif not (farming or walkFarmEnabled) then
            statusLabel.Text = "Status: Farm OFF"
        elseif not myChar then
            statusLabel.Text = "Status: No Character"
        elseif not inArena then
            if walkFarmEnabled or walkToPortalMode then
                statusLabel.Text = "Status: Walking to Arena Portal..."
            else
                statusLabel.Text = "Status: Teleporting to arena (attempt " .. farmTeleportAttempts .. "/5)"
            end
        elseif farming then
            statusLabel.Text = "Status: TP Farm (Attacking)"
        elseif walkFarmEnabled then
            statusLabel.Text = "Status: Walk Farm (Walking)"
        else
            statusLabel.Text = "Status: Ready"
        end
    end

    RunService.Heartbeat:Wait()
end
