-- ==========================================
-- TYCOON HUB - MATERIAL UI (TOGGLE ADDED)
-- ==========================================
local Material = loadstring(game:HttpGet("https://raw.githubusercontent.com/Kinlei/MaterialLua/master/Module.lua"))()

local UI = Material.Load({
    Title = "Tycoon Hub Premium V3",
    Style = 1,
    SizeX = 400,
    SizeY = 450,
    Theme = "Dark",
    ColorOverrides = {
        Main = Color3.fromRGB(47, 134, 233)
    }
})

-- State Configuration Flags
local Flags = {
    AutoFarmAll = false,
    LemonDashUpgrade = false,
    WakeIncome = false,
    LemonStandUpgrade = false,
    PhoneOffer = false,
    DashManager = false,
    WalkSpeedTweak = false
}

-- Safe Path Target
local function getTycoonPath()
    return workspace:FindFirstChild("Tycoon2")
end

-- ==========================================
-- PACKET EXECUTOR ENGINE (0.05s Loop)
-- ==========================================
task.spawn(function()
    while true do
        local Tycoon = getTycoonPath()
        if Tycoon then
            local purchases = Tycoon:FindFirstChild("Purchases")
            local remotes = Tycoon:FindFirstChild("Remotes")

            -- 1. Lemon Dash Upgrade
            if Flags.LemonDashUpgrade or Flags.AutoFarmAll then
                if purchases and purchases:FindFirstChild("LemonDash") then
                    local ev = purchases.LemonDash:FindFirstChild("LemonDash") and purchases.LemonDash.LemonDash:FindFirstChild("LemonDash") and purchases.LemonDash.LemonDash.LemonDash:FindFirstChild("Upgrade")
                    if ev then task.spawn(function() ev:InvokeServer(1) end) end
                end
            end

            -- 2. Wake Income Stream
            if Flags.WakeIncome or Flags.AutoFarmAll then
                if remotes and remotes:FindFirstChild("WakeIncomeStream") then
                    task.spawn(function() remotes.WakeIncomeStream:InvokeServer("LemonDash") end)
                end
            end

            -- 3. Lemon Stand Upgrade
            if Flags.LemonStandUpgrade or Flags.AutoFarmAll then
                if purchases and purchases:FindFirstChild("Lemon Stand") then
                    local ev = purchases["Lemon Stand"]:FindFirstChild("Lemon Stand") and purchases["Lemon Stand"]["Lemon Stand"]:FindFirstChild("Lemon Stand") and purchases["Lemon Stand"]["Lemon Stand"]["Lemon Stand"]:FindFirstChild("Upgrade")
                    if ev then task.spawn(function() ev:InvokeServer(1) end) end
                end
            end

            -- 4. Phone Offer Accept
            if Flags.PhoneOffer or Flags.AutoFarmAll then
                if remotes and remotes:FindFirstChild("PhoneOffer") then
                    task.spawn(function() remotes.PhoneOffer:FireServer("Accept") end)
                end
            end

            -- 5. Dash Manager Purchase
            if Flags.DashManager or Flags.AutoFarmAll then
                if purchases and purchases:FindFirstChild("LemonDash") then
                    local buttons = purchases.LemonDash:FindFirstChild("Buttons")
                    local other = buttons and buttons:FindFirstChild("Other")
                    local manager = other and other:FindFirstChild("Dash Manager")
                    local ev = manager and manager:FindFirstChild("Purchase")
                    if ev then task.spawn(function() ev:InvokeServer(false) end) end
                end
            end
        end
        task.wait(0.05)
    end
end)

-- ==========================================
-- LOCAL PLAYER MODS & PERFORMANCE
-- ==========================================
local function BoostFPS()
    local Terrain = workspace:FindFirstChildOfClass("Terrain")
    if Terrain then
        Terrain.WaterWaveSize = 0 Terrain.WaterWaveSpeed = 0
        Terrain.WaterReflectance = 0 Terrain.WaterTransparency = 0
    end
    game:GetService("Lighting").GlobalShadows = false
    
    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") and not v:IsA("MeshPart") then
            v.Material = Enum.Material.SmoothPlastic
        elseif v:IsA("Texture") or v:IsA("Decal") then
            v:Destroy()
        elseif v:IsA("ParticleEmitter") or v:IsA("Trail") then
            v.Enabled = false
        end
    end
end

task.spawn(function()
    local LocalPlayer = game:GetService("Players").LocalPlayer
    while true do
        if Flags.WalkSpeedTweak and LocalPlayer.Character then
            local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 100 end
        end
        task.wait(0.5)
    end
end)

-- ==========================================
-- UI TABS & CONTROLS
-- ==========================================
local MainTab = UI.New({ Title = "Main Automation" })
local PlayerTab = UI.New({ Title = "Player & Visuals" })

-- Master Controls
MainTab.Toggle({
    Text = "Master Auto-Farm All Packets",
    Callback = function(state)
        Flags.AutoFarmAll = state
    end,
    Enabled = false
})

-- Individual Packet Splits
MainTab.Toggle({
    Text = "Auto Upgrade Lemon Dash",
    Callback = function(state) Flags.LemonDashUpgrade = state end,
    Enabled = false
})

MainTab.Toggle({
    Text = "Auto Wake Income Stream",
    Callback = function(state) Flags.WakeIncome = state end,
    Enabled = false
})

MainTab.Toggle({
    Text = "Auto Upgrade Lemon Stand",
    Callback = function(state) Flags.LemonStandUpgrade = state end,
    Enabled = false
})

MainTab.Toggle({
    Text = "Auto Accept Phone Offers",
    Callback = function(state) Flags.PhoneOffer = state end,
    Enabled = false
})

MainTab.Toggle({
    Text = "Auto Purchase Dash Manager",
    Callback = function(state) Flags.DashManager = state end,
    Enabled = false
})

-- Player Adjustments
PlayerTab.Toggle({
    Text = "Insane WalkSpeed (100)",
    Callback = function(state) Flags.WalkSpeedTweak = state end,
    Enabled = false
})

PlayerTab.Button({
    Text = "Run FPS Booster Engine",
    Callback = function()
        BoostFPS()
    end
})

-- ==========================================
-- GLOBAL KEYBOARD TOGGLE (LEFT CTRL)
-- ==========================================
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local uiVisible = true

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.LeftControl then
        -- Locate the Material UI Core ScreenGui container
        local targetGui = CoreGui:FindFirstChild("Tycoon Hub Premium V3") or CoreGui:FindFirstChild("Material")
        
        if targetGui then
            uiVisible = not uiVisible
            targetGui.Enabled = uiVisible
        end
    end
end)