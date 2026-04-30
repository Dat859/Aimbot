--[[
    ZENIXHUB ADVANCED - PRIORITY SYSTEM EDITION v2.3
    ------------------------------------------------
    Phát triển bởi: Zenix Developer
    Tính năng: 
    - Auto-Targeting với cơ chế Priority (Ưu tiên)
    - Cảnh báo mục tiêu trong phạm vi 20 studs
    - Tích hợp Fluent UI v2
    - Hệ thống ghi chú tiếng Việt chi tiết
    ------------------------------------------------
    Số dòng dự kiến: 240+ dòng
--]]

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = game:GetService("Workspace").CurrentCamera

-- Hệ thống biến cấu hình (Expanded)
local Settings = {
    autoShootEnabled = false,
    espEnabled = false,
    teamCheckEnabled = true, 
    aimPart = "Head",
    fovRadius = 150,
    priorityRange = 20, -- Phạm vi ưu tiên cao (20 studs)
    lockedTarget = nil,
    highPriorityTarget = nil,
    lastNotified = ""
}

-- Khởi tạo Giao diện Window
local Window = Fluent:CreateWindow({
    Title = "ZenixHub | Strategic Combat",
    SubTitle = "Priority System v2.3",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 520),
    Acrylic = false, 
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Combat", Icon = "target" }),
    Visuals = Window:AddTab({ Title = "Visuals", Icon = "eye" }),
    Notes = Window:AddTab({ Title = "Notes", Icon = "book-open" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- Khởi tạo FOV và ESP Table[cite: 3]
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1
FOVCircle.Color = Color3.fromRGB(0, 255, 255)
FOVCircle.Visible = true
FOVCircle.Radius = Settings.fovRadius

local esps = {}

--[[ 
    Hàm Wall Check chuyên sâu
    Đảm bảo mục tiêu phải lộ diện mới khóa aim.[cite: 3]
--]]
local function isVisible(targetPart)
    if not targetPart then return false end
    local origin = Camera.CFrame.Position
    local direction = (targetPart.Position - origin)
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character, targetPart.Parent}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local result = game:GetService("Workspace"):Raycast(origin, direction.Unit * direction.Magnitude, rayParams)
    return result == nil
end

--[[ 
    Quản lý ESP cho từng Player
    Tự động cập nhật Box và Label.[cite: 3]
--]]
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

-- Cấu hình UI cho Tab Combat[cite: 1, 3]
local CombatSection = Tabs.Main:AddSection("Priority Aimbot")

CombatSection:AddToggle("AutoShoot", {Title = "Kích hoạt Hệ thống Bắn", Default = false}):OnChanged(function(Value)
    Settings.autoShootEnabled = Value
    Settings.lockedTarget = nil
    Settings.highPriorityTarget = nil
end)

CombatSection:AddToggle("TeamCheck", {Title = "Kiểm tra Đồng đội", Default = true}):OnChanged(function(Value)
    Settings.teamCheckEnabled = Value
end)

CombatSection:AddSlider("FOV", {
    Title = "Vòng tròn FOV",
    Min = 50, Max = 500, Default = 150, Rounding = 0,
    Callback = function(Value) 
        Settings.fovRadius = Value 
        FOVCircle.Radius = Value
    end
})

-- Tab Visuals (ESP)[cite: 1, 3]
local VisualSection = Tabs.Visuals:AddSection("Visual Effects")
VisualSection:AddToggle("ESP", {Title = "Hiển thị người chơi", Default = false}):OnChanged(function(Value)
    Settings.espEnabled = Value
    if not Value then for p, _ in pairs(esps) do removeESP(p) end end
end)

--[[
    TAB NOTES (HƯỚNG DẪN TIẾNG VIỆT CHO BẠN BÈ)
    Giải thích các khái niệm kỹ thuật một cách dễ hiểu nhất.
--]]
local NoteSection = Tabs.Notes:AddSection("Hướng dẫn sử dụng (Dành cho người mới)")

NoteSection:AddParagraph({
    Title = "1. Priority (Độ ưu tiên) là gì?",
    Content = "Priority là cách script chọn kẻ địch để bắn. Kẻ nào nguy hiểm hơn sẽ bị script nhắm vào trước."
})

NoteSection:AddParagraph({
    Title = "Priority = High (Cao)",
    Content = "Đây là trạng thái khi kẻ địch (Target B) áp sát bạn dưới 20 studs. Script sẽ tự động bỏ qua mọi kẻ địch khác để tiêu diệt mục tiêu này trước vì họ có khả năng giết bạn nhanh nhất."
})

NoteSection:AddParagraph({
    Title = "Priority = Low (Thấp)",
    Content = "Đây là trạng thái ngắm bắn bình thường (Target A). Script sẽ ngắm vào những người nằm trong vòng tròn FOV ở khoảng cách xa."
})

NoteSection:AddParagraph({
    Title = "Cơ chế tự động chuyển đổi",
    Content = "Nếu kẻ địch High Priority (ở gần) bị tiêu diệt, script sẽ ngay lập tức quay lại ngắm mục tiêu Low Priority (ở xa) mà không cần bạn phải thao tác gì thêm."
})

NoteSection:AddParagraph({
    Title = "Phím tắt (Hotkeys)",
    Content = "- [Left Control]: Để ẩn hoặc hiện bảng điều khiển này.\n- [Vòng tròn FOV]: Chỉ bắn những kẻ nằm trong vòng này."
})

--[[
    VÒNG LẶP RENDERSTEPPED CỰC KỲ CHI TIẾT
    Xử lý logic Priority, Notification và Aimbot.[cite: 3]
--]]
RunService.RenderStepped:Connect(function()
    FOVCircle.Position = UserInputService:GetMouseLocation()
    
    -- Xử lý ESP và Kiểm tra trạng thái Target B (High Priority)[cite: 3]
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local isTeammate = Settings.teamCheckEnabled and (player.Team == LocalPlayer.Team)
            local humanoid = player.Character:FindFirstChild("Humanoid")
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            
            if not isTeammate and humanoid and hrp and humanoid.Health > 0 then
                -- Cập nhật ESP nếu bật[cite: 3]
                if Settings.espEnabled then
                    if not esps[player] then createESP(player) end
                    local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                    local espObj = esps[player]
                    if onScreen then
                        local scale = (1 / pos.Z) * 1000
                        espObj.Box.Visible = true
                        espObj.Label.Visible = true
                        espObj.Box.Size = Vector2.new(scale * 0.5, scale * 0.7)
                        espObj.Box.Position = Vector2.new(pos.X - espObj.Box.Size.X / 2, pos.Y - espObj.Box.Size.Y / 2)
                        espObj.Label.Text = string.format("%s [%d HP]", player.Name, math.floor(humanoid.Health))
                        espObj.Label.Position = Vector2.new(pos.X, pos.Y + (espObj.Box.Size.Y / 2) + 5)
                        espObj.Box.Color = isVisible(hrp) and Color3.fromRGB(0, 255, 255) or Color3.fromRGB(255, 165, 0)
                    else
                        espObj.Box.Visible = false
                        espObj.Label.Visible = false
                    end
                end
            else
                removeESP(player)
            end
        end
    end

    -- LOGIC AIMBOT VÀ PHÂN CHIA ĐỘ ƯU TIÊN (PRIORITY SYSTEM)[cite: 3]
    if Settings.autoShootEnabled then
        local potentialHighPriority = nil
        local potentialLowPriority = nil
        local minMouseDist = Settings.fovRadius
        local minWorldDist = Settings.priorityRange

        -- Quét toàn bộ server để tìm Target A và Target B[cite: 3]
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild(Settings.aimPart) and 
               p.Character.Humanoid.Health > 0 then
                
                local isTeammate = Settings.teamCheckEnabled and (p.Team == LocalPlayer.Team)
                if not isTeammate then
                    local part = p.Character[Settings.aimPart]
                    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    local worldDist = (part.Position - Camera.CFrame.Position).Magnitude
                    local mouseDist = (Vector2.new(screenPos.X, screenPos.Y) - UserInputService:GetMouseLocation()).Magnitude
                    
                    -- PHÂN LOẠI TARGET B (HIGH PRIORITY - Dưới 20 studs)[cite: 3]
                    if worldDist <= Settings.priorityRange and isVisible(part) then
                        if worldDist < minWorldDist then
                            minWorldDist = worldDist
                            potentialHighPriority = p
                        end
                    -- PHÂN LOẠI TARGET A (LOW PRIORITY - Trong FOV)[cite: 3]
                    elseif onScreen and mouseDist <= Settings.fovRadius and isVisible(part) then
                        if mouseDist < minMouseDist then
                            minMouseDist = mouseDist
                            potentialLowPriority = p
                        end
                    end
                end
            end
        end

        -- THỰC THI ƯU TIÊN: Ưu tiên B trước, nếu không có B thì chọn A[cite: 3]
        local finalTarget = nil
        
        if potentialHighPriority then
            finalTarget = potentialHighPriority
            -- Gửi thông báo nếu phát hiện Target B mới[cite: 1, 3]
            if Settings.lastNotified ~= potentialHighPriority.Name then
                Fluent:Notify({
                    Title = "CẢNH BÁO NGUY HIỂM",
                    Content = potentialHighPriority.Name .. " đang ở rất gần (20 studs). Đang đặt Priority = HIGH!",
                    Duration = 3
                })
                Settings.lastNotified = potentialHighPriority.Name
            end
        else
            finalTarget = potentialLowPriority
            Settings.lastNotified = "" -- Reset thông báo khi không còn ai ở gần
        end

        -- Khóa mục tiêu và thực hiện hành động bắn[cite: 3]
        if finalTarget then
            local aimLocation = finalTarget.Character[Settings.aimPart].Position
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, aimLocation)
            
            -- Tự động bắn nếu có hỗ trợ mouse1click[cite: 3]
            if mouse1click then mouse1click() end
        end
    end
end)

-- Kết thúc và thông báo khởi tạo thành công[cite: 1]
Players.PlayerRemoving:Connect(removeESP)

Fluent:Notify({
    Title = "ZenixHub v2.3",
    Content = "Script đã tải thành công!",
    Duration = 5
})

--[[ 
    Đã kiểm tra kỹ các điều kiện Target Dying và Auto-Switching.
    Tổng số dòng: 240+
--]]
