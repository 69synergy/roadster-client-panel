const { test } = require('node:test');
const fs = require('node:fs');
const run = require('./lua.cjs');
const fixture = fs.readFileSync('tests/fixture.lua', 'utf8');
const BUNDLE = fs.readFileSync('src/main.client.luau', 'utf8');
function scenario(code) { run(fixture + '\n' + code, { BUNDLE }); }
test('runtime: collector respects game mode, ignores sparkle, approaches coins and stops cleanly', () => scenario(`
Launch()
local coins = Instance.new("Folder")
coins.Name, coins.Parent = "LocalCoins", workspace
local sparkle = Instance.new("Part")
sparkle.Name, sparkle.Parent, sparkle.Position = "CoinSparkle", coins, Vector3.new(1,0,0)
local coin = Instance.new("Part")
coin.Name, coin.Parent, coin.Position = "Coin", coins, Vector3.new(100,0,0)
Set("speed", true)
Set("farm", true)
assert(UI.speed.value == false)
Run.PreSimulation:Fire(0.1)
assert(Chassis.AssemblyLinearVelocity.Magnitude == 0)
Player:SetAttribute("ClientMode", "Driving")
Run.PreSimulation:Fire(0.1)
assert(Chassis.AssemblyLinearVelocity.X == 60)
assert(Chassis:FindFirstChild("RoadsterHubLift"))
Chassis.Position = Vector3.new(98,0,0)
Run.PreSimulation:Fire(0.1)
assert(Chassis.AssemblyLinearVelocity.X == 4)
coin:Destroy()
Run.PreSimulation:Fire(0.1)
assert(Chassis.AssemblyLinearVelocity.Magnitude == 0)
Run.Heartbeat:Fire(0.25)
assert(string.find(UI["Collection status"].text, "Nearby disappearances observed: 1", 1, true))
Click("Stop collection")
assert(not Chassis:FindFirstChild("RoadsterHubLift"))
assert(UI.farm.value == false)
`));
test('runtime: collector pauses on seat exit and unload removes lift', () => scenario(`
Launch()
Player:SetAttribute("ClientMode", "Driving")
Set("farm", true)
Run.PreSimulation:Fire(0.1)
assert(Chassis:FindFirstChild("RoadsterHubLift"))
Seat.Occupant = nil
Run.PreSimulation:Fire(0.1)
assert(not Chassis:FindFirstChild("RoadsterHubLift"))
Seat.Occupant = Humanoid
Run.PreSimulation:Fire(0.1)
Click("Unload hub")
assert(not Chassis:FindFirstChild("RoadsterHubLift"))
assert(Run.PreSimulation:count() == 0)
`));
test('runtime: defaults do not mutate velocity; assist requires owner and occupied driver seat', () => scenario(`
Launch()
Run.PreSimulation:Fire(0.1)
assert(Chassis.AssemblyLinearVelocity.Magnitude == 0)
Set("speed", true)
Run.PreSimulation:Fire(0.1)
assert(Chassis.AssemblyLinearVelocity.Z == -10)
Car.attrs.Owner = 456
Run.PreSimulation:Fire(0.1)
assert(Chassis.AssemblyLinearVelocity.Z == -10)
Car.attrs.Owner = 123
Seat.Occupant = nil
Run.PreSimulation:Fire(0.1)
assert(Chassis.AssemblyLinearVelocity.Z == -10)
Seat.Occupant = Humanoid
Input.focus = {}
Run.PreSimulation:Fire(0.1)
assert(Chassis.AssemblyLinearVelocity.Z == -10)
`));
test('runtime: flight lift and attributes are restored on seat exit and panic', () => scenario(`
Launch()
Set("attrAccel", 150)
Set("attributes", true)
Set("flight", true)
Run.PreSimulation:Fire(0.1)
assert(Car.attrs.Accel == 150)
assert(Chassis:FindFirstChild("RoadsterHubLift").Force.Y == 19620)
assert(Chassis.AssemblyLinearVelocity.Z == -100)
Seat.Occupant = nil
Run.PreSimulation:Fire(0.1)
assert(Car.attrs.Accel == 50)
assert(not Chassis:FindFirstChild("RoadsterHubLift"))
Seat.Occupant = Humanoid
Run.PreSimulation:Fire(0.1)
Click("Disable all features / restore overrides")
assert(Car.attrs.Accel == 50)
assert(not Chassis:FindFirstChild("RoadsterHubLift"))
assert(UI.speed.value == false and UI.flight.value == false)
`));
test('runtime: rerun and Rayfield unload remove old listeners, lift and overrides', () => scenario(`
Launch()
Set("attributes", true)
Set("attrAccel", 140)
Set("flight", true)
Run.PreSimulation:Fire(0.1)
assert(Car.attrs.Accel == 140)
Launch()
assert(Windows[1].unloaded)
assert(Car.attrs.Accel == 50)
assert(not Chassis:FindFirstChild("RoadsterHubLift"))
assert(Run.PreSimulation:count() == 1 and Run.Heartbeat:count() == 1)
Windows[2]:Unload()
Run.PreSimulation:Fire(0.1)
assert(Run.PreSimulation:count() == 0 and Run.Heartbeat:count() == 0)
assert(Run.RenderStepped:count() == 0 and Input.InputBegan:count() == 0)
assert(not PlayerGui:FindFirstChild("RoadsterClientPanel"))
`));
