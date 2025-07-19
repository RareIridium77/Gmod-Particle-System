GParticleSystem = GParticleSystem or {}
GParticleSystem.__internal = GParticleSystem.__internal or {}

local useWindCvar = CreateConVar(
    "sv_gparticle_use_wind", "1",
    FCVAR_ARCHIVE,
    "Enable or disable wind affecting particles"
)

local windDirCvar = CreateConVar(
    "sv_gparticle_wind_direction", "90",
    FCVAR_ARCHIVE,
    "Wind direction in degrees (0 = North, 90 = East, etc.)",
    0, 360
)

local windForceCvar = CreateConVar(
    "sv_gparticle_wind_force", "2",
    FCVAR_ARCHIVE,
    "Wind force in m/s",
    0, 2048
)

local windTurbCvar = CreateConVar(
    "sv_gparticle_wind_turbulence", "0.25",
    FCVAR_ARCHIVE,
    "Turbulence force of wind",
    0, 5
)

local utom = 39.37 -- units to meters

function GParticleSystem.__internal.GetWindTurbulence()
    if not useWindCvar:GetBool() then return 0 end
    
    return windTurbCvar:GetFloat() * utom
end

local cachedWindVec = vector_origin
local lastUpdateFrame = -1

function GParticleSystem.__internal.GetWindVelocity()
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