local GParticle = {}
GParticle.__index = GParticle

local dParams = {
    use3D         = false,

    lifetime      = 2.5,
    pos           = Vector(0, 0, 0),
    normal        = Vector(0, 0, 1),
    effectName    = "particles/dust",

    count         = 1,
    repeatCount   = 0,
    repeatDelay   = 0,

    emitRate      = 0,

    entityID      = -1,
    particleID    = "basic",
}

local dParamTypes = {
    use3D        = "bool",

    lifetime     = "float",
    pos          = "vector",
    normal       = "vector",
    effectName   = "string",

    count        = "int",
    repeatCount  = "int",
    repeatDelay  = "float",

    emitRate     = "float",

    entityID     = "int",
    particleID   = "string",
}

-- Map field names to compact indices
local paramIndexMap = {}
local indexParamMap = {}

do
    local idx = 0
    for k, _ in pairs(dParams) do
        paramIndexMap[k] = idx
        indexParamMap[idx] = k
        idx = idx + 1
    end
end

local sub   = string.sub
local upper = string.upper

-- Auto setter, getter
for k, _ in pairs(dParams) do
    local clized = upper(sub(k, 1, 1)) .. sub(k, 2)
    GParticle["Set" .. clized] = function(self, v) self[k] = v end
    GParticle["Get" .. clized] = function(self) return self[k] end
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
        net.WriteUInt(r, 8)
        net.WriteUInt(g, 8)
        net.WriteUInt(b, 8)
    end,
    bool   = function(v) net.WriteBit(v) end,
    string = function(v) net.WriteString(string.sub(v, 1, stringLimit)) end,
    int    = function(v) net.WriteInt(math.Clamp(v, -intLimit, intLimit), 16) end,
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
        local changed = {}

        for k, typ in pairs(dParamTypes) do
            local v = self[k]
            local def = dParams[k]
            if v ~= def then
                changed[#changed + 1] = k
            end
        end

        net.WriteUInt(#changed, 6) -- up to 64 fields

        for _, k in ipairs(changed) do
            local index = paramIndexMap[k]
            net.WriteUInt(index, 6) -- send param ID
            netWriters[dParamTypes[k]](self[k])
        end
    end
end

if CLIENT then
    function GParticle.ReadFromNet()
        local obj = setmetatable({}, GParticle)

        -- Set default first
        for k, v in pairs(dParams) do
            obj[k] = v
        end

        local count = net.ReadUInt(6)
        for i = 1, count do
            local index = net.ReadUInt(6)
            local k = indexParamMap[index]
            local typ = dParamTypes[k]
            obj[k] = netReaders[typ]()
        end

        return obj
    end
end

return GParticle
