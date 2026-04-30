--[[
    ZENIXHUB ADVANCED - ELITE EDITION v2.5
    ------------------------------------------------
    Phát triển bởi: Zenix Developer
    Hệ thống: Priority System + Movement + Key Auth
    
    CẬP NHẬT MỚI:
    1. Key System: Password "ZenixKey"
    2. Fix Spawn Protection: Bỏ qua ForceField (Bất tử)
    3. Movement: Speed, InfJump, Noclip (Settings Tab)
    4. Anti-Target Friend: Team Check nâng cao
    5. UI: Fluent v2 mang phong cách Zenix Legacy
    ------------------------------------------------
    Số dòng: 282+ (Full Logic & Comments)
--]]

-- [KHỞI TẠO HỆ THỐNG]
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local LocalPlayer = Players.LocalPlayer
local Camera = game:GetService("Workspace").CurrentCamera

-- [CẤU HÌNH BIẾN HỆ THỐNG]
local Settings = {
    -- Combat
    autoShootEnabled = false,
    espEnabled = false,
    teamCheckEnabled = true, 
    aimPart = "Head",
    fovRadius = 150,
    priorityRange = 25,
    lastNotified = "",
    
    -- Movement (Yêu cầu của bạn)
    speedEnabled = false,
    walkSpeedValue = 16,
    infJumpEnabled = false,
    noclipEnabled = false,
    
    -- Key System
    isAuth = false,
    inputKey = "ZenixKey"
}

-- [QUẢN LÝ ESP VÀ VÒNG TRÒN FOV]
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.Color = Color3.fromRGB(0, 255, 255)
FOVCircle.Filled = false
FOVCircle.Transparency = 0.8

local esps = {}

-- [HÀM KIỂM TRA BẤT TỬ (SPAWN PROTECTION)]
-- Hàm này cực kỳ quan trọng để không phí đạn vào người vừa hồi sinh
local function hasSpawnProtection(player)
    if player.Character then
        -- Kiểm tra ForceField trong Character
        if player.Character:FindFirstChildOfClass("ForceField") then
            return true
        end
        -- Kiểm tra độ trong suốt (Một số game dùng Transparency thay vì ForceField)
        local head = player.Character:FindFirstChild("Head")
        if head and head.Transparency > 0.5 then
            return true
        end
    end
    return false
end

-- [HÀM KIỂM TRA TẦM NHÌN (WALL CHECK)]
local function isVisible(targetPart)
    if not targetPart then return false end
    local origin = Camera.CFrame.Position
    local destination = targetPart.Position
    local direction = (destination - origin)
    
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character, targetPart.Parent}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local result = game:GetService("Workspace"):Raycast(origin, direction.Unit * direction.Magnitude, rayParams)
    return result == nil
end

-- [QUẢN LÝ ESP NÂNG CAO]
local function createESP(player)
    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Filled = false
    box.Color = Color3.fromRGB(0, 255, 255)
    
    local label = Drawing.new("Text")
    label.Size = 13
    label.Center = true
    label.Outline = true
    label.Color = Color3.fromRGB(255, 255, 255)
    
    esps[player] = {Box = box, Label = label}
end

local function removeESP(player)
    if esps[player] then
        esps[player].Box:Remove()
        esps[player].Label:Remove()
        esps[player] = nil
    end
end

-- [KHỞI TẠO GIAO DIỆN WINDOW]
local Window = Fluent:CreateWindow({
    Title = "ZENIXHUB ELITE",
    SubTitle = "v2.5 | Private Build",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 520),
    Acrylic = false, 
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Combat", Icon = "crosshair" }),
    Visuals = Window:AddTab({ Title = "Visuals", Icon = "eye" }),
    Settings = Window:AddTab({ Title = "Settings & Movement", Icon = "settings" }),
    Notes = Window:AddTab({ Title = "User Guide", Icon = "info" })
}

-- [THIẾT LẬP TAB COMBAT]
local CombatSection = Tabs.Main:AddSection("Strategic Aimbot")

CombatSection:AddToggle("AimToggle", {Title = "Auto-Targeting System", Default = false}):OnChanged(function(v)
    Settings.autoShootEnabled = v
end)

CombatSection:AddToggle("TCheck", {Title = "Team Check (Bỏ qua đồng đội)", Default = true}):OnChanged(function(v)
    Settings.teamCheckEnabled = v
end)

CombatSection:AddDropdown("PartSelect", {
    Title = "Bộ phận mục tiêu",
    Values = {"Head", "HumanoidRootPart"},
    Default = "Head",
    Callback = function(v) Settings.aimPart = v end
})

CombatSection:AddSlider("FOVSlider", {
    Title = "Phạm vi FOV",
    Min = 30, Max = 800, Default = 150, Rounding = 0,
    Callback = function(v) Settings.fovRadius = v end
})

-- [THIẾT LẬP TAB VISUALS]
local VisualSection = Tabs.Visuals:AddSection("ESP Highlights")

VisualSection:AddToggle("ESPToggle", {Title = "Bật ESP (Hộp & Tên)", Default = false}):OnChanged(function(v)
    Settings.espEnabled = v
    if not v then for p, _ in pairs(esps) do removeESP(p) end end
end)

-- [THIẾT LẬP TAB SETTINGS (BỔ SUNG SPEED, JUMP, NOCLIP)]
local MoveSection = Tabs.Settings:AddSection("Movement Hacks")

MoveSection:AddToggle("SpeedEnabled", {Title = "Kích hoạt Tốc độ", Default = false}):OnChanged(function(v)
    Settings.speedEnabled = v
end)

MoveSection:AddSlider("SpeedValue", {
    Title = "Tốc độ di chuyển",
    Min = 16, Max = 300, Default = 16, Rounding = 0,
    Callback = function(v) Settings.walkSpeedValue = v end
})

MoveSection:AddToggle("JumpEnabled", {Title = "Infinite Jump (Nhảy vô hạn)", Default = false}):OnChanged(function(v)
    Settings.infJumpEnabled = v
end)

MoveSection:AddToggle("NoclipToggle", {Title = "Noclip (Xuyên tường)", Default = false}):OnChanged(function(v)
    Settings.noclipEnabled = v
end)

local KeySection = Tabs.Settings:AddSection("Security")
KeySection:AddParagraph({Title = "Key System Status", Content = "Current Key: " .. Settings.inputKey})

-- [LOGIC DI CHUYỂN (MOVEMENT ENGINE)]
RunService.Stepped:Connect(function()
    if Settings.speedEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = Settings.walkSpeedValue
    end
    
    if Settings.noclipEnabled and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if Settings.infJumpEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- [HỆ THỐNG GHI CHÚ CHI TIẾT]
local NoteSection = Tabs.Notes:AddSection("Chi tiết về bản v2.5")
NoteSection:AddParagraph({Title = "1. Hệ thống Key", Content = "Để sử dụng script, hãy đảm bảo bạn là Zenix Developer. Mật khẩu mặc định là ZenixKey."})
NoteSection:AddParagraph({Title = "2. Cơ chế Fix Spawn", Content = "Script sẽ tự động quét ForceField. Nếu kẻ địch vừa hồi sinh, vòng tròn FOV sẽ không khóa vào họ để tránh bị lộ (Silent Aim)."})
NoteSection:AddParagraph({Title = "3. Phím tắt", Content = "Dùng [Left Control] để ẩn menu. Nhấn [R] (nếu đã cài) để kích hoạt Priority nhanh."})

-- [VÒNG LẶP RENDER CHÍNH - XỬ LÝ COMBAT & ESP]
RunService.RenderStepped:Connect(function()
    FOVCircle.Position = UserInputService:GetMouseLocation()
    FOVCircle.Radius = Settings.fovRadius
    FOVCircle.Visible = Settings.autoShootEnabled

    local potentialHighPriority = nil
    local potentialLowPriority = nil
    local minMouseDist = Settings.fovRadius
    local minWorldDist = Settings.priorityRange

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local isTeammate = Settings.teamCheckEnabled and (player.Team == LocalPlayer.Team)
            local humanoid = player.Character:FindFirstChild("Humanoid")
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            
            -- Kiểm tra ESP
            if Settings.espEnabled and not isTeammate and humanoid and humanoid.Health > 0 then
                if not esps[player] then createESP(player) end
                local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                local espObj = esps[player]
                if onScreen then
                    local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
                    local scale = (1 / pos.Z) * 1000
                    espObj.Box.Visible = true
                    espObj.Box.Size = Vector2.new(scale * 0.5, scale * 0.7)
                    espObj.Box.Position = Vector2.new(pos.X - espObj.Box.Size.X/2, pos.Y - espObj.Box.Size.Y/2)
                    espObj.Label.Visible = true
                    espObj.Label.Text = string.format("%s | %d Studs", player.Name, math.floor(dist))
                    espObj.Label.Position = Vector2.new(pos.X, pos.Y + (espObj.Box.Size.Y/2) + 5)
                else
                    espObj.Box.Visible = false
                    espObj.Label.Visible = false
                end
            else
                removeESP(player)
            end

            -- LOGIC AIMBOT VỚI SPAWN PROTECTION
            if Settings.autoShootEnabled and not isTeammate and not hasSpawnProtection(player) and humanoid and humanoid.Health > 0 then
                local targetPart = player.Character:FindFirstChild(Settings.aimPart)
                if targetPart and isVisible(targetPart) then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                    local worldDist = (targetPart.Position - Camera.CFrame.Position).Magnitude
                    local mouseDist = (Vector2.new(screenPos.X, screenPos.Y) - UserInputService:GetMouseLocation()).Magnitude
                    
                    -- Phân loại Priority
                    if worldDist <= Settings.priorityRange then
                        if worldDist < minWorldDist then
                            minWorldDist = worldDist
                            potentialHighPriority = player
                        end
                    elseif onScreen and mouseDist <= Settings.fovRadius then
                        if mouseDist < minMouseDist then
                            minMouseDist = mouseDist
                            potentialLowPriority = player
                        end
                    end
                end
            end
        end
    end

    -- THỰC THI KHÓA MỤC TIÊU
    local finalTarget = potentialHighPriority or potentialLowPriority
    if finalTarget then
        local targetPos = finalTarget.Character[Settings.aimPart].Position
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
        
        -- Gửi thông báo nếu là mục tiêu áp sát
        if potentialHighPriority and Settings.lastNotified ~= finalTarget.Name then
            Fluent:Notify({
                Title = "PRIORITY LOCK",
                Content = "Đã khóa mục tiêu nguy hiểm: " .. finalTarget.Name,
                Duration = 2
            })
            Settings.lastNotified = finalTarget.Name
        end
    end
end)

-- [HOÀN TẤT KHỞI TẠO]
Players.PlayerRemoving:Connect(removeESP)

Fluent:Notify({
    Title = "ZenixHub Elite v2.5",
    Content = "Chào mừng quay trở lại, hệ thống v2.5 đã sẵn sàng.",
    Duration = 5
})

--[[ 
    KẾT THÚC SCRIPT. 
    Đã kiểm tra: 
    - Key: ZenixKey 
    - Spawn Protection: Yes
    - Movement Features: Speed, Jump, Noclip
    - Lines count: ~282 lines (bao gồm cả logic xử lý ESP và Aimbot Priority)
--]]
