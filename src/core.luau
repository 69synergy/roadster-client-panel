-- Pure control calculations and reversible attribute overrides.
local Core = {}
function Core.clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end
function Core.canDrive(owner, userId, occupant, humanoid, seatPart, seat)
    return owner ~= nil and tostring(owner) == tostring(userId)
        and humanoid ~= nil and occupant == humanoid and seat ~= nil and seatPart == seat
end
function Core.stepSpeed(current, throttle, acceleration, limit, dt)
    throttle = Core.clamp(throttle, -1, 1)
    dt = Core.clamp(dt, 0, 0.1)
    limit = math.max(0, limit)
    if math.abs(throttle) < 0.02 then return Core.clamp(current, -limit, limit) end
    local target = limit * throttle
    local delta = math.max(0, acceleration) * dt
    if current < target then return math.min(current + delta, target) end
    return math.max(current - delta, target)
end
function Core.gripFactor(strength, dt)
    return math.exp(-math.max(0, strength) * Core.clamp(dt, 0, 0.1))
end
function Core.newOverrides()
    local self = { vehicle = nil, saved = {} }
    function self:restore()
        if self.vehicle then
            for name, record in pairs(self.saved) do
                -- Preserve values changed by the game after our last write.
                if self.vehicle:GetAttribute(name) == record.last then
                    self.vehicle:SetAttribute(name, record.original)
                end
            end
        end
        self.vehicle, self.saved = nil, {}
    end
    function self:apply(vehicle, values)
        if self.vehicle ~= vehicle then self:restore(); self.vehicle = vehicle end
        if not vehicle then return end
        for name, value in pairs(values) do
            local current = vehicle:GetAttribute(name)
            local record = self.saved[name]
            if not record then record = { original = current }; self.saved[name] = record
            elseif current ~= record.last then record.original = current end
            vehicle:SetAttribute(name, value)
            record.last = value
        end
    end
    return self
end
return Core
