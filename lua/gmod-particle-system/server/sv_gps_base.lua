GParticleSystem = GParticleSystem or {}
GParticleSystem.__internal = GParticleSystem.__internal or {}

local gnet = GParticleSystem.__internal.gnet

if not gnet then
    ErrorNoHalt("[GParticleSystem] Warning: __internal.gnet is not defined!\n")
    return
end

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

concommand.Add("gparticle_test", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local tr = ply:GetEyeTrace()
    local basePos = tr.HitPos
    local normal = tr.HitNormal

    for i = 1, 12 do
        local spread = VectorRand() * 0.5
        local dir = (normal * 2 + spread):GetNormalized()
        local pos = basePos + normal * 2 + VectorRand() * 2

        GParticleSystem:Emit({
            pos           = pos,
            effectName    = "particles/dust",
            lifetime      = math.Rand(1.8, 7),
            speed         = 25,
            startSize     = math.Rand(5, 7),
            endSize       = math.Rand(1, 2),
            color         = {194, 178, 128},
            gravity       = Vector(0, 0, -400),
            airResistance = 6,
            velocity      = dir * math.Rand(100, 140),
            roll          = math.Rand(0, 360),
            rollDelta     = math.Rand(-1.2, 1.2),
            collide       = true,
            lighting      = true,
            bounce        = 0.25,
            particleID    = "sand_impact",
            count         = 8,
            emitRate      = 0.01
        })
    end
end)

