GParticleSystem = GParticleSystem or {}
GParticleSystem.__internal = GParticleSystem.__internal or {}

local gnet = {}
local emitRateLimits = {}
local gparticle = include("gparticle.lua")

-- ConVars
local cvar_unreliable = CreateConVar("sv_gparticle.net.unreliable", "1", FCVAR_ARCHIVE + FCVAR_UNREGISTERED,
    "1 = stable net but may lose visuals, 0 = non-stable net but visuals always show", 0, 1)
local cvar_optimized = CreateConVar("sv_gparticle.net.optimized", "0", FCVAR_ARCHIVE + FCVAR_UNREGISTERED,
    "1 = particles only sent to players who might see them", 0, 1)
local cvar_max_count = CreateConVar("sv_gparticle.max.count", "32", FCVAR_ARCHIVE + FCVAR_UNREGISTERED,
    "Maximum particles per emit call", 1, 256)
local cvar_trace_check = CreateConVar("sv_gparticle.trace.check", "1", FCVAR_ARCHIVE + FCVAR_UNREGISTERED,
    "Prevents emission if inside wall", 0, 1)
local cvar_emit_cooldown = CreateConVar("sv_gparticle.cooldown", "0.025", FCVAR_ARCHIVE + FCVAR_UNREGISTERED,
    "Cooldown between particle emits (per ID)", 0.000001, 0.25)

-- Network
util.AddNetworkString("gparticle.emit")
util.AddNetworkString("gparticle.clear")

-- Utility Functions
local function IsValidPlayer(ply)
    return IsValid(ply) and ply:IsPlayer() and not ply:IsBot()
end

local function IsVisiblePosition(pos)
    if not cvar_trace_check:GetBool() then return true end

    local tr = util.TraceLine({
        start = pos,
        endpos = pos + Vector(0, 0, 1),
        mask = MASK_SOLID_BRUSHONLY
    })

    return not tr.StartSolid
end

local function GetWind()
    return GParticleSystem.__internal.GetWindVelocity() or Vector(0, 0, 0)
end

local function GetTurbulence()
    return GParticleSystem.__internal.GetWindTurbulence() or 0
end

-- Core network emitter
local function TransmitParticle(gp, target)
    local pos = gp:GetPos()
    if not isvector(pos) or not IsVisiblePosition(pos) then return end

    local particleID = gp:GetParticleID() or "__default"
    local now = CurTime()

    -- Rate limiting
    if cvar_optimized:GetBool() then
        if emitRateLimits[particleID] and now < emitRateLimits[particleID] then return end
        emitRateLimits[particleID] = now + cvar_emit_cooldown:GetFloat()
    end

    -- Send
    net.Start("gparticle.emit", cvar_unreliable:GetBool())
    gp:WriteToNet()

    if target then
        if IsValidPlayer(target) then net.Send(target) end
    elseif cvar_optimized:GetBool() then
        net.SendPVS(pos)
    else
        net.Broadcast()
    end
end

-- Emit globally
function gnet:Emit(data)
    local gp = gparticle:new(data)
    gp.count = math.Clamp(tonumber(data.count) or 1, 1, cvar_max_count:GetInt())

    if hook.Run("gparticle.PreEmit", gp) == false then return end

    TransmitParticle(gp)
    hook.Run("gparticle.PostEmit", gp)
end

-- Emit to one player
function gnet:EmitToPlayer(data, ply)
    if not IsValidPlayer(ply) then return end

    local gp = gparticle:new(data)
    gp.count = math.Clamp(tonumber(data.count) or 1, 1, cvar_max_count:GetInt())

    if hook.Run("gparticle.PreEmit", gp, ply) == false then return end

    TransmitParticle(gp, ply)
    hook.Run("gparticle.PostEmit", gp, ply)
end

-- Clear particles
function gnet:ClearAll()
    net.Start("gparticle.clear", false)
    net.Broadcast()
    hook.Run("gparticle.ClearAll")
end

-- Clear for specific player
function gnet:ClearToPlayer(ply)
    if not IsValidPlayer(ply) then return end
    net.Start("gparticle.clear", false)
    net.Send(ply)
    hook.Run("gparticle.ClearToPlayer", ply)
end

-- Register network logic
GParticleSystem.__internal.gnet = gnet

-- API
function GParticleSystem:Emit(gparticleData)
    gnet:Emit(gparticleData)
end

function GParticleSystem:EmitToPlayer(gparticleData, ply)
    gnet:EmitToPlayer(gparticleData, ply)
end

function GParticleSystem:ClearAll()
    gnet:ClearAll()
end

function GParticleSystem:ClearToPlayer(ply)
    gnet:ClearToPlayer(ply)
end

function GParticleSystem:GetWindVelocity()
    return self.__internal.GetWindVelocity()
end

concommand.Add("gparticle_test", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local tr = ply:GetEyeTrace()
    local basePos = tr.HitPos
    local normal = tr.HitNormal

    GParticleSystem:Emit({
        pos        = basePos,
        normal     = normal,
        lifetime   = 10, -- can be changed in cyclic function
        effectName = "particles/dust",
        particleID = "examples.sand",
        count      = 50,
        emitRate   = 0.0025,
    })
end)