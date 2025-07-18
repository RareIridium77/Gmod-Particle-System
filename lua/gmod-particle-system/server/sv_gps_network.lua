GParticleSystem = GParticleSystem or {}
GParticleSystem.__internal = GParticleSystem.__internal or {}

local gnet = {}
local gparticle = include("gparticle.lua")

local unreliableCvar = CreateConVar(
    "sv_gparticle_unreliable", "1",
    bit.bor(FCVAR_ARCHIVE, FCVAR_UNREGISTERED),
    "1 means stable network but visuals are bad. 0 means non-stable network, but visuals are always correct",
    0, 1
)

local optimizedCvar = CreateConVar(
    "sv_gparticle_optimized_net", "1",
    bit.bor(FCVAR_ARCHIVE, FCVAR_UNREGISTERED),
    "1 particle will showed only to player that can see it possibly. 0 every player will noticed about particled without checking visuals",
    0, 1
)

local maxCountCvar = CreateConVar(
    "sv_gparticle_max_count", "32",
    bit.bor(FCVAR_ARCHIVE, FCVAR_UNREGISTERED),
    "Max count that client can emit one time",
    1, 256
)

local tracingCvar = CreateConVar(
    "sv_gparticle_trace_check", "1",
    bit.bor(FCVAR_ARCHIVE, FCVAR_UNREGISTERED),
    "If enabled, prevents particle emission from positions that are blocked (e.g., inside walls)",
    0, 1
)

util.AddNetworkString("gparticle.emit")
util.AddNetworkString("gparticle.clear")

local IsValidPlayer = function(ply)
    return IsValid(ply) and ply:IsPlayer() and not ply:IsBot()
end

local IsTraceVisible = function(pos)
    if not tracingCvar:GetBool() then return true end

    local tr = util.TraceLine({
        start = pos,
        endpos = pos + Vector(0, 0, 1),
        mask = MASK_SOLID_BRUSHONLY
    })
    return not tr.StartSolid
end

function gnet:Emit(dt)
    local gp = gparticle:new(dt)
    local maxCnt = maxCountCvar:GetInt()

    gp.count = math.min(dt.count or 1, maxCnt) -- limit

    if not IsTraceVisible(gp:GetPos()) then return end

    local ok = hook.Run("gparticle.PreEmit", gp)
    if ok == false then return end

    net.Start("gparticle.emit", unreliableCvar:GetBool())
    gp:WriteToNet()
    if optimizedCvar:GetBool() then
        net.SendPVS(gp:GetPos())
    else
        net.Broadcast()
    end

    hook.Run("gparticle.PostEmit", gp)
end

function gnet:EmitToPlayer(dt, ply)
    if not IsValidPlayer(ply) then return end

    local gp = gparticle:new(dt)

    if not IsTraceVisible(gp:GetPos()) then return end

    local ok = hook.Run("gparticle.PreEmit", gp, ply)
    if ok == false then return end

    net.Start("gparticle.emit", unreliableCvar:GetBool())
    gp:WriteToNet()
    net.Send(ply)

    hook.Run("gparticle.PostEmit", gp, ply)
end

function gnet:ClearAll()
    net.Start("gparticle.clear", false)
    net.Broadcast()
    hook.Run("gparticle.ClearAll")
end

function gnet:ClearToPlayer(ply)
    if not IsValidPlayer(ply) then return end
    net.Start("gparticle.clear", false)
    net.Send(ply)
    hook.Run("gparticle.ClearToPlayer", ply)
end

GParticleSystem.__internal.gnet = gnet