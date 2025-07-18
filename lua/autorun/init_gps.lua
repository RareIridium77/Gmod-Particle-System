AddCSLuaFile()
AddCSLuaFile("gparticle.lua")
AddCSLuaFile("gmod-particle-system/client/cl_gps_network.lua")

GParticleSystem = GParticleSystem or {}
GParticleSystem.Version = "0.0.2"

-- Shared
include("gparticle.lua")

-- Client
if CLIENT then
    include("gmod-particle-system/client/cl_gps_network.lua")
end

-- Server
if SERVER then
    include("gmod-particle-system/server/sv_gps_network.lua")
    include("gmod-particle-system/server/sv_gps_base.lua")
end

print("[GParticleSystem] Loaded v" .. GParticleSystem.Version)