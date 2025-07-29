GParticleSystem = GParticleSystem or {}
GParticleSystem.__internal = GParticleSystem.__internal or {}

GParticleSystem.__internal.wind = GParticleSystem.__internal.wind or {}
local wind = GParticleSystem.__internal.wind

local useWindCvar = CreateConVar(
    "sv_gparticle.wind.enabled", "1",
    FCVAR_NONE,
    "Enable or disable wind affecting particles"
)

local windDirCvar = CreateConVar(
    "sv_gparticle.wind.direction", "90",
    FCVAR_NONE,
    "Wind direction in degrees (0 = North, 90 = East, etc.)",
    0, 360
)

local windForceCvar = CreateConVar(
    "sv_gparticle.wind.force", "2",
    FCVAR_NONE,
    "Wind force in m/s",
    0, 2048
)

local windTurbCvar = CreateConVar(
    "sv_gparticle.wind.turbulence", "0.25",
    FCVAR_NONE,
    "Turbulence force of wind",
    0, 5
)

local utom = 39.37 -- units to meters
local cachedWindVec = vector_origin
local lastUpdateFrame = -1

function wind:GetWindTurbulence()
    if not useWindCvar:GetBool() then return 0 end
    
    return windTurbCvar:GetFloat() * utom
end

function wind:GetWindVelocity()
    if not useWindCvar:GetBool() then return vector_origin end

    local frame = FrameNumber()
    if frame == lastUpdateFrame then
        return cachedWindVec
    end

    lastUpdateFrame = frame

    local degrees = windDirCvar:GetFloat()
    local radians = math.rad(degrees)

    local x = math.sin(radians)
    local y = math.cos(radians)
    cachedWindVec = Vector(x, y, 0) * windForceCvar:GetFloat() * utom

    return cachedWindVec
end

function wind:ApplyWindToParticle(p, forceMul, turbMul, seed)
    if not p then return false end

    forceMul = forceMul or 1
    turbMul = turbMul or 1
    seed = seed or 0

    local windVel = wind:GetWindVelocity() * forceMul
    local turb = wind:GetWindTurbulence() * turbMul

    if turb > 0 then
        windVel = windVel + VectorRand() * turb
    end

    p:SetGravity(p:GetGravity() + windVel)
    debugoverlay.Line(p:GetPos(), p:GetPos() + p:GetGravity(), 1, Color(255, 255, 0), true)
    return true 
end

GParticleSystem.__internal.wind = wind

-- API
GParticleSystem.Wind = GParticleSystem.Wind or {}

function GParticleSystem.Wind:GetWindTurbulence() return wind:GetWindTurbulence() end
function GParticleSystem.Wind:GetWindVelocity() return wind:GetWindVelocity() end
function GParticleSystem.Wind:ApplyWindToParticle(particle, forceMul, turbMul, seed)
    return wind:ApplyWindToParticle(particle, forceMul, turbMul, seed)
end