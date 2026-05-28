--[[
    ZENIX LEGACY v47 - MODERN HYBRID MANAGEMENT PANELS & COMMAND SYSTEM
    Features: Core Audit, Live UI Reputation Panel, Automatic AFK Tracking, Fluid Chat Command Arrays
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- 1. INFRASTRUCTURE & ENVIRONMENT AUDIT
local executorName = identifyexecutor and identifyexecutor() or "Unknown Executor"
local requirements = {
    {name = "game:GetService", test = function() return game.GetService ~= nil end},
    {name = "RunService.RenderStepped", test = function() return RunService.RenderStepped ~= nil end},
    {name = "Drawing Library", test = function() return Drawing ~= nil and Drawing.new ~= nil end},
    {name = "Raycasting API", test = function() return workspace.Raycast ~= nil end},
    {name = "UserInputService", test = function() return UserInputService.GetMouseLocation ~= nil end},
    {name = "WorldToViewportPoint", test = function() return Camera.WorldToViewportPoint ~= nil end},
    {name = "mouse1click Simulation", test = function() return mouse1click ~= nil end},
    {name = "Instance Lifecycle API", test = function() return Instance.new ~= nil and game.Destroy ~= nil end}
}

local passedChecks = 0
local auditLog = {}
for _, check in ipairs(requirements) do
    local success, result = pcall(check.test)
    if success and result then passedChecks = passedChecks + 1; table.insert(auditLog, "  [+] " .. check.name .. ": PASSED")
    else table.insert(auditLog, "  [-] " .. check.name .. ": FAILED") end
end

print("\n" .. string.rep("=", 40))
print("ZENIX INFRASTRUCTURE REPORT v47")
print("Executor: " .. executorName .. " | Score: " .. passedChecks .. "/8")
print(string.rep("-", 40))
for _, logLine in ipairs(auditLog) do print(logLine) end
print(string.rep("=", 40) .. "\n")

if passedChecks < 8 then warn("[ZENIX FATAL]: Execution terminated due to system restrictions."); return end

-- 2. RUNTIME GLOBAL CONFIGURATIONS
local Toggles = {
    AutoShoot = false,
    VisualESP = false,
    TeamCheck = true,
    FlyEnabled = false,
    AutofarmEnabled = false,
    AutofarmMode = "Enemy",
    WeaponType = "Gun",
    NoclipEnabled = false
}

local Options = {
    AimPart = "Head",
    FovRadius = 150,
    FlySpeed = 50,
    OrbitRotationSpeed = 4,
    KnifeVerticalOffset = -5.2,
    KnifeHorizontalSlide = 1.2
}

local Binds = {
    OpenGui = Enum.KeyCode.RightControl,
    ToggleFly = Enum.KeyCode.F,
    ToggleFarm = Enum.KeyCode.X,
    AutoShoot = Enum.KeyCode.G,
    VisualESP = Enum.KeyCode.V
}

local lockedTarget = nil
local esps = {}
local playerReputation = {} -- Options: "neutral", "smart", "dumbass", "afk"
local deathTracker = {}
local currentOrbitAngle = 0
local uiVisible = true

-- Chat Action Command Variables
local flingTarget = nil
local annoyTarget = nil
local annoyAngle = 0
local bindingModuleName = nil

local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1
FOVCircle.Color = Color3.fromRGB(0, 255, 255)
FOVCircle.Visible = true
FOVCircle.Radius = Options.FovRadius

-- Helper Client Notifier
local function sendNotification(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 3.5,
            Button1 = "OK"
        })
    end)
end

-- Track Player State Shifts (Team Change / Resets Clear Reputation Flags)
local function trackPlayerLifecycle(player)
    if player == LocalPlayer then return end
    playerReputation[player.Name] = "neutral"
    
    player:GetPropertyChangedSignal("Team"):Connect(function()
        playerReputation[player.Name] = "neutral"
        sendNotification("🛡️ ZENIX ENGINE", player.Name .. " switched teams. Flag reset to Neutral.", 2.5)
    end)

    player.CharacterAdded:Connect(function(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if hum then
            hum.Died:Connect(function()
                if Toggles.AutofarmEnabled and lockedTarget == player then
                    playerReputation[player.Name] = "dumbass"
                    sendNotification("🎯 TARGET DEAD", player.Name .. " flagged as DUMBASS.", 2)
                end
            end)
        end
    end)
end

for _, p in ipairs(Players:GetPlayers()) do trackPlayerLifecycle(p) end
Players.PlayerAdded:Connect(trackPlayerLifecycle)
Players.PlayerRemoving:Connect(function(p) esps[p] = nil; playerReputation[p.Name] = nil end)

-- Handle LocalPlayer Deaths
LocalPlayer.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if hum then
        hum.Died:Connect(function()
            if Toggles.AutofarmEnabled and lockedTarget then
                local tName = lockedTarget.Name
                deathTracker[tName] = (deathTracker[tName] or 0) + 1
                if deathTracker[tName] >= 2 then
                    playerReputation[tName] = "smart"
                    sendNotification("🚫 DANGER WARNING", tName .. " flagged as SMART. Autofarm skipping.", 4)
                end
            end
            lockedTarget = nil
        end)
    end
end)

-- =========================================================================
-- [PREMIUM PANEL INTERFACE]: TABBED MASTER DASHBOARD
-- =========================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Zenix_Dashboard_v47"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 480, 0, 360)
MainFrame.Position = UDim2.new(0.3, 0, 0.25, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(32, 32, 38)
MainStroke.Thickness = 1.5
MainStroke.Parent = MainFrame

-- Top Title Banner
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -20, 1, 0)
TitleText.Position = UDim2.new(0, 15, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Font = Enum.Font.GothamBold
TitleText.Text = "ZENIX LEGACY <font color='#00ffff'>v47</font> | DASHBOARD"
TitleText.RichText = true
TitleText.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleText.TextSize = 14
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 115, 1, -40)
Sidebar.Position = UDim2.new(0, 0, 0, 40)
Sidebar.BackgroundColor3 = Color3.fromRGB(17, 17, 20)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, -130, 1, -55)
Container.Position = UDim2.new(0, 122, 0, 48)
Container.BackgroundTransparency = 1
Container.Parent = MainFrame

local pages = {}
local tabButtons = {}

local function createPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.CanvasSize = UDim2.new(0, 0, 0, 480)
    page.ScrollBarThickness = 2
    page.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 255)
    page.Visible = false
    page.Parent = Container
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page
    
    pages[name] = page
    return page
end

local combatPage = createPage("Combat")
local movementPage = createPage("Movement")
local visualsPage = createPage("Visuals")
local repPage = createPage("Reputation")
local bindPage = createPage("Binds")

local function showPage(name)
    for pName, page in pairs(pages) do page.Visible = (pName == name) end
    for bName, btn in pairs(tabButtons) do
        if bName == name then
            btn.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
            btn.TextColor3 = Color3.fromRGB(0, 255, 255)
        else
            btn.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
            btn.TextColor3 = Color3.fromRGB(150, 150, 150)
        end
    end
end

local tabY = 8
local function createTabBtn(name)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -12, 0, 30)
    btn.Position = UDim2.new(0, 6, 0, tabY)
    btn.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.Text = name
    btn.TextSize = 11
    btn.TextColor3 = Color3.fromRGB(150, 150, 150)
    btn.Parent = Sidebar
    
    local c = Instance.new("UICorner") ; c.CornerRadius = UDim.new(0, 4) ; c.Parent = btn
    btn.MouseButton1Click:Connect(function() showPage(name) end)
    tabButtons[name] = btn
    tabY = tabY + 36
end

createTabBtn("Combat")
createTabBtn("Movement")
createTabBtn("Visuals")
createTabBtn("Reputation")
createTabBtn("Binds")

-- Native UI Toggle Injection
local function createToggle(parent, labelText, noteText, defaultState, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -5, 0, 50)
    row.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
    row.BorderSizePixel = 0
    row.Parent = parent
    
    local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 4); rc.Parent = row
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.6, 0, 0, 22)
    lbl.Position = UDim2.new(0, 10, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(240, 240, 240)
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row
    
    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(0.8, 0, 0, 16)
    desc.Position = UDim2.new(0, 10, 0, 24)
    desc.BackgroundTransparency = 1
    desc.Font = Enum.Font.Gotham
    desc.Text = "↳ " .. noteText
    desc.TextColor3 = Color3.fromRGB(130, 135, 140)
    desc.TextSize = 10
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Parent = row
    
    local tBtn = Instance.new("TextButton")
    tBtn.Size = UDim2.new(0, 42, 0, 20)
    tBtn.Position = UDim2.new(1, -52, 0, 15)
    tBtn.BackgroundColor3 = defaultState and Color3.fromRGB(0, 200, 200) or Color3.fromRGB(45, 45, 50)
    tBtn.Text = ""
    tBtn.Parent = row
    
    local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(1, 0); tc.Parent = tBtn
    
    local state = defaultState
    local function updateView() tBtn.BackgroundColor3 = state and Color3.fromRGB(0, 200, 200) or Color3.fromRGB(45, 45, 50) end
    
    tBtn.MouseButton1Click:Connect(function()
        state = not state
        updateView()
        callback(state)
    end)
    
    return {
        Set = function(v) state = v; updateView(); callback(v) end
    }
end

-- Keybind Mapping Generator Function
local function createBindRow(parent, actionName, optionKey, defaultKey, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -5, 0, 46)
    row.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
    row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.6, 0, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamBold
    lbl.Text = actionName .. " Keybind"
    lbl.TextColor3 = Color3.fromRGB(230, 230, 230)
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row
    
    local bBtn = Instance.new("TextButton")
    bBtn.Size = UDim2.new(0, 70, 0, 22)
    bBtn.Position = UDim2.new(1, -80, 0, 12)
    bBtn.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
    bBtn.Font = Enum.Font.GothamBold
    bBtn.Text = defaultKey.Name
    bBtn.TextColor3 = Color3.fromRGB(0, 255, 255)
    bBtn.TextSize = 10
    bBtn.Parent = row
    Instance.new("UICorner", bBtn).CornerRadius = UDim.new(0, 4)
    
    local listening = false
    bBtn.MouseButton1Click:Connect(function() listening = true; bBtn.Text = "..."; bBtn.TextColor3 = Color3.fromRGB(255, 255, 0) end)
    UserInputService.InputBegan:Connect(function(input, proc)
        if listening and input.UserInputType == Enum.UserInputType.Keyboard then
            listening = false
            bBtn.Text = input.KeyCode.Name
            bBtn.TextColor3 = Color3.fromRGB(0, 255, 255)
            Binds[optionKey] = input.KeyCode
            if callback then callback(input.KeyCode) end
        end
    end)
end

-- Populate Feature Toggles
local togAuto, togTeam, togFarm, togFarmMode, togWeaponStyle, togFly, togEsp
togAuto = createToggle(combatPage, "Auto Shoot Engine", "Locks and runs mouse triggers against crosshair targets", false, function(v) Toggles.AutoShoot = v; if v then togFarm.Set(false) end; lockedTarget = nil end)
togTeam = createToggle(combatPage, "Team Check Filter", "Ignores friendly team players during scanning sweeps", true, function(v) Toggles.TeamCheck = v; lockedTarget = nil end)
togFarm = createToggle(combatPage, "Adaptive Autofarm", "Triggers high-velocity teleport framing sequencing", false, function(v) Toggles.AutofarmEnabled = v; if v then togAuto.Set(false); Options.AimPart = "Head" end; lockedTarget = nil end)
togFarmMode = createToggle(combatPage, "Farm Mode Filter (ON=FFA/OFF=Enemy)", "Filters selection loop targets inside map spaces", false, function(v) if v then Toggles.AutofarmMode = "FFA"; togTeam.Set(false) else Toggles.AutofarmMode = "Enemy"; togTeam.Set(true) end; lockedTarget = nil end)
togWeaponStyle = createToggle(combatPage, "Weapon Engine Mode (ON=Knife/OFF=Gun)", "Knife utilizes sliding math / Gun uses 3 stud orbit fields", false, function(v) Toggles.WeaponType = v and "Knife" or "Gun" end)
togFly = createToggle(movementPage, "Airborne Fly Mechanics", "Toggles structural movement flight features", false, function(v) Toggles.FlyEnabled = v end)
togEsp = createToggle(visualsPage, "Perimeter Render ESP", "Draws visual boundary squares through wall paths", false, function(v) 
    Toggles.VisualESP = v 
    if not v then 
        local elementsToClear = {}
        for player, objects in pairs(esps) do elementsToClear[player] = objects end
        table.clear(esps)
        for _, objects in pairs(elementsToClear) do 
            pcall(function() 
                if objects.Box then objects.Box:Remove() end 
                if objects.Label then objects.Label:Remove() end 
            end) 
        end 
    end 
end)

-- Populate Dynamic Keybind Actions
createBindRow(bindPage, "Menu Dashboard Visibility", "OpenGui", Binds.OpenGui)
createBindRow(bindPage, "Airborne Flight", "ToggleFly", Binds.ToggleFly, function(k) sendNotification("⚡ BIND UPDATE", "Flight mapped to: " .. k.Name) end)
createBindRow(bindPage, "Autofarm Core", "ToggleFarm", Binds.ToggleFarm, function(k) sendNotification("⚡ BIND UPDATE", "Autofarm mapped to: " .. k.Name) end)
createBindRow(bindPage, "Auto Shoot Engine", "AutoShoot", Binds.AutoShoot, function(k) sendNotification("⚡ BIND UPDATE", "Auto Shoot mapped to: " .. k.Name) end)
createBindRow(bindPage, "Visual ESP Engine", "VisualESP", Binds.VisualESP, function(k) sendNotification("⚡ BIND UPDATE", "ESP mapped to: " .. k.Name) end)

-- =========================================================================
-- [REPUTATION UI MANAGEMENT PANEL ENGINE]
-- =========================================================================
local function reloadReputationPanel()
    for _, item in ipairs(repPage:GetChildren()) do if item:IsA("Frame") then item:Destroy() end end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, -5, 0, 42)
            row.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
            row.Parent = repPage
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)
            
            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size = UDim2.new(0.4, 0, 1, 0)
            nameLbl.Position = UDim2.new(0, 8, 0, 0)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Font = Enum.Font.GothamBold
            nameLbl.Text = player.DisplayName .. " (@" .. player.Name .. ")"
            nameLbl.TextColor3 = Color3.fromRGB(240, 240, 240)
            nameLbl.TextSize = 10
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.Parent = row
            
            local btnContainer = Instance.new("Frame")
            btnContainer.Size = UDim2.new(0.6, -10, 0, 24)
            btnContainer.Position = UDim2.new(0.4, 5, 0, 9)
            btnContainer.BackgroundTransparency = 1
            btnContainer.Parent = row
            
            local btnLayout = Instance.new("UIListLayout")
            btnLayout.FillDirection = Enum.FillDirection.Horizontal
            btnLayout.Padding = UDim.new(0, 4)
            btnLayout.SortOrder = Enum.SortOrder.LayoutOrder
            btnLayout.Parent = btnContainer
            
            local states = {"Neutral", "Smart", "Dumbass", "AFK"}
            local stateColors = {
                Neutral = Color3.fromRGB(70, 70, 75),
                Smart = Color3.fromRGB(200, 50, 50),
                Dumbass = Color3.fromRGB(50, 180, 50),
                AFK = Color3.fromRGB(180, 180, 50)
            }
            
            for _, sName in ipairs(states) do
                local sBtn = Instance.new("TextButton")
                sBtn.Size = UDim2.new(0, 48, 1, 0)
                sBtn.Font = Enum.Font.GothamBold
                sBtn.Text = sName
                sBtn.TextSize = 9
                sBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                sBtn.Parent = btnContainer
                Instance.new("UICorner", sBtn).CornerRadius = UDim.new(0, 3)
                
                local function refreshButtonColor()
                    local current = playerReputation[player.Name] or "neutral"
                    if current == sName:lower() then
                        sBtn.BackgroundColor3 = stateColors[sName]
                        sBtn.BackgroundTransparency = 0
                    else
                        sBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
                        sBtn.BackgroundTransparency = 0.4
                    end
                end
                
                refreshButtonColor()
                sBtn.MouseButton1Click:Connect(function()
                    playerReputation[player.Name] = sName:lower()
                    sendNotification("🛡️ REPUTATION SYSTEM", player.Name .. " manually set to " .. sName:upper(), 2)
                    for _, b in ipairs(btnContainer:GetChildren()) do
                        if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(35, 35, 40); b.BackgroundTransparency = 0.4 end
                    end
                    sBtn.BackgroundColor3 = stateColors[sName]
                    sBtn.BackgroundTransparency = 0
                    if player == lockedTarget and (sName == "Smart" or sName == "AFK") then lockedTarget = nil end
                end)
            end
        end
    end
end

repPage:GetPropertyChangedSignal("Visible"):Connect(function() if repPage.Visible then reloadReputationPanel() end end)
Players.PlayerAdded:Connect(function() if repPage.Visible then task.wait(0.5); reloadReputationPanel() end end)
Players.PlayerRemoving:Connect(function() if repPage.Visible then task.wait(0.5); reloadReputationPanel() end end)

showPage("Combat")

-- =========================================================================
-- [CORE INTEGRATED CHAT PROCESSING MATRIX & COMMAND ARRAYS]
-- =========================================================================
local function runTargetStringLookup(searchStr)
    local found = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower():sub(1, #searchStr) == searchStr:lower() or p.DisplayName:lower():sub(1, #searchStr) == searchStr:lower() then
            table.insert(found, p)
        end
    end
    return found[1]
end

local function executeUniversalCommand(inputMsg)
    local tokens = {}
    for word in string.gmatch(inputMsg, "%S+") do table.insert(tokens, word) end
    if #tokens == 0 then return end
    
    local cmd = tokens[1]:lower()
    
    if cmd == "/flag" and #tokens >= 3 then
        local target = runTargetStringLookup(tokens[2])
        local targetFlag = tokens[3]:lower()
        if target and (targetFlag == "smart" or targetFlag == "dumbass" or targetFlag == "afk" or targetFlag == "neutral") then
            playerReputation[target.Name] = targetFlag
            sendNotification("🛡️ CHAT SYSTEM", "Set " .. target.Name .. " flag status to -> " .. targetFlag:upper(), 3)
            if repPage.Visible then reloadReputationPanel() end
        end

    elseif cmd == "/panel" then
        local CommandPanel = Instance.new("ScreenGui")
        CommandPanel.Name = "CmdPanel"
        CommandPanel.Parent = LocalPlayer:WaitForChild("PlayerGui")
        
        local Frame = Instance.new("Frame", CommandPanel)
        Frame.Size = UDim2.new(0, 200, 0, 250)
        Frame.Position = UDim2.new(0.5, -100, 0.5, -125)
        Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        Frame.Active = true
        Frame.Draggable = true
        
        local cmds = {"/noclip", "/fling", "/annoy", "/bind"}
        for i, v in ipairs(cmds) do
            local btn = Instance.new("TextButton", Frame)
            btn.Size = UDim2.new(1, -10, 0, 30)
            btn.Position = UDim2.new(0, 5, 0, (i-1) * 35 + 5)
            btn.Text = v
            btn.TextColor3 = Color3.new(1,1,1)
            btn.BackgroundColor3 = Color3.fromRGB(50,50,50)
            btn.MouseButton1Click:Connect(function() 
                sendNotification("CMD", "Executing: " .. v, 2)
            end)
        end
        
        local close = Instance.new("TextButton", Frame)
        close.Size = UDim2.new(1, 0, 0, 20)
        close.Position = UDim2.new(0, 0, 1, -20)
        close.Text = "CLOSE"
        close.MouseButton1Click:Connect(function() CommandPanel:Destroy() end)
    
    elseif cmd == "/noclip" then
        Toggles.NoclipEnabled = not Toggles.NoclipEnabled
        sendNotification("🚀 PHYSICS ENGINE", "Noclip bounds modified. Active status: " .. tostring(Toggles.NoclipEnabled):upper(), 3)
    
    elseif cmd == "/fling" and #tokens >= 2 then
        local target = runTargetStringLookup(tokens[2])
        if target then
            flingTarget = target
            sendNotification("⚡ KINETIC SLAM", "Engaging torque kinetic fly vectors targeting: " .. target.Name, 3)
        end
        
    elseif cmd == "/annoy" and #tokens >= 2 then
        local target = runTargetStringLookup(tokens[2])
        if target then
            annoyTarget = target
            sendNotification("🔄 VECTOR ANNOY", "Running safe proximity distance orbit cycles around: " .. target.Name, 3)
        end
        
    elseif cmd == "/bind" and #tokens >= 2 then
        local searchModule = tokens[2]:lower()
        if searchModule == "flight" or searchModule == "fly" then bindingModuleName = "ToggleFly"
        elseif searchModule == "autofarm" or searchModule == "farm" then bindingModuleName = "ToggleFarm"
        elseif searchModule == "autoshoot" or searchModule == "shoot" then bindingModuleName = "AutoShoot"
        elseif searchModule == "esp" or searchModule == "visuals" then bindingModuleName = "VisualESP" end
        
        if bindingModuleName then
            sendNotification("⚡ INPUT CONTROLLER", "Press any keyboard button key to map module: " .. searchModule:upper(), 4)
            local listenConnection
            listenConnection = UserInputService.InputBegan:Connect(function(input, processed)
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    listenConnection:Disconnect()
                    Binds[bindingModuleName] = input.KeyCode
                    sendNotification("⚡ BIND SET", searchModule:upper() .. " bound successfully to key: " .. input.KeyCode.Name, 3)
                    bindingModuleName = nil
                end
            end)
        else
            sendNotification("🚫 BIND ERROR", "Module identity tag not found.", 2.5)
        end
        
    elseif cmd == "/ad" or cmd == "/advertisement" then
        task.spawn(function()
            for i = 1, 2 do
                local sayText = "made by dat bugfixes by gemini huge W to gemini for helping me"
                if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
                    local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
                    if channel then channel:SendAsync(sayText) end
                else
                    pcall(function() game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(sayText, "All") end)
                end
                sendNotification("💬 BROADCASTER", "Dispatched script global ad cycle: " .. i .. "/2", 2)
                if i < 2 then task.wait(3) end
            end
        end)
        
    elseif cmd == "/notifier" and #tokens >= 2 then
        local parsedMessage = string.sub(inputMsg, 10)
        sendNotification("🔔 CLIENT ALERT", parsedMessage, 4)
    end
end

-- Hook Legacy and Modern Text Systems For Processing Commands
if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
    TextChatService.SendingMessage:Connect(function(textMsg)
        if textMsg.Text:sub(1,1) == "/" then executeUniversalCommand(textMsg.Text) end
    end)
else
    LocalPlayer.Chatted:Connect(function(msg)
        if msg:sub(1,1) == "/" then executeUniversalCommand(msg) end
    end)
end

-- =========================================================================
-- [MATH CORE, DRAWING ENGINE UTILITIES & RUNTIME PROCESSING PIPELINE]
-- =========================================================================
local function isGodMode(player) return player.Character and player.Character:FindFirstChildOfClass("ForceField") ~= nil end
local function isVisible(targetPart)
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin)
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character, targetPart.Parent}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    return workspace:Raycast(origin, direction.Unit * direction.Magnitude, rayParams) == nil
end

UserInputService.InputBegan:Connect(function(input, proc)
    if proc then return end
    if input.KeyCode == Binds.OpenGui then uiVisible = not uiVisible; MainFrame.Visible = uiVisible
    elseif input.KeyCode == Binds.ToggleFly then togFly.Set(not Toggles.FlyEnabled)
    elseif input.KeyCode == Binds.ToggleFarm then togFarm.Set(not Toggles.AutofarmEnabled)
    elseif input.KeyCode == Binds.AutoShoot then togAuto.Set(not Toggles.AutoShoot)
    elseif input.KeyCode == Binds.VisualESP then togEsp.Set(not Toggles.VisualESP) end
end)

RunService.RenderStepped:Connect(function()
    FOVCircle.Position = UserInputService:GetMouseLocation()
    local character = LocalPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    
    -- --- NOCLIP SUBSYSTEM ENGINE ---
    if Toggles.NoclipEnabled and character then
        for _, part in ipairs(character:GetChildren()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
    
    -- --- ACTIVE FLING KINETIC SIMULATION MATRIX ---
    if flingTarget and flingTarget.Character and flingTarget.Character:FindFirstChild("HumanoidRootPart") and rootPart and humanoid then
        local fHrp = flingTarget.Character.HumanoidRootPart
        if flingTarget.Character:FindFirstChildOfClass("Humanoid") and flingTarget.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            rootPart.CFrame = fHrp.CFrame * CFrame.new(0, 0, 0)
            -- Apply unstable physics speeds to trigger target joint detachment
            rootPart.Velocity = Vector3.new(99999, 99999, 99999)
            if tick() % 0.2 < 0.1 then
                rootPart.RotVelocity = Vector3.new(0, 99999, 0)
            else
                rootPart.RotVelocity = Vector3.new(99999, 0, 99999)
            end
            return -- Override other position loops while fling is running
        else
            flingTarget = nil
            rootPart.Velocity = Vector3.new(0,0,0)
            rootPart.RotVelocity = Vector3.new(0,0,0)
            sendNotification("⚡ FLING SYSTEM", "Target cleared or eliminated.", 2.5)
        end
    end

    -- --- ANNOY HIGH SPEED ORBIT MATRIX ---
    if annoyTarget and annoyTarget.Character and annoyTarget.Character:FindFirstChild("HumanoidRootPart") and rootPart then
        local aHrp = annoyTarget.Character.HumanoidRootPart
        if annoyTarget.Character:FindFirstChildOfClass("Humanoid") and annoyTarget.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            annoyAngle = annoyAngle + 0.35 -- Extreme step acceleration speed
            local radDist = 18 -- Out of common weapon hitbox reach distance
            local offX = math.cos(annoyAngle) * radDist
            local offZ = math.sin(annoyAngle) * radDist
            rootPart.CFrame = CFrame.new(aHrp.Position + Vector3.new(offX, 4, offZ), aHrp.Position)
            rootPart.Velocity = Vector3.new(0,0,0)
            return
        else
            annoyTarget = nil
            sendNotification("🔄 ANNOY SYSTEM", "Annoy victim eliminated or unavailable.", 2.5)
        end
    end

    -- --- AIRBORNE FLIGHT ENGINE MECHANICS ---
    if Toggles.FlyEnabled and rootPart then
        local flyDirection = Vector3.new(0, 0, 0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then flyDirection = flyDirection + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then flyDirection = flyDirection - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then flyDirection = flyDirection - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then flyDirection = flyDirection + Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then flyDirection = flyDirection + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then flyDirection = flyDirection - Vector3.new(0, 1, 0) end
        rootPart.Velocity = flyDirection.Unit * Options.FlySpeed
        if flyDirection == Vector3.new(0, 0, 0) then rootPart.Velocity = Vector3.new(0, 0, 0) end
    end

    -- --- ESP CORE RENDER PIPELINE ---
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local isTeammate = Toggles.TeamCheck and (player.Team == LocalPlayer.Team)
            if not isTeammate and Toggles.VisualESP then
                local pHrp = player.Character:FindFirstChild("HumanoidRootPart")
                local pHum = player.Character:FindFirstChildOfClass("Humanoid")
                if pHrp and pHum and pHum.Health > 0 then
                    if not esps[player] then
                        local box = Drawing.new("Square"); box.Thickness = 1; box.Filled = false; box.Color = Color3.fromRGB(0, 255, 255)
                        local label = Drawing.new("Text"); label.Size = 12; label.Center = true; label.Outline = true; label.Color = Color3.fromRGB(255, 255, 255)
                        esps[player] = {Box = box, Label = label}
                    end
                    local pos, onScreen = Camera:WorldToViewportPoint(pHrp.Position)
                    local espObj = esps[player]
                    if onScreen then
                        local scale = (1 / pos.Z) * 1000
                        espObj.Box.Visible, espObj.Label.Visible = true, true
                        espObj.Box.Size = Vector2.new(scale * 0.5, scale * 0.7)
                        espObj.Box.Position = Vector2.new(pos.X - espObj.Box.Size.X / 2, pos.Y - espObj.Box.Size.Y / 2)
                        
                        local rStatus = playerReputation[player.Name] or "neutral"
                        local statusLabel = rStatus ~= "neutral" and " [" .. rStatus:upper() .. "]" or ""
                        espObj.Label.Text = player.Name .. statusLabel .. " [" .. math.floor(pHum.Health) .. "]"
                        espObj.Label.Position = Vector2.new(pos.X, pos.Y + (espObj.Box.Size.Y / 2) + 4)
                        espObj.Box.Color = isVisible(pHrp) and Color3.fromRGB(0, 255, 255) or Color3.fromRGB(255, 140, 0)
                    else espObj.Box.Visible, espObj.Label.Visible = false, false end
                elseif esps[player] then pcall(function() esps[player].Box:Remove(); esps[player].Label:Remove() end); esps[player] = nil end
            elseif esps[player] then pcall(function() esps[player].Box:Remove(); esps[player].Label:Remove() end); esps[player] = nil end
        end
    end

    -- --- DYNAMIC SCANNER SEEKER & TELEPORT TARGET LOCK CONTROLLER ---
    if Toggles.AutoShoot or Toggles.AutofarmEnabled then
        local activeRep = lockedTarget and playerReputation[lockedTarget.Name] or "neutral"
        local dropTarget = false

        if lockedTarget then
            local tChar = lockedTarget.Character
            local tHum = tChar and tChar:FindFirstChildOfClass("Humanoid")
            local tPart = tChar and tChar:FindFirstChild(Options.AimPart)
            -- Drop target immediately if target is dead, flagged Smart, or manually flagged AFK
            if not (tChar and tHum and tPart and tHum.Health > 0 and activeRep ~= "smart" and activeRep ~= "afk" and not isGodMode(lockedTarget)) then dropTarget = true
            elseif not Toggles.AutofarmEnabled and not isVisible(tPart) then dropTarget = true end
        else dropTarget = true end

        if dropTarget then
            lockedTarget = nil
            local shortest = Options.FovRadius
            local bestTarget = nil
            local highestWeight = -1
            
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild(Options.AimPart) and p.Character:FindFirstChildOfClass("Humanoid") then
                    local isTeammate = Toggles.TeamCheck and (p.Team == LocalPlayer.Team)
                    local repStatus = playerReputation[p.Name] or "neutral"
                    
                    -- ABSOLUTE BLOCK: Never target anyone flagged Smart or AFK
                    if not isTeammate and not isGodMode(p) and p.Character:FindFirstChildOfClass("Humanoid").Health > 0 and repStatus ~= "smart" and repStatus ~= "afk" then
                        local part = p.Character[Options.AimPart]
                        local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
                        local dist = (Vector2.new(pos.X, pos.Y) - UserInputService:GetMouseLocation()).Magnitude
                        
                        local weight = 1
                        if repStatus == "dumbass" then weight = 2 end
                        
                        if Toggles.AutofarmEnabled then
                            if weight > highestWeight then highestWeight = weight; bestTarget = p
                            elseif weight == highestWeight and bestTarget then
                                local cHrp = bestTarget.Character:FindFirstChild("HumanoidRootPart")
                                local checkHrp = p.Character:FindFirstChild("HumanoidRootPart")
                                if cHrp and checkHrp and rootPart then
                                    if (checkHrp.Position - rootPart.Position).Magnitude < (cHrp.Position - rootPart.Position).Magnitude then bestTarget = p end
                                end
                            end
                        elseif onScreen and dist < shortest and isVisible(part) then shortest = dist; bestTarget = p end
                    end
                end
            end
            lockedTarget = bestTarget
        end

        -- --- POSITIONAL VECTOR TRANSLATION ENGINE ---
        if lockedTarget and lockedTarget.Character and lockedTarget.Character:FindFirstChild(Options.AimPart) then
            local targetPos = lockedTarget.Character[Options.AimPart].Position
            local targetHrp = lockedTarget.Character:FindFirstChild("HumanoidRootPart")
            
            if Toggles.AutofarmEnabled and rootPart and targetHrp then
                if Toggles.WeaponType == "Knife" then
                    local tVel = targetHrp.Velocity
                    local fProj = targetHrp.CFrame.LookVector * Options.KnifeHorizontalSlide
                    if tVel.Magnitude > 1 then fProj = fProj + (tVel.Unit * 0.5) end
                    
                    rootPart.CFrame = CFrame.new(targetHrp.Position + fProj + Vector3.new(0, Options.KnifeVerticalOffset, 0), Vector3.new(targetPos.X, rootPart.Position.Y, targetPos.Z))
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
                else
                    currentOrbitAngle = currentOrbitAngle + math.rad(Options.OrbitRotationSpeed)
                    local offX = math.cos(currentOrbitAngle) * 3
                    local offZ = math.sin(currentOrbitAngle) * 3
                    
                    rootPart.CFrame = CFrame.new(targetHrp.Position + Vector3.new(offX, 1.5, offZ))
                    rootPart.Velocity = Vector3.new(0,0,0)
                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
                end
            elseif Toggles.AutoShoot then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
                if mouse1click then mouse1click() end
            end
        end
    end
end)