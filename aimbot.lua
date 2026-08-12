-- pthub v2.9.6 | UI REWORK — pure dark / minimal / smooth + circle orb (overlap FIXED)
-- RightShift = toggle | LocalScript / Executor

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
	Version = "2.9.6",
	Bg = Color3.fromHex("#0a0a0f"),
	Surface = Color3.fromHex("#12121a"),
	Surface2 = Color3.fromHex("#1a1a24"),
	Border = Color3.fromHex("#2a2a38"),
	Text = Color3.fromHex("#e8e8ed"),
	TextDim = Color3.fromHex("#6b6b7b"),
	Accent = Color3.fromHex("#8b5cf6"),
	AccentDim = Color3.fromHex("#6d28d9"),
	Good = Color3.fromHex("#22c55e"),
	Bad = Color3.fromHex("#ef4444"),
	Warn = Color3.fromHex("#eab308"),
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
	OrbSize = 54,
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
	FullBrightEnabled = false, FullBrightIntensity = 55,
	FPSBoostEnabled = false,
	InvisibleEnabled = false, InvisibleSaved = {}, InvisibleNameTagHidden = false,
	TeleportSpeed = 120, TeleportStyle = "FlyTo", IsTeleporting = false, TeleportTarget = nil,
	MenuOpen = true, Minimized = false, ActiveTab = "Combat",
	Connections = {}, ESPObjects = {},
	FlyBodyVelocity = nil, FlyBodyGyro = nil,
	Character = nil, Humanoid = nil, HRP = nil,
	SavedLighting = nil, SavedPostFX = {}, SavedTerrain = nil, SavedQuality = nil,
	FB_CC = nil, SceneDarkness = 0.5,
	LastPlayerCount = 0, PlayerCountLabel = nil, RefreshStatusLabel = nil,
	SavedMainPos = nil,
	AnimLock = false,
}

local function SafePcall(fn, ...) local ok, res = pcall(fn, ...) return ok, res end

local function Create(class, props)
	local obj = Instance.new(class)
	for k, v in pairs(props or {}) do if k ~= "Parent" then obj[k] = v end end
	if props and props.Parent then obj.Parent = props.Parent end
	return obj
end

local function Tween(obj, props, duration, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(duration or 0.22, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function GetCharacter(player)
	player = player or LocalPlayer
	local char = player.Character
	if not char then return nil, nil, nil end
	return char, char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
end

local function GetEffectiveWalkSpeed() return math.clamp(State.WalkSpeed * State.SpeedBoostMult, 0, 1000) end
local function GetEffectiveJumpPower()
	if State.SuperJump then return math.clamp(State.SuperJumpPower * State.JumpBoostMult, 0, 2000) end
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
			if State.Humanoid.UseJumpPower == false then State.Humanoid.JumpHeight = jp / 20 end
		else
			State.Humanoid.JumpPower = 50
			if State.Humanoid.UseJumpPower == false then State.Humanoid.JumpHeight = 7.2 end
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
			if not CONFIG.InvisibleLocalOnly then inst.Transparency = 1 end
			if CONFIG.InvisibleHideShadow then inst.CastShadow = false end
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
			if State.InvisibleEnabled then task.defer(function() SweepCharacterInvisible(char) end) end
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

local function SetInvisible(on) if on then StartInvisible() else StopInvisible() end end

-- =========================================================
-- FULLBRIGHT + FPS
-- =========================================================
local function Luma(c) return c.R * 0.2126 + c.G * 0.7152 + c.B * 0.0722 end

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
	if not wasNoClip then State.NoClipEnabled = true StartNoClip() end
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

-- =========================================================
-- UI
-- =========================================================
local ScreenGui = Create("ScreenGui", {
	Name = "pthub_UI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	IgnoreGuiInset = true,
	Parent = CoreGui,
})

local Main = Create("Frame", {
	Name = "Main",
	Size = UDim2.fromOffset(420, 560),
	Position = UDim2.new(0.5, -210, 0.5, -280),
	BackgroundColor3 = CONFIG.Bg,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Parent = ScreenGui,
})
local MainCorner = Create("UICorner", {CornerRadius = UDim.new(0, 16), Parent = Main})
local MainStroke = Create("UIStroke", {Color = CONFIG.Border, Thickness = 1, Transparency = 0.35, Parent = Main})

local Shadow = Create("ImageLabel", {
	Name = "Shadow",
	BackgroundTransparency = 1,
	Image = "rbxassetid://6014261993",
	ImageColor3 = Color3.new(0, 0, 0),
	ImageTransparency = 0.45,
	ScaleType = Enum.ScaleType.Slice,
	SliceCenter = Rect.new(49, 49, 450, 450),
	Size = UDim2.new(1, 48, 1, 48),
	Position = UDim2.fromOffset(-24, -24),
	ZIndex = 0,
	Parent = Main,
})

-- BODY holds all interactive chrome so minimize never nukes tab state wrong
local Body = Create("Frame", {
	Name = "Body",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Parent = Main,
})

-- HEADER
local Header = Create("Frame", {
	Size = UDim2.new(1, 0, 0, 52),
	BackgroundColor3 = CONFIG.Surface,
	BorderSizePixel = 0,
	Parent = Body,
})
Create("UICorner", {CornerRadius = UDim.new(0, 16), Parent = Header})
Create("Frame", {
	Size = UDim2.new(1, 0, 0, 18),
	Position = UDim2.new(0, 0, 1, -18),
	BackgroundColor3 = CONFIG.Surface,
	BorderSizePixel = 0,
	Parent = Header,
})
Create("Frame", {
	Size = UDim2.new(1, 0, 0, 1),
	Position = UDim2.new(0, 0, 1, -1),
	BackgroundColor3 = CONFIG.Accent,
	BorderSizePixel = 0,
	BackgroundTransparency = 0.55,
	Parent = Header,
})
Create("TextLabel", {
	Size = UDim2.new(0, 160, 1, 0),
	Position = UDim2.fromOffset(18, 0),
	BackgroundTransparency = 1,
	Text = "pthub",
	TextColor3 = CONFIG.Text,
	TextSize = 18,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = Header,
})
local Ver = Create("TextLabel", {
	Size = UDim2.fromOffset(52, 20),
	Position = UDim2.new(0, 78, 0.5, -10),
	BackgroundColor3 = CONFIG.Surface2,
	Text = "v"..CONFIG.Version,
	TextColor3 = CONFIG.TextDim,
	TextSize = 11,
	Font = Enum.Font.GothamMedium,
	Parent = Header,
})
Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = Ver})

local function IconBtn(parent, x, txt, bg)
	local b = Create("TextButton", {
		Size = UDim2.fromOffset(30, 30),
		Position = UDim2.new(1, x, 0.5, -15),
		BackgroundColor3 = bg or CONFIG.Surface2,
		Text = txt,
		TextColor3 = CONFIG.Text,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = false,
		Parent = parent,
	})
	Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = b})
	b.MouseEnter:Connect(function() Tween(b, {BackgroundTransparency = 0.15}, 0.15) end)
	b.MouseLeave:Connect(function() Tween(b, {BackgroundTransparency = 0}, 0.15) end)
	return b
end

local MinBtn = IconBtn(Header, -78, "—")
local CloseBtn = IconBtn(Header, -40, "✕", Color3.fromHex("#3f1d1d"))

-- ORB
local Orb = Create("TextButton", {
	Name = "MinimizeOrb",
	Size = UDim2.fromOffset(CONFIG.OrbSize, CONFIG.OrbSize),
	Position = UDim2.new(0.5, -CONFIG.OrbSize/2, 0.5, -CONFIG.OrbSize/2),
	BackgroundColor3 = CONFIG.Bg,
	Text = "",
	AutoButtonColor = false,
	Visible = false,
	Parent = ScreenGui,
	ZIndex = 20,
})
Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = Orb})
local OrbStroke = Create("UIStroke", {
	Color = CONFIG.Accent,
	Thickness = 2,
	Transparency = 0.15,
	Parent = Orb,
})
Create("ImageLabel", {
	Name = "OrbShadow",
	BackgroundTransparency = 1,
	Image = "rbxassetid://6014261993",
	ImageColor3 = Color3.new(0, 0, 0),
	ImageTransparency = 0.35,
	ScaleType = Enum.ScaleType.Slice,
	SliceCenter = Rect.new(49, 49, 450, 450),
	Size = UDim2.new(1, 28, 1, 28),
	Position = UDim2.fromOffset(-14, -14),
	ZIndex = 19,
	Parent = Orb,
})
local OrbCore = Create("Frame", {
	Size = UDim2.fromOffset(38, 38),
	Position = UDim2.new(0.5, -19, 0.5, -19),
	BackgroundColor3 = CONFIG.Surface,
	BorderSizePixel = 0,
	ZIndex = 21,
	Parent = Orb,
})
Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = OrbCore})
local OrbLabel = Create("TextLabel", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "P",
	TextColor3 = CONFIG.Accent,
	TextSize = 18,
	Font = Enum.Font.GothamBold,
	ZIndex = 22,
	Parent = OrbCore,
})
local OrbGlow = Create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = CONFIG.Accent,
	BackgroundTransparency = 0.88,
	BorderSizePixel = 0,
	ZIndex = 20,
	Parent = Orb,
})
Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = OrbGlow})

task.spawn(function()
	while Orb.Parent do
		if Orb.Visible then
			Tween(OrbStroke, {Transparency = 0.05, Thickness = 2.4}, 0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			Tween(OrbGlow, {BackgroundTransparency = 0.82}, 0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(0.95)
			Tween(OrbStroke, {Transparency = 0.25, Thickness = 1.6}, 0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			Tween(OrbGlow, {BackgroundTransparency = 0.92}, 0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(0.95)
		else
			task.wait(0.25)
		end
	end
end)

-- TABS
local TabBar = Create("Frame", {
	Size = UDim2.new(1, -28, 0, 36),
	Position = UDim2.fromOffset(14, 62),
	BackgroundColor3 = CONFIG.Surface,
	BorderSizePixel = 0,
	Parent = Body,
})
Create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = TabBar})
Create("UIPadding", {PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3), PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3), Parent = TabBar})
Create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Parent = TabBar})

local function MakeTab(text, active)
	local b = Create("TextButton", {
		Size = UDim2.new(0.5, -2, 1, 0),
		BackgroundColor3 = active and CONFIG.Accent or Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = active and 0 or 1,
		Text = text,
		TextColor3 = active and CONFIG.Text or CONFIG.TextDim,
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = false,
		Parent = TabBar,
	})
	Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = b})
	return b
end

local CombatTab = MakeTab("COMBAT", true)
local VisualsTab = MakeTab("VISUALS", false)

local function MakeScroll(vis)
	local sf = Create("ScrollingFrame", {
		Size = UDim2.new(1, -28, 1, -118),
		Position = UDim2.fromOffset(14, 108),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = CONFIG.Accent,
		ScrollBarImageTransparency = 0.4,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = vis,
		Parent = Body,
	})
	Create("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sf})
	Create("UIPadding", {PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 16), PaddingRight = UDim.new(0, 6), Parent = sf})
	return sf
end

local CombatContent = MakeScroll(true)
local VisualsContent = MakeScroll(false)

local order = 0
local function nextOrder() order += 1 return order end

local function Section(parent, title)
	local s = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = CONFIG.Surface,
		BorderSizePixel = 0,
		LayoutOrder = nextOrder(),
		Parent = parent,
	})
	Create("UICorner", {CornerRadius = UDim.new(0, 12), Parent = s})
	Create("UIStroke", {Color = CONFIG.Border, Thickness = 1, Transparency = 0.55, Parent = s})
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = s,
	})
	Create("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = s})
	Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = CONFIG.TextDim,
		TextSize = 11,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
		Parent = s,
	})
	return s
end

local function Toggle(parent, text, default, callback)
	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		LayoutOrder = #parent:GetChildren() + 1,
		Parent = parent,
	})
	Create("TextLabel", {
		Size = UDim2.new(1, -54, 1, 0),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = CONFIG.Text,
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = holder,
	})
	local track = Create("Frame", {
		Size = UDim2.fromOffset(44, 24),
		Position = UDim2.new(1, -44, 0.5, -12),
		BackgroundColor3 = default and CONFIG.Accent or CONFIG.Surface2,
		Parent = holder,
	})
	Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = track})
	local knob = Create("Frame", {
		Size = UDim2.fromOffset(18, 18),
		Position = default and UDim2.new(1, -21, 0.5, -9) or UDim2.fromOffset(3, 3),
		BackgroundColor3 = CONFIG.Text,
		Parent = track,
	})
	Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = knob})
	local on = default
	local hit = Create("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = holder})
	local function render()
		Tween(track, {BackgroundColor3 = on and CONFIG.Accent or CONFIG.Surface2}, 0.18)
		Tween(knob, {Position = on and UDim2.new(1, -21, 0.5, -9) or UDim2.fromOffset(3, 3)}, 0.18, Enum.EasingStyle.Quint)
	end
	hit.MouseButton1Click:Connect(function()
		on = not on
		render()
		if callback then callback(on) end
	end)
	return {Set = function(v) on = v render() end, Get = function() return on end}
end

local function Slider(parent, text, min, max, default, callback)
	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = CONFIG.Surface2,
		BorderSizePixel = 0,
		LayoutOrder = #parent:GetChildren() + 1,
		Parent = parent,
	})
	Create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = holder})
	Create("UIPadding", {
		PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = holder,
	})
	Create("TextLabel", {
		Size = UDim2.new(0.7, 0, 0, 16),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = CONFIG.Text,
		TextSize = 12,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = holder,
	})
	local valLab = Create("TextLabel", {
		Size = UDim2.new(0.3, 0, 0, 16),
		Position = UDim2.new(0.7, 0, 0, 0),
		BackgroundTransparency = 1,
		Text = tostring(default),
		TextColor3 = CONFIG.Accent,
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = holder,
	})
	local track = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 6),
		Position = UDim2.fromOffset(0, 32),
		BackgroundColor3 = CONFIG.Bg,
		BorderSizePixel = 0,
		Parent = holder,
	})
	Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = track})
	local fill = Create("Frame", {
		Size = UDim2.new((default - min) / math.max(max - min, 1), 0, 1, 0),
		BackgroundColor3 = CONFIG.Accent,
		BorderSizePixel = 0,
		Parent = track,
	})
	Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = fill})
	local knob = Create("Frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.new((default - min) / math.max(max - min, 1), -7, 0.5, -7),
		BackgroundColor3 = CONFIG.Text,
		ZIndex = 2,
		Parent = track,
	})
	Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = knob})

	local dragging, cur = false, default
	local function set(v)
		v = math.clamp(tonumber(v) or cur, min, max)
		if max >= 20 then v = math.floor(v + 0.5) else v = math.floor(v * 100 + 0.5) / 100 end
		cur = v
		local pct = (v - min) / math.max(max - min, 1)
		Tween(fill, {Size = UDim2.new(pct, 0, 1, 0)}, 0.08)
		Tween(knob, {Position = UDim2.new(pct, -7, 0.5, -7)}, 0.08)
		valLab.Text = tostring(v)
		if callback then callback(v) end
	end
	local function pick(x)
		local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		set(min + rel * (max - min))
	end
	track.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true pick(i.Position.X)
		end
	end)
	knob.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			pick(i.Position.X)
		end
	end)
	return {Set = set, Get = function() return cur end}
end

local function Btn(parent, text, color, callback)
	local b = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundColor3 = color or CONFIG.Accent,
		Text = text,
		TextColor3 = CONFIG.Text,
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		AutoButtonColor = false,
		LayoutOrder = #parent:GetChildren() + 1,
		Parent = parent,
	})
	Create("UICorner", {CornerRadius = UDim.new(0, 9), Parent = b})
	b.MouseEnter:Connect(function() Tween(b, {BackgroundTransparency = 0.12}, 0.12) end)
	b.MouseLeave:Connect(function() Tween(b, {BackgroundTransparency = 0}, 0.12) end)
	b.MouseButton1Click:Connect(function() if callback then callback(b) end end)
	return b
end

-- COMBAT
local speedSec = Section(CombatContent, "SPEED")
Toggle(speedSec, "Speed Override", true, function(v) State.SpeedEnabled = v ApplyMovementStats() end)
Slider(speedSec, "WalkSpeed", 16, 500, 16, function(v) State.WalkSpeed = v ApplyMovementStats() end)
Slider(speedSec, "Boost Multiplier", 1, 10, 1, function(v) State.SpeedBoostMult = v ApplyMovementStats() end)
Toggle(speedSec, "CFrame Mode", false, function(v) State.UseCFrameSpeed = v ApplyMovementStats() end)
Slider(speedSec, "CFrame Power", 1, 25, 2, function(v) State.CFrameSpeedValue = v end)

local jumpSec = Section(CombatContent, "JUMP")
Toggle(jumpSec, "Jump Override", true, function(v) State.JumpEnabled = v ApplyMovementStats() end)
Slider(jumpSec, "JumpPower", 50, 500, 50, function(v) State.JumpPower = v ApplyMovementStats() end)
Slider(jumpSec, "Jump Multiplier", 1, 15, 1, function(v) State.JumpBoostMult = v ApplyMovementStats() end)
Toggle(jumpSec, "Super Jump", false, function(v) State.SuperJump = v ApplyMovementStats() end)
Slider(jumpSec, "Super Jump Power", 80, 1500, 120, function(v) State.SuperJumpPower = v ApplyMovementStats() end)
Toggle(jumpSec, "Infinite Jump", false, function(v) State.InfiniteJump = v end)

local flySec = Section(CombatContent, "FLY")
Toggle(flySec, "Fly Enabled", false, function(v)
	State.FlyEnabled = v
	if v then StartFly() else StopFly() end
end)
Slider(flySec, "Fly Speed", 10, 500, 80, function(v) State.FlySpeed = v end)
Slider(flySec, "Vertical Mult", 0.2, 5, 1, function(v) State.FlyVerticalMult = v end)
Toggle(flySec, "Smooth Gyro", true, function(v) State.FlySmooth = v end)
local flyModeLab = Create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = "Mode: Velocity",
	TextColor3 = CONFIG.TextDim, TextSize = 11, Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 90, Parent = flySec,
})
Btn(flySec, "Switch Velocity / CFrame", CONFIG.Surface2, function()
	State.FlyMode = (State.FlyMode == "Velocity") and "CFrame" or "Velocity"
	flyModeLab.Text = "Mode: " .. State.FlyMode
	if State.FlyEnabled then StartFly() end
end)

local noclipSec = Section(CombatContent, "NOCLIP")
local noclipStatus = Create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = "Status: OFF",
	TextColor3 = CONFIG.Bad, TextSize = 12, Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = noclipSec,
})
function SetNoClip(on)
	State.NoClipEnabled = on
	if on then
		StartNoClip()
		noclipStatus.Text = "Status: ON"
		noclipStatus.TextColor3 = CONFIG.Good
	else
		StopNoClip()
		noclipStatus.Text = "Status: OFF"
		noclipStatus.TextColor3 = CONFIG.Bad
	end
end
Toggle(noclipSec, "NoClip", false, function(v) SetNoClip(v) end)
Btn(noclipSec, "Toggle NoClip", CONFIG.Accent, function(btn)
	SetNoClip(not State.NoClipEnabled)
	btn.Text = State.NoClipEnabled and "Disable NoClip" or "Enable NoClip"
	btn.BackgroundColor3 = State.NoClipEnabled and CONFIG.Bad or CONFIG.Accent
end)

local aimSec = Section(CombatContent, "AIM ASSIST")
Toggle(aimSec, "Aim Assist", false, function(v) State.AimAssistEnabled = v end)
Slider(aimSec, "FOV", 30, 360, 120, function(v) State.AimFOV = v UpdateFOVCircle() end)
Slider(aimSec, "Smoothness", 1, 100, 35, function(v) State.AimSmooth = v / 100 end)
local aimModeLab = Create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = "Target: Closest In FOV",
	TextColor3 = CONFIG.TextDim, TextSize = 11, Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 80, Parent = aimSec,
})
Btn(aimSec, "Closest / Selected", CONFIG.Surface2, function()
	if State.AimMode == "Closest" then
		State.AimMode = "Selected" aimModeLab.Text = "Target: Selected Player"
	else
		State.AimMode = "Closest" aimModeLab.Text = "Target: Closest In FOV"
	end
end)

-- VISUALS
local invisSec = Section(VisualsContent, "INVISIBLE / GHOST")
local invisStatus = Create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = "Invisible: OFF",
	TextColor3 = CONFIG.Bad, TextSize = 12, Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = invisSec,
})
local invisBtn
local function SetInvisibleUI(on)
	SetInvisible(on)
	if on then
		invisStatus.Text = "Invisible: ON"
		invisStatus.TextColor3 = CONFIG.Good
		if invisBtn then invisBtn.Text = "Disable Invisible" invisBtn.BackgroundColor3 = CONFIG.Bad end
	else
		invisStatus.Text = "Invisible: OFF"
		invisStatus.TextColor3 = CONFIG.Bad
		if invisBtn then invisBtn.Text = "Enable Invisible" invisBtn.BackgroundColor3 = CONFIG.Accent end
	end
end
Toggle(invisSec, "Invisible", false, function(v) SetInvisibleUI(v) end)
Toggle(invisSec, "Hide Shadows", true, function(v)
	CONFIG.InvisibleHideShadow = v
	if State.InvisibleEnabled then StopInvisible() StartInvisible() end
end)
Toggle(invisSec, "Hide Name Tag", true, function(v)
	CONFIG.InvisibleHideNameTag = v
	if State.InvisibleEnabled then
		local _, hum = GetCharacter()
		if v and hum then HideNameTag(hum) elseif hum then RestoreNameTag(hum) end
	end
end)
Toggle(invisSec, "Keep Tools Visible", false, function(v)
	CONFIG.InvisibleKeepTools = v
	if State.InvisibleEnabled then StopInvisible() StartInvisible() end
end)
invisBtn = Btn(invisSec, "Enable Invisible", CONFIG.Accent, function()
	SetInvisibleUI(not State.InvisibleEnabled)
end)
Btn(invisSec, "Reapply Ghost Sweep", CONFIG.Surface2, function()
	if State.InvisibleEnabled then
		local c = LocalPlayer.Character
		if c then SweepCharacterInvisible(c) end
	end
end)

local worldSec = Section(VisualsContent, "WORLD / PERF")
local fbStatus = Create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = "Full Bright: OFF",
	TextColor3 = CONFIG.Bad, TextSize = 12, Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = worldSec,
})
local fbBtn
local function SetFullBright(on)
	if on then
		StartFullBright()
		fbStatus.Text = string.format("Full Bright: ON  ·  dark %d%%", math.floor(State.SceneDarkness * 100))
		fbStatus.TextColor3 = CONFIG.Good
		if fbBtn then fbBtn.Text = "Disable Full Bright" fbBtn.BackgroundColor3 = CONFIG.Bad end
	else
		StopFullBright()
		fbStatus.Text = "Full Bright: OFF"
		fbStatus.TextColor3 = CONFIG.Bad
		if fbBtn then fbBtn.Text = "Enable Full Bright" fbBtn.BackgroundColor3 = CONFIG.Warn end
	end
end
Toggle(worldSec, "Full Bright", false, function(v) SetFullBright(v) end)
Slider(worldSec, "Intensity", 0, 100, 55, function(v)
	State.FullBrightIntensity = v
	if State.FullBrightEnabled then ApplyAdaptiveFullBright() end
end)
fbBtn = Btn(worldSec, "Enable Full Bright", CONFIG.Warn, function()
	SetFullBright(not State.FullBrightEnabled)
end)

local fpsStatus = Create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = "FPS Boost: OFF",
	TextColor3 = CONFIG.Bad, TextSize = 12, Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 20, Parent = worldSec,
})
local fpsBtn
local function SetFPSBoost(on)
	if on then
		StartFPSBoost()
		fpsStatus.Text = "FPS Boost: ON"
		fpsStatus.TextColor3 = CONFIG.Good
		if fpsBtn then fpsBtn.Text = "Disable FPS Boost" fpsBtn.BackgroundColor3 = CONFIG.Bad end
	else
		StopFPSBoost()
		fpsStatus.Text = "FPS Boost: OFF"
		fpsStatus.TextColor3 = CONFIG.Bad
		if fpsBtn then fpsBtn.Text = "Enable FPS Boost" fpsBtn.BackgroundColor3 = CONFIG.Accent end
	end
end
Toggle(worldSec, "FPS Boost", false, function(v) SetFPSBoost(v) end)
fpsBtn = Btn(worldSec, "Enable FPS Boost", CONFIG.Accent, function()
	SetFPSBoost(not State.FPSBoostEnabled)
end)

local tpSec = Section(VisualsContent, "FLY-TO TELEPORT")
Slider(tpSec, "Fly-To Speed", 30, 600, 120, function(v) State.TeleportSpeed = v end)
Btn(tpSec, "Cancel Fly-To", CONFIG.Bad, function() if State.IsTeleporting then StopFlyTo() end end)

local espSec = Section(VisualsContent, "ESP")
Toggle(espSec, "Global Player ESP", false, function(v)
	State.ESPEnabled = v
	if v then StartESP() else StopESP() end
end)

local listSec = Section(VisualsContent, "PLAYERS")
State.PlayerCountLabel = Create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Text = "Players: 0",
	TextColor3 = CONFIG.Accent, TextSize = 12, Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = listSec,
})
State.RefreshStatusLabel = Create("TextLabel", {
	Size = UDim2.new(1, 0, 0, 12), BackgroundTransparency = 1, Text = "sync ready",
	TextColor3 = CONFIG.TextDim, TextSize = 10, Font = Enum.Font.Gotham,
	TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, Parent = listSec,
})
local PlayerListFrame = Create("Frame", {
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, LayoutOrder = 10, Parent = listSec,
})
Create("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = PlayerListFrame})

local RefreshPlayerList
local function UpdatePlayerCountUI(extra)
	local total = #Players:GetPlayers()
	local others = math.max(0, total - 1)
	State.LastPlayerCount = total
	if State.PlayerCountLabel then
		State.PlayerCountLabel.Text = string.format("Players: %d  ·  listed %d", total, others)
	end
	if State.RefreshStatusLabel then
		State.RefreshStatusLabel.Text = (extra or "synced") .. "  ·  " .. os.date("%H:%M:%S")
		State.RefreshStatusLabel.TextColor3 = CONFIG.Good
		task.delay(1.1, function()
			if State.RefreshStatusLabel then State.RefreshStatusLabel.TextColor3 = CONFIG.TextDim end
		end)
	end
end

Btn(listSec, "Refresh List", CONFIG.Accent, function(btn)
	local old = btn.Text
	btn.Text = "..."
	RefreshPlayerList(true)
	task.delay(0.2, function() if btn and btn.Parent then btn.Text = old end end)
end).LayoutOrder = 3

Toggle(listSec, "Auto-Refresh", true, function(v)
	CONFIG.AutoRefreshPlayers = v
	if State.RefreshStatusLabel then State.RefreshStatusLabel.Text = v and "auto on" or "auto off" end
end)

local function DestroyESPForPlayer(plr)
	local objs = State.ESPObjects[plr]
	if objs and objs.Billboard then objs.Billboard:Destroy() end
	State.ESPObjects[plr] = nil
end

local function CreateESPForPlayer(plr)
	if State.ESPObjects[plr] then return end
	local billboard = Create("BillboardGui", {
		Name = "pthub_ESP_" .. plr.Name, Size = UDim2.fromOffset(180, 58),
		StudsOffset = Vector3.new(0, 3.1, 0), AlwaysOnTop = true, MaxDistance = 5000, Parent = CoreGui,
	})
	local box = Create("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = billboard})
	Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = plr.Name,
		TextColor3 = CONFIG.Text, TextSize = 13, Font = Enum.Font.GothamBold,
		TextStrokeTransparency = 0.5, Parent = box,
	})
	local distTag = Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 16), BackgroundTransparency = 1,
		Text = "0m", TextColor3 = CONFIG.Accent, TextSize = 11, Font = Enum.Font.Gotham, Parent = box,
	})
	local healthBg = Create("Frame", {
		Size = UDim2.new(0.75, 0, 0, 4), Position = UDim2.new(0.125, 0, 0, 34),
		BackgroundColor3 = CONFIG.Surface2, BorderSizePixel = 0, Parent = box,
	})
	Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = healthBg})
	local healthFill = Create("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = CONFIG.Good, BorderSizePixel = 0, Parent = healthBg,
	})
	Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = healthFill})
	local healthText = Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 12), Position = UDim2.fromOffset(0, 40), BackgroundTransparency = 1,
		Text = "100%", TextColor3 = CONFIG.TextDim, TextSize = 10, Font = Enum.Font.Gotham, Parent = box,
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
					objs.HealthFill.Size = UDim2.fromScale(hpPct, 1)
					objs.HealthText.Text = string.format("%d%%", math.floor(hpPct * 100))
					objs.HealthFill.BackgroundColor3 = (hpPct > 0.6 and CONFIG.Good) or (hpPct > 0.3 and CONFIG.Warn) or CONFIG.Bad
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
		if btn then btn.BackgroundColor3 = CONFIG.Surface2 btn.Text = "ESP" end
	else
		CreateESPForPlayer(plr) EnsureESPLoop()
		if btn then btn.BackgroundColor3 = CONFIG.Good btn.Text = "ON" end
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
			CreateESPForPlayer(plr) EnsureESPLoop()
		end
		local row = Create("Frame", {
			Size = UDim2.new(1, 0, 0, 38),
			BackgroundColor3 = CONFIG.Surface2,
			Parent = PlayerListFrame,
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = row})
		local display = plr.DisplayName ~= plr.Name and (plr.DisplayName .. " (@" .. plr.Name .. ")") or plr.Name
		Create("TextLabel", {
			Size = UDim2.new(1, -140, 1, 0), Position = UDim2.fromOffset(10, 0), BackgroundTransparency = 1,
			Text = display, TextColor3 = CONFIG.Text, TextSize = 11, Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
		})
		local function small(x, label, col, fn)
			local b = Create("TextButton", {
				Size = UDim2.fromOffset(38, 24), Position = UDim2.new(1, x, 0.5, -12),
				BackgroundColor3 = col, Text = label, TextColor3 = CONFIG.Text,
				TextSize = 10, Font = Enum.Font.GothamBold, AutoButtonColor = false, Parent = row,
			})
			Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = b})
			b.MouseButton1Click:Connect(fn)
			return b
		end
		small(-130, "FLY", CONFIG.Accent, function() FlyToPlayer(plr) end)
		local espOn = State.ESPObjects[plr] ~= nil
		local espB = small(-88, espOn and "ON" or "ESP", espOn and CONFIG.Good or CONFIG.Surface2, function() end)
		espB.MouseButton1Click:Connect(function() TogglePlayerESP(plr, espB) end)
		small(-46, "AIM", CONFIG.AccentDim, function()
			State.SelectedAimPlayer = plr
			State.AimMode = "Selected"
			aimModeLab.Text = "Target: " .. plr.Name
		end)
	end
	if shown == 0 then
		local empty = Create("Frame", {
			Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = CONFIG.Surface2, Parent = PlayerListFrame,
		})
		Create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = empty})
		Create("TextLabel", {
			Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(8, 0), BackgroundTransparency = 1,
			Text = "no other players",
			TextColor3 = CONFIG.TextDim, TextSize = 11, Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left, Parent = empty,
		})
	end
	UpdatePlayerCountUI(manual and "manual ok" or "auto ok")
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
		bv.Velocity = Vector3.zero bv.Parent = State.HRP State.FlyBodyVelocity = bv
		if State.FlySmooth then
			local bg = Instance.new("BodyGyro")
			bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
			bg.P = 9e4 bg.D = 500 bg.Parent = State.HRP State.FlyBodyGyro = bg
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
	if State.Connections.Fly then State.Connections.Fly:Disconnect() State.Connections.Fly = nil end
	if State.FlyBodyVelocity then State.FlyBodyVelocity:Destroy() State.FlyBodyVelocity = nil end
	if State.FlyBodyGyro then State.FlyBodyGyro:Destroy() State.FlyBodyGyro = nil end
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
				UpdatePlayerCountUI("live")
			end
		end
	end
end)

-- AIM
local FOVCircle = Drawing and Drawing.new("Circle") or nil
if FOVCircle then
	FOVCircle.Thickness = 1.2 FOVCircle.NumSides = 64 FOVCircle.Radius = 120
	FOVCircle.Filled = false FOVCircle.Color = CONFIG.Accent
	FOVCircle.Transparency = 0.55 FOVCircle.Visible = false
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
					shortest = dist2D closest = hrp
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

-- drag main
local draggingUI, dragStart, startPos = false, nil, nil
Header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingUI = true dragStart = input.Position startPos = Main.Position
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
		Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)

-- drag orb
local draggingOrb, orbDragStart, orbStartPos = false, nil, nil
Orb.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingOrb = true
		orbDragStart = input.Position
		orbStartPos = Orb.Position
	end
end)
Orb.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		draggingOrb = false
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if draggingOrb and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local d = input.Position - orbDragStart
		Orb.Position = UDim2.new(orbStartPos.X.Scale, orbStartPos.X.Offset + d.X, orbStartPos.Y.Scale, orbStartPos.Y.Offset + d.Y)
	end
end)

-- =========================
-- TAB APPLY (single source of truth)
-- =========================
local function applyTab(tabName, refreshList)
	State.ActiveTab = tabName
	local combat = tabName == "Combat"
	CombatContent.Visible = combat
	VisualsContent.Visible = not combat
	CombatTab.BackgroundTransparency = combat and 0 or 1
	CombatTab.BackgroundColor3 = combat and CONFIG.Accent or CONFIG.Surface
	CombatTab.TextColor3 = combat and CONFIG.Text or CONFIG.TextDim
	VisualsTab.BackgroundTransparency = combat and 1 or 0
	VisualsTab.BackgroundColor3 = combat and CONFIG.Surface or CONFIG.Accent
	VisualsTab.TextColor3 = combat and CONFIG.TextDim or CONFIG.Text
	if refreshList and not combat then
		RefreshPlayerList(true)
	end
end

local function setTab(combat)
	applyTab(combat and "Combat" or "Visuals", true)
	Tween(CombatTab, {BackgroundTransparency = combat and 0 or 1, BackgroundColor3 = combat and CONFIG.Accent or CONFIG.Surface}, 0.18)
	Tween(VisualsTab, {BackgroundTransparency = combat and 1 or 0, BackgroundColor3 = combat and CONFIG.Surface or CONFIG.Accent}, 0.18)
end
CombatTab.MouseButton1Click:Connect(function() setTab(true) end)
VisualsTab.MouseButton1Click:Connect(function() setTab(false) end)

-- =========================
-- MINIMIZE / RESTORE (no overlap)
-- =========================
local function getMainCenterAbs()
	local p = Main.AbsolutePosition
	local s = Main.AbsoluteSize
	return Vector2.new(p.X + s.X * 0.5, p.Y + s.Y * 0.5)
end

local function minimizeToOrb()
	if State.Minimized or State.AnimLock then return end
	State.AnimLock = true
	State.Minimized = true
	State.SavedMainPos = Main.Position

	local center = getMainCenterAbs()
	local orbPos = UDim2.fromOffset(center.X - CONFIG.OrbSize * 0.5, center.Y - CONFIG.OrbSize * 0.5)

	-- only hide the body wrapper — tabs stay intact underneath
	Body.Visible = false
	Shadow.Visible = false

	Tween(MainCorner, {CornerRadius = UDim.new(1, 0)}, 0.28, Enum.EasingStyle.Quint)
	Tween(MainStroke, {Color = CONFIG.Accent, Transparency = 0.1, Thickness = 2}, 0.28)
	Tween(Main, {
		Size = UDim2.fromOffset(CONFIG.OrbSize, CONFIG.OrbSize),
		Position = orbPos,
	}, 0.32, Enum.EasingStyle.Quint)

	task.delay(0.3, function()
		if not State.Minimized then
			State.AnimLock = false
			return
		end
		Main.Visible = false
		Orb.Position = orbPos
		Orb.Size = UDim2.fromOffset(0, 0)
		Orb.Visible = true
		Tween(Orb, {Size = UDim2.fromOffset(CONFIG.OrbSize, CONFIG.OrbSize)}, 0.22, Enum.EasingStyle.Back)
		State.AnimLock = false
	end)
end

local function restoreFromOrb()
	if not State.Minimized or State.AnimLock then return end
	State.AnimLock = true
	State.Minimized = false

	local orbAbs = Orb.AbsolutePosition
	local startPos = UDim2.fromOffset(orbAbs.X, orbAbs.Y)
	local targetPos = State.SavedMainPos or UDim2.new(0.5, -210, 0.5, -280)

	Tween(Orb, {Size = UDim2.fromOffset(0, 0)}, 0.16, Enum.EasingStyle.Quint)
	task.delay(0.14, function()
		Orb.Visible = false

		Main.Visible = true
		Main.Size = UDim2.fromOffset(CONFIG.OrbSize, CONFIG.OrbSize)
		Main.Position = startPos
		MainCorner.CornerRadius = UDim.new(1, 0)
		MainStroke.Color = CONFIG.Accent
		MainStroke.Thickness = 2
		MainStroke.Transparency = 0.1

		-- body still hidden until expand finishes a bit
		Body.Visible = false
		Shadow.Visible = false

		Tween(Main, {
			Size = UDim2.fromOffset(420, 560),
			Position = targetPos,
		}, 0.34, Enum.EasingStyle.Quint)
		Tween(MainCorner, {CornerRadius = UDim.new(0, 16)}, 0.34, Enum.EasingStyle.Quint)
		Tween(MainStroke, {Color = CONFIG.Border, Transparency = 0.35, Thickness = 1}, 0.34)

		task.delay(0.16, function()
			-- restore ONLY the active tab, never both
			applyTab(State.ActiveTab or "Combat", false)
			Body.Visible = true
			Shadow.Visible = true
			State.AnimLock = false
		end)
	end)
end

MinBtn.MouseButton1Click:Connect(function()
	minimizeToOrb()
end)

local orbClickStart = nil
Orb.MouseButton1Down:Connect(function()
	orbClickStart = Orb.AbsolutePosition
end)
Orb.MouseButton1Click:Connect(function()
	if orbClickStart then
		local moved = (Orb.AbsolutePosition - orbClickStart).Magnitude
		if moved > 8 then return end
	end
	restoreFromOrb()
end)

Orb.MouseEnter:Connect(function()
	if not State.Minimized then return end
	Tween(Orb, {Size = UDim2.fromOffset(CONFIG.OrbSize + 4, CONFIG.OrbSize + 4)}, 0.15, Enum.EasingStyle.Quint)
	Tween(OrbLabel, {TextSize = 20}, 0.15)
end)
Orb.MouseLeave:Connect(function()
	if not State.Minimized then return end
	Tween(Orb, {Size = UDim2.fromOffset(CONFIG.OrbSize, CONFIG.OrbSize)}, 0.15, Enum.EasingStyle.Quint)
	Tween(OrbLabel, {TextSize = 18}, 0.15)
end)

CloseBtn.MouseButton1Click:Connect(function()
	if State.Minimized then
		Tween(Orb, {Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1}, 0.18)
	end
	Tween(Main, {Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1}, 0.2, Enum.EasingStyle.Quint)
	task.delay(0.22, function()
		if State.FullBrightEnabled then StopFullBright() end
		if State.FPSBoostEnabled then StopFPSBoost() end
		if State.InvisibleEnabled then StopInvisible() end
		StopFlyTo()
		ScreenGui:Destroy()
		StopFly() StopNoClip() StopESP()
		for _, c in pairs(State.Connections) do
			if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
		end
		if FOVCircle then FOVCircle:Remove() end
	end)
end)

-- open anim
Main.Size = UDim2.fromOffset(0, 0)
Main.BackgroundTransparency = 1
Tween(Main, {Size = UDim2.fromOffset(420, 560), BackgroundTransparency = 0}, 0.38, Enum.EasingStyle.Back)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		if State.Minimized then
			restoreFromOrb()
			State.MenuOpen = true
		else
			State.MenuOpen = not State.MenuOpen
			Main.Visible = State.MenuOpen
		end
	end
end)

applyTab("Combat", false)
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

print("[pthub] v"..CONFIG.Version.." | orb restore fixed | RightShift")
