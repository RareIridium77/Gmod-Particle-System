GParticleSystem = GParticleSystem or {}
GParticleSystem.__internal = GParticleSystem.__internal or {}

GParticleSystem.CyclicFuncs = GParticleSystem.CyclicFuncs or {}

function GParticleSystem.__internal:RegisterCycle(name, func, force)
    assert(isstring(name), "Cycle name must be a string")
    assert(isfunction(func), "Cycle function must be a function")

    if not GParticleSystem.CyclicFuncs[name] or force then
        GParticleSystem.CyclicFuncs[name] = func
    else
        ErrorNoHaltWithStack("[GParticleSystem] Cycle '" .. name .. "' already exists. Use force=true to override.\n")
    end
end

function GParticleSystem.__internal:EmitCycle(name, particle, step, gparticle)
    local func = GParticleSystem.CyclicFuncs[name]
    if isfunction(func) then
        return func(particle, step, gparticle)
    else
        ErrorNoHaltWithStack("[GParticleSystem] Warning: No cyclic function for '".. name)
    end
end

function GParticleSystem:RegisterCycle(name, func, force)
    return GParticleSystem.__internal:RegisterCycle(name, func, force)
end

function GParticleSystem:EmitCycle(name, particle, i, gp)
    return GParticleSystem.__internal:EmitCycle(name, particle, i, gp)
end


--- Example GParticle Cycle ---
GParticleSystem:RegisterCycle("examples.sand", function(p, i, gp)
    local rnd = math.Rand
    local rn = math.random

    local normal = gp:GetNormal()
    local basePos = gp:GetPos()

    local wind = GParticleSystem.__internal.wind
    local windVec = wind and wind:GetWindVelocity() or Vector(0, 0, 0)
    local turbulence = wind and wind:GetWindTurbulence() or 0

    local time = CurTime()
    local wobble = Vector(
        math.sin(time * 6 + i) * turbulence,
        math.cos(time * 5.2 + i) * turbulence,
        0
    )

    local dir = (normal * 200 + VectorRand() * rnd(30, 60) + windVec + wobble):GetNormalized()
    p:SetVelocity(dir * rnd(80, 130))

    p:SetGravity(Vector(0, 0, -250))
    p:SetAirResistance(20)
    p:SetStartAlpha(200)
    p:SetEndAlpha(0)

    p:SetStartSize(rnd(5, 6.5))
    p:SetEndSize(0)

    p:SetColor(rn(180, 200), rn(160, 180), rn(120, 130))

    p:SetCollide(true)
    p:SetBounce(0.1)
    p:SetLighting(false)
end, true)
