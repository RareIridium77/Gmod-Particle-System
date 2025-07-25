local GParticle = {}
GParticle.__index = GParticle

local dParams = {
    lifetime      = 2.5,
    speed         = 1,
    color         = {194, 178, 128},
    pos           = Vector(0, 0, 0),
    use3D         = false,
    effectName    = "particles/dust",

    startAlpha    = 200,
    endAlpha      = 10,
    startSize     = 4,
    endSize       = 2,
    roll          = math.Rand(0, 360),
    rollDelta     = math.Rand(-0.5, 0.5),
    gravity       = Vector(0, 0, -250),
    airResistance = 10,
    velocity      = Vector(0, 0, 0),
    collide       = true,
    bounce        = 0.2,
    lighting      = false,
    angleVel      = Angle(0, 0, 0),
    count         = 1,
    emitRate      = 0,
    entityID      = -1,
    particleID    = "basic",
    wind          = vector_origin,
    windTurbulence= 0.05,
}

local dParamTypes = {
    lifetime     = "float",
    speed        = "float",
    color        = "color",
    pos          = "vector",
    use3D        = "bool",
    effectName   = "string",

    startAlpha   = "int",
    endAlpha     = "int",
    startSize    = "float",
    endSize      = "float",
    roll         = "float",
    rollDelta    = "float",
    gravity      = "vector",
    airResistance= "float",
    velocity     = "vector",
    collide      = "bool",
    bounce       = "float",
    lighting     = "bool",
    angleVel     = "angle",
    count        = "int",
    emitRate     = "float",
    entityID     = "int",
    particleID   = "string",
    wind         = "vector",
    windTurbulence="float"
}

local sub   = string.sub
local upper = string.upper

-- Auto setter, getter
for k, _ in pairs(dParams) do
    local clized = upper(sub(k, 1, 1)) .. sub(k, 2)
    GParticle["Set" .. clized] = function(self, v)
        self[k] = v
    end
    GParticle["Get" .. clized] = function(self)
        return self[k]
    end
end

function GParticle:new(params)
    local obj = setmetatable({}, self)

    if params and IsValid(params.entityParent) then
        obj.entityID = params.entityParent:EntIndex()
    end

    for k, default in pairs(dParams) do
        obj[k] = (params and params[k] ~= nil) and params[k] or default
    end

    return obj
end

function GParticle:AddGravity(gravity)
    assert(isvector(gravity), "gravity is not vector. Cannot add it")
    self.gravity = self.gravity + gravity
end

function GParticle:AddVelocity(velocity)
    assert(isvector(velocity), "velocity is not vector. Cannot add it")
    self.velocity = self.velocity + velocity
end

function GParticle:ToTable()
    local data = {}
    for k in pairs(dParams) do
        data[k] = self[k]
    end
    return data
end

--- [ Net type dispatch ] ---

local floatLimit = 131072
local intLimit = 32768
local stringLimit = 128

local netWriters = {
    float  = function(v) net.WriteFloat(math.Clamp(v, -floatLimit, floatLimit)) end,
    vector = function(v) net.WriteVector(v) end,
    color = function(v)
        local r, g, b = 255, 255, 255
        if IsColor(v) then
            r, g, b = v.r, v.g, v.b
        elseif istable(v) and #v >= 3 then
            r, g, b = v[1], v[2], v[3]
        end
        net.WriteUInt(r or 255, 8)
        net.WriteUInt(g or 255, 8)
        net.WriteUInt(b or 255, 8)
    end,
    bool   = function(v) net.WriteBit(v) end,
    string = function(v) net.WriteString(string.sub(v, 1, stringLimit or 128)) end,
    int = function(v) net.WriteInt(math.Clamp(v, -intLimit, intLimit), 16) end,
    angle  = function(v) net.WriteAngle(v) end
}

local netReaders = {
    float  = function() return net.ReadFloat() end,
    vector = function() return net.ReadVector() end,
    color  = function()
        return { net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8) }
    end,
    bool   = function() return tobool(net.ReadBit()) end,
    string = function() return net.ReadString() end,
    int    = function() return net.ReadInt(16) end,
    angle  = function() return net.ReadAngle() end
}

if SERVER then
    function GParticle:WriteToNet()
        for k, typ in pairs(dParamTypes) do
            local writeFunc = netWriters[typ]
            if writeFunc then
                writeFunc(self[k])
            end
        end
    end
end

if CLIENT then
    function GParticle.ReadFromNet()
        local obj = setmetatable({}, GParticle)
        for k, typ in pairs(dParamTypes) do
            local readFunc = netReaders[typ]
            if readFunc then
                obj[k] = readFunc()
            end
        end
        return obj
    end
end

return GParticle
