--==============================================================
--  🍋 SELL LEMONS — AUTO FARM  (Fluent UI Remaster)
--==============================================================
local RS = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

-- Load Fluent UI Library
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Sell Lemons Farm 🍋",
    SubTitle = "by Dat859",
    TabWidth = 160,
    Size = UDim2.new(0, 580, 0, 460),
    Acrylic = true, -- Blur effect background
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- Game Module Fetchers
local function req(p) local ok,m=pcall(require,p) return ok and m or nil end
local Tycoon                = req(RS.Modules.Tycoon.Tycoon)
local TycoonBalances        = req(RS.Modules.Tycoon.Component.TycoonBalances)
local ClientTycoonBalances  = req(RS.Modules.Tycoon.Component.Client.ClientTycoonBalances)
local ClientTycoonRebirth   = req(RS.Modules.Tycoon.Component.Client.ClientTycoonRebirth)
local ClientTycoonAscension = req(RS.Modules.Tycoon.Component.Client.ClientTycoonAscension)
local ClientTycoonEvolution = req(RS.Modules.Tycoon.Component.Client.ClientTycoonEvolution)
local ClientTycoonPowers    = req(RS.Modules.Tycoon.Component.Client.ClientTycoonPowers)
local ClientTycoonPhoneOffers=req(RS.Modules.Tycoon.Component.Client.ClientTycoonPhoneOffers)
local RemoteSignal          = req(RS.Core.RemoteSignal)
local RemoteRequest         = req(RS.Core.RemoteRequest)
local Entity                = req(RS.Core.Entity)
local Huge                  = req(RS.Modules.Huge)
local Config                = req(RS.Config)

-- Core Configurations State
local State = {
    AutoBuy = false, AutoUpgradeEarners = false, AutoUpgradePowers = false,
    AutoWake = false, AutoCashDrop = false, AutoPhone = false, AutoFruit = false,
    AutoRebirth = false, AutoEvolve = false, AutoAscend = false,
    AntiAFK = false, SpeedOn = false, SpeedVal = 16,
}

local function getTycoon() return Tycoon and Tycoon.getLocal() end
local function afford(price,cur) local ok,r=pcall(function() return price~=nil and price<=cur end) return ok and r end

local _root,_buy,_earn=nil,{},{}
local function refreshCaches(t)
    if not t or not t.Instance then return end
    if _root==t.Instance and #_buy>0 then return end
    _root,_buy,_earn=t.Instance,{},{}
    for _,i in CollectionService:GetTagged("Tycoon.Purchase") do if i:IsDescendantOf(_root) then table.insert(_buy,i) end end
    for _,i in CollectionService:GetTagged("Tycoon.Earner") do if i:IsDescendantOf(_root) then table.insert(_earn,i) end end
end

-- Farm Logic Routines
local function doAutoBuy(t)
    local bal=t:GetComponent(TycoonBalances); if not bal then return end
    for _,inst in _buy do
        if not State.AutoBuy then return end
        if inst:GetAttribute("Shown") and not inst:GetAttribute("Purchased") then
            local e=Entity.getUnsafe(inst)
            if e and not e.Special then
                local okp,price=pcall(function() return e:GetPrice() end)
                if okp and afford(price,bal:GetCash()) then pcall(function() e:TryPurchaseAsync(false) end) end
            end
        end
    end
end

local function doUpgradeEarners(t)
    local bal=t:GetComponent(TycoonBalances); if not bal then return end
    for _,inst in _earn do
        if not State.AutoUpgradeEarners then return end
        local e=Entity.getUnsafe(inst)
        if e then
            local okl,lvl=pcall(function() return e:GetUpgradeLevel() end)
            if okl then
                local ok,price,count=pcall(function() return e:GetUpgradePrice(lvl, math.huge, bal:GetCash()) end)
                if ok and count and count>0 then pcall(function() e:UpgradeAsync(count) end) end
            end
        end
    end
end

local function doUpgradePowers(t)
    local bal=t:GetComponent(ClientTycoonBalances); if not bal then return end
    local pw=t:GetComponent(ClientTycoonPowers); if not (pw and Config) then return end
    for name in pairs(Config.Powers) do
        if not State.AutoUpgradePowers then return end
        local okl,lvl=pcall(function() return pw:GetLevel(name) end)
        local okm,maxl=pcall(function() return pw:GetMaxLevel(name) end)
        if okl and okm and maxl and lvl<maxl then
            local okp,price=pcall(function() return pw:GetUpgradePrice(name) end)
            local oki,inv=pcall(function() return bal:GetInvestors() end)
            if okp and price and oki and afford(price,inv) then pcall(function() pw:UpgradeAsync(name) end) end
        end
    end
end

local function doWake(t)
    for _,inst in _earn do
        if not State.AutoWake then return end
        local e=Entity.getUnsafe(inst)
        if e and e.WakeAsync then pcall(function() e:WakeAsync() end) end
    end
end

local _phoneCd=0
local function doPhone(t)
    if os.clock()<_phoneCd then return end
    local po=t:GetComponent(ClientTycoonPhoneOffers); if not po then return end
    local ok,offer=pcall(function() return po:GetCurrentOffer() end)
    if ok and type(offer)=="number" then pcall(function() po:AcceptOffer() end) _phoneCd=os.clock()+1.5 end
end

local function tryRebirth(t)
    local rb=t:GetComponent(ClientTycoonRebirth); if not rb then return end
    local ok,pot=pcall(function() return rb:GetPotentialInvestors() end); if not ok then return end
    local cok,ready=pcall(function() return Huge.one<pot end)
    if cok and ready then pcall(function() rb:RebirthAsync(false) end) end
end

local function tryEvolve(t)
    local ev=t:GetComponent(ClientTycoonEvolution); if not ev then return end
    local ok,p=pcall(function() return ev:GetEvolutionProgress() end)
    if ok and type(p)=="number" and p>=1 then pcall(function() ev:EvolveAsync() end) end
end

local function tryAscend(t)
    local a=t:GetComponent(ClientTycoonAscension); if not a then return end
    local okd,d=pcall(function() return a:IsDiscovered() end); if not(okd and d) then return end
    local ok,p=pcall(function() return a:GetAscension() end)
    if ok and type(p)=="number" and p>=1 then pcall(function() a:AscendAsync() end) end
end

-- Cash drop intercept hook
do
    local ok,redeem=pcall(function() return RemoteRequest.new("CashDropService.Redeem") end)
    local ok2,newSig=pcall(function() return RemoteSignal.new("CashDropService.New") end)
    if ok and ok2 and redeem and newSig then
        newSig.OnClientEvent:Connect(function(id) if State.AutoCashDrop and id~=nil then pcall(function() redeem:InvokeServer(id) end) end end)
    end
end

-- Anti-AFK Method
do local vu=game:GetService("VirtualUser")
    LP.Idled:Connect(function() if State.AntiAFK then pcall(function() vu:CaptureController() vu:ClickButton2(Vector2.new()) end) end end)
end

-- Heartbeat Walkspeed Lock
RunService.Heartbeat:Connect(function()
    if State.SpeedOn then local c=LP.Character local h=c and c:FindFirstChildOfClass("Humanoid")
        if h and h.WalkSpeed~=State.SpeedVal then h.WalkSpeed=State.SpeedVal end end
end)

-- Orchard Auto-Fruit Loop
local _fruit,_savedCF={},nil
local function gatherFruit()
    _fruit={}
    local myT=getTycoon() and getTycoon().Instance
    for _,d in workspace:GetDescendants() do
        if d:IsA("BasePart") and d.Name=="ClickPart" and d.Parent and d.Parent.Name=="Fruit" then
            local a=d while a.Parent and a.Parent~=workspace do a=a.Parent end
            local mine=(a.Name=="LemonTree") or (myT and d:IsDescendantOf(myT))
            if mine then local cd=d:FindFirstChildOfClass("ClickDetector") if cd then table.insert(_fruit,{part=d,cd=cd}) end end
        end
    end
end

task.spawn(function()
    local idx=1
    while true do
        if State.AutoFruit then
            local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if not _savedCF and hrp then _savedCF=hrp.CFrame gatherFruit() idx=1 end
            if hrp and #_fruit>0 then
                local f=_fruit[idx]
                if f and f.part and f.part.Parent then
                    hrp.CFrame=CFrame.new(f.part.Position+Vector3.new(0,4,0))
                    task.wait(0.1)
                    local o=hrp.Position
                    for _,g in _fruit do
                        if g.part and g.part.Parent and (g.part.Position-o).Magnitude<=g.cd.MaxActivationDistance then
                            pcall(function() fireclickdetector(g.cd) end)
                        end
                    end
                end
                idx=idx+8 if idx>#_fruit then idx=1 end
            end
            task.wait(0.05)
        else
            if _savedCF then local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                if hrp then pcall(function() hrp.CFrame=_savedCF end) end _savedCF=nil end
            task.wait(0.2)
        end
    end
end)

--========================= FLUENT TABS SETUP =========================
local Tabs = {
    Stats   = Window:AddTab({ Title = "Statistics", Icon = "bar-chart-2" }),
    Main    = Window:AddTab({ Title = "Auto Farm", Icon = "combine" }),
    Prog    = Window:AddTab({ Title = "Progression", Icon = "trending-up" }),
    Utility = Window:AddTab({ Title = "Utility", Icon = "settings" })
}

-- 1. STATISTICS TAB
local CashParagraph = Tabs.Stats:AddParagraph({ Title = "Cash Available", Content = "Connecting..." })
local InvestorsParagraph = Tabs.Stats:AddParagraph({ Title = "Total Investors", Content = "Connecting..." })
local RebirthsParagraph = Tabs.Stats:AddParagraph({ Title = "Total Rebirths", Content = "Connecting..." })
local EvolutionParagraph = Tabs.Stats:AddParagraph({ Title = "Evolution Progress", Content = "Connecting..." })

-- 2. AUTO FARM TAB
Tabs.Main:AddToggle("AutoBuy", {Title = "Auto Buy Tiles", Default = false, Callback = function(Value) State.AutoBuy = Value end})
Tabs.Main:AddToggle("AutoUpgradeEarners", {Title = "Auto Upgrade Earners", Default = false, Callback = function(Value) State.AutoUpgradeEarners = Value end})
Tabs.Main:AddToggle("AutoUpgradePowers", {Title = "Auto Upgrade Powers", Default = false, Callback = function(Value) State.AutoUpgradePowers = Value end})
Tabs.Main:AddToggle("AutoFruit", {Title = "Auto Collect Fruit (Orchard Teleport)", Default = false, Callback = function(Value) State.AutoFruit = Value end})
Tabs.Main:AddToggle("AutoWake", {Title = "Auto Wake Earners", Default = false, Callback = function(Value) State.AutoWake = Value end})
Tabs.Main:AddToggle("AutoCashDrop", {Title = "Auto Collect Cash Drops", Default = false, Callback = function(Value) State.AutoCashDrop = Value end})
Tabs.Main:AddToggle("AutoPhone", {Title = "Auto Accept Phone Deals", Default = false, Callback = function(Value) State.AutoPhone = Value end})

-- 3. PROGRESSION TAB
Tabs.Prog:AddToggle("AutoRebirth", {Title = "Auto Rebirth (>1 Investor)", Default = false, Callback = function(Value) State.AutoRebirth = Value end})
Tabs.Prog:AddToggle("AutoEvolve", {Title = "Auto Evolve (At 100%)", Default = false, Callback = function(Value) State.AutoEvolve = Value end})
Tabs.Prog:AddToggle("AutoAscend", {Title = "Auto Ascend (Warning: Resets All!)", Default = false, Callback = function(Value) State.AutoAscend = Value end})

-- 4. UTILITY TAB
Tabs.Utility:AddToggle("AntiAFK", {Title = "Anti-AFK Disconnect Protection", Default = false, Callback = function(Value) State.AntiAFK = Value end})

local SpeedToggle = Tabs.Utility:AddToggle("SpeedOn", {Title = "Enable Custom Walk Speed", Default = false, Callback = function(Value) State.SpeedOn = Value end})
local SpeedSlider = Tabs.Utility:AddSlider("SpeedVal", {
    Title = "Walk Speed Value",
    Description = "Adjust your character's travel speed",
    Default = 16,
    Min = 16,
    Max = 150,
    Rounding = 0,
    Callback = function(Value) State.SpeedVal = Value end
})

--========================= BACKGROUND DATA REFRESH LOOP =========================
task.spawn(function()
    while true do
        local t = getTycoon()
        if t then 
            refreshCaches(t)
            pcall(function()
                local bal = t:GetComponent(ClientTycoonBalances) or t:GetComponent(TycoonBalances)
                if bal then 
                    CashParagraph:SetTitle("Cash Available: " .. Huge.formatShort(bal:GetCash()))
                    InvestorsParagraph:SetTitle("Total Investors: " .. Huge.formatShort(bal:GetInvestors()))
                end
                
                local rb = t:GetComponent(ClientTycoonRebirth) 
                if rb then 
                    RebirthsParagraph:SetTitle("Total Rebirths: " .. tostring(rb:GetRebirths())) 
                end
                
                local ev = t:GetComponent(ClientTycoonEvolution) 
                if ev then 
                    EvolutionParagraph:SetTitle("Evolution Progress: " .. string.format("%.0f%%", math.clamp(ev:GetEvolutionProgress() * 100, 0, 100))) 
                end
                
                -- Process background tasks sequentially
                if State.AutoBuy then doAutoBuy(t) end
                if State.AutoUpgradeEarners then doUpgradeEarners(t) end
                if State.AutoUpgradePowers then doUpgradePowers(t) end
                if State.AutoWake then doWake(t) end
                if State.AutoPhone then doPhone(t) end
                if State.AutoRebirth then tryRebirth(t) end
                if State.AutoEvolve then tryEvolve(t) end
                if State.AutoAscend then tryAscend(t) end
            end)
        else
            CashParagraph:SetTitle("Searching for a valid Tycoon...")
        end
        task.wait(0.1)
    end
end)

Window:SelectTab(1)
Fluent:Notify({ Title = "Sell Lemons Remastered", Content = "Fluent Interface loaded. Press Left-Control to hide.", Duration = 5 })
print("[Sell Lemons Farm] Fluent Upgrade Complete.")