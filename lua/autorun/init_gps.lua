AddCSLuaFile()
AddCSLuaFile("gparticle.lua")
AddCSLuaFile("gmod-particle-system/client/cl_gps_wind.lua")
AddCSLuaFile("gmod-particle-system/client/cl_gps_cyclic.lua")
AddCSLuaFile("gmod-particle-system/client/cl_gps_network.lua")

GParticleSystem = GParticleSystem or {}
GParticleSystem.Version = "0.0.4"
GParticleSystem.VersionType = "beta"

-- Client
if CLIENT then
    include("gmod-particle-system/client/cl_gps_wind.lua")
    include("gmod-particle-system/client/cl_gps_cyclic.lua")
    include("gmod-particle-system/client/cl_gps_network.lua")

    print("[GParticleSystem] Loaded v" .. GParticleSystem.Version .. "-" .. GParticleSystem.VersionType)
end

-- Server
if SERVER then
    include("gmod-particle-system/server/sv_gps_network.lua")

    local FCVAR_SERVER = bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED)

    CreateConVar(
        "sv_gparticle.wind.enabled", "1",
        FCVAR_SERVER,
        "Enable or disable wind affecting particles"
    )

    CreateConVar(
        "sv_gparticle.wind.direction", "90",
        FCVAR_SERVER,
        "Wind direction in degrees (0 = North, 90 = East, etc.)",
        0, 360
    )

    CreateConVar(
        "sv_gparticle.wind.force", "2",
        FCVAR_SERVER,
        "Wind force in m/s",
        0, 2048
    )

    CreateConVar(
        "sv_gparticle.wind.turbulence", "0.25",
        FCVAR_SERVER,
        "Turbulence force of wind",
        0, 5
    )
end