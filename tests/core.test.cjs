const { test } = require('node:test');
const fs = require('node:fs');
const run = require('./lua.cjs');
const core = 'local Core = (function()\n' + fs.readFileSync('src/core.luau', 'utf8') + '\nend)()\n';
test('speed controller: acceleration, reverse, deadzone, lag cap, no overshoot', () => run(core + `
assert(Core.stepSpeed(0, 1, 100, 180, 0.1) == 10)
assert(Core.stepSpeed(175, 1, 100, 180, 0.1) == 180)
assert(Core.stepSpeed(0, -1, 100, 180, 0.1) == -10)
assert(Core.stepSpeed(40, 0, 100, 180, 0.1) == 40)
assert(Core.stepSpeed(200, 0, 100, 180, 0.1) == 180)
assert(Core.stepSpeed(0, 1, 100, 180, 10) == 10)
assert(Core.stepSpeed(40, 1, 100, 180, -1) == 40)
assert(Core.stepSpeed(0, 0.5, 1000, 100, 0.1) == 50)
`));
test('grip damping is frame-rate independent for ordinary steps', () => run(core + `
local a = Core.gripFactor(4, 1/60)^60
local b = Core.gripFactor(4, 1/30)^30
assert(math.abs(a - b) < 0.000001)
assert(Core.gripFactor(0, 0.1) == 1)
`));
test('control gate rejects non-owners, empty seats and passengers', () => run(core + `
local human, other, driver, passenger = {}, {}, {}, {}
assert(Core.canDrive(123, 123, human, human, driver, driver))
assert(Core.canDrive("123", 123, human, human, driver, driver))
assert(not Core.canDrive(456, 123, human, human, driver, driver))
assert(not Core.canDrive(123, 123, other, human, driver, driver))
assert(not Core.canDrive(123, 123, nil, nil, driver, driver))
assert(not Core.canDrive(123, 123, human, human, passenger, driver))
assert(not Core.canDrive(nil, 123, human, human, driver, driver))
`));
test('attribute restore handles nil/false and preserves newer game values', () => run(core + `
local function vehicle(values)
    return { GetAttribute = function(_, k) return values[k] end,
        SetAttribute = function(_, k, v) values[k] = v end }
end
local values = { Accel = 50, Flag = false }
local first = vehicle(values)
local overrides = Core.newOverrides()
overrides:apply(first, { Accel = 100, Flag = true, Missing = 3 })
assert(values.Accel == 100 and values.Flag and values.Missing == 3)
overrides:restore()
assert(values.Accel == 50 and values.Flag == false and values.Missing == nil)
overrides:apply(first, { Accel = 100 })
values.Accel = 75
overrides:restore()
assert(values.Accel == 75)
overrides:apply(first, { Accel = 100 })
values.Accel = 80
overrides:apply(first, { Accel = 120 })
overrides:restore()
assert(values.Accel == 80)
local secondValues = { Accel = 60 }
local second = vehicle(secondValues)
overrides:apply(first, { Accel = 100 })
overrides:apply(second, { Accel = 150 })
assert(values.Accel == 80 and secondValues.Accel == 150)
overrides:restore()
assert(secondValues.Accel == 60)
overrides:restore()
`));
