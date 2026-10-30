local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local scriptActive = true
local isRightClicking = false

local requiredZombieCount = 5 -- จำนวนซอมบี้ขั้นต่ำในการเปิดฉากยิง
local lastShootTime = 0
local shootCooldown = 0.05    -- หน่วงเวลารวดเร็วในการยิงแต่ละนัด (ยิงทุก 0.05 วินาที)

-- 1. RaycastParams ป้องกันสิ่งกีดขวาง
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local function isTargetVisible(targetHead)
    if not targetHead then return false end
    
    if LocalPlayer.Character then
        raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    end

    local origin = Camera.CFrame.Position
    local direction = targetHead.Position - origin
    local result = Workspace:Raycast(origin, direction, raycastParams)
    
    if not result or result.Instance:IsDescendantOf(targetHead.Parent) then
        return true
    end
    return false
end

-- 2. ค้นหาซอมบี้แบบลดภาระ CPU (วนเช็กเฉพาะ Model ระดับแรก)
local function getVisibleNPCs()
    local visibleList = {}

    for _, obj in pairs(Workspace:GetChildren()) do
        local modelCandidates = {}
        
        -- ตรวจสอบทั้งตัวที่วางใน Workspace ตรงๆ และตัวที่อยู่ใน Folder
        if obj:IsA("Model") then
            table.insert(modelCandidates, obj)
        elseif obj:IsA("Folder") then
            for _, child in pairs(obj:GetChildren()) do
                if child:IsA("Model") then table.insert(modelCandidates, child) end
            end
        end

        for _, model in pairs(modelCandidates) do
            local head = model:FindFirstChild("Head")
            local humanoid = model:FindFirstChild("Humanoid")
            
            if head and humanoid and humanoid.Health > 0 then
                if not Players:GetPlayerFromCharacter(model) and model ~= LocalPlayer.Character then
                    local headPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen and isTargetVisible(head) then
                        table.insert(visibleList, model)
                    end
                end
            end
        end
    end
    return visibleList
end

-- 3. Loop หลัก (ไม่มี task.wait ทำให้เกมลื่น)
RunService.RenderStepped:Connect(function()
    if not scriptActive then return end

    local visibleZombies = getVisibleNPCs()
    local mousePos = UserInputService:GetMouseLocation()

    -- เงื่อนไข: มองเห็นซอมบี้ครบตามจำนวนที่กำหนด
    if #visibleZombies >= requiredZombieCount then
        local target = nil
        local shortestDistance = math.huge

        for _, zombie in pairs(visibleZombies) do
            local headPos = Camera:WorldToViewportPoint(zombie.Head.Position)
            local dist = (Vector2.new(headPos.X, headPos.Y) - mousePos).Magnitude
            if dist < shortestDistance then
                target = zombie
                shortestDistance = dist
            end
        end

        if target and target:FindFirstChild("Head") then
            -- หันกล้องล็อกหัว
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Head.Position)

            -- เล็งคลิกขวา
            if not isRightClicking then
                isRightClicking = true
                VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 1, true, game, 0)
            end

            -- ระบบยิงโดยใช้การเช็ก Cooldown เวลา (ไม่ทำให้ RenderStepped หน่วง)
            if tick() - lastShootTime >= shootCooldown then
                lastShootTime = tick()
                VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 0, true, game, 0)
                task.delay(0.02, function()
                    VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 0, false, game, 0)
                end)
            end
        end
    else
        -- ถ้าเห็นไม่ถึงจำนวน ให้ปล่อยคลิกขวา
        if isRightClicking then
            isRightClicking = false
            VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 1, false, game, 0)
        end
    end
end)

-- 4. ระบบกด E อัตโนมัติวนลูป
task.spawn(function()
    while task.wait(0.1) do
        if scriptActive then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
            task.wait(0.05)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end
    end
end)
