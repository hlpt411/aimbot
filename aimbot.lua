-- // pthub v2.9.3
-- // Adaptive FullBright + Fly-To TP + FPS Boost + Combat + Refresh Players + INVISIBLE (MENU)
-- // LocalScript / Executor | RightShift = toggle menu
-- // INVISIBLE = Visuals tab → "👻 INVISIBLE / GHOST"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local Terrain = workspace:FindFirstChildOfClass("Terrain")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local GameSettings = UserSettings():GetService("UserGameSettings")

local CONFIG = {
    Version = "2.9.3",
    MainColor = Color3.fromHex("#0d0d1a"),
    AccentPurple = Color3.fromHex("#6c5ce7"),
    AccentTeal = Color3.fromHex("#00cec9"),
    AccentPink = Color3.fromHex("#fd79a8"),
    TextWhite = Color3.fromHex("#ffffff"),
    TextDim = Color3.fromHex("#b2bec3"),
    DangerRed = Color3.fromHex("#ff4757"),
    SuccessGreen = Color3.fromHex("#2ed573"),
    WarningYellow = Color3.fromHex("#ffa502"),
    AimTeamCheck = true,
    AimVisibleCheck = true,
    TeleportOffset = Vector3.new(3.5, 3, 0),
    FlyToArriveDist = 4.5,
    AutoRefreshPlayers = true,
    AutoRefreshInterval = 3,
    InvisibleLocalOnly = true,
    InvisibleHideShadow = true,
    InvisibleHideNameTag = true,
    InvisibleReapplyRate = 0.15,
    InvisibleKeepTools = false,
}

local State = {
    SpeedEnabled = true, WalkSpeed = 16, SpeedBoostMult = 1,
    UseCFrameSpeed = false, CFrameSpeedValue = 2,
    JumpEnabled = true, JumpPower = 50, JumpBoostMult = 1,
    InfiniteJump = false, SuperJump = false, SuperJumpPower = 120,
    FlyEnabled = false, FlySpeed = 80, FlyVerticalMult = 1,
    FlyMode = "Velocity", FlySmooth = true,
    NoClipEnabled = false, ESPEnabled = false,
    AimAssistEnabled = false, AimFOV = 120, AimSmooth = 0.35,
    AimMode = "Closest", SelectedAimPlayer = nil,

    FullBrightEnabled = false,
    FullBrightIntensity = 55,
    FPSBoostEnabled = false,

    InvisibleEnabled = false,
    InvisibleSaved = {},
    InvisibleNameTagHidden = false,

    TeleportSpeed = 120,
    TeleportStyle = "FlyTo",
    IsTeleporting = false,
    TeleportTarget = nil,

    MenuOpen = true,
    Connections = {},
    ESPObjects = {},
    FlyBodyVelocity = nil, FlyBodyGyro = nil,
    Character = nil, Humanoid = nil, HRP = nil,

    SavedLighting = nil,
    SavedPostFX = {},
    SavedTerrain = nil,
    SavedQuality = nil,
    FB_CC = nil,
    SceneDarkness = 0.5,

    LastPlayerCount = 0,
    PlayerCountLabel = nil,
    RefreshStatusLabel = nil,
}

local function SafePcall(fn, ...)
    local ok, res = pcall(fn, ...)
    return ok, res
end

local function Create(class, props)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then obj[k] = v end
    end
    if props and props.Parent then obj.Parent = props.Parent end
    return obj
end

local function Tween(obj, props, duration, style, dir)
    local t = TweenService:Create(obj,
        TweenInfo.new(duration or 0.25, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

local function GetCharacter(player)
    player = player or LocalPlayer
    local char = player.Character
    if not char then return nil, nil, nil end
    return char, char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
end

local function GetEffectiveWalkSpeed()
    return math.clamp(State.WalkSpeed * State.SpeedBoostMult, 0, 1000)
end

local function GetEffectiveJumpPower()
    if State.SuperJump then
        return math.clamp(State.SuperJumpPower * State.JumpBoostMult, 0, 2000)
    end
    return math.clamp(State.JumpPower * State.JumpBoostMult, 0, 2000)
end

local function ApplyMovementStats()
    if not State.Humanoid then return end
    SafePcall(function()
        if State.SpeedEnabled and not State.UseCFrameSpeed then
            State.Humanoid.WalkSpeed = GetEffectiveWalkSpeed()
        elseif not State.SpeedEnabled then
            State.Humanoid.WalkSpeed = 16
        end
        if State.JumpEnabled then
            local jp = GetEffectiveJumpPower()
            State.Humanoid.JumpPower = jp
            if State.Humanoid.UseJumpPower == false then
                State.Humanoid.JumpHeight = jp / 20
            end
        else
            State.Humanoid.JumpPower = 50
            if State.Humanoid.UseJumpPower == false then
                State.Humanoid.JumpHeight = 7.2
            end
        end
    end)
end

local function RefreshCharacter()
    State.Character, State.Humanoid, State.HRP = GetCharacter()
    ApplyMovementStats()
end

-- =========================================================
-- INVISIBLE ENGINE
-- =========================================================
local function IsInvisibleTarget(inst)
    if not inst then return false end
    if inst:IsA("BasePart") or inst:IsA("MeshPart") then return true end
    if inst:IsA("Decal") or inst:IsA("Texture") then return true end
    if inst:IsA("Accessory") then return true end
    if inst:IsA("Tool") and not CONFIG.InvisibleKeepTools then return true end
    if inst:IsA("Shirt") or inst:IsA("Pants") or inst:IsA("ShirtGraphic") then return true end
    if inst:IsA("CharacterMesh") then return true end
    if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam") then return true end
    if inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then return true end
    return false
end

local function CacheOriginal(inst)
    if State.InvisibleSaved[inst] then return end
    local entry = {}
    if inst:IsA("BasePart") then
        entry.Transparency = inst.Transparency
        entry.LocalTransparencyModifier = inst.LocalTransparencyModifier
        entry.CastShadow = inst.CastShadow
    elseif inst:IsA("Decal") or inst:IsA("Texture") then
        entry.Transparency = inst.Transparency
    elseif inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam")
        or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
        entry.Enabled = inst.Enabled
    end
    State.InvisibleSaved[inst] = entry
end

local function ForceGhost(inst)
    if not inst or not inst.Parent then return end
    CacheOriginal(inst)
    SafePcall(function()
        if inst:IsA("BasePart") then
            inst.LocalTransparencyModifier = 1
            if not CONFIG.InvisibleLocalOnly then
                inst.Transparency = 1
            end
            if CONFIG.InvisibleHideShadow then
                inst.CastShadow = false
            end
        elseif inst:IsA("Decal") or inst:IsA("Texture") then
            inst.Transparency = 1
        elseif inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam")
            or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
            inst.Enabled = false
        end
    end)
end

local function RestoreOne(inst, entry)
    if not inst or not inst.Parent or not entry then return end
    SafePcall(function()
        if inst:IsA("BasePart") then
            if entry.LocalTransparencyModifier ~= nil then inst.LocalTransparencyModifier = entry.LocalTransparencyModifier end
            if entry.Transparency ~= nil then inst.Transparency = entry.Transparency end
            if entry.CastShadow ~= nil then inst.CastShadow = entry.CastShadow end
        elseif inst:IsA("Decal") or inst:IsA("Texture") then
            if entry.Transparency ~= nil then inst.Transparency = entry.Transparency end
        elseif inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam")
            or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
            if entry.Enabled ~= nil then inst.Enabled = entry.Enabled end
        end
    end)
end

local function SweepCharacterInvisible(char)
    if not char then return end
    for _, inst in ipairs(char:GetDescendants()) do
        if IsInvisibleTarget(inst) then ForceGhost(inst) end
    end
    for _, name in ipairs({"HumanoidRootPart", "Head", "Torso", "UpperTorso", "LowerTorso"}) do
        local p = char:FindFirstChild(name)
        if p and p:IsA("BasePart") then ForceGhost(p) end
    end
end

local function HideNameTag(hum)
    if not hum or not CONFIG.InvisibleHideNameTag then return end
    SafePcall(function()
        hum.NameDisplayDistance = 0
        hum.HealthDisplayDistance = 0
        hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        State.InvisibleNameTagHidden = true
    end)
end

local function RestoreNameTag(hum)
    if not hum then return end
    SafePcall(function()
        hum.NameDisplayDistance = 100
        hum.HealthDisplayDistance = 100
        hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
        State.InvisibleNameTagHidden = false
    end)
end

function StartInvisible()
    RefreshCharacter()
    local char, hum = State.Character, State.Humanoid
    if not char then return end

    State.InvisibleEnabled = true
    State.InvisibleSaved = {}
    SweepCharacterInvisible(char)
    if hum then HideNameTag(hum) end

    if State.Connections.InvisibleAdded then State.Connections.InvisibleAdded:Disconnect() end
    State.Connections.InvisibleAdded = char.DescendantAdded:Connect(function(inst)
        if not State.InvisibleEnabled then return end
        task.defer(function()
            if IsInvisibleTarget(inst) then ForceGhost(inst) end
            if inst:IsA("Accessory") then
                task.wait(0.05)
                for _, d in ipairs(inst:GetDescendants()) do
                    if IsInvisibleTarget(d) then ForceGhost(d) end
                end
            end
        end)
    end)

    if State.Connections.InvisibleLoop then State.Connections.InvisibleLoop:Disconnect() end
    local acc = 0
    State.Connections.InvisibleLoop = RunService.RenderStepped:Connect(function(dt)
        if not State.InvisibleEnabled then return end
        acc += dt
        if acc < CONFIG.InvisibleReapplyRate then return end
        acc = 0
        local c, h = GetCharacter()
        if not c then return end
        SweepCharacterInvisible(c)
        if h then HideNameTag(h) end
    end)

    if State.Connections.InvisibleTool then State.Connections.InvisibleTool:Disconnect() end
    if hum then
        State.Connections.InvisibleTool = hum.ChildAdded:Connect(function()
            if State.InvisibleEnabled then
                task.defer(function() SweepCharacterInvisible(char) end)
            end
        end)
    end
end

function StopInvisible()
    State.InvisibleEnabled = false
    if State.Connections.InvisibleAdded then State.Connections.InvisibleAdded:Disconnect() State.Connections.InvisibleAdded = nil end
    if State.Connections.InvisibleLoop then State.Connections.InvisibleLoop:Disconnect() State.Connections.InvisibleLoop = nil end
    if State.Connections.InvisibleTool then State.Connections.InvisibleTool:Disconnect() State.Connections.InvisibleTool = nil end
    for inst, entry in pairs(State.InvisibleSaved) do RestoreOne(inst, entry) end
    State.InvisibleSaved = {}
    local _, hum = GetCharacter()
    if hum then RestoreNameTag(hum) end
end

local function SetInvisible(on)
    if on then StartInvisible() else StopInvisible() end
end

-- =========================================================
-- ADAPTIVE FULL BRIGHT
-- =========================================================
local function Luma(c)
    return c.R * 0.2126 + c.G * 0.7152 + c.B * 0.0722
end

local function SampleSceneDarkness()
    local amb = Luma(Lighting.Ambient)
    local out = Luma(Lighting.OutdoorAmbient)
    local br = math.clamp(Lighting.Brightness / 4, 0, 1)
    local fogFactor = 0
    if Lighting.FogEnd < 200 then fogFactor = 0.55
    elseif Lighting.FogEnd < 600 then fogFactor = 0.35
    elseif Lighting.FogEnd < 1500 then fogFactor = 0.18 end
    local clock = Lighting.ClockTime
    local night = 0
    if clock < 6 or clock > 18.5 then night = 0.45
    elseif clock < 7.5 or clock > 17 then night = 0.2 end
    local lightScore = (amb * 0.35 + out * 0.35 + br * 0.3)
    local darkness = math.clamp((1 - lightScore) * 0.75 + fogFactor + night * 0.5, 0, 1)
    State.SceneDarkness = darkness
    return darkness
end

local function CaptureLighting()
    State.SavedLighting = {
        Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, FogColor = Lighting.FogColor,
        GlobalShadows = Lighting.GlobalShadows, OutdoorAmbient = Lighting.OutdoorAmbient,
        Ambient = Lighting.Ambient, ColorShift_Top = Lighting.ColorShift_Top,
        ColorShift_Bottom = Lighting.ColorShift_Bottom, ExposureCompensation = Lighting.ExposureCompensation,
        EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
        ShadowSoftness = Lighting.ShadowSoftness,
    }
    State.SavedPostFX = {}
    for _, fx in ipairs(Lighting:GetChildren()) do
        if fx:IsA("BlurEffect") or fx:IsA("ColorCorrectionEffect") or fx:IsA("BloomEffect")
            or fx:IsA("SunRaysEffect") or fx:IsA("DepthOfFieldEffect") or fx:IsA("Atmosphere") then
            if fx.Name == "pthub_FB_CC" then continue end
            local entry = {Instance = fx, Enabled = (not fx:IsA("Atmosphere")) and fx.Enabled or true, Props = {}}
            if fx:IsA("BlurEffect") then entry.Props.Size = fx.Size end
            if fx:IsA("ColorCorrectionEffect") then
                entry.Props.Brightness = fx.Brightness; entry.Props.Contrast = fx.Contrast
                entry.Props.Saturation = fx.Saturation; entry.Props.TintColor = fx.TintColor
            end
            if fx:IsA("BloomEffect") then
                entry.Props.Intensity = fx.Intensity; entry.Props.Size = fx.Size; entry.Props.Threshold = fx.Threshold
            end
            if fx:IsA("DepthOfFieldEffect") then
                entry.Props.FarIntensity = fx.FarIntensity; entry.Props.NearIntensity = fx.NearIntensity
            end
            if fx:IsA("Atmosphere") then
                entry.Props.Density = fx.Density; entry.Props.Haze = fx.Haze; entry.Props.Glare = fx.Glare
            end
            table.insert(State.SavedPostFX, entry)
        end
    end
end

local function EnsureFBColorCorrection()
    if State.FB_CC and State.FB_CC.Parent then return State.FB_CC end
    local cc = Lighting:FindFirstChild("pthub_FB_CC")
    if not cc then
        cc = Instance.new("ColorCorrectionEffect")
        cc.Name = "pthub_FB_CC"
        cc.Parent = Lighting
    end
    State.FB_CC = cc
    return cc
end

local function ApplyAdaptiveFullBright()
    SafePcall(function()
        local dark = SampleSceneDarkness()
        local t = math.clamp(State.FullBrightIntensity / 100, 0, 1)
        local need = dark * 0.85 + t * 0.35
        local mix = math.clamp(need * t * 1.15, 0, 1)
        local saved = State.SavedLighting
        if not saved then return end

        local targetBright = saved.Brightness + mix * (1.1 + dark * 1.2)
        targetBright = math.clamp(targetBright, saved.Brightness, 3.2)
        if dark < 0.25 then targetBright = saved.Brightness + mix * 0.25 end
        Lighting.Brightness = targetBright

        local ambLift = mix * (0.15 + dark * 0.35)
        local function liftColor(c, amt)
            return Color3.new(math.clamp(c.R + amt, 0, 1), math.clamp(c.G + amt, 0, 1), math.clamp(c.B + amt, 0, 1))
        end
        Lighting.Ambient = liftColor(saved.Ambient, ambLift * 0.85)
        Lighting.OutdoorAmbient = liftColor(saved.OutdoorAmbient, ambLift)
        Lighting.ExposureCompensation = saved.ExposureCompensation + mix * (0.15 + dark * 0.35)

        if saved.FogEnd < 2500 then
            Lighting.FogEnd = math.clamp(saved.FogEnd + mix * (8000 + dark * 40000), saved.FogEnd, 200000)
            Lighting.FogStart = math.max(0, saved.FogStart * (1 - mix * 0.8))
        end

        Lighting.GlobalShadows = (mix > 0.45 and dark > 0.35) and false or saved.GlobalShadows
        if dark > 0.55 and t > 0.4 then
            Lighting.ClockTime = saved.ClockTime + (13.5 - saved.ClockTime) * mix * 0.55
        else
            Lighting.ClockTime = saved.ClockTime
        end

        for _, fx in ipairs(Lighting:GetChildren()) do
            if fx:IsA("Atmosphere") and dark > 0.3 then
                fx.Density = math.max(0, (fx.Density or 0) * (1 - mix * 0.7))
                fx.Haze = math.max(0, (fx.Haze or 0) * (1 - mix * 0.7))
            end
            if fx:IsA("BloomEffect") and mix > 0.6 then fx.Intensity = math.min(fx.Intensity, 0.4) end
            if fx:IsA("DepthOfFieldEffect") and mix > 0.5 then fx.Enabled = false end
            if fx:IsA("BlurEffect") and mix > 0.5 then fx.Size = math.min(fx.Size, 2) end
        end

        local cc = EnsureFBColorCorrection()
        cc.Enabled = true
        cc.Brightness = mix * (0.04 + dark * 0.14)
        cc.Contrast = mix * (0.02 + dark * 0.06)
        cc.Saturation = mix * 0.03
        cc.TintColor = Color3.fromRGB(255, 255, 255)
    end)
end

function StartFullBright()
    if not State.SavedLighting then CaptureLighting() end
    SampleSceneDarkness()
    State.FullBrightEnabled = true
    ApplyAdaptiveFullBright()
    if State.Connections.FullBright then State.Connections.FullBright:Disconnect() end
    local acc = 0
    State.Connections.FullBright = RunService.RenderStepped:Connect(function(dt)
        if not State.FullBrightEnabled then return end
        acc += dt
        if acc >= 0.1 then acc = 0 ApplyAdaptiveFullBright() end
    end)
end

function StopFullBright()
    State.FullBrightEnabled = false
    if State.Connections.FullBright then State.Connections.FullBright:Disconnect() State.Connections.FullBright = nil end
    if State.FB_CC then State.FB_CC:Destroy() State.FB_CC = nil end
    local old = Lighting:FindFirstChild("pthub_FB_CC")
    if old then old:Destroy() end
    if not State.SavedLighting then return end
    SafePcall(function()
        local s = State.SavedLighting
        Lighting.Brightness = s.Brightness; Lighting.ClockTime = s.ClockTime
        Lighting.FogEnd = s.FogEnd; Lighting.FogStart = s.FogStart; Lighting.FogColor = s.FogColor
        Lighting.GlobalShadows = s.GlobalShadows; Lighting.OutdoorAmbient = s.OutdoorAmbient
        Lighting.Ambient = s.Ambient; Lighting.ColorShift_Top = s.ColorShift_Top
        Lighting.ColorShift_Bottom = s.ColorShift_Bottom; Lighting.ExposureCompensation = s.ExposureCompensation
        Lighting.EnvironmentDiffuseScale = s.EnvironmentDiffuseScale
        Lighting.EnvironmentSpecularScale = s.EnvironmentSpecularScale
        Lighting.ShadowSoftness = s.ShadowSoftness
        for _, entry in ipairs(State.SavedPostFX) do
            local fx = entry.Instance
            if fx and fx.Parent then
                if not fx:IsA("Atmosphere") then fx.Enabled = entry.Enabled end
                for prop, val in pairs(entry.Props) do SafePcall(function() fx[prop] = val end) end
            end
        end
    end)
end

-- =========================================================
-- FLY-TO TELEPORT
-- =========================================================
local function StopFlyTo()
    if State.Connections.FlyTo then State.Connections.FlyTo:Disconnect() State.Connections.FlyTo = nil end
    State.IsTeleporting = false
    State.TeleportTarget = nil
    if State.HRP then
        SafePcall(function()
            State.HRP.AssemblyLinearVelocity = Vector3.zero
            State.HRP.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    if State.Humanoid and not State.FlyEnabled then
        SafePcall(function()
            State.Humanoid.PlatformStand = false
            State.Humanoid:ChangeState(Enum.HumanoidStateType.Running)
        end)
    end
    ApplyMovementStats()
end

local function FlyToPlayer(targetPlayer)
    if State.IsTeleporting then StopFlyTo() end
    local _, localHum, localHRP = GetCharacter()
    local _, targetHum, targetHRP = GetCharacter(targetPlayer)
    if not localHRP or not localHum or not targetHRP or not targetHum then return end
    if localHum.Health <= 0 or targetHum.Health <= 0 then return end

    State.IsTeleporting = true
    State.TeleportTarget = targetPlayer

    local wasNoClip = State.NoClipEnabled
    if not wasNoClip then
        State.NoClipEnabled = true
        StartNoClip()
    end

    SafePcall(function()
        localHum.PlatformStand = true
        localHum:ChangeState(Enum.HumanoidStateType.Physics)
        localHRP.AssemblyLinearVelocity = Vector3.zero
    end)

    local arrive, maxTime, elapsed = CONFIG.FlyToArriveDist, 20, 0
    if State.Connections.FlyTo then State.Connections.FlyTo:Disconnect() end
    State.Connections.FlyTo = RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        local _, hum, hrp = GetCharacter()
        local _, tHum, tHRP = GetCharacter(targetPlayer)

        if not hum or not hrp or hum.Health <= 0 or elapsed > maxTime then
            if not wasNoClip then SetNoClip(false) end
            StopFlyTo()
            return
        end
        if not tHRP or not tHum or tHum.Health <= 0 then
            if not wasNoClip then SetNoClip(false) end
            StopFlyTo()
            return
        end

        local tcf = tHRP.CFrame
        local off = CONFIG.TeleportOffset
        local worldSide = tcf:VectorToWorldSpace(Vector3.new(off.X, 0, off.Z))
        local dest = tcf.Position + worldSide + Vector3.new(0, off.Y, 0)
        local pos = hrp.Position
        local delta = dest - pos
        local dist = delta.Magnitude

        if dist <= arrive then
            SafePcall(function()
                local _, y = tcf:ToEulerAnglesYXZ()
                hrp.CFrame = CFrame.new(dest) * CFrame.Angles(0, y, 0)
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
            if not wasNoClip then State.NoClipEnabled = false StopNoClip() end
            StopFlyTo()
            return
        end

        local speed = math.clamp(State.TeleportSpeed, 20, 800)
        local ease = dist < 30 and math.clamp(dist / 30, 0.25, 1) or 1
        local step = math.min(dist, speed * ease * dt)
        local dir = delta.Unit
        hrp.CFrame = CFrame.new(pos + dir * step, pos + dir * step + tcf.LookVector)
        hrp.AssemblyLinearVelocity = dir * speed * ease * 0.35
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
end

-- =========================================================
-- FPS BOOST
-- =========================================================
local function CaptureGraphics()
    SafePcall(function() State.SavedQuality = GameSettings.SavedQualityLevel end)
    if Terrain then
        State.SavedTerrain = {
            Decoration = Terrain.Decoration, WaterWaveSize = Terrain.WaterWaveSize,
            WaterWaveSpeed = Terrain.WaterWaveSpeed, WaterReflectance = Terrain.WaterReflectance,
            WaterTransparency = Terrain.WaterTransparency,
        }
    end
end

function StartFPSBoost()
    if not State.SavedQuality then CaptureGraphics() end
    State.FPSBoostEnabled = true
    SafePcall(function() GameSettings.SavedQualityLevel = Enum.SavedQualitySetting.QualityLevel1 end)
    SafePcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level01
    end)
    SafePcall(function()
        Lighting.GlobalShadows = false
        Lighting.EnvironmentSpecularScale = 0
        for _, fx in ipairs(Lighting:GetChildren()) do
            if fx:IsA("BlurEffect") or fx:IsA("BloomEffect") or fx:IsA("SunRaysEffect") or fx:IsA("DepthOfFieldEffect") then
                fx.Enabled = false
            end
            if fx:IsA("Atmosphere") then fx.Density = 0 fx.Haze = 0 fx.Glare = 0 end
        end
    end)
    if Terrain then
        SafePcall(function()
            Terrain.Decoration = false; Terrain.WaterWaveSize = 0; Terrain.WaterWaveSpeed = 0
            Terrain.WaterReflectance = 0; Terrain.WaterTransparency = 1
        end)
    end
    SafePcall(function()
        for _, inst in ipairs(workspace:GetDescendants()) do
            if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam")
                or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
                inst.Enabled = false
            end
        end
    end)
    if State.Connections.FPSDesc then State.Connections.FPSDesc:Disconnect() end
    State.Connections.FPSDesc = workspace.DescendantAdded:Connect(function(inst)
        if not State.FPSBoostEnabled then return end
        task.defer(function()
            SafePcall(function()
                if inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam")
                    or inst:IsA("Fire") or inst:IsA("Smoke") or inst:IsA("Sparkles") then
                    inst.Enabled = false
                end
            end)
        end)
    end)
    if State.Connections.FPSLock then State.Connections.FPSLock:Disconnect() end
    State.Connections.FPSLock = RunService.Heartbeat:Connect(function()
        if not State.FPSBoostEnabled then return end
        SafePcall(function()
            if settings().Rendering.QualityLevel ~= Enum.QualityLevel.Level01 then
                settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            end
        end)
    end)
end

function StopFPSBoost()
    State.FPSBoostEnabled = false
    if State.Connections.FPSDesc then State.Connections.FPSDesc:Disconnect() State.Connections.FPSDesc = nil end
    if State.Connections.FPSLock then State.Connections.FPSLock:Disconnect() State.Connections.FPSLock = nil end
    SafePcall(function()
        GameSettings.SavedQualityLevel = State.SavedQuality or Enum.SavedQualitySetting.Automatic
        settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
    end)
    if Terrain and State.SavedTerrain then
        SafePcall(function()
            Terrain.Decoration = State.SavedTerrain.Decoration
            Terrain.WaterWaveSize = State.SavedTerrain.WaterWaveSize
            Terrain.WaterWaveSpeed = State.SavedTerrain.WaterWaveSpeed
            Terrain.WaterReflectance = State.SavedTerrain.WaterReflectance
            Terrain.WaterTransparency = State.SavedTerrain.WaterTransparency
        end)
    end
end

-- // UI ROOT
local ScreenGui = Create("ScreenGui", {
    Name = "pthub_UI", ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = CoreGui,
})
local MainFrame = Create("Frame", {
    Name = "Main", Size = UDim2.new(0, 510, 0, 680), Position = UDim2.new(0.5, -255, 0.5, -340),
    BackgroundColor3 = CONFIG.MainColor, BorderSizePixel = 0, ClipsDescendants = true, Parent = ScreenGui,
})
Create("UICorner", {CornerRadius = UDim.new(0, 12), Parent = MainFrame})
Create("UIStroke", {Color = CONFIG.AccentPurple, Thickness = 2, Transparency = 0.25, Parent = MainFrame})

local Header = Create("Frame", {
    Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = Color3.fromRGB(12, 12, 28),
    BorderSizePixel = 0, Parent = MainFrame,
})
Create("UICorner", {CornerRadius = UDim.new(0, 12), Parent = Header})
Create("Frame", {
    Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2),
    BackgroundColor3 = CONFIG.AccentTeal, BorderSizePixel = 0, Parent = Header,
})
Create("TextLabel", {
    Size = UDim2.new(0, 220, 1, 0), Position = UDim2.new(0, 16, 0, 0), BackgroundTransparency = 1,
    Text = "⚡ pthub", TextColor3 = CONFIG.TextWhite, TextSize = 22, Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = Header,
})
local VersionTag = Create("TextLabel", {
    Size = UDim2.new(0, 64, 0, 18), Position = UDim2.new(0, 120, 0.5, -9),
    BackgroundColor3 = CONFIG.AccentPurple, Text = "v" .. CONFIG.Version,
    TextColor3 = CONFIG.TextWhite, TextSize = 11, Font = Enum.Font.Gotham, Parent = Header,
})
Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = VersionTag})
local MinimizeBtn = Create("TextButton", {
    Size = UDim2.new(0, 32, 0, 32), Position = UDim2.new(1, -80, 0.5, -16),
    BackgroundColor3 = Color3.fromRGB(30, 30, 50), Text = "—", TextColor3 = CONFIG.TextWhite,
    TextSize = 16, Font = Enum.Font.GothamBold, Parent = Header,
})
Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = MinimizeBtn})
local CloseBtn = Create("TextButton", {
    Size = UDim2.new(0, 32, 0, 32), Position = UDim2.new(1, -40, 0.5, -16),
    BackgroundColor3 = CONFIG.DangerRed, Text = "✕", TextColor3 = CONFIG.TextWhite,
    TextSize = 14, Font = Enum.Font.GothamBold, Parent = Header,
})
Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = CloseBtn})

local TabBar = Create("Frame", {
    Size = UDim2.new(1, -24, 0, 40), Position = UDim2.new(0, 12, 0, 58),
    BackgroundTransparency = 1, Parent = MainFrame,
})
local CombatTabBtn = Create("TextButton", {
    Size = UDim2.new(0.5, -4, 1, 0), BackgroundColor3 = CONFIG.AccentPurple, Text = "COMBAT",
    TextColor3 = CONFIG.TextWhite, TextSize = 14, Font = Enum.Font.GothamBold, Parent = TabBar,
})
Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = CombatTabBtn})
local VisualsTabBtn = Create("TextButton", {
    Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.new(0.5, 4, 0, 0),
    BackgroundColor3 = Color3.fromRGB(25, 25, 45), Text = "VISUALS",
    TextColor3 = CONFIG.TextDim, TextSize = 14, Font = Enum.Font.GothamBold, Parent = TabBar,
})
Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = VisualsTabBtn})

local function MakeScroll(vis, col)
    local sf = Create("ScrollingFrame", {
        Size = UDim2.new(1, -24, 1, -114), Position = UDim2.new(0, 12, 0, 106),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5,
        ScrollBarImageColor3 = col, CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = vis, Parent = MainFrame,
    })
    Create("UIListLayout", {Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sf})
    Create("UIPadding", {
        PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 20),
        PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 8), Parent = sf,
    })
    return sf
end
local CombatContent = MakeScroll(true, CONFIG.AccentPurple)
local VisualsContent = MakeScroll(false, CONFIG.AccentTeal)

local layoutOrderCounter = 0
local function nextOrder() layoutOrderCounter += 1 return layoutOrderCounter end

local function CreateSection(parent, title)
    local section = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Color3.fromRGB(16, 16, 32), BorderSizePixel = 0,
        LayoutOrder = nextOrder(), Parent = parent,
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = section})
    Create("UIStroke", {Color = Color3.fromRGB(45, 45, 75), Thickness = 1, Parent = section})
    Create("UIPadding", {
        PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 14),
        PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = section,
    })
    Create("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = section})
    Create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = title,
        TextColor3 = CONFIG.AccentTeal, TextSize = 13, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 0, Parent = section,
    })
    return section
end

local function CreateToggle(parent, text, default, callback)
    local holder = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1,
        LayoutOrder = #parent:GetChildren() + 1, Parent = parent,
    })
    Create("TextLabel", {
        Size = UDim2.new(1, -60, 1, 0), BackgroundTransparency = 1, Text = text,
        TextColor3 = CONFIG.TextWhite, TextSize = 14, Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
    })
    local toggleBg = Create("Frame", {
        Size = UDim2.new(0, 50, 0, 28), Position = UDim2.new(1, -50, 0.5, -14),
        BackgroundColor3 = default and CONFIG.AccentPurple or Color3.fromRGB(40, 40, 60), Parent = holder,
    })
    Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = toggleBg})
    local knob = Create("Frame", {
        Size = UDim2.new(0, 22, 0, 22),
        Position = default and UDim2.new(1, -25, 0.5, -11) or UDim2.new(0, 3, 0.5, -11),
        BackgroundColor3 = CONFIG.TextWhite, Parent = toggleBg,
    })
    Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = knob})
    local enabled = default
    local btn = Create("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", Parent = holder})
    local function render()
        Tween(toggleBg, {BackgroundColor3 = enabled and CONFIG.AccentPurple or Color3.fromRGB(40, 40, 60)}, 0.18)
        Tween(knob, {Position = enabled and UDim2.new(1, -25, 0.5, -11) or UDim2.new(0, 3, 0.5, -11)}, 0.18)
    end
    btn.MouseButton1Click:Connect(function()
        enabled = not enabled; render()
        if callback then callback(enabled) end
    end)
    return {Set = function(v) enabled = v; render() end, Get = function() return enabled end}
end

local function CreateSlider(parent, text, min, max, default, callback)
    local holder = Create("Frame", {
        Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = Color3.fromRGB(20, 20, 38),
        BorderSizePixel = 0, LayoutOrder = #parent:GetChildren() + 1, Parent = parent,
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = holder})
    Create("UIPadding", {
        PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = holder,
    })
    Create("TextLabel", {
        Size = UDim2.new(0.65, 0, 0, 18), BackgroundTransparency = 1, Text = text,
        TextColor3 = CONFIG.TextWhite, TextSize = 13, Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = holder,
    })
    local valueLabel = Create("TextLabel", {
        Size = UDim2.new(0.35, 0, 0, 18), Position = UDim2.new(0.65, 0, 0, 0), BackgroundTransparency = 1,
        Text = tostring(default), TextColor3 = CONFIG.AccentTeal, TextSize = 14, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right, Parent = holder,
    })
    local track = Create("Frame", {
        Size = UDim2.new(1, -70, 0, 12), Position = UDim2.new(0, 0, 0, 30),
        BackgroundColor3 = Color3.fromRGB(28, 28, 52), BorderSizePixel = 0, Parent = holder,
    })
    Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = track})
    local fill = Create("Frame", {
        Size = UDim2.new((default - min) / math.max(max - min, 1), 0, 1, 0),
        BackgroundColor3 = CONFIG.AccentPurple, BorderSizePixel = 0, Parent = track,
    })
    Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = fill})
    Create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, CONFIG.AccentPurple),
            ColorSequenceKeypoint.new(1, CONFIG.AccentPink),
        }), Parent = fill,
    })
    local knob = Create("Frame", {
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new((default - min) / math.max(max - min, 1), -10, 0.5, -10),
        BackgroundColor3 = CONFIG.TextWhite, ZIndex = 3, Parent = track,
    })
    Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = knob})
    Create("UIStroke", {Color = CONFIG.AccentPink, Thickness = 2, Parent = knob})
    local inputBox = Create("TextBox", {
        Size = UDim2.new(0, 60, 0, 24), Position = UDim2.new(1, -60, 0, 24),
        BackgroundColor3 = Color3.fromRGB(25, 25, 48), Text = tostring(default),
        TextColor3 = CONFIG.TextWhite, TextSize = 13, Font = Enum.Font.GothamBold,
        ClearTextOnFocus = false, Parent = holder,
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = inputBox})
    Create("UIStroke", {Color = CONFIG.AccentPurple, Thickness = 1, Transparency = 0.4, Parent = inputBox})

    local dragging, currentVal = false, default
    local function SetValue(val, fromInput)
        val = math.clamp(tonumber(val) or currentVal, min, max)
        if max >= 20 then val = math.floor(val + 0.5) else val = math.floor(val * 100 + 0.5) / 100 end
        currentVal = val
        local pct = (val - min) / math.max(max - min, 1)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, -10, 0.5, -10)
        valueLabel.Text = tostring(val)
        if not fromInput then inputBox.Text = tostring(val) end
        if callback then callback(val) end
    end
    local function pick(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        SetValue(min + rel * (max - min))
    end
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; pick(i.Position.X)
        end
    end)
    knob.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            pick(i.Position.X)
        end
    end)
    inputBox.FocusLost:Connect(function()
        local num = tonumber(inputBox.Text)
        if num then SetValue(num, true); inputBox.Text = tostring(currentVal)
        else inputBox.Text = tostring(currentVal) end
    end)
    return {Set = SetValue, Get = function() return currentVal end}
end

local function CreateButton(parent, text, color, callback)
    local btn = Create("TextButton", {
        Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = color or CONFIG.AccentPurple,
        Text = text, TextColor3 = CONFIG.TextWhite, TextSize = 13, Font = Enum.Font.GothamBold,
        LayoutOrder = #parent:GetChildren() + 1, AutoButtonColor = false, Parent = parent,
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = btn})
    btn.MouseButton1Click:Connect(function() if callback then callback(btn) end end)
    btn.MouseEnter:Connect(function() Tween(btn, {BackgroundTransparency = 0.12}, 0.12) end)
    btn.MouseLeave:Connect(function() Tween(btn, {BackgroundTransparency = 0}, 0.12) end)
    return btn
end

-- =========================================================
-- COMBAT TAB
-- =========================================================
local speedSection = CreateSection(CombatContent, "⚡ SPEED  —  DRAG SLIDERS")
CreateToggle(speedSection, "Enable Speed Override", true, function(v) State.SpeedEnabled = v ApplyMovementStats() end)
CreateSlider(speedSection, "WalkSpeed", 16, 500, 16, function(v) State.WalkSpeed = v ApplyMovementStats() end)
CreateSlider(speedSection, "Speed Boost Multiplier", 1, 10, 1, function(v) State.SpeedBoostMult = v ApplyMovementStats() end)
CreateToggle(speedSection, "CFrame Speed Mode", false, function(v) State.UseCFrameSpeed = v ApplyMovementStats() end)
CreateSlider(speedSection, "CFrame Speed Power", 1, 25, 2, function(v) State.CFrameSpeedValue = v end)

local jumpSection = CreateSection(CombatContent, "🚀 JUMP BOOST  —  DRAG SLIDERS")
CreateToggle(jumpSection, "Enable Jump Override", true, function(v) State.JumpEnabled = v ApplyMovementStats() end)
CreateSlider(jumpSection, "JumpPower", 50, 500, 50, function(v) State.JumpPower = v ApplyMovementStats() end)
CreateSlider(jumpSection, "Jump Boost Multiplier", 1, 15, 1, function(v) State.JumpBoostMult = v ApplyMovementStats() end)
CreateToggle(jumpSection, "Super Jump Mode", false, function(v) State.SuperJump = v ApplyMovementStats() end)
CreateSlider(jumpSection, "Super Jump Power", 80, 1500, 120, function(v) State.SuperJumpPower = v ApplyMovementStats() end)
CreateToggle(jumpSection, "Infinite Jump", false, function(v) State.InfiniteJump = v end)

local flySection = CreateSection(CombatContent, "🕊️ FLY CUSTOMIZE")
CreateToggle(flySection, "Fly Enabled", false, function(v)
    State.FlyEnabled = v
    if v then StartFly() else StopFly() end
end)
CreateSlider(flySection, "Fly Speed", 10, 500, 80, function(v) State.FlySpeed = v end)
CreateSlider(flySection, "Vertical Multiplier", 0.2, 5, 1, function(v) State.FlyVerticalMult = v end)
CreateToggle(flySection, "Smooth Fly Gyro", true, function(v) State.FlySmooth = v end)
local flyModeLabel = Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = "Fly Mode: Velocity",
    TextColor3 = CONFIG.TextDim, TextSize = 12, Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 90, Parent = flySection,
})
CreateButton(flySection, "TOGGLE FLY MODE (Velocity / CFrame)", Color3.fromRGB(40, 55, 100), function()
    State.FlyMode = (State.FlyMode == "Velocity") and "CFrame" or "Velocity"
    flyModeLabel.Text = "Fly Mode: " .. State.FlyMode
    if State.FlyEnabled then StartFly() end
end)

local noclipSection = CreateSection(CombatContent, "👻 NOCLIP")
local noclipStatus = Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = "Status: OFF",
    TextColor3 = CONFIG.DangerRed, TextSize = 13, Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = noclipSection,
})
function SetNoClip(on)
    State.NoClipEnabled = on
    if on then
        StartNoClip()
        noclipStatus.Text = "Status: ON — walking through walls"
        noclipStatus.TextColor3 = CONFIG.SuccessGreen
    else
        StopNoClip()
        noclipStatus.Text = "Status: OFF"
        noclipStatus.TextColor3 = CONFIG.DangerRed
    end
end
CreateToggle(noclipSection, "NoClip Enabled", false, function(v) SetNoClip(v) end)
CreateButton(noclipSection, "▶  ENABLE NOCLIP", CONFIG.AccentTeal, function(btn)
    SetNoClip(not State.NoClipEnabled)
    if State.NoClipEnabled then
        btn.Text = "■  DISABLE NOCLIP"; btn.BackgroundColor3 = CONFIG.DangerRed
    else
        btn.Text = "▶  ENABLE NOCLIP"; btn.BackgroundColor3 = CONFIG.AccentTeal
    end
end)

local aimSection = CreateSection(CombatContent, "🎯 AIM ASSIST")
CreateToggle(aimSection, "Aim Assist Enabled", false, function(v) State.AimAssistEnabled = v end)
CreateSlider(aimSection, "Aim FOV", 30, 360, 120, function(v) State.AimFOV = v UpdateFOVCircle() end)
CreateSlider(aimSection, "Smoothness", 1, 100, 35, function(v) State.AimSmooth = v / 100 end)
local aimModeLabel = Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = "Target Mode: Closest In FOV",
    TextColor3 = CONFIG.TextDim, TextSize = 12, Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 80, Parent = aimSection,
})
CreateButton(aimSection, "SWITCH: Closest / Selected Player", Color3.fromRGB(35, 35, 60), function()
    if State.AimMode == "Closest" then
        State.AimMode = "Selected"; aimModeLabel.Text = "Target Mode: Selected Player"
    else
        State.AimMode = "Closest"; aimModeLabel.Text = "Target Mode: Closest In FOV"
    end
end)

-- =========================================================
-- VISUALS TAB  (INVISIBLE LIVES HERE — TOP OF TAB)
-- =========================================================

-- ★★★ INVISIBLE / GHOST — FIRST SECTION IN VISUALS ★★★
local invisSection = CreateSection(VisualsContent, "👻 INVISIBLE / GHOST")
local invisStatus = Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = "Invisible: OFF",
    TextColor3 = CONFIG.DangerRed, TextSize = 13, Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = invisSection,
})
Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
    Text = "Local ghost — body / fits / particles / nametag wiped",
    TextColor3 = CONFIG.TextDim, TextSize = 11, Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, Parent = invisSection,
})

local invisBtn
local function SetInvisibleUI(on)
    SetInvisible(on)
    if on then
        invisStatus.Text = "Invisible: ON — you are a damn ghost"
        invisStatus.TextColor3 = CONFIG.SuccessGreen
        if invisBtn then
            invisBtn.Text = "■  DISABLE INVISIBLE"
            invisBtn.BackgroundColor3 = CONFIG.DangerRed
        end
    else
        invisStatus.Text = "Invisible: OFF"
        invisStatus.TextColor3 = CONFIG.DangerRed
        if invisBtn then
            invisBtn.Text = "👻  ENABLE INVISIBLE"
            invisBtn.BackgroundColor3 = CONFIG.AccentPurple
        end
    end
end

CreateToggle(invisSection, "Invisible Enabled", false, function(v)
    SetInvisibleUI(v)
end)
CreateToggle(invisSection, "Hide Shadows", true, function(v)
    CONFIG.InvisibleHideShadow = v
    if State.InvisibleEnabled then StopInvisible() StartInvisible() end
end)
CreateToggle(invisSection, "Hide Name / Health Tag", true, function(v)
    CONFIG.InvisibleHideNameTag = v
    if State.InvisibleEnabled then
        local _, hum = GetCharacter()
        if v and hum then HideNameTag(hum) elseif hum then RestoreNameTag(hum) end
    end
end)
CreateToggle(invisSection, "Keep Tools Visible", false, function(v)
    CONFIG.InvisibleKeepTools = v
    if State.InvisibleEnabled then StopInvisible() StartInvisible() end
end)
invisBtn = CreateButton(invisSection, "👻  ENABLE INVISIBLE", CONFIG.AccentPurple, function()
    SetInvisibleUI(not State.InvisibleEnabled)
end)
CreateButton(invisSection, "REAPPLY GHOST SWEEP", Color3.fromRGB(40, 55, 100), function()
    if State.InvisibleEnabled then
        local c = LocalPlayer.Character
        if c then SweepCharacterInvisible(c) end
    end
end)

-- WORLD / PERFORMANCE
local worldSection = CreateSection(VisualsContent, "☀️ WORLD / PERFORMANCE")
local fbStatus = Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = "Full Bright: OFF",
    TextColor3 = CONFIG.DangerRed, TextSize = 13, Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = worldSection,
})
Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
    Text = "Adaptive — dark maps lift more, bright maps stay soft",
    TextColor3 = CONFIG.TextDim, TextSize = 11, Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, Parent = worldSection,
})

local fbBtn
local function SetFullBright(on)
    if on then
        StartFullBright()
        local d = math.floor(State.SceneDarkness * 100)
        fbStatus.Text = string.format("Full Bright: ON  |  scene dark %d%%", d)
        fbStatus.TextColor3 = CONFIG.SuccessGreen
        if fbBtn then fbBtn.Text = "■  DISABLE FULL BRIGHT" fbBtn.BackgroundColor3 = CONFIG.DangerRed end
    else
        StopFullBright()
        fbStatus.Text = "Full Bright: OFF"
        fbStatus.TextColor3 = CONFIG.DangerRed
        if fbBtn then fbBtn.Text = "☀  ENABLE FULL BRIGHT" fbBtn.BackgroundColor3 = CONFIG.WarningYellow end
    end
end
CreateToggle(worldSection, "Full Bright Toggle", false, function(v) SetFullBright(v) end)
CreateSlider(worldSection, "Full Bright Intensity (adaptive)", 0, 100, 55, function(v)
    State.FullBrightIntensity = v
    if State.FullBrightEnabled then ApplyAdaptiveFullBright() end
end)
fbBtn = CreateButton(worldSection, "☀  ENABLE FULL BRIGHT", CONFIG.WarningYellow, function()
    SetFullBright(not State.FullBrightEnabled)
end)

local fpsStatus = Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = "FPS Boost: OFF",
    TextColor3 = CONFIG.DangerRed, TextSize = 13, Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 20, Parent = worldSection,
})
local fpsBtn
local function SetFPSBoost(on)
    if on then
        StartFPSBoost()
        fpsStatus.Text = "FPS Boost: ON — low graphics / less lag"
        fpsStatus.TextColor3 = CONFIG.SuccessGreen
        if fpsBtn then fpsBtn.Text = "■  DISABLE FPS BOOST" fpsBtn.BackgroundColor3 = CONFIG.DangerRed end
    else
        StopFPSBoost()
        fpsStatus.Text = "FPS Boost: OFF"
        fpsStatus.TextColor3 = CONFIG.DangerRed
        if fpsBtn then fpsBtn.Text = "🚀  ENABLE SUPER FPS BOOST" fpsBtn.BackgroundColor3 = CONFIG.AccentTeal end
    end
end
CreateToggle(worldSection, "Super FPS Boost Toggle", false, function(v) SetFPSBoost(v) end)
fpsBtn = CreateButton(worldSection, "🚀  ENABLE SUPER FPS BOOST", CONFIG.AccentTeal, function()
    SetFPSBoost(not State.FPSBoostEnabled)
end)

local tpCtrlSection = CreateSection(VisualsContent, "✈️ FLY-TO TELEPORT")
Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
    Text = "TP buttons fly you to the player (not instant blink)",
    TextColor3 = CONFIG.TextDim, TextSize = 11, Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = tpCtrlSection,
})
CreateSlider(tpCtrlSection, "Fly-To Speed (studs/sec)", 30, 600, 120, function(v)
    State.TeleportSpeed = v
end)
CreateButton(tpCtrlSection, "■  CANCEL FLY-TO", CONFIG.DangerRed, function()
    if State.IsTeleporting then StopFlyTo() end
end)

local espSection = CreateSection(VisualsContent, "ESP SYSTEM")
CreateToggle(espSection, "Global Player ESP", false, function(v)
    State.ESPEnabled = v
    if v then StartESP() else StopESP() end
end)

-- PLAYERS LIST
local tpSection = CreateSection(VisualsContent, "PLAYERS — FLY-TO / ESP / AIM")
State.PlayerCountLabel = Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
    Text = "Players in server: 0",
    TextColor3 = CONFIG.AccentTeal, TextSize = 13, Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = tpSection,
})
State.RefreshStatusLabel = Create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
    Text = "List sync: waiting...",
    TextColor3 = CONFIG.TextDim, TextSize = 11, Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, Parent = tpSection,
})
local PlayerListFrame = Create("Frame", {
    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1, LayoutOrder = 10, Parent = tpSection,
})
Create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = PlayerListFrame})

local RefreshPlayerList

local function UpdatePlayerCountUI(extra)
    local total = #Players:GetPlayers()
    local others = math.max(0, total - 1)
    State.LastPlayerCount = total
    if State.PlayerCountLabel then
        State.PlayerCountLabel.Text = string.format("Players in server: %d  |  listed: %d", total, others)
    end
    if State.RefreshStatusLabel then
        local stamp = os.date("%H:%M:%S")
        State.RefreshStatusLabel.Text = (extra or "List synced") .. "  •  " .. stamp
        State.RefreshStatusLabel.TextColor3 = CONFIG.SuccessGreen
        task.delay(1.2, function()
            if State.RefreshStatusLabel then State.RefreshStatusLabel.TextColor3 = CONFIG.TextDim end
        end)
    end
end

local refreshBtn = CreateButton(tpSection, "🔄  REFRESH PLAYER LIST", CONFIG.AccentPurple, function(btn)
    local oldText = btn.Text
    btn.Text = "🔄  REFRESHING..."
    btn.BackgroundColor3 = CONFIG.WarningYellow
    RefreshPlayerList(true)
    task.delay(0.25, function()
        if btn and btn.Parent then btn.Text = oldText btn.BackgroundColor3 = CONFIG.AccentPurple end
    end)
end)
refreshBtn.LayoutOrder = 3

CreateToggle(tpSection, "Auto-Refresh Players", true, function(v)
    CONFIG.AutoRefreshPlayers = v
    if State.RefreshStatusLabel then
        State.RefreshStatusLabel.Text = v and "Auto-refresh ON" or "Auto-refresh OFF"
    end
end)

local function DestroyESPForPlayer(plr)
    local objs = State.ESPObjects[plr]
    if objs and objs.Billboard then objs.Billboard:Destroy() end
    State.ESPObjects[plr] = nil
end

local function CreateESPForPlayer(plr)
    if State.ESPObjects[plr] then return end
    local billboard = Create("BillboardGui", {
        Name = "pthub_ESP_" .. plr.Name, Size = UDim2.new(0, 200, 0, 70),
        StudsOffset = Vector3.new(0, 3.2, 0), AlwaysOnTop = true, MaxDistance = 5000, Parent = CoreGui,
    })
    local container = Create("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Parent = billboard})
    Create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = plr.Name,
        TextColor3 = CONFIG.TextWhite, TextSize = 14, Font = Enum.Font.GothamBold,
        TextStrokeTransparency = 0.4, Parent = container,
    })
    local distTag = Create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 16), BackgroundTransparency = 1,
        Text = "0m", TextColor3 = CONFIG.AccentTeal, TextSize = 12, Font = Enum.Font.Gotham,
        TextStrokeTransparency = 0.4, Parent = container,
    })
    local healthBg = Create("Frame", {
        Size = UDim2.new(0.8, 0, 0, 6), Position = UDim2.new(0.1, 0, 0, 36),
        BackgroundColor3 = Color3.fromRGB(30, 30, 30), BorderSizePixel = 0, Parent = container,
    })
    Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = healthBg})
    local healthFill = Create("Frame", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = CONFIG.SuccessGreen, BorderSizePixel = 0, Parent = healthBg,
    })
    Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = healthFill})
    local healthText = Create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 44), BackgroundTransparency = 1,
        Text = "100%", TextColor3 = CONFIG.TextDim, TextSize = 11, Font = Enum.Font.Gotham, Parent = container,
    })
    State.ESPObjects[plr] = {Billboard = billboard, DistTag = distTag, HealthFill = healthFill, HealthText = healthText}
    local function adorn()
        local head = plr.Character and plr.Character:FindFirstChild("Head")
        if head then billboard.Adornee = head end
    end
    adorn()
    plr.CharacterAdded:Connect(adorn)
end

local function EnsureESPLoop()
    if State.Connections.ESP then return end
    State.Connections.ESP = RunService.RenderStepped:Connect(function()
        local localHRP = State.HRP or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"))
        for plr, objs in pairs(State.ESPObjects) do
            if plr.Parent and plr.Character and objs.Billboard then
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                local head = plr.Character:FindFirstChild("Head")
                if hum and hrp and head then
                    objs.Billboard.Adornee = head
                    if localHRP then
                        objs.DistTag.Text = string.format("%dm", math.floor((localHRP.Position - hrp.Position).Magnitude))
                    end
                    local hpPct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                    objs.HealthFill.Size = UDim2.new(hpPct, 0, 1, 0)
                    objs.HealthText.Text = string.format("%d%%", math.floor(hpPct * 100))
                    objs.HealthFill.BackgroundColor3 = (hpPct > 0.6 and CONFIG.SuccessGreen)
                        or (hpPct > 0.3 and CONFIG.WarningYellow) or CONFIG.DangerRed
                end
            end
        end
    end)
end

function StartESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then CreateESPForPlayer(plr) end
    end
    EnsureESPLoop()
end

function StopESP()
    for plr in pairs(State.ESPObjects) do DestroyESPForPlayer(plr) end
    if State.Connections.ESP then State.Connections.ESP:Disconnect() State.Connections.ESP = nil end
end

local function TogglePlayerESP(plr, btn)
    if State.ESPObjects[plr] then
        DestroyESPForPlayer(plr)
        if btn then btn.BackgroundColor3 = Color3.fromRGB(40, 40, 65); btn.Text = "ESP" end
    else
        CreateESPForPlayer(plr); EnsureESPLoop()
        if btn then btn.BackgroundColor3 = CONFIG.SuccessGreen; btn.Text = "ON" end
    end
end

RefreshPlayerList = function(manual)
    for _, child in ipairs(PlayerListFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    for plr, _ in pairs(State.ESPObjects) do
        if not plr.Parent or plr == LocalPlayer then DestroyESPForPlayer(plr) end
    end

    local list = Players:GetPlayers()
    table.sort(list, function(a, b) return string.lower(a.Name) < string.lower(b.Name) end)

    local shown = 0
    for _, plr in ipairs(list) do
        if plr == LocalPlayer then continue end
        shown += 1
        if State.ESPEnabled and not State.ESPObjects[plr] then
            CreateESPForPlayer(plr)
            EnsureESPLoop()
        end

        local row = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = Color3.fromRGB(22, 22, 40), Parent = PlayerListFrame,
        })
        Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = row})

        local display = plr.DisplayName ~= plr.Name and (plr.DisplayName .. " (@" .. plr.Name .. ")") or plr.Name
        Create("TextLabel", {
            Size = UDim2.new(1, -155, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1,
            Text = display, TextColor3 = CONFIG.TextWhite, TextSize = 12, Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
        })

        local tpBtn = Create("TextButton", {
            Size = UDim2.new(0, 40, 0, 28), Position = UDim2.new(1, -146, 0.5, -14),
            BackgroundColor3 = CONFIG.AccentTeal, Text = "FLY", TextColor3 = CONFIG.MainColor,
            TextSize = 11, Font = Enum.Font.GothamBold, Parent = row,
        })
        Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = tpBtn})
        tpBtn.MouseButton1Click:Connect(function() FlyToPlayer(plr) end)

        local espOn = State.ESPObjects[plr] ~= nil
        local espBtn = Create("TextButton", {
            Size = UDim2.new(0, 40, 0, 28), Position = UDim2.new(1, -100, 0.5, -14),
            BackgroundColor3 = espOn and CONFIG.SuccessGreen or Color3.fromRGB(40, 40, 65),
            Text = espOn and "ON" or "ESP", TextColor3 = CONFIG.TextWhite,
            TextSize = 11, Font = Enum.Font.GothamBold, Parent = row,
        })
        Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = espBtn})
        espBtn.MouseButton1Click:Connect(function() TogglePlayerESP(plr, espBtn) end)

        local aimBtn = Create("TextButton", {
            Size = UDim2.new(0, 40, 0, 28), Position = UDim2.new(1, -54, 0.5, -14),
            BackgroundColor3 = CONFIG.AccentPurple, Text = "AIM", TextColor3 = CONFIG.TextWhite,
            TextSize = 11, Font = Enum.Font.GothamBold, Parent = row,
        })
        Create("UICorner", {CornerRadius = UDim.new(0, 5), Parent = aimBtn})
        aimBtn.MouseButton1Click:Connect(function()
            State.SelectedAimPlayer = plr
            State.AimMode = "Selected"
            aimModeLabel.Text = "Target Mode: " .. plr.Name
        end)
    end

    if shown == 0 then
        local empty = Create("Frame", {
            Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Color3.fromRGB(18, 18, 34), Parent = PlayerListFrame,
        })
        Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = empty})
        Create("TextLabel", {
            Size = UDim2.new(1, -16, 1, 0), Position = UDim2.new(0, 8, 0, 0), BackgroundTransparency = 1,
            Text = "No other players yet — hit Refresh when someone joins",
            TextColor3 = CONFIG.TextDim, TextSize = 12, Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = empty,
        })
    end
    UpdatePlayerCountUI(manual and "Manual refresh OK" or "Auto sync OK")
end

-- FLY / NOCLIP
function StartFly()
    StopFly()
    RefreshCharacter()
    if not State.HRP or not State.Humanoid then return end
    State.Humanoid.PlatformStand = true
    if State.FlyMode == "Velocity" then
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Velocity = Vector3.zero; bv.Parent = State.HRP; State.FlyBodyVelocity = bv
        if State.FlySmooth then
            local bg = Instance.new("BodyGyro")
            bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bg.P = 9e4; bg.D = 500; bg.Parent = State.HRP; State.FlyBodyGyro = bg
        end
    end
    State.Connections.Fly = RunService.RenderStepped:Connect(function(dt)
        if not State.FlyEnabled or not State.HRP or not State.HRP.Parent then StopFly() return end
        if State.IsTeleporting then return end
        local camCF = Camera.CFrame
        local dir, upDown = Vector3.zero, 0
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= camCF.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then upDown += 1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then upDown -= 1 end
        if State.FlyMode == "Velocity" then
            local final = Vector3.zero
            if dir.Magnitude > 0 then final += dir.Unit * State.FlySpeed end
            final += Vector3.new(0, upDown * State.FlySpeed * State.FlyVerticalMult, 0)
            if State.FlyBodyVelocity then State.FlyBodyVelocity.Velocity = final end
            if State.FlyBodyGyro then State.FlyBodyGyro.CFrame = camCF end
        else
            local move = Vector3.zero
            if dir.Magnitude > 0 then move += dir.Unit end
            move += Vector3.new(0, upDown * State.FlyVerticalMult, 0)
            if move.Magnitude > 0 then State.HRP.CFrame += move.Unit * State.FlySpeed * dt * 3.5 end
            State.HRP.AssemblyLinearVelocity = Vector3.zero
            State.HRP.AssemblyAngularVelocity = Vector3.zero
            if State.FlySmooth then
                State.HRP.CFrame = CFrame.new(State.HRP.Position, State.HRP.Position + camCF.LookVector)
            end
        end
    end)
end

function StopFly()
    if State.Connections.Fly then State.Connections.Fly:Disconnect(); State.Connections.Fly = nil end
    if State.FlyBodyVelocity then State.FlyBodyVelocity:Destroy(); State.FlyBodyVelocity = nil end
    if State.FlyBodyGyro then State.FlyBodyGyro:Destroy(); State.FlyBodyGyro = nil end
    if State.Humanoid and not State.IsTeleporting then State.Humanoid.PlatformStand = false end
end

function StartNoClip()
    StopNoClip()
    State.Connections.NoClip = RunService.Stepped:Connect(function()
        if not State.NoClipEnabled then return end
        local char = LocalPlayer.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end)
end

function StopNoClip()
    if State.Connections.NoClip then
        State.Connections.NoClip:Disconnect()
        State.Connections.NoClip = nil
    end
end

Players.PlayerAdded:Connect(function(plr)
    if State.ESPEnabled then
        task.spawn(function()
            task.wait(0.5)
            if plr.Parent then CreateESPForPlayer(plr) EnsureESPLoop() end
        end)
    end
    task.defer(function() RefreshPlayerList(false) end)
    task.delay(1, function() if plr.Parent then RefreshPlayerList(false) end end)
end)

Players.PlayerRemoving:Connect(function(plr)
    DestroyESPForPlayer(plr)
    if State.SelectedAimPlayer == plr then State.SelectedAimPlayer = nil end
    if State.TeleportTarget == plr then StopFlyTo() end
    task.defer(function() RefreshPlayerList(false) end)
end)

task.spawn(function()
    while ScreenGui.Parent do
        task.wait(CONFIG.AutoRefreshInterval)
        if not ScreenGui.Parent then break end
        if CONFIG.AutoRefreshPlayers then
            local count = #Players:GetPlayers()
            if count ~= State.LastPlayerCount then
                RefreshPlayerList(false)
            else
                UpdatePlayerCountUI("Live check")
            end
        end
    end
end)

-- AIM
local FOVCircle = Drawing and Drawing.new("Circle") or nil
if FOVCircle then
    FOVCircle.Thickness = 1.5; FOVCircle.NumSides = 64; FOVCircle.Radius = 120
    FOVCircle.Filled = false; FOVCircle.Color = Color3.fromRGB(108, 92, 231)
    FOVCircle.Transparency = 0.4; FOVCircle.Visible = false
end
function UpdateFOVCircle() if FOVCircle then FOVCircle.Radius = State.AimFOV end end

local function IsVisible(targetHRP)
    if not CONFIG.AimVisibleCheck then return true end
    local origin = Camera.CFrame.Position
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LocalPlayer.Character}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local result = workspace:Raycast(origin, targetHRP.Position - origin, params)
    if result then
        local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
        return hitChar and hitChar:FindFirstChildOfClass("Humanoid") ~= nil
    end
    return true
end

local function GetClosestInFOV()
    local closest, shortest = nil, State.AimFOV
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if CONFIG.AimTeamCheck and plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team then continue end
        local _, hum, hrp = GetCharacter(plr)
        if hum and hum.Health > 0 and hrp then
            local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen then
                local center = Camera.ViewportSize / 2
                local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(center.X, center.Y)).Magnitude
                if dist2D < shortest and IsVisible(hrp) then
                    shortest = dist2D; closest = hrp
                end
            end
        end
    end
    return closest
end

State.Connections.Aim = RunService.RenderStepped:Connect(function()
    if FOVCircle then
        FOVCircle.Position = Camera.ViewportSize / 2
        FOVCircle.Visible = State.AimAssistEnabled
        FOVCircle.Radius = State.AimFOV
    end
    if not State.AimAssistEnabled then return end
    local targetPart = nil
    if State.AimMode == "Selected" and State.SelectedAimPlayer then
        local _, hum, hrp = GetCharacter(State.SelectedAimPlayer)
        if hum and hum.Health > 0 and hrp then targetPart = hrp end
    else
        targetPart = GetClosestInFOV()
    end
    if targetPart then
        local cur = Camera.CFrame
        Camera.CFrame = cur:Lerp(CFrame.new(cur.Position, targetPart.Position + Vector3.new(0, 1.5, 0)), State.AimSmooth)
    end
end)

State.Connections.InputJump = UserInputService.JumpRequest:Connect(function()
    if not State.InfiniteJump then return end
    local _, hum, hrp = GetCharacter()
    if hum and hrp and hum.Health > 0 then
        SafePcall(function()
            local power = GetEffectiveJumpPower()
            hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, power * 0.65, hrp.AssemblyLinearVelocity.Z)
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end
end)

local function OnCharacterAdded()
    task.wait(0.15)
    RefreshCharacter()
    if State.IsTeleporting then StopFlyTo() end
    if State.FlyEnabled then StartFly() end
    if State.NoClipEnabled then StartNoClip() end
    if State.InvisibleEnabled then
        task.defer(function()
            task.wait(0.2)
            StartInvisible()
        end)
    end
    if State.Humanoid then
        State.Humanoid.Died:Connect(function()
            StopFly()
            StopFlyTo()
        end)
    end
end
if LocalPlayer.Character then OnCharacterAdded() end
LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)

-- chrome
local draggingUI, dragStart, startPos = false, nil, nil
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingUI = true; dragStart = input.Position; startPos = MainFrame.Position
    end
end)
Header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingUI = false
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if draggingUI and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

local minimized = false
MinimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Tween(MainFrame, {Size = minimized and UDim2.new(0, 510, 0, 50) or UDim2.new(0, 510, 0, 680)}, 0.28)
end)

CloseBtn.MouseButton1Click:Connect(function()
    Tween(MainFrame, {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1}, 0.22)
    task.delay(0.25, function()
        if State.FullBrightEnabled then StopFullBright() end
        if State.FPSBoostEnabled then StopFPSBoost() end
        if State.InvisibleEnabled then StopInvisible() end
        StopFlyTo()
        ScreenGui:Destroy()
        StopFly(); StopNoClip(); StopESP()
        for _, c in pairs(State.Connections) do
            if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
        end
        if FOVCircle then FOVCircle:Remove() end
    end)
end)

CombatTabBtn.MouseButton1Click:Connect(function()
    CombatContent.Visible = true; VisualsContent.Visible = false
    Tween(CombatTabBtn, {BackgroundColor3 = CONFIG.AccentPurple}, 0.15)
    Tween(VisualsTabBtn, {BackgroundColor3 = Color3.fromRGB(25, 25, 45)}, 0.15)
    CombatTabBtn.TextColor3 = CONFIG.TextWhite; VisualsTabBtn.TextColor3 = CONFIG.TextDim
end)
VisualsTabBtn.MouseButton1Click:Connect(function()
    CombatContent.Visible = false; VisualsContent.Visible = true
    Tween(VisualsTabBtn, {BackgroundColor3 = CONFIG.AccentTeal}, 0.15)
    Tween(CombatTabBtn, {BackgroundColor3 = Color3.fromRGB(25, 25, 45)}, 0.15)
    VisualsTabBtn.TextColor3 = CONFIG.TextWhite; CombatTabBtn.TextColor3 = CONFIG.TextDim
    RefreshPlayerList(true)
end)

MainFrame.Size = UDim2.new(0, 0, 0, 0)
MainFrame.BackgroundTransparency = 1
Tween(MainFrame, {Size = UDim2.new(0, 510, 0, 680), BackgroundTransparency = 0}, 0.35, Enum.EasingStyle.Back)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        State.MenuOpen = not State.MenuOpen
        MainFrame.Visible = State.MenuOpen
    end
end)

RefreshCharacter()
RefreshPlayerList(true)

State.Connections.Stats = RunService.Heartbeat:Connect(function()
    if State.IsTeleporting then return end
    if not State.Humanoid or not State.Humanoid.Parent then RefreshCharacter() return end
    if State.SpeedEnabled and not State.UseCFrameSpeed and not State.FlyEnabled then
        local target = GetEffectiveWalkSpeed()
        if State.Humanoid.WalkSpeed ~= target then
            SafePcall(function() State.Humanoid.WalkSpeed = target end)
        end
    end
    if State.JumpEnabled and not State.FlyEnabled then
        local jp = GetEffectiveJumpPower()
        if State.Humanoid.JumpPower ~= jp then
            SafePcall(function()
                State.Humanoid.JumpPower = jp
                if State.Humanoid.UseJumpPower == false then State.Humanoid.JumpHeight = jp / 20 end
            end)
        end
    end
    if State.SpeedEnabled and State.UseCFrameSpeed and State.HRP and not State.FlyEnabled then
        if State.Humanoid.MoveDirection.Magnitude > 0 then
            State.HRP.CFrame += State.Humanoid.MoveDirection * State.CFrameSpeedValue * State.SpeedBoostMult
        end
    end
end)

print("[pthub] v" .. CONFIG.Version .. " | INVISIBLE top of VISUALS tab | RightShift")
