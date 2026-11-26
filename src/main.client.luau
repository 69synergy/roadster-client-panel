-- Roadster Client Panel: reads replicated state; writes only its own UI and camera.
-- Self-contained: no runtime downloads or game module execution.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local Storage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
assert(player, "Run Roadster Client Panel on the client")
local playerGui = player:WaitForChild("PlayerGui")
local old = playerGui:FindFirstChild("RoadsterClientPanel")
if old then
    local shutdown = old:FindFirstChild("Shutdown")
    if shutdown and shutdown:IsA("BindableEvent") then shutdown:Fire() end
    old:Destroy()
end

local connections, markers = {}, {}
local alive, cameraBackup = true, nil
local state = { tab = "Vehicle", police = false, missions = false, camera = "Game", fov = 70 }
local car, chassis, policeList, missionList = nil, nil, {}, {}
local accent = Color3.fromRGB(255, 59, 127)
local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end
local function create(class, properties, parent)
    local object = Instance.new(class)
    for key, value in pairs(properties) do object[key] = value end
    object.Parent = parent
    return object
end
local gui = create("ScreenGui", {
    Name = "RoadsterClientPanel", ResetOnSpawn = false, DisplayOrder = 25,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)
local shutdown = create("BindableEvent", { Name = "Shutdown" }, gui)
local window = create("Frame", {
    Size = UDim2.new(0.92, 0, 0.78, 0), Position = UDim2.fromScale(0.04, 0.11),
    BackgroundColor3 = Color3.fromRGB(14, 14, 19), BorderSizePixel = 0,
}, gui)
create("UISizeConstraint", { MaxSize = Vector2.new(620, 650) }, window)
create("UICorner", { CornerRadius = UDim.new(0, 12) }, window)
create("UIStroke", { Color = Color3.fromRGB(56, 56, 68), Thickness = 1 }, window)
local function label(parent, text, size)
    return create("TextLabel", {
        Text = text, Font = Enum.Font.Gotham, TextSize = size or 14,
        TextColor3 = Color3.fromRGB(235, 235, 241), BackgroundTransparency = 1,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true, RichText = false, Size = UDim2.new(1, 0, 0, 30),
    }, parent)
end
local title = label(window, "ROADSTER / CLIENT PANEL", 19)
title.Position = UDim2.fromOffset(18, 16)
title.Size = UDim2.new(1, -36, 0, 28)
local subtitle = label(window, "Local view • Right Ctrl: hide/show • End: unload", 12)
subtitle.Position = UDim2.fromOffset(18, 47)
subtitle.Size = UDim2.new(1, -36, 0, 32)
subtitle.TextColor3 = Color3.fromRGB(158, 158, 174)
local tabs = create("Frame", {
    Position = UDim2.fromOffset(18, 86), Size = UDim2.new(1, -36, 0, 36), BackgroundTransparency = 1,
}, window)
create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }, tabs)
local content = create("ScrollingFrame", {
    Position = UDim2.fromOffset(18, 138), Size = UDim2.new(1, -36, 1, -156),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
    AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
}, window)
create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, content)
local function button(parent, text, action)
    local result = create("TextButton", {
        Text = text, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = Color3.fromRGB(245, 245, 250), BackgroundColor3 = Color3.fromRGB(37, 37, 48),
        BorderSizePixel = 0, Size = UDim2.new(1, -8, 0, 36), AutoButtonColor = true,
    }, parent)
    create("UICorner", { CornerRadius = UDim.new(0, 6) }, result)
    connect(result.Activated, action)
    return result
end
local pages, tabButtons = {}, {}
for _, name in ipairs({ "Vehicle", "Controls", "Police", "Missions" }) do
    local page = create("Frame", {
        Name = name, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Visible = name == state.tab,
    }, content)
    create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, page)
    pages[name] = page
    tabButtons[name] = button(tabs, name, function()
        state.tab = name
        content.CanvasPosition = Vector2.zero
        for tabName, tabPage in pairs(pages) do
            tabPage.Visible = tabName == name
            tabButtons[tabName].BackgroundColor3 = tabName == name and accent or Color3.fromRGB(37, 37, 48)
        end
    end)
    tabButtons[name].Size = UDim2.new(0.25, -5, 1, 0)
end
tabButtons.Vehicle.BackgroundColor3 = accent
local function body(page, text)
    local result = label(page, text)
    result.AutomaticSize = Enum.AutomaticSize.Y
    result.Size = UDim2.new(1, 0, 0, 24)
    return result
end
local telemetry = body(pages.Vehicle, "Waiting for your Roadster…")
local status = body(pages.Vehicle, "")
status.TextColor3 = accent
body(pages.Controls, "Camera and display controls only. Driving, upgrades, rewards and mission actions stay with the game's own controls.")
local function restoreCamera()
    if not cameraBackup then return end
    local backup = cameraBackup
    cameraBackup = nil
    pcall(function()
        backup.camera.CameraType = backup.kind
        if backup.subject and backup.subject.Parent then
            backup.camera.CameraSubject = backup.subject
        elseif player.Character then
            backup.camera.CameraSubject = player.Character:FindFirstChildOfClass("Humanoid")
        end
        backup.camera.FieldOfView = backup.fov
        backup.camera.CFrame = backup.cframe
        backup.camera.Focus = backup.focus
    end)
end
local cameraButton
cameraButton = button(pages.Controls, "Camera: Game", function()
    local modes = { Game = "Chase", Chase = "Overhead", Overhead = "Game" }
    state.camera = modes[state.camera]
    if state.camera == "Game" then restoreCamera() end
    cameraButton.Text = "Camera: " .. state.camera
end)
local fovButton
fovButton = button(pages.Controls, "Panel camera FOV: 70", function()
    state.fov = state.fov >= 100 and 50 or state.fov + 10
    fovButton.Text = "Panel camera FOV: " .. state.fov
end)
button(pages.Controls, "Reset local camera", function()
    state.camera = "Game"
    cameraButton.Text = "Camera: Game"
    restoreCamera()
end)
local policeButton
policeButton = button(pages.Police, "Police markers: Off", function()
    state.police = not state.police
    policeButton.Text = "Police markers: " .. (state.police and "On" or "Off")
end)
local policeText = body(pages.Police, "Waiting for streamed police vehicles…")
body(pages.Police, "Distances cover vehicles visible to your client. Nearby police are not necessarily pursuing you. Markers respect occlusion.")
local missionButton
missionButton = button(pages.Missions, "Mission markers: Off", function()
    state.missions = not state.missions
    missionButton.Text = "Mission markers: " .. (state.missions and "On" or "Off")
end)
local missionText = body(pages.Missions, "Waiting for client-visible mission markers…")
local raceText = body(pages.Missions, "")
body(pages.Missions, "Marker proximity is not completion. Active quest and reward semantics are not verified yet.")

local function partFor(object)
    if object:IsA("BasePart") then return object end
    if object:IsA("Model") and object.PrimaryPart then return object.PrimaryPart end
    return object:FindFirstChildWhichIsA("BasePart", true)
end
local function origin()
    if chassis and chassis.Parent then return chassis.Position end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    return root and root.Position or nil
end
local function distance(part, position)
    return position and (part.Position - position).Magnitude or math.huge
end
local function scan()
    car, chassis = nil, nil
    policeList, missionList = {}, {}
    local cars = workspace:FindFirstChild("Cars")
    if cars then
        for _, model in ipairs(cars:GetChildren()) do
            if model:IsA("Model") and string.sub(model.Name, 1, 9) == "Roadster_"
                and tostring(model:GetAttribute("Owner")) == tostring(player.UserId) then
                car = model
                local candidate = model:FindFirstChild("Chassis")
                chassis = candidate and candidate:IsA("BasePart") and candidate or model.PrimaryPart
                break
            end
        end
        for _, model in ipairs(cars:GetChildren()) do
            if string.sub(model.Name, 1, 7) == "Police_" then
                local part = partFor(model)
                if part then table.insert(policeList, { object = model, part = part, name = model.Name }) end
            end
        end
    end
    for _, name in ipairs({ "MissionLocal", "MissionSpots" }) do
        local folder = workspace:FindFirstChild(name)
        if folder then
            for _, object in ipairs(folder:GetChildren()) do
                local part = partFor(object)
                if part then table.insert(missionList, { object = object, part = part, name = name .. "/" .. object.Name }) end
            end
        end
    end
end
local function sortedAvailable(entries)
    local result, position = {}, origin()
    for _, entry in ipairs(entries) do
        if entry.part:IsDescendantOf(workspace) then
            table.insert(result, { object = entry.object, part = entry.part, name = entry.name, distance = distance(entry.part, position) })
        end
    end
    table.sort(result, function(a, b) return a.distance < b.distance end)
    return result
end
local function distanceText(value)
    return value == math.huge and "unknown distance" or string.format("%.0f studs", value)
end
local function updateList(entries, enabled, limit, color, wanted)
    local lines = {}
    for index, entry in ipairs(entries) do
        if index > limit then break end
        local text = entry.name .. " • " .. distanceText(entry.distance)
        table.insert(lines, text)
        if enabled then
            wanted[entry.object] = true
            local marker = markers[entry.object]
            if not marker then
                local billboard = create("BillboardGui", {
                    Name = "LocalMarker", Size = UDim2.fromOffset(220, 40), AlwaysOnTop = false,
                    StudsOffsetWorldSpace = Vector3.new(0, 5, 0), MaxDistance = 2000,
                }, gui)
                local textLabel = label(billboard, "", 12)
                textLabel.TextColor3 = color
                textLabel.TextStrokeTransparency = 0.3
                textLabel.TextXAlignment = Enum.TextXAlignment.Center
                marker = { gui = billboard, label = textLabel }
                markers[entry.object] = marker
            end
            marker.gui.Adornee = entry.part
            marker.label.Text = text
        end
    end
    return #lines > 0 and table.concat(lines, "\n") or "No matching objects currently streamed."
end
local function attr(name)
    local value = car and car:GetAttribute(name)
    if value == nil then return "unavailable" end
    return tostring(value)
end
local function refresh()
    if car and chassis and car.Parent and chassis.Parent then
        telemetry.Text = string.format(
            "%s\n\nSpeed   %.1f studs/s\nGear   %s\nEngine   %s\nAcceleration attribute   %s\nGrip scale   %s\nBoost active   %s\nBoost seconds attribute   %s\nFlying   %s\nDriver   %s",
            car.Name, chassis.AssemblyLinearVelocity.Magnitude, attr("Gear"), attr("Engine"), attr("Accel"),
            attr("GripScale"), attr("BoostActive"), attr("BoostSeconds"), attr("Flying"),
            tostring(car:GetAttribute("Driver")) == tostring(player.UserId) and "You" or "Other / empty")
    else
        telemetry.Text = "Your Roadster is not currently streamed. Spawn it using the game's controls."
    end
    local wanted = {}
    local police = sortedAvailable(policeList)
    policeText.Text = "Streamed police: " .. #police .. "\n\n" .. updateList(police, state.police, 12, Color3.fromRGB(98, 171, 255), wanted)
    missionText.Text = "Nearby mission objects:\n\n" .. updateList(sortedAvailable(missionList), state.missions, 8, accent, wanted)
    for object, marker in pairs(markers) do
        if not wanted[object] then marker.gui:Destroy(); markers[object] = nil end
    end
    local race = Storage:FindFirstChild("RaceState")
    local values = {}
    if race then
        for key, value in pairs(race:GetAttributes()) do table.insert(values, key .. " = " .. tostring(value)) end
        for _, child in ipairs(race:GetChildren()) do
            if child:IsA("ValueBase") then table.insert(values, child.Name .. " = " .. tostring(child.Value)) end
        end
        table.sort(values)
    end
    while #values > 20 do table.remove(values) end
    raceText.Text = "RaceState (raw client view):\n" .. (#values > 0 and table.concat(values, "\n") or "No readable state currently available.")
end
local function destroy()
    if not alive then return end
    alive = false
    for _, connection in ipairs(connections) do connection:Disconnect() end
    restoreCamera()
    gui:Destroy()
end
connect(shutdown.Event, destroy)
connect(gui.Destroying, destroy)
button(pages.Controls, "Unload panel", destroy)
connect(Input.InputBegan, function(input, processed)
    if processed or Input:GetFocusedTextBox() then return end
    if input.KeyCode == Enum.KeyCode.RightControl then window.Visible = not window.Visible end
    if input.KeyCode == Enum.KeyCode.End then destroy() end
end)
local elapsed, scanElapsed = 1, 1
connect(RunService.Heartbeat, function(dt)
    elapsed, scanElapsed = elapsed + dt, scanElapsed + dt
    if elapsed < 0.25 then return end
    elapsed = 0
    local ok, err = pcall(function()
        if scanElapsed >= 1 then scanElapsed = 0; scan() end
        refresh()
    end)
    status.Text = ok and "Reading local state • no server actions" or "Read error: " .. tostring(err)
end)
connect(RunService.RenderStepped, function()
    if state.camera == "Game" then return end
    local camera = workspace.CurrentCamera
    if not camera or not chassis or not chassis:IsDescendantOf(workspace) then restoreCamera(); return end
    if cameraBackup and cameraBackup.camera ~= camera then restoreCamera() end
    if not cameraBackup then
        cameraBackup = { camera = camera, kind = camera.CameraType, subject = camera.CameraSubject,
            fov = camera.FieldOfView, cframe = camera.CFrame, focus = camera.Focus }
    end
    local target = chassis.Position
    local offset = state.camera == "Overhead" and Vector3.new(0, 65, 0.1)
        or -chassis.CFrame.LookVector * 24 + Vector3.new(0, 9, 0)
    camera.CameraType = Enum.CameraType.Scriptable
    camera.FieldOfView = state.fov
    camera.CFrame = CFrame.lookAt(target + offset, target)
    camera.Focus = CFrame.new(target)
end)
