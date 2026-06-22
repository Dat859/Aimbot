--==============================================================
--  🍋 SELL LEMONS — AUTO FARM  (v4 — faster + auto fruit)
--  Paste into your executor and run while in "Sell Lemons 🍋".
--==============================================================
local RS=game:GetService("ReplicatedStorage")
local CollectionService=game:GetService("CollectionService")
local UserInputService=game:GetService("UserInputService")
local TweenService=game:GetService("TweenService")
local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local LP=Players.LocalPlayer

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

local State={
    AutoBuy=false, AutoUpgradeEarners=false, AutoUpgradePowers=false,
    AutoWake=false, AutoCashDrop=false, AutoPhone=false, AutoFruit=false,
    AutoRebirth=false, AutoEvolve=false, AutoAscend=false,
    AntiAFK=false, SpeedOn=false, SpeedVal=16,
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
local function doUpgradeEarners(t)  -- bulk: max affordable per earner in ONE call
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

-- Cash drops
do
    local ok,redeem=pcall(function() return RemoteRequest.new("CashDropService.Redeem") end)
    local ok2,newSig=pcall(function() return RemoteSignal.new("CashDropService.New") end)
    if ok and ok2 and redeem and newSig then
        newSig.OnClientEvent:Connect(function(id) if State.AutoCashDrop and id~=nil then pcall(function() redeem:InvokeServer(id) end) end end)
    end
end
-- Anti-AFK
do local vu=game:GetService("VirtualUser")
    LP.Idled:Connect(function() if State.AntiAFK then pcall(function() vu:CaptureController() vu:ClickButton2(Vector2.new()) end) end end)
end
-- Walk speed
RunService.Heartbeat:Connect(function()
    if State.SpeedOn then local c=LP.Character local h=c and c:FindFirstChildOfClass("Humanoid")
        if h and h.WalkSpeed~=State.SpeedVal then h.WalkSpeed=State.SpeedVal end end
end)

-- AUTO FRUIT (teleport-harvest the orchard)
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

--========================= GUI =========================
local parent=LP:WaitForChild("PlayerGui")
local old=parent:FindFirstChild("LemonFarmGui"); if old then old:Destroy() end
local ACCENT,BG,BG2,BG3=Color3.fromRGB(242,201,76),Color3.fromRGB(22,23,28),Color3.fromRGB(31,33,40),Color3.fromRGB(45,47,56)
local TXT,SUB,OFFCOL=Color3.fromRGB(236,238,243),Color3.fromRGB(146,150,162),Color3.fromRGB(66,68,78)
local function corner(o,r) local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,r or 8) c.Parent=o return c end
local function pad(o,t,b,l,r) local p=Instance.new("UIPadding") p.PaddingTop=UDim.new(0,t or 0) p.PaddingBottom=UDim.new(0,b or 0) p.PaddingLeft=UDim.new(0,l or 0) p.PaddingRight=UDim.new(0,r or 0) p.Parent=o return p end

local gui=Instance.new("ScreenGui") gui.Name="LemonFarmGui" gui.ResetOnSpawn=false gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling gui.IgnoreGuiInset=true gui.DisplayOrder=999 gui.Parent=parent
local main=Instance.new("Frame") main.Name="Main" main.Size=UDim2.new(0,318,0,476) main.Position=UDim2.new(0,40,0.5,-238) main.BackgroundColor3=BG main.BorderSizePixel=0 main.Parent=gui corner(main,14)
local mstr=Instance.new("UIStroke") mstr.Color=Color3.fromRGB(0,0,0) mstr.Transparency=0.45 mstr.Thickness=1.5 mstr.Parent=main

local bar=Instance.new("Frame") bar.Name="Bar" bar.Size=UDim2.new(1,0,0,46) bar.BackgroundColor3=BG2 bar.BorderSizePixel=0 bar.Parent=main corner(bar,14)
local bf=Instance.new("Frame") bf.Size=UDim2.new(1,0,0,16) bf.Position=UDim2.new(0,0,1,-16) bf.BackgroundColor3=BG2 bf.BorderSizePixel=0 bf.Parent=bar
local ab=Instance.new("Frame") ab.Size=UDim2.new(0,4,0,22) ab.Position=UDim2.new(0,12,0.5,-11) ab.BackgroundColor3=ACCENT ab.BorderSizePixel=0 ab.ZIndex=2 ab.Parent=bar corner(ab,2)
local title=Instance.new("TextLabel") title.BackgroundTransparency=1 title.Size=UDim2.new(1,-110,1,0) title.Position=UDim2.new(0,24,0,0) title.Font=Enum.Font.GothamBold title.TextSize=16 title.TextColor3=TXT title.TextXAlignment=Enum.TextXAlignment.Left title.Text="🍋 Sell Lemons Farm" title.ZIndex=2 title.Parent=bar
local function barBtn(txt,xoff,col) local b=Instance.new("TextButton") b.Size=UDim2.new(0,28,0,28) b.Position=UDim2.new(1,xoff,0.5,-14) b.BackgroundColor3=BG3 b.Text=txt b.Font=Enum.Font.GothamBold b.TextSize=15 b.TextColor3=col or TXT b.BorderSizePixel=0 b.ZIndex=2 b.Parent=bar corner(b,8) return b end
local closeBtn=barBtn("X",-36,Color3.fromRGB(235,120,120)) local minBtn=barBtn("-",-70)

local body=Instance.new("ScrollingFrame") body.Name="Body" body.Size=UDim2.new(1,0,1,-46) body.Position=UDim2.new(0,0,0,46) body.BackgroundTransparency=1 body.BorderSizePixel=0 body.ScrollBarThickness=4 body.ScrollBarImageColor3=ACCENT body.ScrollBarImageTransparency=0.3 body.AutomaticCanvasSize=Enum.AutomaticSize.Y body.CanvasSize=UDim2.new(0,0,0,0) body.Parent=main pad(body,10,12,12,8)
local lay=Instance.new("UIListLayout") lay.Padding=UDim.new(0,7) lay.SortOrder=Enum.SortOrder.LayoutOrder lay.Parent=body
local ord=0 local function nO() ord=ord+1 return ord end

local stat=Instance.new("Frame") stat.Size=UDim2.new(1,0,0,86) stat.BackgroundColor3=BG2 stat.BorderSizePixel=0 stat.LayoutOrder=nO() stat.Parent=body corner(stat,10) pad(stat,9,9,11,11)
local sl=Instance.new("UIListLayout") sl.Padding=UDim.new(0,3) sl.Parent=stat
local function statRow(tt) local r=Instance.new("Frame") r.Size=UDim2.new(1,0,0,17) r.BackgroundTransparency=1 r.Parent=stat
    local k=Instance.new("TextLabel") k.BackgroundTransparency=1 k.Size=UDim2.new(0.55,0,1,0) k.Font=Enum.Font.Gotham k.TextSize=13 k.TextColor3=SUB k.TextXAlignment=Enum.TextXAlignment.Left k.Text=tt k.Parent=r
    local v=Instance.new("TextLabel") v.BackgroundTransparency=1 v.Size=UDim2.new(0.45,0,1,0) v.Position=UDim2.new(0.55,0,0,0) v.Font=Enum.Font.GothamBold v.TextSize=13 v.TextColor3=TXT v.TextXAlignment=Enum.TextXAlignment.Right v.Text="--" v.Parent=r return v end
local vCash=statRow("Cash") local vInv=statRow("Investors") local vReb=statRow("Rebirths") local vEvo=statRow("Evolve")

local function section(txt) local h=Instance.new("TextLabel") h.Size=UDim2.new(1,0,0,18) h.BackgroundTransparency=1 h.Font=Enum.Font.GothamBold h.TextSize=12 h.TextColor3=ACCENT h.TextXAlignment=Enum.TextXAlignment.Left h.Text=txt h.LayoutOrder=nO() h.Parent=body pad(h,4,0,2,0) end
local function toggleRow(label,desc,key)
    local row=Instance.new("Frame") row.Size=UDim2.new(1,0,0,44) row.BackgroundColor3=BG2 row.BorderSizePixel=0 row.LayoutOrder=nO() row.Parent=body corner(row,10) pad(row,0,0,11,10)
    local lbl=Instance.new("TextLabel") lbl.BackgroundTransparency=1 lbl.Size=UDim2.new(1,-58,0,15) lbl.Position=UDim2.new(0,0,0,8) lbl.Font=Enum.Font.GothamBold lbl.TextSize=13 lbl.TextColor3=TXT lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.Text=label lbl.Parent=row
    local sub=Instance.new("TextLabel") sub.BackgroundTransparency=1 sub.Size=UDim2.new(1,-58,0,12) sub.Position=UDim2.new(0,0,0,23) sub.Font=Enum.Font.Gotham sub.TextSize=11 sub.TextColor3=SUB sub.TextXAlignment=Enum.TextXAlignment.Left sub.Text=desc sub.Parent=row
    local sw=Instance.new("TextButton") sw.Text="" sw.AutoButtonColor=false sw.Size=UDim2.new(0,42,0,22) sw.Position=UDim2.new(1,-42,0.5,-11) sw.BackgroundColor3=OFFCOL sw.BorderSizePixel=0 sw.Parent=row corner(sw,11)
    local knob=Instance.new("Frame") knob.Size=UDim2.new(0,18,0,18) knob.Position=UDim2.new(0,2,0.5,-9) knob.BackgroundColor3=Color3.fromRGB(236,236,236) knob.BorderSizePixel=0 knob.Parent=sw corner(knob,9)
    local function render() local on=State[key] TweenService:Create(sw,TweenInfo.new(0.18),{BackgroundColor3=on and ACCENT or OFFCOL}):Play() TweenService:Create(knob,TweenInfo.new(0.18,Enum.EasingStyle.Quad),{Position=on and UDim2.new(1,-20,0.5,-9) or UDim2.new(0,2,0.5,-9)}):Play() end
    sw.MouseButton1Click:Connect(function() State[key]=not State[key] render() end) render()
end
section("AUTO FARM")
toggleRow("Auto Buy Tiles","Buys affordable purchase tiles","AutoBuy")
toggleRow("Auto Upgrade Earners","Bulk-levels income machines (cash)","AutoUpgradeEarners")
toggleRow("Auto Upgrade Powers","Spends investors on powers","AutoUpgradePowers")
toggleRow("Auto Collect Fruit","Harvests lemons (moves you to trees)","AutoFruit")
toggleRow("Auto Wake Earners","Taps manual machines","AutoWake")
toggleRow("Auto Collect Cash Drops","Instantly grabs cash drops","AutoCashDrop")
toggleRow("Auto Phone Deals","Accepts phone cash offers","AutoPhone")
section("PROGRESSION")
toggleRow("Auto Rebirth","Rebirths when worth >1 investor","AutoRebirth")
toggleRow("Auto Evolve","Evolves at 100% progress","AutoEvolve")
toggleRow("Auto Ascend","Ascends at 100% (resets all!)","AutoAscend")
section("UTILITY")
toggleRow("Anti-AFK","Prevents idle disconnect","AntiAFK")
do
    local row=Instance.new("Frame") row.Size=UDim2.new(1,0,0,62) row.BackgroundColor3=BG2 row.BorderSizePixel=0 row.LayoutOrder=nO() row.Parent=body corner(row,10) pad(row,0,0,11,11)
    local lbl=Instance.new("TextLabel") lbl.BackgroundTransparency=1 lbl.Size=UDim2.new(1,-58,0,15) lbl.Position=UDim2.new(0,0,0,7) lbl.Font=Enum.Font.GothamBold lbl.TextSize=13 lbl.TextColor3=TXT lbl.TextXAlignment=Enum.TextXAlignment.Left lbl.Text="Walk Speed" lbl.Parent=row
    local val=Instance.new("TextLabel") val.BackgroundTransparency=1 val.Size=UDim2.new(0,60,0,15) val.Position=UDim2.new(1,-110,0,7) val.Font=Enum.Font.Gotham val.TextSize=12 val.TextColor3=SUB val.TextXAlignment=Enum.TextXAlignment.Right val.Text="16" val.Parent=row
    local sw=Instance.new("TextButton") sw.Text="" sw.AutoButtonColor=false sw.Size=UDim2.new(0,42,0,22) sw.Position=UDim2.new(1,-42,0,5) sw.BackgroundColor3=OFFCOL sw.BorderSizePixel=0 sw.Parent=row corner(sw,11)
    local knob=Instance.new("Frame") knob.Size=UDim2.new(0,18,0,18) knob.Position=UDim2.new(0,2,0.5,-9) knob.BackgroundColor3=Color3.fromRGB(236,236,236) knob.BorderSizePixel=0 knob.Parent=sw corner(knob,9)
    local function rsw() local on=State.SpeedOn TweenService:Create(sw,TweenInfo.new(0.18),{BackgroundColor3=on and ACCENT or OFFCOL}):Play() TweenService:Create(knob,TweenInfo.new(0.18),{Position=on and UDim2.new(1,-20,0.5,-9) or UDim2.new(0,2,0.5,-9)}):Play() end
    sw.MouseButton1Click:Connect(function() State.SpeedOn=not State.SpeedOn rsw() end) rsw()
    local track=Instance.new("Frame") track.Size=UDim2.new(1,0,0,6) track.Position=UDim2.new(0,0,1,-16) track.BackgroundColor3=BG3 track.BorderSizePixel=0 track.Parent=row corner(track,3)
    local fill=Instance.new("Frame") fill.Size=UDim2.new(0,0,1,0) fill.BackgroundColor3=ACCENT fill.BorderSizePixel=0 fill.Parent=track corner(fill,3)
    local sknob=Instance.new("Frame") sknob.Size=UDim2.new(0,14,0,14) sknob.Position=UDim2.new(0,-7,0.5,-7) sknob.BackgroundColor3=TXT sknob.BorderSizePixel=0 sknob.ZIndex=2 sknob.Parent=track corner(sknob,7)
    local MIN,MAX=16,150
    local function setA(a) a=math.clamp(a,0,1) local v=math.floor(MIN+(MAX-MIN)*a+0.5) State.SpeedVal=v val.Text=tostring(v) fill.Size=UDim2.new(a,0,1,0) sknob.Position=UDim2.new(a,-7,0.5,-7) end
    setA(0) local dragging=false
    local function upd(x) setA((x-track.AbsolutePosition.X)/track.AbsoluteSize.X) end
    track.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true upd(i.Position.X) end end)
    UserInputService.InputChanged:Connect(function(i) if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then upd(i.Position.X) end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=false end end)
end
local foot=Instance.new("TextLabel") foot.Name="Foot" foot.Size=UDim2.new(1,0,0,16) foot.BackgroundTransparency=1 foot.Font=Enum.Font.Gotham foot.TextSize=11 foot.TextColor3=SUB foot.Text="starting..." foot.LayoutOrder=nO() foot.Parent=body

do local dragging,ds,sp
    bar.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragging=true ds=i.Position sp=main.Position i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end) end end)
    UserInputService.InputChanged:Connect(function(i) if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then local d=i.Position-ds main.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y) end end)
end
local minimized=false
minBtn.MouseButton1Click:Connect(function() minimized=not minimized TweenService:Create(main,TweenInfo.new(0.22,Enum.EasingStyle.Quad),{Size=minimized and UDim2.new(0,318,0,46) or UDim2.new(0,318,0,476)}):Play() end)
closeBtn.MouseButton1Click:Connect(function() for k,v in pairs(State) do if type(v)=="boolean" then State[k]=false end end task.wait(0.05) gui:Destroy() end)

task.spawn(function()
    while gui.Parent do
        local t=getTycoon()
        if t then refreshCaches(t)
            pcall(function()
                local bal=t:GetComponent(ClientTycoonBalances) or t:GetComponent(TycoonBalances)
                if bal then pcall(function() vCash.Text=Huge.formatShort(bal:GetCash()) end) pcall(function() vInv.Text=Huge.formatShort(bal:GetInvestors()) end) end
                local rb=t:GetComponent(ClientTycoonRebirth) if rb then pcall(function() vReb.Text=tostring(rb:GetRebirths()) end) end
                local ev=t:GetComponent(ClientTycoonEvolution) if ev then pcall(function() vEvo.Text=string.format("%.0f%%",math.clamp(ev:GetEvolutionProgress()*100,0,100)) end) end
                local acts={}
                if State.AutoBuy then doAutoBuy(t) table.insert(acts,"buy") end
                if State.AutoUpgradeEarners then doUpgradeEarners(t) table.insert(acts,"upg") end
                if State.AutoUpgradePowers then doUpgradePowers(t) table.insert(acts,"pow") end
                if State.AutoWake then doWake(t) table.insert(acts,"wake") end
                if State.AutoPhone then doPhone(t) table.insert(acts,"deal") end
                if State.AutoFruit then table.insert(acts,"fruit") end
                if State.AutoRebirth then tryRebirth(t) table.insert(acts,"rebirth") end
                if State.AutoEvolve then tryEvolve(t) table.insert(acts,"evolve") end
                if State.AutoAscend then tryAscend(t) table.insert(acts,"ascend") end
                foot.Text=#acts>0 and ("running: "..table.concat(acts,", ")) or "status: idle"
            end)
        else foot.Text="waiting for tycoon..." end
        task.wait(0.1)
    end
end)
print("[Sell Lemons Farm] v4 loaded")
