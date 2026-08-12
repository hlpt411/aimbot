-- // pthub v2.7.0
-- // FIXED: Big visible drag sliders for Speed / Boost / Jump + NoClip button
-- // LocalScript or Executor | RightShift = toggle menu

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer
local Cam = workspace.CurrentCamera

local CFG = {
    Version = "2.7.0",
    BG = Color3.fromHex("#0d0d1a"),
    Purple = Color3.fromHex("#6c5ce7"),
    Teal = Color3.fromHex("#00cec9"),
    Pink = Color3.fromHex("#fd79a8"),
    White = Color3.fromHex("#ffffff"),
    Dim = Color3.fromHex("#b2bec3"),
    Red = Color3.fromHex("#ff4757"),
    Green = Color3.fromHex("#2ed573"),
    Yellow = Color3.fromHex("#ffa502"),
    TP_OFFSET = Vector3.new(3.5, 5, 0),
    TP_FREEZE = 0.14,
}

local S = {
    SpeedOn = true, WalkSpeed = 16, SpeedBoost = 1, CFrameSpeed = false, CFramePower = 2,
    JumpOn = true, JumpPower = 50, JumpBoost = 1, SuperJump = false, SuperJumpPower = 120, InfJump = false,
    FlyOn = false, FlySpeed = 80, FlyVert = 1, FlyMode = "Velocity", FlySmooth = true,
    NoClip = false, ESP = false, AimOn = false, AimFOV = 120, AimSmooth = 0.35,
    AimMode = "Closest", AimPlr = nil, Open = true,
    Conn = {}, ESPObj = {}, BV = nil, BG = nil, Char = nil, Hum = nil, HRP = nil, TPing = false,
}

-- // helpers
local function pc(fn, ...) local ok, r = pcall(fn, ...) return ok, r end
local function New(c, p)
    local o = Instance.new(c)
    for k, v in pairs(p or {}) do if k ~= "Parent" then o[k] = v end end
    if p and p.Parent then o.Parent = p.Parent end
    return o
end
local function Tw(o, pr, d, st, di)
    local t = TS:Create(o, TweenInfo.new(d or 0.2, st or Enum.EasingStyle.Quad, di or Enum.EasingDirection.Out), pr)
    t:Play() return t
end
local function CharOf(plr)
    plr = plr or LP
    local c = plr.Character
    if not c then return nil, nil, nil end
    return c, c:FindFirstChildOfClass("Humanoid"), c:FindFirstChild("HumanoidRootPart")
end
local function EffSpeed() return math.clamp(S.WalkSpeed * S.SpeedBoost, 0, 1000) end
local function EffJump()
    if S.SuperJump then return math.clamp(S.SuperJumpPower * S.JumpBoost, 0, 2000) end
    return math.clamp(S.JumpPower * S.JumpBoost, 0, 2000)
end
local function ApplyStats()
    if not S.Hum then return end
    pc(function()
        if S.SpeedOn and not S.CFrameSpeed then S.Hum.WalkSpeed = EffSpeed()
        elseif not S.SpeedOn then S.Hum.WalkSpeed = 16 end
        if S.JumpOn then
            local j = EffJump()
            S.Hum.JumpPower = j
            if S.Hum.UseJumpPower == false then S.Hum.JumpHeight = j / 20 end
        else
            S.Hum.JumpPower = 50
            if S.Hum.UseJumpPower == false then S.Hum.JumpHeight = 7.2 end
        end
    end)
end
local function Refresh()
    S.Char, S.Hum, S.HRP = CharOf()
    ApplyStats()
end

-- // Safe TP
local function SafeTP(target)
    if S.TPing then return end
    local lc, lh, lr = CharOf()
    local tc, th, tr = CharOf(target)
    if not (lr and lh and tr and th) or lh.Health <= 0 or th.Health <= 0 then return end
    S.TPing = true
    pc(function()
        lr.AssemblyLinearVelocity = Vector3.zero
        lr.AssemblyAngularVelocity = Vector3.zero
        local wasPS = lh.PlatformStand
        lh.PlatformStand = true
        lh:ChangeState(Enum.HumanoidStateType.Physics)
        local tcf = tr.CFrame
        local off = CFG.TP_OFFSET
        local woff = tcf:VectorToWorldSpace(Vector3.new(off.X, 0, off.Z))
        local dest = tcf.Position + woff + Vector3.new(0, off.Y, 0)
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        rp.FilterDescendantsInstances = {lc, tc}
        local hit = workspace:Raycast(dest + Vector3.new(0, 12, 0), Vector3.new(0, -90, 0), rp)
        if hit then dest = Vector3.new(dest.X, hit.Position.Y + 3.5, dest.Z)
        else dest = tcf.Position + Vector3.new(off.X, math.max(off.Y, 8), off.Z) end
        lr.Anchored = true
        local _, y = tcf:ToEulerAnglesYXZ()
        lr.CFrame = CFrame.new(dest) * CFrame.Angles(0, y, 0)
        task.wait(CFG.TP_FREEZE)
        lr.AssemblyLinearVelocity = Vector3.zero
        lr.AssemblyAngularVelocity = Vector3.zero
        lr.Anchored = false
        lh.PlatformStand = wasPS
        if not S.FlyOn then lh:ChangeState(Enum.HumanoidStateType.Running) end
        ApplyStats()
    end)
    task.delay(0.2, function() S.TPing = false end)
end

-- =========================================================
-- UI ROOT
-- =========================================================
local Gui = New("ScreenGui", {Name = "pthub_UI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = CoreGui})
local Main = New("Frame", {
    Name = "Main", Size = UDim2.new(0, 520, 0, 680), Position = UDim2.new(0.5, -260, 0.5, -340),
    BackgroundColor3 = CFG.BG, BorderSizePixel = 0, ClipsDescendants = true, Parent = Gui,
})
New("UICorner", {CornerRadius = UDim.new(0, 14), Parent = Main})
New("UIStroke", {Color = CFG.Purple, Thickness = 2, Transparency = 0.2, Parent = Main})

local Header = New("Frame", {Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = Color3.fromRGB(10, 10, 24), BorderSizePixel = 0, Parent = Main})
New("UICorner", {CornerRadius = UDim.new(0, 14), Parent = Header})
New("Frame", {Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2), BackgroundColor3 = CFG.Teal, BorderSizePixel = 0, Parent = Header})
New("TextLabel", {
    Size = UDim2.new(0, 240, 1, 0), Position = UDim2.new(0, 16, 0, 0), BackgroundTransparency = 1,
    Text = "⚡ pthub", TextColor3 = CFG.White, TextSize = 24, Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = Header,
})
local Ver = New("TextLabel", {
    Size = UDim2.new(0, 66, 0, 20), Position = UDim2.new(0, 125, 0.5, -10), BackgroundColor3 = CFG.Purple,
    Text = "v" .. CFG.Version, TextColor3 = CFG.White, TextSize = 11, Font = Enum.Font.Gotham, Parent = Header,
})
New("UICorner", {CornerRadius = UDim.new(0, 5), Parent = Ver})
local MinBtn = New("TextButton", {
    Size = UDim2.new(0, 34, 0, 34), Position = UDim2.new(1, -84, 0.5, -17), BackgroundColor3 = Color3.fromRGB(28, 28, 48),
    Text = "—", TextColor3 = CFG.White, TextSize = 16, Font = Enum.Font.GothamBold, Parent = Header,
})
New("UICorner", {CornerRadius = UDim.new(0, 7), Parent = MinBtn})
local XBtn = New("TextButton", {
    Size = UDim2.new(0, 34, 0, 34), Position = UDim2.new(1, -42, 0.5, -17), BackgroundColor3 = CFG.Red,
    Text = "✕", TextColor3 = CFG.White, TextSize = 14, Font = Enum.Font.GothamBold, Parent = Header,
})
New("UICorner", {CornerRadius = UDim.new(0, 7), Parent = XBtn})

-- tabs
local TabBar = New("Frame", {Size = UDim2.new(1, -24, 0, 42), Position = UDim2.new(0, 12, 0, 60), BackgroundTransparency = 1, Parent = Main})
local TabCombat = New("TextButton", {
    Size = UDim2.new(0.5, -5, 1, 0), BackgroundColor3 = CFG.Purple, Text = "COMBAT",
    TextColor3 = CFG.White, TextSize = 14, Font = Enum.Font.GothamBold, Parent = TabBar,
})
New("UICorner", {CornerRadius = UDim.new(0, 9), Parent = TabCombat})
local TabVisual = New("TextButton", {
    Size = UDim2.new(0.5, -5, 1, 0), Position = UDim2.new(0.5, 5, 0, 0), BackgroundColor3 = Color3.fromRGB(24, 24, 44),
    Text = "VISUALS", TextColor3 = CFG.Dim, TextSize = 14, Font = Enum.Font.GothamBold, Parent = TabBar,
})
New("UICorner", {CornerRadius = UDim.new(0, 9), Parent = TabVisual})

local function MakeScroll(name, vis, barCol)
    local sf = New("ScrollingFrame", {
        Name = name, Size = UDim2.new(1, -24, 1, -120), Position = UDim2.new(0, 12, 0, 112),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
        ScrollBarImageColor3 = barCol, CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = vis, Parent = Main,
    })
    New("UIListLayout", {Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sf})
    New("UIPadding", {PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 24), PaddingRight = UDim.new(0, 8), Parent = sf})
    return sf
end
local Combat = MakeScroll("Combat", true, CFG.Purple)
local Visuals = MakeScroll("Visuals", false, CFG.Teal)

-- =========================================================
-- UI COMPONENTS — BIG SLIDERS YOU CAN ACTUALLY DRAG
-- =========================================================
local order = 0
local function nextO() order += 1 return order end

local function Section(parent, title)
    local f = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Color3.fromRGB(14, 14, 30), BorderSizePixel = 0,
        LayoutOrder = nextO(), Parent = parent,
    })
    New("UICorner", {CornerRadius = UDim.new(0, 12), Parent = f})
    New("UIStroke", {Color = Color3.fromRGB(48, 48, 80), Thickness = 1, Parent = f})
    New("UIPadding", {
        PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14),
        PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = f,
    })
    New("UIListLayout", {Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = f})
    New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Text = title,
        TextColor3 = CFG.Teal, TextSize = 14, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 0, Parent = f,
    })
    return f
end

local function Toggle(parent, text, default, cb)
    local h = New("Frame", {Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = #parent:GetChildren()+1, Parent = parent})
    New("TextLabel", {
        Size = UDim2.new(1, -64, 1, 0), BackgroundTransparency = 1, Text = text,
        TextColor3 = CFG.White, TextSize = 14, Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = h,
    })
    local bg = New("Frame", {
        Size = UDim2.new(0, 54, 0, 30), Position = UDim2.new(1, -54, 0.5, -15),
        BackgroundColor3 = default and CFG.Purple or Color3.fromRGB(42, 42, 64), Parent = h,
    })
    New("UICorner", {CornerRadius = UDim.new(1, 0), Parent = bg})
    local knob = New("Frame", {
        Size = UDim2.new(0, 24, 0, 24),
        Position = default and UDim2.new(1, -27, 0.5, -12) or UDim2.new(0, 3, 0.5, -12),
        BackgroundColor3 = CFG.White, Parent = bg,
    })
    New("UICorner", {CornerRadius = UDim.new(1, 0), Parent = knob})
    local on = default
    local b = New("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", Parent = h})
    local function paint()
        Tw(bg, {BackgroundColor3 = on and CFG.Purple or Color3.fromRGB(42, 42, 64)}, 0.15)
        Tw(knob, {Position = on and UDim2.new(1, -27, 0.5, -12) or UDim2.new(0, 3, 0.5, -12)}, 0.15)
    end
    b.MouseButton1Click:Connect(function() on = not on paint() if cb then cb(on) end end)
    return {Set = function(v) on = v paint() end, Get = function() return on end}
end

-- FAT SLIDER — tall track, big knob, value + textbox
local function Slider(parent, label, min, max, default, cb)
    local box = New("Frame", {
        Size = UDim2.new(1, 0, 0, 84),
        BackgroundColor3 = Color3.fromRGB(18, 18, 36),
        BorderSizePixel = 0,
        LayoutOrder = #parent:GetChildren() + 1,
        Parent = parent,
    })
    New("UICorner", {CornerRadius = UDim.new(0, 10), Parent = box})
    New("UIStroke", {Color = Color3.fromRGB(55, 40, 90), Thickness = 1, Parent = box})
    New("UIPadding", {
        PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = box,
    })

    New("TextLabel", {
        Size = UDim2.new(0.7, 0, 0, 20), BackgroundTransparency = 1, Text = label,
        TextColor3 = CFG.White, TextSize = 14, Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Left, Parent = box,
    })
    local valLbl = New("TextLabel", {
        Size = UDim2.new(0.3, 0, 0, 20), Position = UDim2.new(0.7, 0, 0, 0), BackgroundTransparency = 1,
        Text = tostring(default), TextColor3 = CFG.Teal, TextSize = 16, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right, Parent = box,
    })

    -- TRACK (drag zone)
    local track = New("Frame", {
        Name = "Track",
        Size = UDim2.new(1, -72, 0, 16),
        Position = UDim2.new(0, 0, 0, 34),
        BackgroundColor3 = Color3.fromRGB(30, 30, 55),
        BorderSizePixel = 0,
        Parent = box,
    })
    New("UICorner", {CornerRadius = UDim.new(1, 0), Parent = track})

    local fill = New("Frame", {
        Name = "Fill",
        Size = UDim2.new(math.clamp((default - min) / math.max(max - min, 1), 0, 1), 0, 1, 0),
        BackgroundColor3 = CFG.Purple,
        BorderSizePixel = 0,
        Parent = track,
    })
    New("UICorner", {CornerRadius = UDim.new(1, 0), Parent = fill})
    New("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, CFG.Purple),
            ColorSequenceKeypoint.new(1, CFG.Pink),
        }),
        Parent = fill,
    })

    local knob = New("Frame", {
        Name = "Knob",
        Size = UDim2.new(0, 26, 0, 26),
        Position = UDim2.new(math.clamp((default - min) / math.max(max - min, 1), 0, 1), -13, 0.5, -13),
        BackgroundColor3 = CFG.White,
        ZIndex = 5,
        Parent = track,
    })
    New("UICorner", {CornerRadius = UDim.new(1, 0), Parent = knob})
    New("UIStroke", {Color = CFG.Pink, Thickness = 2.5, Parent = knob})

    local tb = New("TextBox", {
        Size = UDim2.new(0, 64, 0, 28),
        Position = UDim2.new(1, -64, 0, 28),
        BackgroundColor3 = Color3.fromRGB(26, 26, 50),
        Text = tostring(default),
        TextColor3 = CFG.White,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        ClearTextOnFocus = false,
        Parent = box,
    })
    New("UICorner", {CornerRadius = UDim.new(0, 7), Parent = tb})
    New("UIStroke", {Color = CFG.Purple, Thickness = 1.2, Parent = tb})

    -- hint
    New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -14), BackgroundTransparency = 1,
        Text = "drag bar  •  or type value", TextColor3 = CFG.Dim, TextSize = 11,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, Parent = box,
    })

    local dragging = false
    local cur = default

    local function set(v, fromBox)
        v = math.clamp(tonumber(v) or cur, min, max)
        if max >= 10 then v = math.floor(v + 0.5) else v = math.floor(v * 100 + 0.5) / 100 end
        cur = v
        local pct = (v - min) / math.max(max - min, 1)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, -13, 0.5, -13)
        valLbl.Text = tostring(v)
        if not fromBox then tb.Text = tostring(v) end
        if cb then cb(v) end
    end

    local function fromX(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        set(min + rel * (max - min))
    end

    local function begin(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            fromX(input.Position.X)
        end
    end
    track.InputBegan:Connect(begin)
    knob.InputBegan:Connect(begin)
    -- also whole box bottom area
    box.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local y = input.Position.Y
            if y >= track.AbsolutePosition.Y - 8 and y <= track.AbsolutePosition.Y + track.AbsoluteSize.Y + 8 then
                dragging = true
                fromX(input.Position.X)
            end
        end
    end)

    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            fromX(input.Position.X)
        end
    end)
    tb.FocusLost:Connect(function()
        local n = tonumber(tb.Text)
        if n then set(n, true) tb.Text = tostring(cur) else tb.Text = tostring(cur) end
    end)

    return {Set = set, Get = function() return cur end}
end

local function Btn(parent, text, col, cb)
    local b = New("TextButton", {
        Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = col or CFG.Purple,
        Text = text, TextColor3 = CFG.White, TextSize = 14, Font = Enum.Font.GothamBold,
        AutoButtonColor = false, LayoutOrder = #parent:GetChildren()+1, Parent = parent,
    })
    New("UICorner", {CornerRadius = UDim.new(0, 9), Parent = b})
    b.MouseButton1Click:Connect(function() if cb then cb(b) end end)
    b.MouseEnter:Connect(function() Tw(b, {BackgroundTransparency = 0.12}, 0.1) end)
    b.MouseLeave:Connect(function() Tw(b, {BackgroundTransparency = 0}, 0.1) end)
    return b
end

-- =========================================================
-- COMBAT: SPEED SLIDERS + BOOST + JUMP + NOCLIP BUTTON
-- =========================================================
local speedSec = Section(Combat, "⚡ SPEED  —  KÉO THANH / DRAG SLIDER")
Toggle(speedSec, "Enable Speed", true, function(v) S.SpeedOn = v ApplyStats() end)
Slider(speedSec, "WalkSpeed", 16, 500, 16, function(v) S.WalkSpeed = v ApplyStats() end)
Slider(speedSec, "Speed Boost Multiplier", 1, 10, 1, function(v) S.SpeedBoost = v ApplyStats() end)
Toggle(speedSec, "CFrame Speed Mode", false, function(v) S.CFrameSpeed = v ApplyStats() end)
Slider(speedSec, "CFrame Power", 1, 25, 2, function(v) S.CFramePower = v end)
Btn(speedSec, "RESET SPEED", Color3.fromRGB(70, 45, 100), function()
    S.WalkSpeed = 16 S.SpeedBoost = 1 S.CFrameSpeed = false S.CFramePower = 2 S.SpeedOn = true ApplyStats()
end)

local jumpSec = Section(Combat, "🚀 JUMP BOOST  —  KÉO THANH / DRAG SLIDER")
Toggle(jumpSec, "Enable Jump", true, function(v) S.JumpOn = v ApplyStats() end)
Slider(jumpSec, "JumpPower", 50, 500, 50, function(v) S.JumpPower = v ApplyStats() end)
Slider(jumpSec, "Jump Boost Multiplier", 1, 15, 1, function(v) S.JumpBoost = v ApplyStats() end)
Toggle(jumpSec, "Super Jump", false, function(v) S.SuperJump = v ApplyStats() end)
Slider(jumpSec, "Super Jump Power", 80, 1500, 120, function(v) S.SuperJumpPower = v ApplyStats() end)
Toggle(jumpSec, "Infinite Jump", false, function(v) S.InfJump = v end)
Btn(jumpSec, "RESET JUMP", Color3.fromRGB(70, 45, 100), function()
    S.JumpPower = 50 S.JumpBoost = 1 S.SuperJump = false S.SuperJumpPower = 120 S.InfJump = false S.JumpOn = true ApplyStats()
end)

local flySec = Section(Combat, "🕊️ FLY")
Toggle(flySec, "Fly Enabled", false, function(v) S.FlyOn = v if v then StartFly() else StopFly() end end)
Slider(flySec, "Fly Speed", 10, 500, 80, function(v) S.FlySpeed = v end)
Slider(flySec, "Vertical Mult", 0.2, 5, 1, function(v) S.FlyVert = v end)
Toggle(flySec, "Smooth Gyro", true, function(v) S.FlySmooth = v end)
local flyModeLbl = New("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = "Mode: Velocity",
    TextColor3 = CFG.Dim, TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = 50, Parent = flySec,
})
Btn(flySec, "TOGGLE FLY MODE Velocity/CFrame", Color3.fromRGB(40, 55, 100), function()
    S.FlyMode = S.FlyMode == "Velocity" and "CFrame" or "Velocity"
    flyModeLbl.Text = "Mode: " .. S.FlyMode
    if S.FlyOn then StartFly() end
end)

-- NOCLIP — status + toggle + BIG BUTTON
local ncSec = Section(Combat, "👻 NOCLIP")
local ncStatus = New("TextLabel", {
    Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = "Status: OFF",
    TextColor3 = CFG.Red, TextSize = 14, Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = ncSec,
})
local ncBig
local function SetNoClip(on)
    S.NoClip = on
    if on then
        StartNoClip()
        ncStatus.Text = "Status: ON — phasethrough walls"
        ncStatus.TextColor3 = CFG.Green
        if ncBig then ncBig.Text = "■  DISABLE NOCLIP" ncBig.BackgroundColor3 = CFG.Red end
    else
        StopNoClip()
        ncStatus.Text = "Status: OFF"
        ncStatus.TextColor3 = CFG.Red
        if ncBig then ncBig.Text = "▶  ENABLE NOCLIP" ncBig.BackgroundColor3 = CFG.Teal end
    end
end
Toggle(ncSec, "NoClip Toggle", false, function(v) SetNoClip(v) end)
ncBig = Btn(ncSec, "▶  ENABLE NOCLIP", CFG.Teal, function()
    SetNoClip(not S.NoClip)
end)

local aimSec = Section(Combat, "🎯 AIM ASSIST")
Toggle(aimSec, "Aim Assist", false, function(v) S.AimOn = v end)
Slider(aimSec, "Aim FOV", 30, 360, 120, function(v) S.AimFOV = v if UpdateFOV then UpdateFOV() end end)
Slider(aimSec, "Smoothness", 1, 100, 35, function(v) S.AimSmooth = v / 100 end)
local aimModeLbl = New("TextLabel", {
    Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = "Target: Closest FOV",
    TextColor3 = CFG.Dim, TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
    LayoutOrder = 40, Parent = aimSec,
})
Btn(aimSec, "SWITCH Closest / Selected", Color3.fromRGB(36, 36, 60), function()
    if S.AimMode == "Closest" then S.AimMode = "Selected" aimModeLbl.Text = "Target: Selected Player"
    else S.AimMode = "Closest" aimModeLbl.Text = "Target: Closest FOV" end
end)

-- =========================================================
-- VISUALS
-- =========================================================
local espSec = Section(Visuals, "ESP")
Toggle(espSec, "Global Player ESP", false, function(v)
    S.ESP = v
    if v then StartESP() else StopESP() end
end)
New("TextLabel", {
    Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
    Text = "Or press ESP on each player row", TextColor3 = CFG.Dim, TextSize = 11,
    Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 10, Parent = espSec,
})

local plrSec = Section(Visuals, "PLAYERS — TP / ESP / AIM")
local List = New("Frame", {
    Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1, LayoutOrder = 5, Parent = plrSec,
})
New("UIListLayout", {Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder, Parent = List})

-- ESP funcs
local function KillESP(plr)
    local o = S.ESPObj[plr]
    if o and o.BB then o.BB:Destroy() end
    S.ESPObj[plr] = nil
end
local function MakeESP(plr)
    if S.ESPObj[plr] then return end
    local bb = New("BillboardGui", {
        Name = "pthub_ESP_" .. plr.Name, Size = UDim2.new(0, 200, 0, 70),
        StudsOffset = Vector3.new(0, 3.2, 0), AlwaysOnTop = true, MaxDistance = 5000, Parent = CoreGui,
    })
    local c = New("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Parent = bb})
    local name = New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Text = plr.Name,
        TextColor3 = CFG.White, TextSize = 14, Font = Enum.Font.GothamBold, TextStrokeTransparency = 0.4, Parent = c,
    })
    local dist = New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 16), BackgroundTransparency = 1,
        Text = "0m", TextColor3 = CFG.Teal, TextSize = 12, Font = Enum.Font.Gotham, TextStrokeTransparency = 0.4, Parent = c,
    })
    local hbg = New("Frame", {
        Size = UDim2.new(0.8, 0, 0, 6), Position = UDim2.new(0.1, 0, 0, 36),
        BackgroundColor3 = Color3.fromRGB(30, 30, 30), BorderSizePixel = 0, Parent = c,
    })
    New("UICorner", {CornerRadius = UDim.new(1, 0), Parent = hbg})
    local hfill = New("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = CFG.Green, BorderSizePixel = 0, Parent = hbg})
    New("UICorner", {CornerRadius = UDim.new(1, 0), Parent = hfill})
    local htxt = New("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 0, 44), BackgroundTransparency = 1,
        Text = "100%", TextColor3 = CFG.Dim, TextSize = 11, Font = Enum.Font.Gotham, Parent = c,
    })
    S.ESPObj[plr] = {BB = bb, Dist = dist, Fill = hfill, Htxt = htxt}
    local function adorn()
        local head = plr.Character and plr.Character:FindFirstChild("Head")
        if head then bb.Adornee = head end
    end
    adorn()
    plr.CharacterAdded:Connect(adorn)
end
local function ESPLoop()
    if S.Conn.ESP then return end
    S.Conn.ESP = RunService.RenderStepped:Connect(function()
        local lhrp = S.HRP or (LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"))
        for plr, o in pairs(S.ESPObj) do
            if plr.Parent and plr.Character and o.BB then
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                local head = plr.Character:FindFirstChild("Head")
                if hum and hrp and head then
                    o.BB.Adornee = head
                    if lhrp then o.Dist.Text = string.format("%dm", math.floor((lhrp.Position - hrp.Position).Magnitude)) end
                    local p = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                    o.Fill.Size = UDim2.new(p, 0, 1, 0)
                    o.Htxt.Text = string.format("%d%%", math.floor(p * 100))
                    o.Fill.BackgroundColor3 = p > 0.6 and CFG.Green or (p > 0.3 and CFG.Yellow or CFG.Red)
                end
            end
        end
    end)
end
function StartESP()
    for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then MakeESP(p) end end
    ESPLoop()
end
function StopESP()
    for p in pairs(S.ESPObj) do KillESP(p) end
    if S.Conn.ESP then S.Conn.ESP:Disconnect() S.Conn.ESP = nil end
end
local function ToggleESP(plr, btn)
    if S.ESPObj[plr] then
        KillESP(plr)
        if btn then btn.Text = "ESP" btn.BackgroundColor3 = Color3.fromRGB(40, 40, 65) end
    else
        MakeESP(plr) ESPLoop()
        if btn then btn.Text = "ON" btn.BackgroundColor3 = CFG.Green end
    end
end

local function RefreshList()
    for _, ch in ipairs(List:GetChildren()) do if ch:IsA("Frame") then ch:Destroy() end end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        local row = New("Frame", {Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Color3.fromRGB(20, 20, 38), Parent = List})
        New("UICorner", {CornerRadius = UDim.new(0, 8), Parent = row})
        New("TextLabel", {
            Size = UDim2.new(1, -160, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1,
            Text = plr.DisplayName ~= plr.Name and (plr.DisplayName .. " (@" .. plr.Name .. ")") or plr.Name,
            TextColor3 = CFG.White, TextSize = 12, Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
        })
        local tp = New("TextButton", {
            Size = UDim2.new(0, 38, 0, 30), Position = UDim2.new(1, -148, 0.5, -15),
            BackgroundColor3 = CFG.Teal, Text = "TP", TextColor3 = CFG.BG, TextSize = 12, Font = Enum.Font.GothamBold, Parent = row,
        })
        New("UICorner", {CornerRadius = UDim.new(0, 6), Parent = tp})
        tp.MouseButton1Click:Connect(function() SafeTP(plr) end)

        local on = S.ESPObj[plr] ~= nil
        local eb = New("TextButton", {
            Size = UDim2.new(0, 42, 0, 30), Position = UDim2.new(1, -104, 0.5, -15),
            BackgroundColor3 = on and CFG.Green or Color3.fromRGB(40, 40, 65),
            Text = on and "ON" or "ESP", TextColor3 = CFG.White, TextSize = 12, Font = Enum.Font.GothamBold, Parent = row,
        })
        New("UICorner", {CornerRadius = UDim.new(0, 6), Parent = eb})
        eb.MouseButton1Click:Connect(function() ToggleESP(plr, eb) end)

        local ab = New("TextButton", {
            Size = UDim2.new(0, 42, 0, 30), Position = UDim2.new(1, -56, 0.5, -15),
            BackgroundColor3 = CFG.Purple, Text = "AIM", TextColor3 = CFG.White, TextSize = 12, Font = Enum.Font.GothamBold, Parent = row,
        })
        New("UICorner", {CornerRadius = UDim.new(0, 6), Parent = ab})
        ab.MouseButton1Click:Connect(function()
            S.AimPlr = plr S.AimMode = "Selected" aimModeLbl.Text = "Target: " .. plr.Name
        end)
    end
end

-- FLY
function StartFly()
    StopFly() Refresh()
    if not S.HRP or not S.Hum then return end
    S.Hum.PlatformStand = true
    if S.FlyMode == "Velocity" then
        local bv = Instance.new("BodyVelocity")
        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        bv.Velocity = Vector3.zero bv.Parent = S.HRP S.BV = bv
        if S.FlySmooth then
            local bg = Instance.new("BodyGyro")
            bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bg.P = 9e4 bg.D = 500 bg.Parent = S.HRP S.BG = bg
        end
    end
    S.Conn.Fly = RunService.RenderStepped:Connect(function(dt)
        if not S.FlyOn or not S.HRP or not S.HRP.Parent then StopFly() return end
        if S.TPing then return end
        local cf = Cam.CFrame
        local dir, ud = Vector3.zero, 0
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir += cf.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= cf.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= cf.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir += cf.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then ud += 1 end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then ud -= 1 end
        if S.FlyMode == "Velocity" then
            local f = Vector3.zero
            if dir.Magnitude > 0 then f += dir.Unit * S.FlySpeed end
            f += Vector3.new(0, ud * S.FlySpeed * S.FlyVert, 0)
            if S.BV then S.BV.Velocity = f end
            if S.BG then S.BG.CFrame = cf end
        else
            local m = Vector3.zero
            if dir.Magnitude > 0 then m += dir.Unit end
            m += Vector3.new(0, ud * S.FlyVert, 0)
            if m.Magnitude > 0 then S.HRP.CFrame += m.Unit * S.FlySpeed * dt * 3.5 end
            S.HRP.AssemblyLinearVelocity = Vector3.zero
            S.HRP.AssemblyAngularVelocity = Vector3.zero
            if S.FlySmooth then S.HRP.CFrame = CFrame.new(S.HRP.Position, S.HRP.Position + cf.LookVector) end
        end
    end)
end
function StopFly()
    if S.Conn.Fly then S.Conn.Fly:Disconnect() S.Conn.Fly = nil end
    if S.BV then S.BV:Destroy() S.BV = nil end
    if S.BG then S.BG:Destroy() S.BG = nil end
    if S.Hum then S.Hum.PlatformStand = false end
end

function StartNoClip()
    StopNoClip()
    S.Conn.NC = RunService.Stepped:Connect(function()
        if not S.NoClip then return end
        local c = LP.Character
        if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end)
end
function StopNoClip()
    if S.Conn.NC then S.Conn.NC:Disconnect() S.Conn.NC = nil end
end

Players.PlayerAdded:Connect(function(plr)
    if S.ESP then task.wait(1) MakeESP(plr) ESPLoop() end
    task.defer(RefreshList)
end)
Players.PlayerRemoving:Connect(function(plr)
    KillESP(plr)
    if S.AimPlr == plr then S.AimPlr = nil end
    task.defer(RefreshList)
end)

-- AIM
local FOV = Drawing and Drawing.new("Circle") or nil
if FOV then
    FOV.Thickness = 1.5 FOV.NumSides = 64 FOV.Radius = 120 FOV.Filled = false
    FOV.Color = Color3.fromRGB(108, 92, 231) FOV.Transparency = 0.4 FOV.Visible = false
end
function UpdateFOV() if FOV then FOV.Radius = S.AimFOV end end

local function Visible(hrp)
    local origin = Cam.CFrame.Position
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {LP.Character}
    rp.FilterType = Enum.RaycastFilterType.Exclude
    local r = workspace:Raycast(origin, hrp.Position - origin, rp)
    if r then
        local m = r.Instance:FindFirstAncestorOfClass("Model")
        return m and m:FindFirstChildOfClass("Humanoid") ~= nil
    end
    return true
end
local function Closest()
    local best, short = nil, S.AimFOV
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LP then continue end
        if plr.Team and LP.Team and plr.Team == LP.Team then continue end
        local _, hum, hrp = CharOf(plr)
        if hum and hum.Health > 0 and hrp then
            local sp, on = Cam:WorldToViewportPoint(hrp.Position)
            if on then
                local c = Cam.ViewportSize / 2
                local d = (Vector2.new(sp.X, sp.Y) - Vector2.new(c.X, c.Y)).Magnitude
                if d < short and Visible(hrp) then short = d best = hrp end
            end
        end
    end
    return best
end
S.Conn.Aim = RunService.RenderStepped:Connect(function()
    if FOV then
        FOV.Position = Cam.ViewportSize / 2
        FOV.Visible = S.AimOn
        FOV.Radius = S.AimFOV
    end
    if not S.AimOn then return end
    local part
    if S.AimMode == "Selected" and S.AimPlr then
        local _, hum, hrp = CharOf(S.AimPlr)
        if hum and hum.Health > 0 and hrp then part = hrp end
    else part = Closest() end
    if part then
        local cur = Cam.CFrame
        Cam.CFrame = cur:Lerp(CFrame.new(cur.Position, part.Position + Vector3.new(0, 1.5, 0)), S.AimSmooth)
    end
end)

S.Conn.Jump = UIS.JumpRequest:Connect(function()
    if not S.InfJump then return end
    local _, hum, hrp = CharOf()
    if hum and hrp and hum.Health > 0 then
        pc(function()
            local pwr = EffJump()
            hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, pwr * 0.65, hrp.AssemblyLinearVelocity.Z)
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end
end)

local function OnChar()
    task.wait(0.15) Refresh()
    if S.FlyOn then StartFly() end
    if S.NoClip then StartNoClip() end
    if S.Hum then S.Hum.Died:Connect(function() StopFly() end) end
end
if LP.Character then OnChar() end
LP.CharacterAdded:Connect(OnChar)

-- window chrome
local drag, d0, p0 = false, nil, nil
Header.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        drag = true d0 = i.Position p0 = Main.Position
    end
end)
Header.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = false end
end)
UIS.InputChanged:Connect(function(i)
    if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local d = i.Position - d0
        Main.Position = UDim2.new(p0.X.Scale, p0.X.Offset + d.X, p0.Y.Scale, p0.Y.Offset + d.Y)
    end
end)

local mini = false
MinBtn.MouseButton1Click:Connect(function()
    mini = not mini
    Tw(Main, {Size = mini and UDim2.new(0, 520, 0, 52) or UDim2.new(0, 520, 0, 680)}, 0.25)
end)
XBtn.MouseButton1Click:Connect(function()
    Tw(Main, {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1}, 0.2)
    task.delay(0.22, function()
        Gui:Destroy() StopFly() StopNoClip() StopESP()
        for _, c in pairs(S.Conn) do if typeof(c) == "RBXScriptConnection" then c:Disconnect() end end
        if FOV then FOV:Remove() end
    end)
end)

TabCombat.MouseButton1Click:Connect(function()
    Combat.Visible = true Visuals.Visible = false
    Tw(TabCombat, {BackgroundColor3 = CFG.Purple}, 0.12)
    Tw(TabVisual, {BackgroundColor3 = Color3.fromRGB(24, 24, 44)}, 0.12)
    TabCombat.TextColor3 = CFG.White TabVisual.TextColor3 = CFG.Dim
end)
TabVisual.MouseButton1Click:Connect(function()
    Combat.Visible = false Visuals.Visible = true
    Tw(TabVisual, {BackgroundColor3 = CFG.Teal}, 0.12)
    Tw(TabCombat, {BackgroundColor3 = Color3.fromRGB(24, 24, 44)}, 0.12)
    TabVisual.TextColor3 = CFG.White TabCombat.TextColor3 = CFG.Dim
    RefreshList()
end)

Main.Size = UDim2.new(0, 0, 0, 0)
Main.BackgroundTransparency = 1
Tw(Main, {Size = UDim2.new(0, 520, 0, 680), BackgroundTransparency = 0}, 0.35, Enum.EasingStyle.Back)

UIS.InputBegan:Connect(function(i, g)
    if g then return end
    if i.KeyCode == Enum.KeyCode.RightShift then
        S.Open = not S.Open
        Main.Visible = S.Open
    end
end)

Refresh()
RefreshList()

S.Conn.Stats = RunService.Heartbeat:Connect(function()
    if S.TPing then return end
    if not S.Hum or not S.Hum.Parent then Refresh() return end
    if S.SpeedOn and not S.CFrameSpeed and not S.FlyOn then
        local t = EffSpeed()
        if S.Hum.WalkSpeed ~= t then pc(function() S.Hum.WalkSpeed = t end) end
    end
    if S.JumpOn and not S.FlyOn then
        local j = EffJump()
        if S.Hum.JumpPower ~= j then
            pc(function()
                S.Hum.JumpPower = j
                if S.Hum.UseJumpPower == false then S.Hum.JumpHeight = j / 20 end
            end)
        end
    end
    if S.SpeedOn and S.CFrameSpeed and S.HRP and not S.FlyOn then
        if S.Hum.MoveDirection.Magnitude > 0 then
            S.HRP.CFrame += S.Hum.MoveDirection * S.CFramePower * S.SpeedBoost
        end
    end
end)

print("[pthub] v" .. CFG.Version .. " | SPEED + BOOST + JUMP sliders + NOCLIP button | RightShift")