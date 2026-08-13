local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"

local Library = loadstring(game:HttpGet(repo.."Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo.."addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo.."addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local Stats = cloneref(game:GetService("Stats"))
local Lighting = cloneref(game:GetService("Lighting"))
local ws = cloneref(game:GetService("Workspace"))
local lp = Players.LocalPlayer
local cam = ws.CurrentCamera

local Window = Library:CreateWindow({
    Title = "Rivals Hub",
    Footer = "v2.2",
    Icon = 120959262762131,
    CornerElements = false,
    NotifySide = "Right",
    ShowCustomCursor = true,
})

local Tabs = {
    Combat = Window:AddTab("Combat", "swords"),
    Visuals = Window:AddTab("Visuals", "eye"),
    Game = Window:AddTab("Game", "gamepad-2"),
    ModGun = Window:AddTab("Mod Gun", "crosshair"),
    Settings = Window:AddTab("UI Settings", "settings"),
}

local function newPage(tab)
    return {
        _tab = tab,
        _groups = {},
        Section = function(self, cfg)
            local side = cfg.Side or 1
            local key = side == 2 and "right" or "left"
            local g = self._groups[key]
            if not g then
                g = side == 2 and self._tab:AddRightGroupbox(cfg.Name) or self._tab:AddLeftGroupbox(cfg.Name)
                self._groups[key] = g
            end
            return g
        end,
    }
end

local CompatPages = {
    Aimbot = newPage(Tabs.Combat),
    Silent = newPage(Tabs.Combat),
    Rage = newPage(Tabs.Combat),
    Wallbang = newPage(Tabs.Combat),
    HitSound = newPage(Tabs.Combat),
    FOV = newPage(Tabs.Visuals),
    Camera = newPage(Tabs.Game),
    Misc = newPage(Tabs.Game),
    Skybox = newPage(Tabs.Game),
}

local WindowCompat = {}
function WindowCompat:Category() end
function WindowCompat:Page(cfg)
    local map = {Aimbot=CompatPages.Aimbot,["Silent Aim"]=CompatPages.Silent,Ragebot=CompatPages.Rage,Wallbang=CompatPages.Wallbang,["Hit Sound"]=CompatPages.HitSound,FOV=CompatPages.FOV,Camera=CompatPages.Camera,Misc=CompatPages.Misc,Skybox=CompatPages.Skybox}
    return map[cfg.Name]
end
function WindowCompat:Init() end
Window = WindowCompat

local function compatLabel(group, text)
    local label = group:AddLabel(text)
    function label:Colorpicker(cfg)
        return self:AddColorPicker(cfg.Name or "Color", {Default = cfg.Default, Transparency = cfg.Transparency or 0, Callback = cfg.Callback})
    end
    return label
end

local function compatDefault(v)
    if type(v) == "table" then return v[1] end
    return v
end

local function patchGroup(group)
    function group:Toggle(cfg)
        return self:AddToggle(cfg.Flag, {Text=cfg.Name, Default=cfg.Default or false, Callback=cfg.Callback})
    end
    function group:Slider(cfg)
        return self:AddSlider(cfg.Flag, {Text=cfg.Name, Min=cfg.Min, Max=cfg.Max, Default=cfg.Default, Rounding=cfg.Rounding or 0, Suffix=cfg.Suffix, Callback=cfg.Callback})
    end
    function group:Dropdown(cfg)
        return self:AddDropdown(cfg.Flag, {Text=cfg.Name, Values=cfg.Items, Default=compatDefault(cfg.Default), Multi=cfg.Multi or false, Searchable=cfg.Searchable or false, Callback=cfg.Callback})
    end
    function group:Button(cfg)
        return self:AddButton({Text=cfg.Name, Func=cfg.Callback, DoubleClick=cfg.DoubleClick or false})
    end
    function group:Label(text)
        return compatLabel(self, text)
    end
    return group
end

for _, page in pairs(CompatPages) do
    local mt = getmetatable(page)
    for _, group in pairs(page._groups) do
        patchGroup(group)
    end
end

local function patchPage(page)
    local old = page.Section
    function page:Section(cfg)
        local g = old(self, cfg)
        return patchGroup(g)
    end
end
for _, page in pairs(CompatPages) do patchPage(page) end

local function notify(title, desc, dur)
    Library:Notify({Title=title, Description=desc, Time=dur or 2})
end

local function getFlag(key, default)
    local t = Toggles[key]
    if t then return t.Value end
    local o = Options[key]
    if o then return o.Value end
    return default
end

local ModGunTab = Tabs.ModGun
local GunBox = ModGunTab:AddLeftGroupbox("Gun Mods")

-- ============================================================
-- Bullet Tracer - Mod Gun
-- Stable module: no DependencyBox, Rainbow default
-- ============================================================
local BulletTracerEnabled = true
local BulletTracerRainbow = true
local BulletTracerColor = Color3.fromRGB(255, 105, 180)
local BulletTracerLifetime = 3
local BulletTracerFadeTime = 0.5
local BulletTracerSize = 1
local BulletTracers = {}
local BulletTracerHooked = false
local BulletTracerHue = 0

local BulletTracerToggle = GunBox:AddToggle("BulletTracerEnabled", {
    Text = "Bullet Tracer",
    Default = true,
    Callback = function(v)
        BulletTracerEnabled = v

        if not v then
            for i = #BulletTracers, 1, -1 do
                local tr = BulletTracers[i]
                pcall(function() tr.Line:Remove() end)
                pcall(function() tr.Outline:Remove() end)
                table.remove(BulletTracers, i)
            end
        end
    end,
})

BulletTracerToggle:AddColorPicker("BulletTracerColor", {
    Default = BulletTracerColor,
    Title = "Tracer Color",
    Transparency = false,
    Callback = function(v)
        BulletTracerColor = v
    end,
})

GunBox:AddToggle("BulletTracerRainbow", {
    Text = "Rainbow Color",
    Default = true,
    Callback = function(v)
        BulletTracerRainbow = v
    end,
})

local function getBulletTracerColor()
    if BulletTracerRainbow then
        return Color3.fromHSV(BulletTracerHue % 1, 0.85, 1)
    end
    return BulletTracerColor
end

local function BulletTracerMuzzle()
    local vm = workspace:FindFirstChild("ViewModels")
    local fp = vm and vm:FindFirstChild("FirstPerson")

    if fp then
        for _, model in ipairs(fp:GetChildren()) do
            if model:IsA("Model") and model.Name:find("^" .. lp.Name) then
                local iv = model:FindFirstChild("ItemVisual")
                local body = iv and iv:FindFirstChild("Body")
                local bp = body and body:FindFirstChild("BodyPrimary")
                local muzzle = bp and bp:FindFirstChild("_muzzle")

                if muzzle and muzzle:IsA("Attachment") then
                    return muzzle.WorldPosition
                end
            end
        end
    end

    -- Fallback so the tracer still works if the first-person muzzle
    -- is not available on mobile/after respawn.
    local character = lp.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root then
        return root.Position
    end

    local camera = workspace.CurrentCamera
    return camera and camera.CFrame.Position or nil
end

local function BulletMakeTracer(startPos, endPos)
    if not BulletTracerEnabled or not startPos or not endPos then
        return
    end

    local line = Drawing.new("Line")
    line.Thickness = 2 * BulletTracerSize
    line.Color = getBulletTracerColor()
    line.Transparency = 1
    line.Visible = false

    local outline = Drawing.new("Line")
    outline.Thickness = 4 * BulletTracerSize
    outline.Color = Color3.new(0, 0, 0)
    outline.Transparency = 1
    outline.Visible = false

    BulletTracers[#BulletTracers + 1] = {
        Line = line,
        Outline = outline,
        StartPos = startPos,
        EndPos = endPos,
        Created = tick(),
    }
end

RunService.RenderStepped:Connect(function(dt)
    BulletTracerHue = (BulletTracerHue + dt * 0.18) % 1

    local camera = workspace.CurrentCamera
    if not camera then return end

    local now = tick()

    for i = #BulletTracers, 1, -1 do
        local tr = BulletTracers[i]
        local age = now - tr.Created

        if age >= BulletTracerLifetime or not BulletTracerEnabled then
            pcall(function() tr.Line:Remove() end)
            pcall(function() tr.Outline:Remove() end)
            table.remove(BulletTracers, i)
        else
            local fade = 1

            if BulletTracerFadeTime > 0
                and age >= BulletTracerLifetime - BulletTracerFadeTime then
                fade = 1 - math.clamp(
                    (age - (BulletTracerLifetime - BulletTracerFadeTime))
                    / BulletTracerFadeTime,
                    0,
                    1
                )
            end

            local s, sVisible = camera:WorldToViewportPoint(tr.StartPos)
            local e, eVisible = camera:WorldToViewportPoint(tr.EndPos)

            if sVisible and eVisible and s.Z > 0 and e.Z > 0 then
                tr.Outline.From = Vector2.new(s.X, s.Y)
                tr.Outline.To = Vector2.new(e.X, e.Y)
                tr.Outline.Transparency = fade
                tr.Outline.Visible = true

                tr.Line.From = Vector2.new(s.X, s.Y)
                tr.Line.To = Vector2.new(e.X, e.Y)
                tr.Line.Transparency = fade
                tr.Line.Color = getBulletTracerColor()
                tr.Line.Visible = true
            else
                tr.Outline.Visible = false
                tr.Line.Visible = false
            end
        end
    end
end)

local function HookBulletTracer()
    if BulletTracerHooked then
        return true
    end

    local ok = pcall(function()
        local modulesFolder = lp.PlayerScripts:FindFirstChild("Modules")
        local tracerModule = modulesFolder and modulesFolder:FindFirstChild("TracerEffect")

        if not tracerModule then
            return false
        end

        local TracerEffect = require(tracerModule)
        if type(TracerEffect.Play) ~= "function" then
            return false
        end

        if TracerEffect.__PinkTracerHooked then
            BulletTracerHooked = true
            return true
        end

        local oldPlay = TracerEffect.Play

        TracerEffect.Play = function(self, tracerData, config, extraData)
            if BulletTracerEnabled and tracerData then
                local isLocal = tracerData.IsLocal
                if isLocal == nil or isLocal == true then
                    local muzzle = BulletTracerMuzzle()
                    local results = tracerData.RaycastResults

                    if muzzle and results then
                        for _, result in ipairs(results) do
                            if result and result.Position then
                                BulletMakeTracer(muzzle, result.Position)
                            end
                        end
                    elseif muzzle and tracerData.Position then
                        BulletMakeTracer(muzzle, tracerData.Position)
                    end
                end
            end

            return oldPlay(self, tracerData, config, extraData)
        end

        TracerEffect.__PinkTracerHooked = true
        BulletTracerHooked = true
        return true
    end)

    return ok
end

task.spawn(function()
    for _ = 1, 60 do
        if HookBulletTracer() then
            break
        end
        task.wait(0.5)
    end
end)

local function toggleTableAttribute(attribute,value)
    for _,gcVal in pairs(getgc(true)) do
        if type(gcVal) == "table" and rawget(gcVal,attribute) ~= nil then
            gcVal[attribute] = value
        end
    end
end
GunBox:AddToggle("ModGun",{
    Text = "Mod Gun",
    Default = false,
    Callback = function(v)
        if v then
            toggleTableAttribute("ShootCooldown",0)
            toggleTableAttribute("ShootSpread",0)
            toggleTableAttribute("ShootRecoil",0)
        end
    end
})

    local function safeRequire(path)
        local ok, r = pcall(require, path)
        return ok and r or nil
    end

    -- =============================================
    --   Module References
    --   Each has a timeout so no infinite yield
    -- =============================================

    local CameraController  = safeRequire(lp.PlayerScripts:WaitForChild("Controllers",10):WaitForChild("CameraController",10))
    local FighterController = safeRequire(lp.PlayerScripts:WaitForChild("Controllers",10):WaitForChild("FighterController",10))
    local util              = safeRequire(ReplicatedStorage:WaitForChild("Modules",10):WaitForChild("Utility",10))
    local enums             = safeRequire(ReplicatedStorage:WaitForChild("Modules",10):WaitForChild("EnumLibrary",10))
    local GunModule         = safeRequire(lp.PlayerScripts.Modules.ItemTypes.Gun)
    local DebugController   = safeRequire(lp.PlayerScripts:WaitForChild("Controllers",10):WaitForChild("DebugController",10))

    -- =============================================
    --   Remotes
    -- =============================================

    local RB = ReplicatedStorage:WaitForChild("Remotes",10)
    local RBF = RB:WaitForChild("Replication",10):WaitForChild("Fighter",10)

    local UseItemRemote     = RBF:WaitForChild("UseItem",10)
    local PickWeaponsRemote = RBF:WaitForChild("PickWeapons",10)
    local VoteRemote        = RB:WaitForChild("Duels",10):WaitForChild("Vote",10)
    local QueueRemote       = RB:WaitForChild("Matchmaking",10):WaitForChild("JoinQueue",10)

    pcall(function()
        if DebugController then DebugController:SetHandicapsEnabled(true) end
    end)

    -- =============================================
    --   Lists
    -- =============================================

    local PRIMARY_WEAPONS = {
        "Distortion","Permafrost","Energy Rifle","Flamethrower",
        "Grenade Launcher","Minigun","Paintball","Assault Rifle",
        "Bow","Burst Rifle","Crossbow","Gunblade","RPG","Shotgun","Sniper",
    }
    local SECONDARY_WEAPONS = {
        "Warper","Energy Pistols","Exogun","Slingshot","Daggers",
        "Flare Gun","Handgun","Revolver","Shorty","Spray","Uzi",
    }
    local MELEE_WEAPONS = {
        "Maul","Spear","Trowel","Battle Axe","Chainsaw","Fist",
        "Katana","Knife","Riot Shield","Scythe",
    }
    local UTILITY_WEAPONS = {
        "Grappler","Medkit","Subspace Tripmine","Warpstone",
        "Flashbang","Freeze Ray","Grenade","Jump Pad",
        "Molotov","Satchel","Smoke Grenade","War Horn",
    }
    local MAPS = {
        "Arena","Big Arena","Backrooms","Big Backrooms","Legacy Backrooms",
        "Baseplate","Battleground","Legacy Battleground","Bridge","Chess",
        "Construction","Crossroads","Big Crossroads","Legacy Crossroads",
        "Dimensions","Docks","Legacy Docks","Graveyard","Big Graveyard",
    }
    local QUEUE_MODES = {"1v1","2v2","3v3","4v4","5v5"}

    local HIT_SOUNDS = {
        ["Rust"]          = "rbxassetid://4764109000",
        ["Click"]         = "rbxassetid://6042053626",
        ["Click 2"]       = "rbxassetid://5153644999",
        ["Beep"]          = "rbxassetid://9120386436",
        ["Ding"]          = "rbxassetid://4612375109",
        ["Pop"]           = "rbxassetid://5982421855",
        ["Punch"]         = "rbxassetid://386946753",
        ["Headshot"]      = "rbxassetid://4612378735",
        ["Bone Crack"]    = "rbxassetid://5801253825",
        ["Minecraft Hit"] = "rbxassetid://131070686",
        ["Minecraft"]     = "rbxassetid://135478009117226",
        ["Neverlose"]     = "rbxassetid://82938206376993",
        ["Skibidi"]       = "rbxassetid://18723913",
        ["Bruh"]          = "rbxassetid://9120253754",
        ["Oof"]           = "rbxassetid://5997174966",
        ["Vine Boom"]     = "rbxassetid://7293984919",
        ["Metal Hit"]     = "rbxassetid://10734947730",
        ["Wet"]           = "rbxassetid://4768489490",
        ["Arrow"]         = "rbxassetid://4612394498",
        ["Laser"]         = "rbxassetid://5992660828",
        ["Squeak"]        = "rbxassetid://1300087530",
        ["Cash"]          = "rbxassetid://4612379547",
        ["Among Us"]      = "rbxassetid://6936643745",
    }
    local HIT_SOUND_LIST = {}
    for k in pairs(HIT_SOUNDS) do table.insert(HIT_SOUND_LIST,k) end
    table.sort(HIT_SOUND_LIST)

    local SKYBOXES = {
        ["Default"] = {
            SkyboxBk="rbxassetid://159454299",SkyboxDn="rbxassetid://159454296",
            SkyboxFt="rbxassetid://159454293",SkyboxLf="rbxassetid://159454286",
            SkyboxRt="rbxassetid://159454300",SkyboxUp="rbxassetid://159454295",
        },
        ["Night Sky"] = {
            SkyboxBk="rbxassetid://3095606289",SkyboxDn="rbxassetid://3095606289",
            SkyboxFt="rbxassetid://3095606294",SkyboxLf="rbxassetid://3095606292",
            SkyboxRt="rbxassetid://3095606291",SkyboxUp="rbxassetid://3095606290",isNight=true,
        },
        ["Bliss"] = {
            SkyboxBk="rbxassetid://6444884337",SkyboxDn="rbxassetid://6422644718",
            SkyboxFt="rbxassetid://6444884344",SkyboxLf="rbxassetid://6444884341",
            SkyboxRt="rbxassetid://6444884348",SkyboxUp="rbxassetid://6444884351",
        },
        ["Sunset"] = {
            SkyboxBk="rbxassetid://2708786809",SkyboxDn="rbxassetid://2708786814",
            SkyboxFt="rbxassetid://2708786816",SkyboxLf="rbxassetid://2708786812",
            SkyboxRt="rbxassetid://2708786819",SkyboxUp="rbxassetid://2708786821",
        },
        ["Space"] = {
            SkyboxBk="rbxassetid://159454299",SkyboxDn="rbxassetid://159454296",
            SkyboxFt="rbxassetid://159454293",SkyboxLf="rbxassetid://159454286",
            SkyboxRt="rbxassetid://159454300",SkyboxUp="rbxassetid://159454295",isSpace=true,
        },
    }
    local SKYBOX_LIST = {"Default","Night Sky","Bliss","Sunset","Space"}
    local PARTS = {"Head","HumanoidRootPart","UpperTorso","LowerTorso","Body","Random"}
    local PMAP = {
        ["Head"]={"Head"},["HumanoidRootPart"]={"HumanoidRootPart"},
        ["UpperTorso"]={"UpperTorso","Torso","HumanoidRootPart"},
        ["LowerTorso"]={"LowerTorso","Torso","HumanoidRootPart"},
        ["Body"]={"UpperTorso","LowerTorso","Torso","HumanoidRootPart"},
        ["Random"]={"Random"},
    }

    -- =============================================
    --   Helpers
    -- =============================================

    local function bPart(char,s)
        local pr=PMAP[s] or {"Head"}
        if pr[1]=="Random" then
            local av={}
            for _,n in ipairs({"Head","UpperTorso","LowerTorso","HumanoidRootPart"}) do
                local p=char:FindFirstChild(n);if p then table.insert(av,p) end
            end
            return #av>0 and av[math.random(1,#av)] or nil
        end
        for _,n in ipairs(pr) do
            local p=char:FindFirstChild(n);if p then return p end
        end
    end

    local function scr()
        return Vector2.new(cam.ViewportSize.X/2,cam.ViewportSize.Y/2)
    end

    local function getMouse()
        return UserInputService:GetMouseLocation()
    end

    local function sameTm(p)
        local r=false
        pcall(function()
            local a=lp:GetAttribute("TeamID");local b=p:GetAttribute("TeamID")
            if a~=nil and b~=nil then r=(a==b) end
        end)
        return r
    end

    local vpRp=RaycastParams.new()
    vpRp.FilterType=Enum.RaycastFilterType.Exclude

    local function isVis(orig,part)
        if not part then return false end
        local ok,res=pcall(function()
            vpRp.FilterDescendantsInstances={lp.Character,part.Parent}
            local d=part.Position-orig
            local h=ws:Raycast(orig,d,vpRp)
            return h==nil or h.Instance:IsDescendantOf(part.Parent)
        end)
        return ok and res or false
    end

    local function inFov(part,fovSz)
        if not part then return false end
        local sp,on=cam:WorldToViewportPoint(part.Position)
        if not on then return false end
        return (Vector2.new(sp.X,sp.Y)-scr()).Magnitude<=fovSz
    end

    local function angDiff(f,t)
        local d=t-f
        return ((d+math.pi)%(math.pi*2))-math.pi
    end

    local function isValidTarget(player)
        if not player or not player:IsA("Player") then return false end
        if player==lp then return false end
        local char=player.Character
        if not char or not char:IsDescendantOf(workspace) then return false end
        local hum=char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health<=0 then return false end
        if hum:GetState()==Enum.HumanoidStateType.Dead then return false end
        if not char:FindFirstChild("HumanoidRootPart") then return false end
        local myChar=lp.Character
        if myChar then
            local myHRP=myChar:FindFirstChild("HumanoidRootPart")
            local hrp=char:FindFirstChild("HumanoidRootPart")
            if myHRP and hrp and (myHRP.Position-hrp.Position).Magnitude>3000 then
                return false
            end
        end
        return true
    end

    local function notify(title,desc,dur)
        Library:Notification({Title=title,Description=desc,Duration=dur or 2,Icon="73789337996373"})
    end

    -- =============================================
    --   FLAG HELPER — works with neverlose flags
    -- =============================================

    local function getFlag(key, default)
        local v = Library.Flags and Library.Flags[key]
        if v == nil then return default end
        if type(v) == "table" then return v[1] or default end
        return v
    end

    -- ============================================================
    --   PAGES & SECTIONS
    -- ============================================================

    Window:Category("Combat")
    local CombatPage = Window:Page({Name="Aimbot",     Icon="138827881557940"})
    local SilentPage = Window:Page({Name="Silent Aim", Icon="138827881557940"})
    local RagePage   = Window:Page({Name="Ragebot",    Icon="138827881557940"})
    local WBPage     = Window:Page({Name="Wallbang",   Icon="138827881557940"})
    local HSPage     = Window:Page({Name="Hit Sound",  Icon="138827881557940"})

    Window:Category("Visuals")
    local FOVPage    = Window:Page({Name="FOV",        Icon="138827881557940"})

    Window:Category("Game")
    local CamPage    = Window:Page({Name="Camera",     Icon="138827881557940"})
    local MiscPage   = Window:Page({Name="Misc",       Icon="138827881557940"})
    local SkyPage    = Window:Page({Name="Skybox",     Icon="138827881557940"})

    local ABMain  = CombatPage:Section({Name="Aimbot",           Side=1})
    local ABAdv   = CombatPage:Section({Name="Advanced",         Side=2})
    local SAMain  = SilentPage:Section({Name="Silent Aim",       Side=1})
    local SACirc  = SilentPage:Section({Name="Silent Circle",    Side=2})
    local RGMain  = RagePage:Section({Name="Ragebot",            Side=1})
    local RGAdv   = RagePage:Section({Name="Advanced",           Side=2})
    local WBMain  = WBPage:Section({Name="Wallbang",             Side=1})
    local HSMain  = HSPage:Section({Name="Hit Sound",            Side=1})
    local FOVMain = FOVPage:Section({Name="Aimbot FOV",          Side=1})
    local FOVSil  = FOVPage:Section({Name="Silent FOV",          Side=2})
    local CamMain = CamPage:Section({Name="Camera",              Side=1})
    local CamAdv  = CamPage:Section({Name="Sensitivity & VM",   Side=2})
    local MLoad   = MiscPage:Section({Name="Loadout",            Side=1})
    local MQueue  = MiscPage:Section({Name="Queue & Vote",       Side=2})
    local SkyMain = SkyPage:Section({Name="Skybox",              Side=1})

    -- ============================================================
    --   AIMBOT
    -- ============================================================

    local AB={
        on=false,part="Head",team=true,vis=true,fov=150,
        dynFov=false,lockMode="Soft",curvePct=10,
        speed=1.0,speedAttack=1.0,speedScaleFov=50,
        maxLock=3.0,reactTime=100,useCenter=false,
    }
    local abTgt=nil;local abLockT=0;local abReactT=0
    local abDoReact=false;local abPrevPos=nil;local abPrevTick=0
    local abCurveProgress=0;local abCurveStart=nil

    local abCirc=Drawing.new("Circle")
    abCirc.NumSides=64;abCirc.Filled=false
    abCirc.Color=Color3.fromRGB(255,255,255)
    abCirc.Thickness=1.5;abCirc.Visible=false

    local function abEffFov()
        return AB.dynFov and AB.fov*(cam.FieldOfView/70) or AB.fov
    end

    local function abTgtValid(pt)
        if not pt or not pt.Parent then return false end
        local h=pt.Parent:FindFirstChildOfClass("Humanoid")
        if not h or h.Health<=0 then return false end
        if not inFov(pt,abEffFov()) then return false end
        if AB.vis and not isVis(cam.CFrame.Position,pt) then return false end
        if AB.team then
            local p=Players:GetPlayerFromCharacter(pt.Parent)
            if p and sameTm(p) then return false end
        end
        return true
    end

    local function abFind()
        local center=AB.useCenter and scr() or getMouse()
        local fv=abEffFov();local best=nil;local bd=fv
        for _,p in ipairs(Players:GetPlayers()) do
            if p==lp or (AB.team and sameTm(p)) or not isValidTarget(p) then continue end
            local chr=p.Character;local pt=bPart(chr,AB.part)
            if not pt then continue end
            local sp,on=cam:WorldToViewportPoint(pt.Position)
            if not on then continue end
            local d=(Vector2.new(sp.X,sp.Y)-center).Magnitude
            if d<bd then
                if AB.vis and not isVis(cam.CFrame.Position,pt) then continue end
                bd=d;best=pt
            end
        end
        return best
    end

    local function getPredictedPos(pt)
        local now=tick();local pos=pt.Position
        if abPrevPos and (now-abPrevTick)>0 then
            local vel=(pos-abPrevPos)/(now-abPrevTick)
            pos=pos+vel*(0.08*AB.speedAttack)
        end
        abPrevPos=pt.Position;abPrevTick=now;return pos
    end

    local function applySmartLock(tRot,cur,dt,sd,fr)
        local df=AB.speed
        if fr>0 then df=AB.speed+(AB.speedScaleFov/100)*(1-math.clamp(sd/fr,0,1))*math.max(AB.speedAttack-AB.speed,0) end
        local eff=math.clamp(df,0.01,5);local fac=math.clamp(eff*dt*6,0,1)
        if AB.lockMode~="Curve" then
            return Vector2.new(cur.X+(tRot.X-cur.X)*fac,cur.Y+angDiff(cur.Y,tRot.Y)*fac)
        end
        local dist2=math.sqrt((tRot.X-cur.X)^2+angDiff(cur.Y,tRot.Y)^2)
        if abCurveStart==nil or dist2>0.5 then abCurveStart=cur;abCurveProgress=0 end
        local sp2=(AB.curvePct/100)*3*eff
        abCurveProgress=math.clamp(abCurveProgress+sp2*dt,0,1)
        local c=abCurveProgress^2*(3-2*abCurveProgress)
        local nP=abCurveStart.X+(tRot.X-abCurveStart.X)*c
        local nY=abCurveStart.Y+angDiff(abCurveStart.Y,tRot.Y)*c
        if abCurveProgress>=1 then abCurveStart=nil;abCurveProgress=0 end
        return Vector2.new(nP,nY)
    end

    ABMain:Toggle({Name="Enable Aimbot",Flag="AimbotOn",Default=false,Callback=function(v)
        AB.on=v
        if not v then abTgt=nil;abLockT=0;abDoReact=false;abPrevPos=nil;abCurveStart=nil;abCurveProgress=0 end
        notify("Aimbot",v and "Active!" or "Off")
    end})
    ABMain:Toggle({Name="Team Check",Flag="AimbotTeam",Default=true,Callback=function(v) AB.team=v end})
    ABMain:Toggle({Name="Visible Check",Flag="AimbotVis",Default=true,Callback=function(v) AB.vis=v end})
    ABMain:Toggle({Name="Screen Center",Flag="AimbotCenter",Default=false,Callback=function(v) AB.useCenter=v end})
    ABMain:Toggle({Name="Dynamic FOV",Flag="AimbotDynFov",Default=false,Callback=function(v) AB.dynFov=v end})
    ABMain:Dropdown({Name="Aim Part",Flag="AimbotPart",Default={"Head"},Items=PARTS,Multi=false,Callback=function(v) AB.part=type(v)=="table" and v[1] or v end})
    ABMain:Dropdown({Name="Lock Mode",Flag="AimbotMode",Default={"Soft"},Items={"Soft","Magnet","Curve"},Multi=false,Callback=function(v) AB.lockMode=type(v)=="table" and v[1] or v;abCurveStart=nil;abCurveProgress=0 end})
    ABMain:Slider({Name="FOV Size",Flag="AimbotFov",Min=10,Max=500,Default=150,Suffix=" px",Callback=function(v) AB.fov=v;abCirc.Radius=v end})
    ABAdv:Slider({Name="Speed",Flag="AimbotSpd",Min=1,Max=500,Default=100,Suffix="x0.01",Callback=function(v) AB.speed=v/100 end})
    ABAdv:Slider({Name="Attack Speed",Flag="AimbotAtkSpd",Min=1,Max=500,Default=100,Suffix="x0.01",Callback=function(v) AB.speedAttack=v/100 end})
    ABAdv:Slider({Name="Speed Scale FOV",Flag="AimbotSpdScale",Min=0,Max=100,Default=50,Suffix="%",Callback=function(v) AB.speedScaleFov=v end})
    ABAdv:Slider({Name="Curve",Flag="AimbotCurve",Min=1,Max=400,Default=10,Suffix="%",Callback=function(v) AB.curvePct=v end})
    ABAdv:Slider({Name="Max Lock",Flag="AimbotMaxLock",Min=1,Max=1000,Default=300,Suffix="x0.01s",Callback=function(v) AB.maxLock=v/100 end})
    ABAdv:Slider({Name="Reaction",Flag="AimbotReact",Min=0,Max=500,Default=100,Suffix="ms",Callback=function(v) AB.reactTime=v end})

    -- ============================================================
    --   FOV CIRCLES
    -- ============================================================

    local fovCfg={visible=true,half=false,color=Color3.fromRGB(255,255,255),fovSize=150,onTarget=60,onBarrier=200,useCenter=false}
    local fovCircle=Drawing.new("Circle")
    fovCircle.Visible=false;fovCircle.Thickness=1.5;fovCircle.Color=Color3.fromRGB(255,255,255)
    fovCircle.Filled=false;fovCircle.NumSides=64;fovCircle.Radius=150
    local fovHalf=Drawing.new("Circle")
    fovHalf.Visible=false;fovHalf.Thickness=1;fovHalf.Color=Color3.fromRGB(255,255,255)
    fovHalf.Filled=false;fovHalf.NumSides=32;fovHalf.Radius=75

    FOVMain:Toggle({Name="Show FOV Circle",Flag="FovVisible",Default=true,Callback=function(v) fovCfg.visible=v end})
    FOVMain:Toggle({Name="Half Circle",Flag="FovHalf",Default=false,Callback=function(v) fovCfg.half=v end})
    FOVMain:Toggle({Name="Screen Center",Flag="FovCenter",Default=false,Callback=function(v) fovCfg.useCenter=v end})
    FOVMain:Label("FOV Color"):Colorpicker({Name="Color",Flag="FovColor",Default=Color3.fromRGB(255,255,255),Callback=function(v) fovCfg.color=v end})
    FOVMain:Slider({Name="FOV Radius",Flag="FovRadius",Min=10,Max=500,Default=150,Suffix=" px",Callback=function(v) fovCfg.fovSize=v;AB.fov=v;fovCircle.Radius=v;abCirc.Radius=v end})
    FOVMain:Slider({Name="On Target",Flag="FovOnTarget",Min=10,Max=500,Default=60,Suffix=" px",Callback=function(v) fovCfg.onTarget=v end})
    FOVMain:Slider({Name="On Barrier",Flag="FovOnBarrier",Min=10,Max=500,Default=200,Suffix=" px",Callback=function(v) fovCfg.onBarrier=v end})

    -- ============================================================
    --   SILENT AIM
    -- ============================================================

    local silentCfg={
        enabled=false,hitChance=100,prediction=0,visCheck=true,
        useCenter=false,fovSize=150,maxDist=200,part="Head",
        circleVisible=true,circleColor=Color3.fromRGB(0,200,255),
        circleThick=1.5,targetColor=Color3.fromRGB(255,50,50),
    }
    local silentCircle=Drawing.new("Circle")
    silentCircle.Thickness=1.5;silentCircle.Filled=false;silentCircle.NumSides=64
    silentCircle.Visible=false;silentCircle.Radius=150;silentCircle.Color=Color3.fromRGB(0,200,255)

    local silentHooked=false;local origRaycast=nil;local origMeta=nil;local origIdx=nil

    local function getSilentTarget(origin)
        local center=silentCfg.useCenter and scr() or getMouse()
        local best,bd=nil,math.huge
        for _,p in pairs(Players:GetPlayers()) do
            if p==lp or not isValidTarget(p) then continue end
            local char=p.Character;local head=bPart(char,silentCfg.part)
            local hum=char:FindFirstChildOfClass("Humanoid")
            if not head or not hum or hum.Health<=0 then continue end
            if (origin-head.Position).Magnitude>silentCfg.maxDist then continue end
            if silentCfg.visCheck and not isVis(origin,head) then continue end
            local sp,vis=cam:WorldToViewportPoint(head.Position)
            if not vis then continue end
            local d=(Vector2.new(sp.X,sp.Y)-center).Magnitude
            if d<silentCfg.fovSize and d<bd then bd=d;best=head end
        end
        return best
    end

    local function buildSilentWrapper(orig)
        return function(self,origin,direction,distance,...)
            if silentCfg.enabled and math.random(1,100)<=silentCfg.hitChance then
                local myRoot=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
                local o=myRoot and myRoot.Position or cam.CFrame.Position
                local tgt=getSilentTarget(o)
                if tgt then
                    local pred=tgt.Position
                    if silentCfg.prediction>0 then
                        pcall(function()
                            local hrp=tgt.Parent and tgt.Parent:FindFirstChild("HumanoidRootPart")
                            local vel=hrp and hrp.AssemblyLinearVelocity or Vector3.zero
                            pred=tgt.Position+vel*(silentCfg.prediction*0.05)
                        end)
                    end
                    return orig(self,origin,pred-origin,distance,...)
                end
            end
            return orig(self,origin,direction,distance,...)
        end
    end

    local function hookSilent()
        if silentHooked or not util then return end
        local ok,mt=pcall(getrawmetatable,util)
        if ok and mt then
            local cs=pcall(setrawmetatable,util,mt)
            if cs then
                origMeta=mt;origIdx=rawget(mt,"__index")
                rawset(mt,"__index",function(t,k)
                    if k=="Raycast" then
                        local rf=type(origIdx)=="function" and origIdx(t,k)
                            or type(origIdx)=="table" and origIdx[k]
                            or rawget(t,k)
                        if rf then return buildSilentWrapper(rf) end
                    end
                    return type(origIdx)=="function" and origIdx(t,k)
                        or type(origIdx)=="table" and origIdx[k]
                        or rawget(t,k)
                end)
                silentHooked=true;return
            end
        end
        origRaycast=rawget(util,"Raycast") or util.Raycast
        if origRaycast then rawset(util,"Raycast",buildSilentWrapper(origRaycast));silentHooked=true end
    end

    local function unhookSilent()
        if not silentHooked then return end
        if origMeta and origIdx then pcall(function() rawset(origMeta,"__index",origIdx) end);origMeta=nil;origIdx=nil
        elseif origRaycast and util then pcall(function() rawset(util,"Raycast",origRaycast) end);origRaycast=nil end
        silentHooked=false
    end

    SAMain:Toggle({Name="Enable Silent Aim",Flag="SilentOn",Default=false,Callback=function(v)
        silentCfg.enabled=v
        if v then hookSilent();notify("Silent Aim","Active!") else unhookSilent();notify("Silent Aim","Off") end
    end})
    SAMain:Toggle({Name="Visible Check",Flag="SilentVis",Default=true,Callback=function(v) silentCfg.visCheck=v end})
    SAMain:Toggle({Name="Screen Center",Flag="SilentCenter",Default=false,Callback=function(v) silentCfg.useCenter=v end})
    SAMain:Dropdown({Name="Target Part",Flag="SilentPart",Default={"Head"},Items=PARTS,Multi=false,Callback=function(v) silentCfg.part=type(v)=="table" and v[1] or v end})
    SAMain:Slider({Name="Hit Chance",Flag="SilentChance",Min=1,Max=100,Default=100,Suffix="%",Callback=function(v) silentCfg.hitChance=v end})
    SAMain:Slider({Name="Prediction",Flag="SilentPred",Min=0,Max=100,Default=0,Suffix="x0.05",Callback=function(v) silentCfg.prediction=v end})
    SAMain:Slider({Name="FOV",Flag="SilentFov",Min=10,Max=600,Default=150,Suffix=" px",Callback=function(v) silentCfg.fovSize=v;silentCircle.Radius=v end})
    SAMain:Slider({Name="Max Distance",Flag="SilentDist",Min=10,Max=2000,Default=200,Suffix=" studs",Callback=function(v) silentCfg.maxDist=v end})

    FOVSil:Toggle({Name="Show Circle",Flag="SilentCircOn",Default=true,Callback=function(v) silentCfg.circleVisible=v;if not v then silentCircle.Visible=false end end})
    FOVSil:Label("Normal Color"):Colorpicker({Name="Color",Flag="SilentCircColor",Default=Color3.fromRGB(0,200,255),Callback=function(v) silentCfg.circleColor=v end})
    FOVSil:Label("On Target Color"):Colorpicker({Name="Color",Flag="SilentTargColor",Default=Color3.fromRGB(255,50,50),Callback=function(v) silentCfg.targetColor=v end})
    FOVSil:Slider({Name="Thickness",Flag="SilentCircThick",Min=5,Max=50,Default=15,Suffix="x0.1",Callback=function(v) silentCfg.circleThick=v*0.1;silentCircle.Thickness=v*0.1 end})
    FOVSil:Slider({Name="Segments",Flag="SilentCircSegs",Min=8,Max=128,Default=64,Suffix=" sides",Callback=function(v) silentCircle.NumSides=v end})

    -- ============================================================
    --   RAGEBOT v3.0
    -- ============================================================

    local rageCfg={
        enabled=false,improvedManip=false,useDesync=true,
        hideRange=0.3,attackRange=0.3,mutualKillFix=true,
        doubleTap=false,doubleTapDelay=0.08,teamCheck=true,
        visCheck=false,maxDist=500,
        v1y=12,v2y=16,v3y=20,v4y=24,
        v5y=28,v6y=32,v7y=36,v8y=40,
        v1x=0,v2x=0,v3x=0,v4x=0,
        v1z=0,v2z=0,v3z=0,v4z=0,
        vectors={},
        improv={scanAngle=15,multiPass=true,spiralScan=false,adaptDist=true},
    }
    local rageConn=nil;local rageRunning=false
    local rageDesyncConn=nil;local rageDesyncActive=false

    local ray_p=RaycastParams.new()
    ray_p.FilterType=Enum.RaycastFilterType.Exclude

    local function rebuildVectors()
        rageCfg.vectors={
            Vector3.new(rageCfg.v1x,rageCfg.v1y,rageCfg.v1z),
            Vector3.new(rageCfg.v2x,rageCfg.v2y,rageCfg.v2z),
            Vector3.new(rageCfg.v3x,rageCfg.v3y,rageCfg.v3z),
            Vector3.new(rageCfg.v4x,rageCfg.v4y,rageCfg.v4z),
            Vector3.new(0,rageCfg.v5y,0),Vector3.new(0,rageCfg.v6y,0),
            Vector3.new(0,rageCfg.v7y,0),Vector3.new(0,rageCfg.v8y,0),
        }
    end
    rebuildVectors()

    local function rageGetClosest()
        if not lp.Character then return nil,nil end
        local myHRP=lp.Character:FindFirstChild("HumanoidRootPart")
        if not myHRP then return nil,nil end
        local bestT,bestC,bestD=nil,nil,math.huge
        for _,p in ipairs(Players:GetPlayers()) do
            if not isValidTarget(p) then continue end
            if rageCfg.teamCheck and sameTm(p) then continue end
            local char=p.Character;local head=char:FindFirstChild("Head")
            if not head then continue end
            local dist=(myHRP.Position-head.Position).Magnitude
            if dist>rageCfg.maxDist or dist>bestD then continue end
            if rageCfg.visCheck and not isVis(cam.CFrame.Position,head) then continue end
            local owner=Players:GetPlayerFromCharacter(char)
            if not owner or owner==lp then continue end
            bestD=dist;bestT=head;bestC=char
        end
        return bestT,bestC
    end

    local function rageCalcPoint(orig,tPos,tChar)
        ray_p.FilterDescendantsInstances={lp.Character,tChar}
        if not ws:Raycast(orig,tPos-orig,ray_p) then return orig,nil end
        for _,off in next,rageCfg.vectors do
            local sp=orig+off
            if not ws:Raycast(sp,tPos-sp,ray_p) then return sp,off.Y end
        end
        return nil,nil
    end

    local function improvedCalcPoint(orig,tPos,tChar)
        ray_p.FilterDescendantsInstances={lp.Character,tChar}
        local function try(sp)
            local r=ws:Raycast(sp,tPos-sp,ray_p)
            return r==nil or r.Instance:IsDescendantOf(tChar)
        end
        if try(orig) then return orig,nil end
        for _,off in next,rageCfg.vectors do
            local sp=orig+off;if try(sp) then return sp,off.Y end
        end
        if rageCfg.improv.multiPass then
            for _,off in next,rageCfg.vectors do
                for ang=-45,45,rageCfg.improv.scanAngle do
                    local rad=math.rad(ang)
                    local sp=orig+Vector3.new(off.X*math.cos(rad)-off.Z*math.sin(rad),off.Y,off.X*math.sin(rad)+off.Z*math.cos(rad))
                    if try(sp) then return sp,off.Y end
                end
            end
        end
        if rageCfg.improv.spiralScan then
            for layer=1,4 do
                local h=layer*8
                for s2=0,11 do
                    local a=(s2/12)*math.pi*2
                    local sp=orig+Vector3.new(math.cos(a)*2*layer,h,math.sin(a)*2*layer)
                    if try(sp) then return sp,h end
                end
            end
        end
        for _,side in next,{
            Vector3.new(2,0,0),Vector3.new(-2,0,0),Vector3.new(0,0,2),Vector3.new(0,0,-2),
            Vector3.new(3,8,0),Vector3.new(-3,8,0),Vector3.new(0,8,3),Vector3.new(0,8,-3),
        } do
            local sp=orig+side;if try(sp) then return sp,side.Y end
        end
        if rageCfg.improv.adaptDist then
            local sc=math.clamp((orig-tPos).Magnitude/50,0.5,3)
            for _,off in next,rageCfg.vectors do
                local sp=orig+Vector3.new(off.X*sc,off.Y*sc,off.Z*sc)
                if try(sp) then return sp,off.Y*sc end
            end
        end
        return nil,nil
    end

    local function startRageDesync(tChar)
        if rageDesyncConn then rageDesyncConn:Disconnect();rageDesyncConn=nil end
        rageDesyncActive=true
        local head=tChar and tChar:FindFirstChild("Head")
        if not head then return end
        rageDesyncConn=RunService.Heartbeat:Connect(function()
            if not rageDesyncActive then return end
            local root=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
            if not root then return end
            if not head or not head.Parent then
                rageDesyncActive=false
                if rageDesyncConn then rageDesyncConn:Disconnect();rageDesyncConn=nil end
                return
            end
            local sCF=root.CFrame;local sLV=root.AssemblyLinearVelocity;local sAV=root.AssemblyAngularVelocity
            root.CFrame=head.CFrame*CFrame.new(0,-5,0)
            RunService:BindToRenderStep("__rdR",101,function()
                pcall(function() root.CFrame=sCF;root.AssemblyLinearVelocity=sLV;root.AssemblyAngularVelocity=sAV end)
                RunService:UnbindFromRenderStep("__rdR")
            end)
        end)
    end

    local function stopRageDesync()
        rageDesyncActive=false
        if rageDesyncConn then rageDesyncConn:Disconnect();rageDesyncConn=nil end
        pcall(function() RunService:UnbindFromRenderStep("__rdR") end)
    end

    local function rageFireShot(item,tp,tc,manip,height)
        pcall(function()
            local camCF=cam.CFrame
            local so=height~=nil and Vector3.new(camCF.Position.X,camCF.Position.Y+height,camCF.Position.Z) or camCF.Position
            local tPos=tp.Position
            local cf1=CFrame.lookAt(so,tPos);local cf2=CFrame.lookAt(tPos,so)
            local rel=tp.CFrame:ToObjectSpace(CFrame.new(tPos))
            local cd={}
            cd[utf8.char(1)]={[utf8.char(0)]=util:EncodeCFrame(cf1),[utf8.char(1)]=util:EncodeCFrame(cf2),[utf8.char(2)]=tp,[utf8.char(3)]=util:EncodeCFrame(rel)}
            UseItemRemote:FireServer(item:Get("ObjectID"),enums:ToEnum("StartShooting"),cd,nil)
            if rageCfg.doubleTap and rageCfg.mutualKillFix then
                task.delay(rageCfg.doubleTapDelay,function()
                    if not tp or not tp.Parent then return end
                    local hum=tc:FindFirstChildOfClass("Humanoid")
                    if not hum or hum.Health<=0 then return end
                    local off=Vector3.new(math.random(-10,10)*0.01,math.random(-10,10)*0.01,math.random(-10,10)*0.01)
                    local cd2={}
                    cd2[utf8.char(1)]={[utf8.char(0)]=util:EncodeCFrame(CFrame.lookAt(so+off,tPos)),[utf8.char(1)]=util:EncodeCFrame(CFrame.lookAt(tPos,so+off)),[utf8.char(2)]=tp,[utf8.char(3)]=util:EncodeCFrame(rel)}
                    pcall(function() UseItemRemote:FireServer(item:Get("ObjectID"),enums:ToEnum("StartShooting"),cd2,nil) end)
                end)
            end
        end)
    end

    local function startRagebot()
        if rageConn then rageConn:Disconnect();rageConn=nil end
        rageRunning=false
        rageConn=RunService.Heartbeat:Connect(function()
            if not rageCfg.enabled or rageRunning then return end
            if not lp.Character then return end
            local myHRP=lp.Character:FindFirstChild("HumanoidRootPart");if not myHRP then return end
            if not FighterController then return end
            local lf=FighterController.LocalFighter;if not lf then return end
            local item=lf.EquippedItem;if not item then return end
            local tp,tc=rageGetClosest()
            if not tp or not tc then if rageDesyncActive then stopRageDesync() end;return end
            if not tp.Parent then return end
            local hum=tp.Parent:FindFirstChildOfClass("Humanoid")
            if not hum or hum.Health<=0 then return end
            rageRunning=true
            task.spawn(function()
                -- PHASE 1: Hide (desync)
                if rageCfg.useDesync then
                    startRageDesync(tc)
                    task.wait(rageCfg.hideRange)  -- task.wait NOT safeWait
                end
                -- Revalidate
                if not rageCfg.enabled or not tp or not tp.Parent then
                    stopRageDesync();rageRunning=false;return
                end
                local hum2=tc:FindFirstChildOfClass("Humanoid")
                if not hum2 or hum2.Health<=0 then
                    stopRageDesync();rageRunning=false;return
                end
                -- PHASE 2: Shoot
                local camCF=cam.CFrame
                local manip,height
                if rageCfg.improvedManip then
                    manip,height=improvedCalcPoint(camCF.Position,tp.Position,tc)
                else
                    manip,height=rageCalcPoint(camCF.Position,tp.Position,tc)
                end
                if manip or isVis(camCF.Position,tp) then
                    rageFireShot(item,tp,tc,manip,height)
                end
                task.wait(rageCfg.attackRange)  -- task.wait NOT safeWait
                -- PHASE 3: Cleanup
                if rageCfg.useDesync then stopRageDesync() end
                rageRunning=false
            end)
        end)
    end

    local function stopRagebot()
        if rageConn then rageConn:Disconnect();rageConn=nil end
        stopRageDesync();rageCfg.enabled=false;rageRunning=false
    end

    RGMain:Toggle({Name="Enable Ragebot",Flag="RageOn",Default=false,Callback=function(v)
        rageCfg.enabled=v
        if v then startRagebot();notify("Ragebot","Active!") else stopRagebot();notify("Ragebot","Off") end
    end})
    RGMain:Toggle({Name="Team Check",Flag="RageTeam",Default=true,Callback=function(v) rageCfg.teamCheck=v end})
    RGMain:Toggle({Name="Vis Check",Flag="RageVis",Default=false,Callback=function(v) rageCfg.visCheck=v end})
    RGMain:Toggle({Name="Use Desync",Flag="RageDesync",Default=true,Callback=function(v) rageCfg.useDesync=v end})
    RGMain:Slider({Name="Max Distance",Flag="RageDist",Min=50,Max=3000,Default=500,Suffix=" studs",Callback=function(v) rageCfg.maxDist=v end})
    RGMain:Slider({Name="Hide Range",Flag="RageHide",Min=1,Max=10,Default=3,Suffix="x0.1s",Callback=function(v) rageCfg.hideRange=v*0.1 end})
    RGMain:Slider({Name="Attack Range",Flag="RageAtk",Min=1,Max=10,Default=3,Suffix="x0.1s",Callback=function(v) rageCfg.attackRange=v*0.1 end})
    RGMain:Toggle({Name="Mutual Kill Fix",Flag="RageMutual",Default=true,Callback=function(v) rageCfg.mutualKillFix=v end})
    RGMain:Toggle({Name="Double Tap",Flag="RageDTap",Default=false,Callback=function(v) rageCfg.doubleTap=v end})
    RGMain:Slider({Name="Double Tap Delay",Flag="RageDTapDelay",Min=1,Max=20,Default=8,Suffix="x0.01s",Callback=function(v) rageCfg.doubleTapDelay=v*0.01 end})

    RGAdv:Toggle({Name="Improved Manip",Flag="RageImproved",Default=false,Callback=function(v) rageCfg.improvedManip=v end})
    RGAdv:Slider({Name="Scan Angle",Flag="RageScanAngle",Min=1,Max=90,Default=15,Suffix="°",Callback=function(v) rageCfg.improv.scanAngle=v end})
    RGAdv:Toggle({Name="Multi-Pass",Flag="RageMultiPass",Default=true,Callback=function(v) rageCfg.improv.multiPass=v end})
    RGAdv:Toggle({Name="Spiral Scan",Flag="RageSpiral",Default=false,Callback=function(v) rageCfg.improv.spiralScan=v end})
    RGAdv:Toggle({Name="Adapt Distance",Flag="RageAdapt",Default=true,Callback=function(v) rageCfg.improv.adaptDist=v end})

    local vecY={{k="v1y",d=12,l="Vec 1 Y"},{k="v2y",d=16,l="Vec 2 Y"},{k="v3y",d=20,l="Vec 3 Y"},{k="v4y",d=24,l="Vec 4 Y"},{k="v5y",d=28,l="Vec 5 Y"},{k="v6y",d=32,l="Vec 6 Y"},{k="v7y",d=36,l="Vec 7 Y"},{k="v8y",d=40,l="Vec 8 Y"}}
    for i,v in ipairs(vecY) do
        local key=v.k
        RGAdv:Slider({Name=v.l,Flag="RGY"..i,Min=-50,Max=100,Default=v.d,Suffix=" s",Callback=function(val) rageCfg[key]=val;rebuildVectors() end})
    end
    RGAdv:Button({Name="Reset Vectors",Callback=function()
        rageCfg.v1y=12;rageCfg.v2y=16;rageCfg.v3y=20;rageCfg.v4y=24
        rageCfg.v5y=28;rageCfg.v6y=32;rageCfg.v7y=36;rageCfg.v8y=40
        for i=1,4 do rageCfg["v"..i.."x"]=0;rageCfg["v"..i.."z"]=0 end
        rebuildVectors();notify("Ragebot","Vectors reset!")
    end})
    RGAdv:Button({Name="Debug Target",Callback=function()
        local tp,tc=rageGetClosest()
        if tp then
            local owner=Players:GetPlayerFromCharacter(tc)
            local d=lp.Character and lp.Character.HumanoidRootPart
                and math.floor((lp.Character.HumanoidRootPart.Position-tp.Position).Magnitude) or 0
            notify("Ragebot","Target: "..(owner and owner.Name or "???").." | "..d.."studs",4)
        else
            notify("Ragebot","No valid target",3)
        end
    end})

    -- ============================================================
    --   WALLBANG
    -- ============================================================

    local WB={enabled=false,hitPart="Head"}
    local wbState={}
    do
        local __gm=GunModule;local __um=util
        function wbState:init() self.active=false;self.target=nil;self.desync=false;self.conn1=nil;self.conn2=nil;self.task1=nil;self.oldfunc=nil end
        function wbState:find()
            local best,bd=nil,math.huge
            for _,p in next,Players:GetPlayers() do
                if p==lp or not isValidTarget(p) then continue end
                if p:GetAttribute("TeamID")==lp:GetAttribute("TeamID") then continue end
                local c=p.Character;if not c then continue end
                local head=c:FindFirstChild("Head");local hum=c:FindFirstChildWhichIsA("Humanoid")
                if not (head and hum and hum.Health>0) then continue end
                local d=(cam.CFrame.Position-head.Position).Magnitude
                if d<bd then bd=d;best=p end
            end
            return best
        end
        function wbState:getHitPart(char)
            return WB.hitPart=="Head" and char:FindFirstChild("Head")
                or char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
        end
        function wbState:desyncStart(tp2)
            if self.conn2 then self.conn2:Disconnect() end
            self.desync=true
            self.conn2=RunService.Heartbeat:Connect(function()
                if not self.desync then return end
                local root=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart");if not root then return end
                local tc2=tp2.Character;if not tc2 then self:desyncStop();return end
                local h2=tc2:FindFirstChild("Head");if not h2 then self:desyncStop();return end
                local sCF=root.CFrame;local sLV=root.AssemblyLinearVelocity;local sAV=root.AssemblyAngularVelocity
                root.CFrame=h2.CFrame*CFrame.new(0,-5,0)
                RunService:BindToRenderStep("__wbR",101,function()
                    pcall(function() root.CFrame=sCF;root.AssemblyLinearVelocity=sLV;root.AssemblyAngularVelocity=sAV end)
                    RunService:UnbindFromRenderStep("__wbR")
                end)
            end)
        end
        function wbState:desyncStop() self.desync=false;if self.conn2 then self.conn2:Disconnect();self.conn2=nil end end
        function wbState:setup()
            if self.conn1 then self.conn1:Disconnect() end
            self.conn1=RunService.Heartbeat:Connect(function() if not self.active then return end;self.target=self:find() end)
            if not __gm then return end
            local origSS=__gm.StartShooting;self.oldfunc=origSS
            __gm.StartShooting=function(gSelf,...)
                local results={origSS(gSelf,...)}
                if not gSelf.ClientFighter or not gSelf.ClientFighter.IsLocalPlayer then return table.unpack(results) end
                local sd=results[3];if not sd or typeof(sd)~="table" then return table.unpack(results) end
                results[4]=true
                local tgP=self.target
                if not self.active or not tgP or not tgP.Character then return table.unpack(results) end
                self:desyncStart(tgP);task.wait(0.1)
                if self.task1 then task.cancel(self.task1);self.task1=nil end
                local ap=self:getHitPart(tgP.Character);if not ap then return table.unpack(results) end
                local tPos=ap.Position;local tCF2=ap.CFrame;local oPos=tPos-Vector3.new(0,3,0)
                if __um then
                    pcall(function()
                        sd[utf8.char(0)]=__um:EncodeCFrame(CFrame.new(oPos,tPos))
                        sd[utf8.char(1)]=__um:EncodeCFrame(CFrame.new(tPos))
                        sd[utf8.char(2)]=ap
                        sd[utf8.char(3)]=__um:EncodeCFrame(tCF2:ToObjectSpace(CFrame.new(tPos+Vector3.new(math.random(-1,1)*0.5,math.random(-1,1)*0.5,math.random(-1,1)*0.5))))
                        if sd.Hitbox then sd.Hitbox=WB.hitPart=="Head" and "Head" or "Body" end
                    end)
                end
                self.task1=task.delay(0.15,function() self:desyncStop() end)
                return table.unpack(results)
            end
        end
        function wbState:Start() self.active=true;self:setup();notify("Wallbang","Active!") end
        function wbState:Shutdown()
            self.active=false
            if self.conn1 then self.conn1:Disconnect();self.conn1=nil end
            if self.conn2 then self.conn2:Disconnect();self.conn2=nil end
            if self.task1 then task.cancel(self.task1);self.task1=nil end
            if self.oldfunc and __gm then __gm.StartShooting=self.oldfunc;self.oldfunc=nil end
            notify("Wallbang","Off")
        end
    end
    wbState:init()

    WBMain:Toggle({Name="Enable Wallbang",Flag="WBOn",Default=false,Callback=function(v) WB.enabled=v;if v then wbState:Start() else wbState:Shutdown() end end})
    WBMain:Dropdown({Name="Hit Part",Flag="WBPart",Default={"Head"},Items={"Head","Body"},Multi=false,Callback=function(v) WB.hitPart=type(v)=="table" and v[1] or v end})
    WBMain:Button({Name="Debug Target",Callback=function()
        local tg=wbState:find();notify("Wallbang",tg and "Target: "..tg.Name or "No target",3)
    end})

    -- ============================================================
    --   HIT SOUND
    -- ============================================================

    local hsCfg={enabled=false,soundId="rbxassetid://4764109000",volume=1,pitch=1}
    local hsConn=nil

    local function findVM()
        local r=nil
        pcall(function()
            for _,v in pairs(lp.PlayerScripts:GetDescendants()) do
                if v.Name=="ClientViewModel" then r=v;break end
            end
        end)
        return r
    end

    local function applyHS(sId,vol,pit)
        if hsConn then hsConn:Disconnect();hsConn=nil end
        task.spawn(function()
            local vm=findVM();if not vm then notify("Hit Sound","ViewModel not found!",3);return end
            for _,v in pairs(vm:GetChildren()) do
                if v:IsA("Sound") and v.SoundId~="rbxassetid://16537449730" then
                    pcall(function() v.SoundId=sId;v.Pitch=pit;v.Volume=vol end)
                end
            end
            hsConn=vm.ChildAdded:Connect(function(v)
                if not hsCfg.enabled or not v:IsA("Sound") or v.SoundId=="rbxassetid://16537449730" then return end
                task.defer(function() pcall(function() v.SoundId=sId;v.Pitch=pit;v.Volume=vol end) end)
            end)
        end)
    end

    local function stopHS()
        if hsConn then hsConn:Disconnect();hsConn=nil end;hsCfg.enabled=false
    end

    HSMain:Toggle({Name="Enable Hit Sound",Flag="HSOn",Default=false,Callback=function(v)
        hsCfg.enabled=v
        if v then applyHS(hsCfg.soundId,hsCfg.volume,hsCfg.pitch);notify("Hit Sound","Active!")
        else stopHS();notify("Hit Sound","Off") end
    end})
    HSMain:Dropdown({Name="Sound",Flag="HSSound",Default={"Rust"},Items=HIT_SOUND_LIST,Multi=false,Callback=function(v)
        local sel=type(v)=="table" and v[1] or v
        hsCfg.soundId=HIT_SOUNDS[sel] or hsCfg.soundId
        if hsCfg.enabled then applyHS(hsCfg.soundId,hsCfg.volume,hsCfg.pitch) end
    end})
    HSMain:Slider({Name="Volume",Flag="HSVol",Min=1,Max=100,Default=100,Suffix="%",Callback=function(v) hsCfg.volume=v/100;if hsCfg.enabled then applyHS(hsCfg.soundId,hsCfg.volume,hsCfg.pitch) end end})
    HSMain:Slider({Name="Pitch",Flag="HSPitch",Min=1,Max=30,Default=10,Suffix="x0.1",Callback=function(v) hsCfg.pitch=v*0.1;if hsCfg.enabled then applyHS(hsCfg.soundId,hsCfg.volume,hsCfg.pitch) end end})

    -- ============================================================
    --   CAMERA
    -- ============================================================

    local fovChangerConn=nil
    CamMain:Toggle({Name="FOV Changer",Flag="FovChanger",Default=false,Callback=function(v)
        if v then fovChangerConn=RunService.RenderStepped:Connect(function()
            pcall(function() if CameraController then CameraController._base_fov=getFlag("FovVal",80) end end)
        end)
        else if fovChangerConn then fovChangerConn:Disconnect();fovChangerConn=nil end
            pcall(function() if CameraController then CameraController._base_fov=80;ws.CurrentCamera.FieldOfView=80 end end)
        end
    end})
    CamMain:Slider({Name="FOV",Flag="FovVal",Min=30,Max=120,Default=80,Callback=function(v)
        if getFlag("FovChanger",false) then pcall(function() if CameraController then CameraController._base_fov=v end end) end
    end})

    local noShakeConn=nil
    CamMain:Toggle({Name="No Camera Shake",Flag="NoShake",Default=false,Callback=function(v)
        if v then noShakeConn=RunService.RenderStepped:Connect(function()
            pcall(function() if CameraController then CameraController._shake_enabled=false;CameraController.ShakeCFrame=CFrame.identity end end)
        end)
        else if noShakeConn then noShakeConn:Disconnect();noShakeConn=nil end
            pcall(function() if CameraController then CameraController._shake_enabled=true end end)
        end
    end})

    local noSwayConn=nil
    CamMain:Toggle({Name="No Weapon Sway",Flag="NoSway",Default=false,Callback=function(v)
        if v then noSwayConn=RunService.RenderStepped:Connect(function()
            pcall(function() if CameraController then CameraController._sway_spring.Value=Vector2.zero;CameraController._sway_spring.Target=Vector2.zero end end)
        end)
        else if noSwayConn then noSwayConn:Disconnect();noSwayConn=nil end end
    end})

    local noBobConn=nil
    CamMain:Toggle({Name="No Bobbing",Flag="NoBob",Default=false,Callback=function(v)
        if v then noBobConn=RunService.RenderStepped:Connect(function()
            pcall(function()
                if CameraController then
                    CameraController._bobbing_speed_spring.Target=0;CameraController._bobbing_speed_spring.Value=0
                    CameraController._bobbing_value_spring.Target=0;CameraController._bobbing_value_spring.Value=0
                end
            end)
        end)
        else if noBobConn then noBobConn:Disconnect();noBobConn=nil end end
    end})

    local noJumpConn=nil
    CamMain:Toggle({Name="No Jump Effect",Flag="NoJump",Default=false,Callback=function(v)
        if v then noJumpConn=RunService.RenderStepped:Connect(function()
            pcall(function() if CameraController then CameraController._jump_spring.Target=0;CameraController._jump_spring.Value=0 end end)
        end)
        else if noJumpConn then noJumpConn:Disconnect();noJumpConn=nil end end
    end})

    local noSlideConn=nil
    CamMain:Toggle({Name="No Slide Tilt",Flag="NoSlide",Default=false,Callback=function(v)
        if v then noSlideConn=RunService.RenderStepped:Connect(function()
            pcall(function() if CameraController then CameraController._sliding_spring.Target=0;CameraController._sliding_spring.Value=0 end end)
        end)
        else if noSlideConn then noSlideConn:Disconnect();noSlideConn=nil end end
    end})

    local crossConn=nil
    CamMain:Toggle({Name="Force Crosshair",Flag="ForceCross",Default=false,Callback=function(v)
        if v then crossConn=RunService.RenderStepped:Connect(function()
            pcall(function() if CameraController then CameraController._crosshair_disabled=false end end)
        end)
        else if crossConn then crossConn:Disconnect();crossConn=nil end
            pcall(function() if CameraController then CameraController:_UpdateSettings() end end)
        end
    end})

    local sensConn=nil
    CamAdv:Toggle({Name="Override Sensitivity",Flag="SensOn",Default=false,Callback=function(v)
        if v then sensConn=RunService.RenderStepped:Connect(function()
            pcall(function()
                if not CameraController then return end
                CameraController._camera_sensitivity=getFlag("SensVal",100)/100
                CameraController._camera_sensitivity_ads_multiplier=getFlag("SensADS",100)/100
                CameraController._camera_sensitivity_ads_multiplier_scoped=getFlag("SensScoped",100)/100
                CameraController._camera_sensitivity_x=getFlag("SensX",100)/100
                CameraController._camera_sensitivity_y=getFlag("SensY",100)/100
            end)
        end)
        else if sensConn then sensConn:Disconnect();sensConn=nil end
            pcall(function() if CameraController then CameraController:_UpdateSettings() end end)
        end
    end})
    CamAdv:Slider({Name="Sensitivity",Flag="SensVal",Min=1,Max=500,Default=100,Suffix="%",Callback=function(_) end})
    CamAdv:Slider({Name="ADS",Flag="SensADS",Min=1,Max=500,Default=100,Suffix="%",Callback=function(_) end})
    CamAdv:Slider({Name="Scoped",Flag="SensScoped",Min=1,Max=500,Default=100,Suffix="%",Callback=function(_) end})
    CamAdv:Slider({Name="X Axis",Flag="SensX",Min=1,Max=500,Default=100,Suffix="%",Callback=function(_) end})
    CamAdv:Slider({Name="Y Axis",Flag="SensY",Min=1,Max=500,Default=100,Suffix="%",Callback=function(_) end})

    local vmConn=nil;local vmCfg={x=0,y=0,z=0}
    CamAdv:Toggle({Name="Custom Viewmodel",Flag="VMOn",Default=false,Callback=function(v)
        if v then vmConn=RunService.RenderStepped:Connect(function()
            pcall(function() if CameraController then CameraController.ViewModelOffsetCFrame=CFrame.new(vmCfg.x,vmCfg.y,vmCfg.z) end end)
        end)
        else if vmConn then vmConn:Disconnect();vmConn=nil end
            pcall(function() if CameraController then CameraController.ViewModelOffsetCFrame=CFrame.identity end end)
        end
    end})
    CamAdv:Slider({Name="X Offset",Flag="VMX",Min=-50,Max=50,Default=0,Suffix="x0.1",Callback=function(v) vmCfg.x=v*0.1 end})
    CamAdv:Slider({Name="Y Offset",Flag="VMY",Min=-50,Max=50,Default=0,Suffix="x0.1",Callback=function(v) vmCfg.y=v*0.1 end})
    CamAdv:Slider({Name="Z Offset",Flag="VMZ",Min=-50,Max=50,Default=0,Suffix="x0.1",Callback=function(v) vmCfg.z=v*0.1 end})

    -- ============================================================
    --   MISC
    -- ============================================================

    local lCfg={primary=PRIMARY_WEAPONS[1],secondary=SECONDARY_WEAPONS[1],melee=MELEE_WEAPONS[1],utility=UTILITY_WEAPONS[1]}

    MLoad:Dropdown({Name="Primary",Flag="LPrimary",Default={PRIMARY_WEAPONS[1]},Items=PRIMARY_WEAPONS,Multi=false,Callback=function(v) lCfg.primary=type(v)=="table" and v[1] or v end})
    MLoad:Dropdown({Name="Secondary",Flag="LSecondary",Default={SECONDARY_WEAPONS[1]},Items=SECONDARY_WEAPONS,Multi=false,Callback=function(v) lCfg.secondary=type(v)=="table" and v[1] or v end})
    MLoad:Dropdown({Name="Melee",Flag="LMelee",Default={MELEE_WEAPONS[1]},Items=MELEE_WEAPONS,Multi=false,Callback=function(v) lCfg.melee=type(v)=="table" and v[1] or v end})
    MLoad:Dropdown({Name="Utility",Flag="LUtility",Default={UTILITY_WEAPONS[1]},Items=UTILITY_WEAPONS,Multi=false,Callback=function(v) lCfg.utility=type(v)=="table" and v[1] or v end})
    MLoad:Button({Name="Apply Loadout",Callback=function()
        pcall(function() PickWeaponsRemote:FireServer({lCfg.primary,lCfg.secondary,lCfg.melee,lCfg.utility});notify("Loadout","Applied!") end)
    end})
    MLoad:Toggle({Name="Auto Apply On Spawn",Flag="AutoLoadout",Default=false,Callback=function(_) end})

    lp.CharacterAdded:Connect(function()
        if getFlag("AutoLoadout",false) then
            task.wait(1)
            pcall(function() PickWeaponsRemote:FireServer({lCfg.primary,lCfg.secondary,lCfg.melee,lCfg.utility}) end)
        end
    end)

    MQueue:Dropdown({Name="Queue Mode",Flag="QMode",Default={"1v1"},Items=QUEUE_MODES,Multi=false,Callback=function(_) end})
    MQueue:Button({Name="Join Queue",Callback=function()
        pcall(function()
            local m=getFlag("QMode","1v1")
            QueueRemote:InvokeServer(m);notify("Queue","Joined "..m.."!")
        end)
    end})
    MQueue:Dropdown({Name="Vote Map",Flag="VMap",Default={MAPS[1]},Items=MAPS,Multi=false,Callback=function(_) end})
    MQueue:Button({Name="Vote Map",Callback=function()
        pcall(function()
            local m=getFlag("VMap",MAPS[1])
            VoteRemote:FireServer(m);notify("Vote","Voted "..m.."!")
        end)
    end})

    local autoVoteOn=false
    MQueue:Toggle({Name="Auto Vote",Flag="AutoVote",Default=false,Callback=function(v)
        autoVoteOn=false;task.wait(0.05)
        if v then
            autoVoteOn=true
            task.spawn(function()
                while autoVoteOn do
                    pcall(function() VoteRemote:FireServer(getFlag("VMap",MAPS[1])) end)
                    task.wait(2)
                end
            end)
        end
    end})

    -- ============================================================
    --   SKYBOX
    -- ============================================================

    local origSky=nil;local skyOn=false
    local function getSky() return ws.Terrain:FindFirstChildOfClass("Sky") end
    local function getAtmo() return ws.Terrain:FindFirstChildOfClass("Atmosphere") end
    local function saveSky()
        if origSky then return end;local sky=getSky();if not sky then return end
        origSky={SkyboxBk=sky.SkyboxBk,SkyboxDn=sky.SkyboxDn,SkyboxFt=sky.SkyboxFt,SkyboxLf=sky.SkyboxLf,SkyboxRt=sky.SkyboxRt,SkyboxUp=sky.SkyboxUp}
    end
    local function applySky(name)
        local data=SKYBOXES[name];if not data then return end;saveSky()
        local sky=getSky();if not sky then sky=Instance.new("Sky");sky.Parent=ws.Terrain end
        sky.SkyboxBk=data.SkyboxBk;sky.SkyboxDn=data.SkyboxDn;sky.SkyboxFt=data.SkyboxFt
        sky.SkyboxLf=data.SkyboxLf;sky.SkyboxRt=data.SkyboxRt;sky.SkyboxUp=data.SkyboxUp
        local atmo=getAtmo()
        if data.isNight then Lighting.ClockTime=0;Lighting.Ambient=Color3.fromRGB(30,30,60);if atmo then atmo.Density=0.8;atmo.Color=Color3.fromRGB(0,0,30) end
        elseif data.isSpace then Lighting.ClockTime=0;Lighting.Ambient=Color3.fromRGB(10,10,20);Lighting.Brightness=0;if atmo then atmo.Density=0 end
        else Lighting.ClockTime=14;Lighting.Ambient=Color3.fromRGB(70,70,70);Lighting.Brightness=2;if atmo then atmo.Density=0.395;atmo.Color=Color3.fromRGB(199,170,0) end end
    end
    local function restoreSky()
        if not origSky then return end;local sky=getSky();if not sky then return end
        sky.SkyboxBk=origSky.SkyboxBk;sky.SkyboxDn=origSky.SkyboxDn;sky.SkyboxFt=origSky.SkyboxFt
        sky.SkyboxLf=origSky.SkyboxLf;sky.SkyboxRt=origSky.SkyboxRt;sky.SkyboxUp=origSky.SkyboxUp;origSky=nil
    end

    SkyMain:Toggle({Name="Enable Skybox",Flag="SkyOn",Default=false,Callback=function(v)
        skyOn=v
        if v then applySky(getFlag("SkySel","Default"));notify("Skybox","Applied!")
        else restoreSky();notify("Skybox","Restored!") end
    end})
    SkyMain:Dropdown({Name="Skybox",Flag="SkySel",Default={"Default"},Items=SKYBOX_LIST,Multi=false,Callback=function(v)
        if skyOn then applySky(type(v)=="table" and v[1] or v) end
    end})
    SkyMain:Button({Name="Apply Now",Callback=function()
        if not skyOn then notify("Skybox","Enable first!",2);return end
        applySky(getFlag("SkySel","Default"));notify("Skybox","Applied!")
    end})
    SkyMain:Button({Name="Restore",Callback=function() restoreSky();notify("Skybox","Restored!") end})
    --   WATERMARK — live update via task.spawn
    --   NOT in RenderStepped — separate thread
    -- ============================================================

    local _fps=0;local _ping=0
    local _frameCount=0;local _frameTimer=tick()

    -- FPS counter on heartbeat (not renderstepped — lighter)
    RunService.Heartbeat:Connect(function()
        _frameCount+=1
        if tick()-_frameTimer>=1 then
            _fps=_frameCount;_frameTimer=tick();_frameCount=0
        end
    end)

    -- Watermark update every 0.5s — not every frame
    task.spawn(function()
        while true do
            task.wait(0.5)
            pcall(function()
                _ping=math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
            end)
            Library:Watermark({
                "Rivals Hub","v2.2",
                120959262762131,
                "FPS: ".._fps.." | Ping: ".._ping.."ms"
            })
        end
    end)

    -- ============================================================
    --   RENDERSTEPPED — Aimbot + Drawing only
    --   No task.wait / safeWait here ever
    --   Only pure math + Drawing updates
    -- ============================================================

    RunService.RenderStepped:Connect(function(dt)
        cam=ws.CurrentCamera

        -- Aimbot
        if AB.on and CameraController then
            if abDoReact then
                abReactT=abReactT-dt
                if abReactT<=0 then abDoReact=false end
            end
            if not abDoReact then
                if abTgt and not abTgtValid(abTgt) then
                    abTgt=nil;abLockT=0;abPrevPos=nil;abCurveStart=nil;abCurveProgress=0
                end
                if not abTgt then
                    abTgt=abFind()
                    if abTgt then
                        abLockT=0;abDoReact=true;abReactT=AB.reactTime/1000
                        abPrevPos=nil;abCurveStart=nil;abCurveProgress=0
                    end
                end
                if abTgt then
                    abLockT+=dt
                    if abLockT>AB.maxLock then
                        abTgt=nil;abLockT=0;abPrevPos=nil;abCurveStart=nil;abCurveProgress=0
                    elseif inFov(abTgt,abEffFov()) then
                        pcall(function()
                            local aimPos=getPredictedPos(abTgt)
                            local du=(aimPos-cam.CFrame.Position).Unit
                            local tRot=Vector2.new(math.asin(math.clamp(du.Y,-1,1)),math.atan2(-du.X,-du.Z))
                            local cur=CameraController.Rotation
                            local sp,_=cam:WorldToViewportPoint(aimPos)
                            local sd=(Vector2.new(sp.X,sp.Y)-scr()).Magnitude
                            local newRot=applySmartLock(tRot,cur,dt,sd,abEffFov())
                            CameraController:ApplyRotationDelta(Vector2.new(newRot.X-cur.X,angDiff(cur.Y,newRot.Y)))
                        end)
                    else
                        abTgt=nil;abLockT=0;abPrevPos=nil;abCurveStart=nil;abCurveProgress=0
                    end
                end
            end
        end

        -- Aimbot FOV
        if not fovCfg.visible then
            fovCircle.Visible=false;fovHalf.Visible=false;abCirc.Visible=false
        else
            local center=fovCfg.useCenter and scr() or getMouse()
            fovCircle.Visible=true;fovCircle.Color=fovCfg.color;fovCircle.Position=center
            local myRoot=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
            local orig=myRoot and myRoot.Position or cam.CFrame.Position
            fovCircle.Radius=abTgt and (isVis(orig,abTgt) and fovCfg.onTarget or fovCfg.onBarrier) or fovCfg.fovSize
            if fovCfg.half then fovHalf.Visible=true;fovHalf.Color=fovCfg.color;fovHalf.Position=center;fovHalf.Radius=fovCircle.Radius*0.5
            else fovHalf.Visible=false end
            abCirc.Position=center;abCirc.Radius=abEffFov();abCirc.Visible=AB.on
        end

        -- Silent FOV
        if not silentCfg.enabled or not silentCfg.circleVisible then
            silentCircle.Visible=false
        else
            local center=silentCfg.useCenter and scr() or getMouse()
            silentCircle.Visible=true;silentCircle.Radius=silentCfg.fovSize
            silentCircle.Thickness=silentCfg.circleThick;silentCircle.Position=center
            local myRoot=lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
            local orig=myRoot and myRoot.Position or cam.CFrame.Position
            silentCircle.Color=getSilentTarget(orig) and silentCfg.targetColor or silentCfg.circleColor
        end
    end)

    -- ============================================================
    --   INIT
    -- ============================================================


local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu")
MenuGroup:AddToggle("KeybindMenuOpen", {Default = Library.KeybindFrame.Visible, Text = "Open Keybind Menu", Callback = function(v) Library.KeybindFrame.Visible = v end})
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {Default="RightShift", NoUI=true, Text="Menu keybind"})
MenuGroup:AddButton("Unload", function() Library:Unload() end)
Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"MenuKeybind"})
ThemeManager:SetFolder("RivalsHub")
SaveManager:SetFolder("RivalsHub/configs")
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:AddThemeOptions(Tabs.Settings)
SaveManager:LoadAutoloadConfig()

notify("Rivals Hub", "v2.2 Loaded!", 5)
