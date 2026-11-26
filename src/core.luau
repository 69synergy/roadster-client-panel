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
function Core.newCoinRoute()
    local self = { target = nil, skipped = {}, observed = 0, message = "Disabled" }
    local function distance(a, b)
        return math.sqrt((a.X-b.X)^2 + (a.Y-b.Y)^2 + (a.Z-b.Z)^2)
    end
    local function close(a, b)
        return (a.X-b.X)^2 + (a.Z-b.Z)^2 <= 25 and math.abs(a.Y-b.Y) <= 8
    end
    function self:pause(message)
        self.target = nil
        self.message = message or "Paused"
    end
    function self:step(points, position, now)
        for i = #self.skipped, 1, -1 do
            if self.skipped[i].untilTime <= now then table.remove(self.skipped, i) end
        end
        local target = self.target
        if target then
            local visible = false
            for _, point in ipairs(points) do
                if distance(point, target.position) < 2 then visible = true; break end
            end
            local remaining = distance(position, target.position)
            if not visible then
                if target.reached or close(position, target.position) then self.observed = self.observed + 1 end
                table.insert(self.skipped, { position = target.position, untilTime = now + 30 })
                self.target = nil
            elseif now - target.started > 30 or now - target.progressAt > 4
                or (target.reached and now - target.reached > 2) then
                table.insert(self.skipped, { position = target.position, untilTime = now + 30 })
                self.target = nil
                self.message = "Skipped stalled or unconfirmed pickup"
                return nil
            else
                if remaining < target.best - 1 then target.best = remaining; target.progressAt = now end
                if close(position, target.position) then target.reached = target.reached or now end
                self.message = target.reached and "In pickup range; waiting for game controller" or "Moving to visible coin"
                return target.position
            end
        end
        local best, bestDistance
        for _, point in ipairs(points) do
            local blocked = false
            for _, entry in ipairs(self.skipped) do
                if distance(point, entry.position) < 2 then blocked = true; break end
            end
            local dd = distance(position, point)
            if not blocked and (not bestDistance or dd < bestDistance) then best, bestDistance = point, dd end
        end
        if best then
            self.target = { position = best, started = now, progressAt = now, best = bestDistance }
            self.message = "Moving to visible coin"
            return best
        end
        self.message = "No available visible coins; check your active coin quest"
        return nil
    end
    return self
end
return Core
