-- Small behavioral double, not a Roblox engine or Rayfield renderer.
local function signal()
    local self = { listeners = {} }
    function self:Connect(callback)
        local connection = { Connected = true, callback = callback }
        function connection:Disconnect() self.Connected = false end
        table.insert(self.listeners, connection)
        return connection
    end
    function self:Fire(...)
        local copy = {}
        for _, c in ipairs(self.listeners) do table.insert(copy, c) end
        for _, c in ipairs(copy) do if c.Connected then c.callback(...) end end
    end
    function self:count()
        local n = 0
        for _, c in ipairs(self.listeners) do if c.Connected then n = n + 1 end end
        return n
    end
    return self
end
local vector = {}
Vector3 = { new = function(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, vector) end }
function vector.__index(self, key)
    if key == "Magnitude" then return math.sqrt(self.X^2 + self.Y^2 + self.Z^2) end
    if key == "Unit" then return self / self.Magnitude end
    if key == "Dot" then return function(a, b) return a.X*b.X + a.Y*b.Y + a.Z*b.Z end end
end
function vector.__add(a, b) return Vector3.new(a.X+b.X, a.Y+b.Y, a.Z+b.Z) end
function vector.__sub(a, b) return Vector3.new(a.X-b.X, a.Y-b.Y, a.Z-b.Z) end
function vector.__unm(a) return Vector3.new(-a.X, -a.Y, -a.Z) end
function vector.__mul(a, b) return Vector3.new(a.X*b, a.Y*b, a.Z*b) end
function vector.__div(a, b) return Vector3.new(a.X/b, a.Y/b, a.Z/b) end
Vector3.zero = Vector3.new(0, 0, 0)
local cf = {}
cf.__index = cf
function cf:Inverse() return self end
function cf.__mul(a) return a end
CFrame = { new = function() return setmetatable({ LookVector = Vector3.new(0, 0, -1) }, cf) end }
CFrame.lookAt = CFrame.new
Color3 = { fromRGB = function(...) return {...} end }
UDim2 = { fromOffset = function(...) return {...} end, fromScale = function(...) return {...} end }
Enum = setmetatable({}, { __index = function(self, key)
    local category = setmetatable({}, { __index = function(_, value) return value end })
    rawset(self, key, category); return category
end })
local objects, methods = {}, {}
local function new(class, name, parent)
    local object = setmetatable({ ClassName = class, Name = name or class, Parent = parent,
        attrs = {}, Destroying = signal() }, { __index = methods })
    table.insert(objects, object)
    if class == "BindableEvent" then object.Event = signal() end
    return object
end
function methods:IsA(class)
    return self.ClassName == class or (class == "BasePart" and (self.ClassName == "Part" or self.ClassName == "VehicleSeat"))
end
function methods:GetChildren()
    local result = {}
    for _, object in ipairs(objects) do if object.Parent == self then table.insert(result, object) end end
    return result
end
function methods:FindFirstChild(name, recursive)
    for _, object in ipairs(self:GetChildren()) do
        if object.Name == name then return object end
        if recursive then local child = object:FindFirstChild(name, true); if child then return child end end
    end
end
methods.WaitForChild = methods.FindFirstChild
function methods:FindFirstChildWhichIsA(class, recursive)
    for _, object in ipairs(self:GetChildren()) do
        if object:IsA(class) then return object end
        if recursive then local child = object:FindFirstChildWhichIsA(class, true); if child then return child end end
    end
end
methods.FindFirstChildOfClass = methods.FindFirstChildWhichIsA
function methods:IsDescendantOf(ancestor)
    local parent = self.Parent
    while parent do if parent == ancestor then return true end; parent = parent.Parent end
    return false
end
function methods:GetAttribute(name) return self.attrs[name] end
function methods:GetAttributes() return self.attrs end
function methods:SetAttribute(name, value) self.attrs[name] = value end
function methods:Fire(...) self.Event:Fire(...) end
function methods:Destroy()
    if self.destroyed then return end
    self.destroyed = true
    self.Destroying:Fire()
    for _, child in ipairs(self:GetChildren()) do child:Destroy() end
    self.Parent = nil
end
function methods:GetPivot() return CFrame.new() end
function methods:PivotTo(value) self.lastPivot = value end
Instance = { new = new }
workspace = new("Workspace")
workspace.Gravity = 196.2
workspace.CurrentCamera = { CFrame = CFrame.new(), Focus = CFrame.new(), FieldOfView = 70, CameraType = "Custom" }
local cars = new("Folder", "Cars", workspace)
Car = new("Model", "Roadster_123", cars)
Car.attrs = { Owner = 123, Accel = 50, GripScale = 1.22, BoostScale = 1, RideHeight = 1.85 }
Chassis = new("Part", "Chassis", Car)
Chassis.Position, Chassis.CFrame = Vector3.zero, CFrame.new()
Chassis.AssemblyLinearVelocity, Chassis.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
Chassis.AssemblyMass = 100
Car.PrimaryPart = Chassis
Seat = new("VehicleSeat", "DriverSeat", Car)
Seat.ThrottleFloat, Seat.SteerFloat = 1, 0
Player = new("Player")
Player.UserId = 123
Player.Character = new("Model", "Character", workspace)
Humanoid = new("Humanoid", "Humanoid", Player.Character)
Humanoid.Health, Humanoid.SeatPart = 100, Seat
Seat.Occupant = Humanoid
PlayerGui = new("PlayerGui", "PlayerGui", Player)
Run = { PreSimulation = signal(), Heartbeat = signal(), RenderStepped = signal() }
Input = { InputBegan = signal(), keys = {} }
function Input:GetFocusedTextBox() return self.focus end
function Input:IsKeyDown(key) return self.keys[key] end
local services = { Players = { LocalPlayer = Player }, RunService = Run, UserInputService = Input,
    ReplicatedStorage = new("ReplicatedStorage") }
game = { GetService = function(_, name) return assert(services[name], name) end,
    HttpGet = function(_, url) assert(url == "https://sirius.menu/gen2"); return "return MockRayfield" end }
loadstring = load
UI, Windows = {}, {}
local tab = {}
local function element(props, kind)
    assert(props.Name == nil and props.Callback == nil, "Gen1 properties are not accepted")
    local handle = { value = props.value, text = props.text, props = props, kind = kind }
    function handle:Set(value, silent)
        self.value, self.text = value, value
        if not silent and props.callback then props.callback(value) end
    end
    UI[props.flag or props.name or tostring(handle)] = handle
    return handle
end
for _, kind in ipairs({ "Toggle", "Slider", "Dropdown", "Text", "Button", "Section" }) do
    tab["Create" .. kind] = function(_, props) return element(props, kind) end
end
MockRayfield = { CreateWindow = function(_, props)
    assert(props.name and props.sidebarLayout and props.theme == "rose")
    local window = { props = props, unloaded = false }
    function window:CreateTab(p) assert(p.name); return tab end
    function window:Notify(p) self.notice = p end
    function window:Unload() self.unloaded = true end
    function window:ToggleHide() self.hidden = not self.hidden end
    function window:ChangeTheme(value) self.theme = value end
    table.insert(Windows, window)
    return window
end }
function Launch() assert(load(BUNDLE))(); Run.Heartbeat:Fire(1) end
function Set(flag, value) assert(UI[flag], flag):Set(value) end
function Click(name) assert(UI[name], name).props.callback() end
